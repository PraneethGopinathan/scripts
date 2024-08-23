#!/bin/bash

# Simple script to check the status of all servers

RESOURCE_GROUP="voodyiowebsite"
VM_NAME="voodyio"
STATUS=$(az vm get-instance-view --resource-group $RESOURCE_GROUP --name $VM_NAME --query "instanceView.statuses[?code=='PowerState/running'] | [0].code" -o tsv)

start_vm() {
    az vm start --resource-group $RESOURCE_GROUP --name $VM_NAME
    echo "VM $VM_NAME started."
}

stop_vm() {
    az vm deallocate --resource-group $RESOURCE_GROUP --name $VM_NAME
    echo "VM $VM_NAME stopped."
}

healthcheck_vm() {
    if [ "$STATUS" == "PowerState/running" ]; then
        echo "VM $VM_NAME is running."
    else
        echo "VM $VM_NAME is not running."
    fi
}

case "$1" in
    start)
        start_vm
        ;;
    stop)
        stop_vm
        ;;
    healthcheck)
        healthcheck_vm
        ;;
    *)
        echo "Usage: $0 {start|stop|healthcheck}"
        exit 1
esac
