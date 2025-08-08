#!/usr/bin/env bash
#
# Copyright IBM Corp All Rights Reserved
#
# SPDX-License-Identifier: Apache-2.0
#

source k8s-setup/check_pre.sh
source k8s-setup/envVar.sh
source k8s-setup/utils.sh

# Initialize namespaces for organizations
function init_namespace() {
  local namespaces=$(echo "$ORG0_NS $ORG1_NS $ORG2_NS" | xargs -n1 | sort -u)
  for ns in $namespaces; do
    push_fn "Creating namespace \"$ns\""
    kubectl create namespace $ns || true
    pop_fn
  done
}

# Delete namespaces for organizations
function delete_namespace() {
  local namespaces=$(echo "$ORG0_NS $ORG1_NS $ORG2_NS" | xargs -n1 | sort -u)
  for ns in $namespaces; do
    push_fn "Deleting namespace \"$ns\""
    kubectl delete namespace $ns || true
    pop_fn
  done
}

# Initialize persistent volume claims for storage
function init_storage_volumes() {
  push_fn "Provisioning volume storage using NFS Provisioner"

  # Create namespace for NFS Provisioner (if not exists)
  kubectl create namespace nfs-provisioner || true

  # Install NFS Subdir External Provisioner
  helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/ || true
  helm upgrade --install nfs-subdir-external-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
    --namespace nfs-provisioner \
    --set nfs.server=$CONTROL_PLANE_IP \
    --set nfs.path=/mnt/nfs_share \
    --set storageClass.name=nfs-client \
    --set storageClass.defaultClass=false || true

  # Apply PVCs for each organization
  kubectl -n $ORG0_NS apply -f kube/org0/fabric-org0-pvc.yaml || true
  kubectl -n $ORG1_NS apply -f kube/org1/fabric-org1-pvc.yaml || true
  kubectl -n $ORG2_NS apply -f kube/org2/fabric-org2-pvc.yaml || true

  pop_fn
}

# Load organization configuration into configmaps
function load_org_config() {
  push_fn "Creating fabric config maps"

  kubectl -n $ORG0_NS delete configmap org0-config || true
  kubectl -n $ORG1_NS delete configmap org1-config || true
  kubectl -n $ORG2_NS delete configmap org2-config || true

  kubectl -n $ORG0_NS create configmap org0-config --from-file=config/org0
  kubectl -n $ORG1_NS create configmap org1-config --from-file=config/org1
  kubectl -n $ORG2_NS create configmap org2-config --from-file=config/org2

  pop_fn
}

# Apply Kubernetes chaincode builder roles
function apply_k8s_builder_roles() {
  push_fn "Applying k8s chaincode builder roles"

  apply_template kube/fabric-builder-role.yaml $ORG1_NS
  apply_template kube/fabric-builder-rolebinding.yaml $ORG1_NS

  pop_fn
}

# Install Kubernetes chaincode builders
function apply_k8s_builders() {
  push_fn "Installing k8s chaincode builders"

  apply_template kube/org1/org1-install-k8s-builder.yaml $ORG1_NS
  apply_template kube/org2/org2-install-k8s-builder.yaml $ORG2_NS

  kubectl -n $ORG1_NS wait --for=condition=complete --timeout=300s job/org1-install-k8s-builder
  kubectl -n $ORG2_NS wait --for=condition=complete --timeout=300s job/org2-install-k8s-builder

  pop_fn
}