#!/usr/bin/env bash
#
# Copyright IBM Corp All Rights Reserved
#
# SPDX-License-Identifier: Apache-2.0
#
set -o errexit

function print_help() {
  set +x
  log
  log "--- Fabric Information"
  log "Fabric Version     \t\t: ${FABRIC_VERSION}"
  log "Fabric CA Version  \t\t: ${FABRIC_CA_VERSION}"
  log "Container Registry \t\t: ${FABRIC_CONTAINER_REGISTRY}"
  log "Network name       \t\t: ${NETWORK_NAME}"
  log "Ingress domain     \t\t: ${DOMAIN}"
  log "Channel name       \t\t: ${CHANNEL_NAME}"
  log "Orderer type       \t\t: ${ORDERER_TYPE}"
  log
  log "--- Cluster Information"
  log "Cluster runtime    \t\t: ${CLUSTER_RUNTIME}"
  log "Cluster name       \t\t: ${CLUSTER_NAME}"
  log "Cluster namespace  \t\t: ${NS}"
  log "Fabric Registry    \t\t: ${FABRIC_CONTAINER_REGISTRY}"
  log "Local Registry     \t\t: ${LOCAL_REGISTRY_NAME}"
  log "Local Registry port\t\t: ${LOCAL_REGISTRY_PORT}"
  log "nginx http port    \t\t: ${NGINX_HTTP_PORT}"
  log "nginx https port   \t\t: ${NGINX_HTTPS_PORT}"
  log
  log "--- Script Information"
  log "Log file           \t\t: ${LOG_FILE}"
  log "Debug log file     \t\t: ${DEBUG_FILE}"
  log
  log "Usage: $0 {init|up|down|channel|chaincode|cc|anchor|rest-easy|application|cluster|rm|clean}"
}

# Include scripts
source k8s-setup/utils.sh
source k8s-setup/envVar.sh
source k8s-setup/check_pre.sh
source k8s-setup/kubeadm.sh
source k8s-setup/cluster.sh
source k8s-setup/fabric_config.sh
source k8s-setup/fabric_CAs.sh
source k8s-setup/test_network.sh
# source k8s-setup/channel.sh
# source k8s-setup/chaincode.sh
# source k8s-setup/rest_sample.sh
# source k8s-setup/application_connection.sh

# Initialize logging
logging_init

# Check prerequisites
check_prerequisites_cluster

# Parse mode
if [ $# -lt 1 ]; then
  print_help
  exit 0
fi

MODE="$1"
shift

case "${MODE}" in
  init)
    push_fn "Setting up Kubernetes cluster using kubeadm"
    kubeadm_init
    sleep 2
    source transfer-k3s.sh || { log "ERROR: Failed to source transfer-k3s.sh"; pop_fn 1; exit 1; }
    log "🏁 - Kubernetes cluster is ready"
    pop_fn 0
    ;;
  up)
    push_fn "Launching network \"${NETWORK_NAME}\""
    network_up
    log "🏁 - Network is ready"
    pop_fn 0
    ;;
  down)
    push_fn "Shutting down test network \"${NETWORK_NAME}\""
    network_down
    log "🏁 - Fabric network is down"
    pop_fn 0
    ;;
  channel)
    channel_command_group "$@"
    ;;
  chaincode|cc)
    chaincode_command_group "$@"
    ;;
  anchor)
    update_anchor_peers "$@"
    ;;
  rest-easy)
    push_fn "Launching fabric-rest-sample application"
    launch_rest_sample
    log "🏁 - Fabric REST sample is ready"
    pop_fn 0
    ;;
  application)
    push_fn "Getting application connection information"
    application_connection
    log "🏁 - Application connection information ready"
    pop_fn 0
    ;;
  cluster)
    cluster_init
    ;;
  rm)
    cluster_clean
    ;;
  clean)
    push_fn "Cleaning up kubeadm cluster"
    kubeadm_clean
    log "🏁 - Kubernetes cluster is cleaned"
    pop_fn 0
    ;;
  *)
    print_help
    pop_fn 1
    exit 1
    ;;
esac