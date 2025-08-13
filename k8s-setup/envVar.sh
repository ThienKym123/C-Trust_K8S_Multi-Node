#!/usr/bin/env bash
#
# Copyright IBM Corp All Rights Reserved
#
# SPDX-License-Identifier: Apache-2.0
#

# Variables
export PATH=$PWD/bin:$PATH
export FABRIC_VERSION="2.5.11"
export FABRIC_CA_VERSION="1.5.15"
export CLUSTER_RUNTIME="kubeadm"
export CONTAINER_CLI="docker"
export CONTAINER_NAMESPACE=""
export FABRIC_CONTAINER_REGISTRY="hyperledger"
export FABRIC_PEER_IMAGE="${FABRIC_CONTAINER_REGISTRY}/fabric-peer:${FABRIC_VERSION}"
export COUCHDB_VERSION="3.4.2"
export NETWORK_NAME="test-network"
export CLUSTER_NAME="fabric-cluster"
export KUBE_NAMESPACE="${NETWORK_NAME}"
export NS="${KUBE_NAMESPACE}"
export ORG0_NS="${NS}"
export ORG1_NS="${NS}"
export ORG2_NS="${NS}"
export ORG0_NODE="admin1"
export ORG1_NODE="admin2"
export ORG2_NODE="admin3"
export DOMAIN="localho.st"
export CHANNEL_NAME="mychannel"
export ORDERER_TYPE="raft"
export ORDERER_TIMEOUT="10s"
export TEMP_DIR="${PWD}/build"
export CHAINCODE_BUILDER="ccaas"
export K8S_CHAINCODE_BUILDER_IMAGE="ghcr.io/hyperledger-labs/fabric-builder-k8s/k8s-fabric-peer"
export K8S_CHAINCODE_BUILDER_VERSION="0.14.0"
export LOG_FILE="network.log"
export DEBUG_FILE="network-debug.log"
export LOG_ERROR_LINES="2"
export LOCAL_REGISTRY_NAME="fabric-registry"
export LOCAL_REGISTRY_INTERFACE="192.168.208.1"
export CONTROL_PLANE_IP="192.168.208.1"
export LOCAL_REGISTRY_PORT="5000"
export STAGE_DOCKER_IMAGES=true
export NGINX_HTTP_PORT="30080"
export NGINX_HTTPS_PORT="30443"
export RCAADMIN_USER="rcaadmin"
export RCAADMIN_PASS="rcaadminpw"
export K8S_VERSION="v1.33.0"
export POD_CIDR="10.244.0.0/16"
export SERVICE_CIDR="10.96.0.0/12"
export CERT_DIR="/etc/docker/certs"
export REGISTRY_CERT="registry.crt"
export REGISTRY_KEY="registry.key"
