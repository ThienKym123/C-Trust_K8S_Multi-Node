#!/usr/bin/env bash
#
# Copyright IBM Corp All Rights Reserved
#
# SPDX-License-Identifier: Apache-2.0
#

. k8s-setup/check_pre.sh
. k8s-setup/envVar.sh
. k8s-setup/utils.sh

# Cluster command group for handling cluster sub-commands
function cluster_command_group() {
  # Default COMMAND is 'init' if not specified
  if [ "$#" -eq 0 ]; then
    COMMAND="init"
  else
    COMMAND=$1
    shift
  fi

  if [ "${COMMAND}" == "init" ]; then
    log "Initializing K8s cluster"
    cluster_init
    log "🏁 - Cluster is ready"

  elif [ "${COMMAND}" == "clean" ]; then
    log "Cleaning k8s cluster"
    cluster_clean
    log "🏁 - Cluster is cleaned"

  elif [ "${COMMAND}" == "load-images" ]; then
    log "Loading Docker images"
    load_images
    log "🏁 - Images are loaded"

  else
    print_help
    exit 1
  fi
}

# Pull Docker images for Fabric and NGINX Ingress
function pull_docker_images() {
  push_fn "Pulling docker images for Fabric ${FABRIC_VERSION}"

  $CONTAINER_CLI pull ${CONTAINER_NAMESPACE} ${FABRIC_CONTAINER_REGISTRY}/fabric-ca:$FABRIC_CA_VERSION
  $CONTAINER_CLI pull ${CONTAINER_NAMESPACE} ${FABRIC_CONTAINER_REGISTRY}/fabric-orderer:$FABRIC_VERSION
  $CONTAINER_CLI pull ${CONTAINER_NAMESPACE} ${FABRIC_PEER_IMAGE}
  $CONTAINER_CLI pull ${CONTAINER_NAMESPACE} couchdb:$COUCHDB_VERSION
  $CONTAINER_CLI pull ${CONTAINER_NAMESPACE} redis:6.2.5

  pop_fn
}

function push_docker_images() {
  push_fn "Pushing docker images to local registry"

  local images=(
    "${FABRIC_CONTAINER_REGISTRY}/fabric-ca:$FABRIC_CA_VERSION"
    "${FABRIC_CONTAINER_REGISTRY}/fabric-orderer:$FABRIC_VERSION"
    "${FABRIC_PEER_IMAGE}"
    "couchdb:$COUCHDB_VERSION"
    "redis:6.2.5"
  )

  for image in "${images[@]}"; do
    local target_image
    case "$image" in
      "${FABRIC_CONTAINER_REGISTRY}/fabric-ca:"*)
        target_image="$CONTROL_PLANE_IP:$LOCAL_REGISTRY_PORT/fabric-ca:$FABRIC_CA_VERSION"
        ;;
      "${FABRIC_CONTAINER_REGISTRY}/fabric-orderer:"*)
        target_image="$CONTROL_PLANE_IP:$LOCAL_REGISTRY_PORT/fabric-orderer:$FABRIC_VERSION"
        ;;
      "${FABRIC_PEER_IMAGE}")
        target_image="$CONTROL_PLANE_IP:$LOCAL_REGISTRY_PORT/fabric-peer:$FABRIC_VERSION"
        ;;
      "couchdb:"*)
        target_image="$CONTROL_PLANE_IP:$LOCAL_REGISTRY_PORT/couchdb:$COUCHDB_VERSION"
        ;;
      "redis:"*)
        target_image="$CONTROL_PLANE_IP:$LOCAL_REGISTRY_PORT/redis:6.2.5"
        ;;
    esac

    log "Tagging ${CONTAINER_NAMESPACE}${image} to $target_image"
    $CONTAINER_CLI tag "${CONTAINER_NAMESPACE}${image}" "$target_image"
    log "Pushing $target_image"
    $CONTAINER_CLI push "$target_image"
    if [ $? -ne 0 ]; then
      log "ERROR: Failed to push $target_image. Check registry connectivity and certificates."
      exit 1
    fi
  done

  pop_fn
}

function apply_flannel() {
  push_fn "Applying Flannel CNI"

  kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml >/dev/null
  if [ $? -ne 0 ]; then
    log "ERROR: Failed to apply Flannel CNI."
    exit 1
  fi

  log "Checking Flannel pods in kube-flannel namespace"
  kubectl get pods -n kube-flannel || true

  kubectl wait --namespace kube-flannel \
    --for=condition=ready pod \
    --selector=app=flannel \
    --timeout=3m >/dev/null
  if [ $? -ne 0 ]; then
    log "ERROR: Flannel pods not ready in kube-flannel namespace."
    kubectl get pods -n kube-flannel
    exit 1
  fi

  pop_fn
}

function delete_flannel() {
  push_fn "Deleting Flannel CNI"

  kubectl delete -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml >/dev/null
  if [ $? -ne 0 ]; then
    log "WARNING: Failed to delete Flannel CNI."
  fi

  sudo rm -rf /var/lib/cni/
  sudo rm -rf /run/flannel/

  pop_fn
}

function apply_nginx_ingress() {
  push_fn "Launching ${CLUSTER_RUNTIME} ingress controller"

  # Create ingress-nginx namespace first
  kubectl create namespace ingress-nginx --dry-run=client -o yaml | kubectl apply -f - >/dev/null
  if [ $? -ne 0 ]; then
    log "ERROR: Failed to create ingress-nginx namespace."
    exit 1
  fi

  kubectl apply -f kube/ingress-nginx-k3s.yaml >/dev/null
  if [ $? -ne 0 ]; then
    log "ERROR: Failed to apply NGINX Ingress."
    exit 1
  fi

  pop_fn
}

function delete_nginx_ingress() {
  push_fn "Deleting ${CLUSTER_RUNTIME} ingress controller"

  kubectl delete -f kube/ingress-nginx-k3s.yaml >/dev/null
  if [ $? -ne 0 ]; then
    log "WARNING: Failed to delete NGINX Ingress."
  fi

  # Delete the namespace if it exists
  kubectl delete namespace ingress-nginx --ignore-not-found >/dev/null

  pop_fn
}

function wait_for_nginx_ingress() {
  push_fn "Waiting for ingress controller"

  kubectl wait --namespace ingress-nginx \
    --for=condition=ready pod \
    --selector=app.kubernetes.io/component=controller \
    --timeout=3m >/dev/null
  if [ $? -ne 0 ]; then
    log "ERROR: NGINX Ingress pods not ready."
    exit 1
  fi

  pop_fn
}

function apply_cert_manager() {
  push_fn "Launching cert-manager"

  kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.6.1/cert-manager.yaml >/dev/null
  if [ $? -ne 0 ]; then
    log "ERROR: Failed to apply cert-manager."
    exit 1
  fi

  pop_fn
}

function delete_cert_manager() {
  push_fn "Deleting cert-manager"

  kubectl delete -f https://github.com/jetstack/cert-manager/releases/download/v1.6.1/cert-manager.yaml >/dev/null
  if [ $? -ne 0 ]; then
    log "WARNING: Failed to delete cert-manager."
  fi

  pop_fn
}

function wait_for_cert_manager() {
  push_fn "Waiting for cert-manager"

  kubectl -n cert-manager rollout status deploy/cert-manager >/dev/null
  kubectl -n cert-manager rollout status deploy/cert-manager-cainjector >/dev/null
  kubectl -n cert-manager rollout status deploy/cert-manager-webhook >/dev/null
  if [ $? -ne 0 ]; then
    log "ERROR: cert-manager deployments not ready."
    exit 1
  fi

  pop_fn
}

function create_local_path() {
  push_fn "Applying local-path-provisioner"

  # Ensure KUBECONFIG is set
  export KUBECONFIG=$HOME/.kube/config
  if [ ! -f "$KUBECONFIG" ]; then
    log "ERROR: KUBECONFIG file not found at $KUBECONFIG"
    exit 1
  fi

  kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml >/dev/null
  if [ $? -ne 0 ]; then
    log "ERROR: Failed to apply local-path-provisioner."
    exit 1
  fi

  log "Checking local-path-provisioner pods in local-path-storage namespace..."
  kubectl get pods -n local-path-storage || true

  kubectl wait --for=condition=available --timeout=120s deployment/local-path-provisioner -n local-path-storage >/dev/null
  if [ $? -ne 0 ]; then
    log "ERROR: local-path-provisioner deployment not ready after 300 seconds."
    kubectl get pods -n local-path-storage
    kubectl describe pod -n local-path-storage -l app=local-path-provisioner
    exit 1
  fi

  pop_fn
}

function cluster_init() {
  push_fn "Initializing K8s cluster"

  check_prerequisites_cluster
  kubectl taint nodes --all node-role.kubernetes.io/control-plane- || true
  kubectl taint nodes --all node-role.kubernetes.io/not-ready- || true
  apply_flannel

  sleep 5

  apply_nginx_ingress
  apply_cert_manager

  sleep 2

  wait_for_cert_manager
  wait_for_nginx_ingress

  if [ "${STAGE_DOCKER_IMAGES}" == true ]; then
    pull_docker_images
    push_docker_images
  fi

  # create_local_path

  pop_fn
}

function cluster_clean() {
  push_fn "Cleaning K8s cluster"

  delete_nginx_ingress
  delete_cert_manager
  delete_flannel

  pop_fn
}

function load_images() {
  push_fn "Loading Docker images"

  check_prerequisites_cluster
  pull_docker_images
  push_docker_images

  pop_fn
}