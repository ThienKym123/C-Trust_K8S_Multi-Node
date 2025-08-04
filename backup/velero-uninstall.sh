#!/bin/bash
# Velero Uninstall Script with logging
source k8s-setup/utils.sh
source k8s-setup/envVar.sh

set -e
logging_init

VELERO_NAMESPACE="velero"

confirm_uninstall() {
    log "WARNING: This will remove Velero and all backup schedules"
    log "Auto-confirm enabled. Proceeding with uninstall..."
}

uninstall_velero() {
    push_fn "Uninstalling Velero"
    velero schedule delete --all --namespace=$VELERO_NAMESPACE --confirm || true
    velero uninstall --namespace=$VELERO_NAMESPACE --force || true
    kubectl delete namespace $VELERO_NAMESPACE --ignore-not-found=true
    log "Velero uninstalled successfully"
    pop_fn 0
}

confirm_uninstall
uninstall_velero
