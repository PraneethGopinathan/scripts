#!/bin/bash

# Script to create Kind clusters with a specified number of worker nodes
# Usage: ./kind-cluster.sh -n <number_of_nodes>

# Default values
NODE_COUNT=1
CLUSTER_NAME="kind"

# Parse command line arguments
while getopts "n:c:" opt; do
  case $opt in
    n) NODE_COUNT=$OPTARG ;;
    c) CLUSTER_NAME=$OPTARG ;;
    *) echo "Usage: $0 [-n node_count] [-c cluster_name]" >&2; exit 1 ;;
  esac
done

# Validate node count is a positive integer
if ! [[ "$NODE_COUNT" =~ ^[0-9]+$ ]] || [ "$NODE_COUNT" -lt 1 ]; then
  echo "Error: Node count must be a positive integer"
  exit 1
fi

echo "Creating Kind cluster '$CLUSTER_NAME' with $NODE_COUNT nodes (1 control-plane + $((NODE_COUNT-1)) workers)"

# Create config with one control-plane and N-1 worker nodes
CONFIG=$(cat <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: $CLUSTER_NAME
nodes:
- role: control-plane
EOF
)

# Add worker nodes
for ((i=1; i<NODE_COUNT; i++)); do
  CONFIG+=$'\n'"- role: worker"
done

# Create the cluster with the generated config
echo "$CONFIG" | kind create cluster --config=-

echo "Cluster created successfully!"
echo "To verify, run: kubectl get nodes"
