#!/usr/bin/env bash
#
# Copyright IBM Corp All Rights Reserved
#
# SPDX-License-Identifier: Apache-2.0
#

source k8s-setup/envVar.sh
source k8s-setup/utils.sh

# Launch Fabric orderers
function launch_orderers() {
  push_fn "Launching orderers"

  apply_template kube/org0/org0-orderer1.yaml $ORG0_NS
  apply_template kube/org0/org0-orderer2.yaml $ORG0_NS
  apply_template kube/org0/org0-orderer3.yaml $ORG0_NS

  kubectl -n $ORG0_NS rollout status deploy/org0-orderer1
  kubectl -n $ORG0_NS rollout status deploy/org0-orderer2
  kubectl -n $ORG0_NS rollout status deploy/org0-orderer3

  if  [ "${ORDERER_TYPE}" == "bft" ]; then
    apply_template kube/org0/org0-orderer4.yaml $ORG0_NS
    kubectl -n $ORG0_NS rollout status deploy/org0-orderer4
  fi

  pop_fn
}

# Launch Fabric peers
function launch_peers() {
  push_fn "Launching peers"

  apply_template kube/org1/org1-peer1.yaml $ORG1_NS
  apply_template kube/org1/org1-peer2.yaml $ORG1_NS
  apply_template kube/org2/org2-peer1.yaml $ORG2_NS
  apply_template kube/org2/org2-peer2.yaml $ORG2_NS

  kubectl -n $ORG1_NS rollout status deploy/org1-peer1
  kubectl -n $ORG1_NS rollout status deploy/org1-peer2
  kubectl -n $ORG2_NS rollout status deploy/org2-peer1
  kubectl -n $ORG2_NS rollout status deploy/org2-peer2

  pop_fn
}

# Create local MSP for a node
function create_node_local_MSP() {
  local node_type=$1
  local org=$2
  local node=$3
  local csr_hosts=$4
  local ns=$5
  local id_name=${org}-${node}
  local id_secret=${node_type}pw
  local ca_name=${org}-ca

  rc=0
  fabric-ca-client register \
    --id.name ${id_name} \
    --id.secret ${id_secret} \
    --id.type ${node_type} \
    --url https://${ca_name}.${DOMAIN}:${NGINX_HTTPS_PORT} \
    --tls.certfiles $TEMP_DIR/cas/${ca_name}/tlsca-cert.pem \
    --mspdir $TEMP_DIR/enrollments/${org}/users/${RCAADMIN_USER}/msp \
    || rc=$?

  if [ $rc -eq 1 ]; then
    echo "CA admin was (probably) previously registered - continuing"
  fi

  cat <<EOF | kubectl -n ${ns} exec deploy/${ca_name} -i -- /bin/sh
set -x
export FABRIC_CA_CLIENT_HOME=/var/hyperledger/fabric-ca-client
export FABRIC_CA_CLIENT_TLS_CERTFILES=/var/hyperledger/fabric/config/tls/ca.crt
fabric-ca-client enroll \
  --url https://${id_name}:${id_secret}@${ca_name} \
  --csr.hosts ${csr_hosts} \
  --mspdir /var/hyperledger/fabric/organizations/${node_type}Organizations/${org}.example.com/${node_type}s/${id_name}.${org}.example.com/msp
echo "NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: cacerts/${org}-ca.pem
    OrganizationalUnitIdentifier: client
  PeerOUIdentifier:
    Certificate: cacerts/${org}-ca.pem
    OrganizationalUnitIdentifier: peer
  AdminOUIdentifier:
    Certificate: cacerts/${org}-ca.pem
    OrganizationalUnitIdentifier: admin
  OrdererOUIdentifier:
    Certificate: cacerts/${org}-ca.pem
    OrganizationalUnitIdentifier: orderer" > /var/hyperledger/fabric/organizations/${node_type}Organizations/${org}.example.com/${node_type}s/${id_name}.${org}.example.com/msp/config.yaml
EOF
}

# Create local MSP for orderers
function create_orderer_local_MSP() {
  local org=$1
  local orderer=$2
  local csr_hosts=${org}-${orderer}

  create_node_local_MSP orderer $org $orderer $csr_hosts $ORG0_NS
}

# Create local MSP for peers
function create_peer_local_MSP() {
  local org=$1
  local peer=$2
  local ns=$3
  local csr_hosts=localhost,${org}-${peer},${org}-peer-gateway-svc

  create_node_local_MSP peer $org $peer $csr_hosts ${ns}
}

# Create local MSP for all nodes
function create_local_MSP() {
  push_fn "Creating local node MSP"

  create_orderer_local_MSP org0 orderer1
  create_orderer_local_MSP org0 orderer2
  create_orderer_local_MSP org0 orderer3
  if [ "${ORDERER_TYPE}" == "bft" ]; then
    create_orderer_local_MSP org0 orderer4
  fi

  create_peer_local_MSP org1 peer1 $ORG1_NS
  create_peer_local_MSP org1 peer2 $ORG1_NS
  create_peer_local_MSP org2 peer1 $ORG2_NS
  create_peer_local_MSP org2 peer2 $ORG2_NS

  pop_fn
}

# Launch the Fabric network
function network_up() {
  push_fn "Launching Fabric network"

  init_namespace
  init_storage_volumes
  load_org_config

  if [ "${CHAINCODE_BUILDER}" == "ccaas" ]; then
    apply_k8s_builder_roles
    apply_k8s_builders
  fi

  init_tls_cert_issuers
  launch_ECert_CAs
  enroll_bootstrap_ECert_CA_users
  create_local_MSP
  launch_orderers
  launch_peers

  pop_fn
}

# Stop all Fabric services
function stop_services() {
  push_fn "Stopping Fabric services"
  for ns in $ORG0_NS $ORG1_NS $ORG2_NS; do
    kubectl get namespace $ns >/dev/null 2>&1 || continue
    log "Deleting resources in namespace $ns..."
    kubectl -n $ns delete ingress --all
    kubectl -n $ns delete deployment --all
    kubectl -n $ns delete pod --all
    kubectl -n $ns delete service --all
    kubectl -n $ns delete configmap --all
    kubectl -n $ns delete cert --all
    kubectl -n $ns delete issuer --all
    kubectl -n $ns delete secret --all
  done
  pop_fn
}

# Scrub organization volumes
function scrub_org_volumes() {
  push_fn "Scrubbing Fabric volumes"
  for org in org0 org1 org2; do
    # clean job to make this function can be rerun
    local namespace_variable=${org^^}_NS
    kubectl -n ${!namespace_variable} delete jobs --all

    # scrub all pv contents
    kubectl -n ${!namespace_variable} create -f kube/${org}/${org}-job-scrub-fabric-volumes.yaml
    kubectl -n ${!namespace_variable} wait --for=condition=complete --timeout=60s job/job-scrub-fabric-volumes
    kubectl -n ${!namespace_variable} delete jobs --all
  done
  pop_fn
}

function cleanup_storage_volumes() {
  push_fn "Cleaning up NFS volumes and provisioner"

  kubectl -n $ORG0_NS delete -f kube/org0/fabric-org0-pvc.yaml || true
  kubectl -n $ORG1_NS delete -f kube/org1/fabric-org1-pvc.yaml || true
  kubectl -n $ORG2_NS delete -f kube/org2/fabric-org2-pvc.yaml || true

  helm uninstall nfs-subdir-external-provisioner -n nfs-provisioner || true
  kubectl delete namespace nfs-provisioner || true

  pop_fn
}

# Tear down the Fabric network
function network_down() {
  set +e
  
  docker images --format '{{.Repository}} {{.Tag}} {{.ID}}' \
| grep -E 'supplychain|<none>' \
| awk '{print $3}' | sort | uniq \
| xargs -r docker rmi -f

  for ns in $ORG0_NS $ORG1_NS $ORG2_NS; do
    kubectl get namespace $ns >/dev/null 2>&1
    if [[ $? -ne 0 ]]; then
      log "No namespace $ns found - nothing to do."
      continue
    fi
    stop_services
    scrub_org_volumes
    delete_namespace
  done
  
  cleanup_storage_volumes
  set -e

  rm -rf $PWD/build
}