### RDS Password Fetch

The `aws-secret-fetch-cronjob` is utilized to update the RDS master password in the EKS configmap. This cronjob is configured to run every hour for seven days, and this duration can be adjusted within the YAML file. The Helm chart, [`rds-update-job`](../remote/helm/rds-update-job/Chart.yaml), facilitates the creation of this cronjob.

The [`aws-secret.py`](aws-secret.py) script is responsible for fetching the latest RDS master password, updating it in the EKS configmap, and subsequently restarting all the deployments. The [`Dockerfile`](dockerfile) is used to build the script into an image and push it to ECR. The resulting image will be used by the cronjobs to spin up the pods and execute the RDS master password update process.

Ensure to specify the secret name and region according to your AWS account in the following section of the `aws-secret.py` script:

```python
secret_name = "<SECRET_ID>"
region_name = "<REGION>"
```

---