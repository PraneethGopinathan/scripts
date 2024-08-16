import os
from kubernetes import client, config
import boto3
from botocore.exceptions import ClientError
import json
import time

GREEN = "\033[32m"
RED = "\033[91m"
RESET = "\033[0m"

def extract_password_from_secret(secret_json):
    try:
        # Parse the JSON string
        parsed_secret = json.loads(secret_json)

        # Extract the password
        password = parsed_secret.get('password', None)

        return password
    except json.JSONDecodeError:
        # Handle JSON decoding error
        print("Error decoding JSON secret.")
        return None

def update_configmap_and_restart_deployments(namespace, configmap_name, password):
    # Access Kubernetes API
    kubernetes_api = client.CoreV1Api()
    apps_api = client.AppsV1Api()
    
    try:
        # Read existing ConfigMap
        configmap = kubernetes_api.read_namespaced_config_map(configmap_name, namespace)

        # Check if the password is different
        if configmap.data.get("POSTGRES_PASSWORD") != password:
            # Update ConfigMap with the new secret value
            configmap.data["POSTGRES_PASSWORD"] = password
            kubernetes_api.replace_namespaced_config_map(configmap_name, namespace, configmap)
         
            # Restart all deployments in the namespace
            deployments = apps_api.list_namespaced_deployment(namespace)
            for deployment in deployments.items:
                apps_api.patch_namespaced_deployment(deployment.metadata.name, namespace, {"spec": {"template": {"metadata": {"annotations": {"date": str(int(time.time()))}}}}})

            print(f"✅{GREEN}RDS password updated.{RESET}")
        else:
            print(f"✅{GREEN}RDS password is same, no update or restart required.{RESET}")
    except client.rest.ApiException as e:
        if e.status == 403:  # Forbidden error
            pass
        else:
            print(f"❌ Failed to update ConfigMap or restart deployments: {e}")

def get_secret_and_update_configmap(namespaces):
    # AWS Secrets Manager configuration
    secret_name = "<SECRET_ID"
    region_name = "<REGION>"

    configmap_name = "dev-config"

    try:
        # Load in-cluster Kubernetes config
        config.load_incluster_config()
    except config.config_exception.ConfigException:
        # If in-cluster config is not available, load kubeconfig
        config.load_kube_config()

    # Create a Secrets Manager client
    session = boto3.session.Session() #profile_name=aws_profile
    secrets_manager_client = session.client('secretsmanager', region_name=region_name)

    for namespace in namespaces:
        try:
            # Retrieve secret from AWS Secrets Manager
            secret_json = secrets_manager_client.get_secret_value(SecretId=secret_name)['SecretString']

            # Extract password from the secret
            password = extract_password_from_secret(secret_json)
            print(password)
            if password is not None:
                update_configmap_and_restart_deployments(namespace, configmap_name, password)
            else:
                print(f"")
        except ClientError as e:
            print(f"❌ {RED}Failed to retrieve secret from AWS Secrets Manager for namespace {RESET}: {e}")

if __name__ == "__main__":
    # Specify the namespaces you want to update
    target_namespaces = ["default"]
    get_secret_and_update_configmap(target_namespaces)
