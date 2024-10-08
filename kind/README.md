# Kind cluster generator

This script is used to generate a config.yaml file which can be passed into kind to create a number of clusters

`generate-kind-nodes.yaml` is used to generate how many nodes of kind cluster should be created

```bash
bash generate-kind-nodes.yaml 5
```
will generate 
```yaml
# YAML is generated by generate-kind-nodes.sh
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
  - role: worker
  - role: worker
  - role: worker
  - role: worker
```
use this yaml file to create cluster with desired nodes

```bash
kind create cluster --config 5-node-cluster.yaml
```