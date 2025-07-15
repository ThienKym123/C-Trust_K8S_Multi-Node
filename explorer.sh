#!/bin/bash
#
# Copyright IBM Corp All Rights Reserved
#
# SPDX-License-Identifier: Apache-2.0
#

# This script creates a secret containing the crypto material for Explorer
# to access the Fabric network. The secret is created from the existing
# crypto-config directory generated during network setup.

set -e

. k8s-setup/envVar.sh
. k8s-setup/utils.sh

function create_crypto_secret() {
  push_fn "Creating crypto secret for Explorer"

  # Delete the secret if it already exists
  kubectl delete secret fabric-crypto-config --namespace=${KUBE_NAMESPACE} --ignore-not-found=true

  # Create the crypto directory structure that Explorer expects
  local temp_crypto_dir="/tmp/fabric-crypto-config"
  rm -rf ${temp_crypto_dir}

  # Create org0 orderer TLS directory structure
  mkdir -p ${temp_crypto_dir}/org0/orderers/org0-orderer1/tls
  if [[ -f "build/cas/org0-ca/tlsca-cert.pem" ]]; then
    cp build/cas/org0-ca/tlsca-cert.pem ${temp_crypto_dir}/org0/orderers/org0-orderer1/tls/ca.crt
  else
    log "Warning: TLS CA certificate not found for org0"
  fi

  # Create org1 directory structure
  mkdir -p ${temp_crypto_dir}/org1/users/org1admin/msp/keystore
  mkdir -p ${temp_crypto_dir}/org1/users/org1admin/msp/signcerts
  mkdir -p ${temp_crypto_dir}/org1/ca
  
  if [[ -f "build/cas/org1-ca/tlsca-cert.pem" ]]; then
    cp build/cas/org1-ca/tlsca-cert.pem ${temp_crypto_dir}/org1/ca/tlsca-cert.pem
  fi

  if [[ -d "build/enrollments/org1/users/org1admin/msp" ]]; then
    # Find and copy the keystore file
    local keystore_file=$(find build/enrollments/org1/users/org1admin/msp/keystore -type f | head -n 1)
    if [[ -n "$keystore_file" ]]; then
      cp "$keystore_file" ${temp_crypto_dir}/org1/users/org1admin/msp/keystore/key.pem
    fi
    
    # Find and copy the signcerts file
    local signcert_file=$(find build/enrollments/org1/users/org1admin/msp/signcerts -type f | head -n 1)
    if [[ -n "$signcert_file" ]]; then
      cp "$signcert_file" ${temp_crypto_dir}/org1/users/org1admin/msp/signcerts/cert.pem
    fi
  fi

  # Create org2 directory structure
  mkdir -p ${temp_crypto_dir}/org2/users/org2admin/msp/keystore
  mkdir -p ${temp_crypto_dir}/org2/users/org2admin/msp/signcerts
  mkdir -p ${temp_crypto_dir}/org2/ca
  
  if [[ -f "build/cas/org2-ca/tlsca-cert.pem" ]]; then
    cp build/cas/org2-ca/tlsca-cert.pem ${temp_crypto_dir}/org2/ca/tlsca-cert.pem
  fi

  if [[ -d "build/enrollments/org2/users/org2admin/msp" ]]; then
    # Find and copy the keystore file
    local keystore_file=$(find build/enrollments/org2/users/org2admin/msp/keystore -type f | head -n 1)
    if [[ -n "$keystore_file" ]]; then
      cp "$keystore_file" ${temp_crypto_dir}/org2/users/org2admin/msp/keystore/key.pem
    fi
    
    # Find and copy the signcerts file
    local signcert_file=$(find build/enrollments/org2/users/org2admin/msp/signcerts -type f | head -n 1)
    if [[ -n "$signcert_file" ]]; then
      cp "$signcert_file" ${temp_crypto_dir}/org2/users/org2admin/msp/signcerts/cert.pem
    fi
  fi

  # Create a tar archive to preserve directory structure
  local crypto_tar="/tmp/fabric-crypto.tar.gz"
  cd ${temp_crypto_dir}
  tar -czf ${crypto_tar} .
  cd -

  # Create the Kubernetes secret from the tar file  
  kubectl create secret generic fabric-crypto-config \
    --from-file=crypto.tar.gz=${crypto_tar} \
    --namespace=${KUBE_NAMESPACE}

  # Clean up temporary files
  rm -rf ${temp_crypto_dir} ${crypto_tar}

  log "✅ - Created fabric-crypto-config secret for Explorer"

  pop_fn
}

function deploy_explorer() {
  push_fn "Deploying Hyperledger Explorer"

  # Apply all explorer manifests
  envsubst < kube/explorer/explorer-pvc.yaml | kubectl apply -f -
  envsubst < kube/explorer/explorer-configmap.yaml | kubectl apply -f -
  envsubst < kube/explorer/explorerdb-deployment.yaml | kubectl apply -f -
  
  # Wait for database to be ready
  kubectl wait --namespace=${KUBE_NAMESPACE} --for=condition=ready pod -l app=explorerdb --timeout=300s

  # Deploy explorer
  envsubst < kube/explorer/explorer-deployment.yaml | kubectl apply -f -
  envsubst < kube/explorer/explorer-ingress.yaml | kubectl apply -f -

  # Wait for explorer to be ready
  kubectl wait --namespace=${KUBE_NAMESPACE} --for=condition=ready pod -l app=explorer --timeout=300s

  pop_fn
}

function print_explorer_info() {
  push_fn "Explorer access information"

  local explorer_host="explorer.${DOMAIN}"
  local explorer_url="http://${explorer_host}"
  
  if [[ "${CLUSTER_RUNTIME}" == "kind" ]]; then
    echo "Explorer is available at: http://localhost:8080"
    echo "Port forward with: kubectl port-forward -n ${KUBE_NAMESPACE} service/explorer 8080:8080"
  else
    echo "Explorer is available at: ${explorer_url}"
  fi
  
  echo ""
  echo "Default login credentials:"
  echo "Username: exploreradmin"
  echo "Password: exploreradminpw"

  pop_fn
}


function clean_explorer() {
  push_fn "Cleaning up Hyperledger Explorer"

  # Delete deployments and services
  kubectl delete deployment explorer explorerdb --namespace=${KUBE_NAMESPACE} --ignore-not-found=true
  kubectl delete service explorer explorerdb --namespace=${KUBE_NAMESPACE} --ignore-not-found=true
  
  # Delete ingress
  kubectl delete ingress explorer-ingress --namespace=${KUBE_NAMESPACE} --ignore-not-found=true
  
  # Delete configmaps
  kubectl delete configmap explorer-config explorer-connection-profile --namespace=${KUBE_NAMESPACE} --ignore-not-found=true
  
  # Delete secret
  kubectl delete secret fabric-crypto-config --namespace=${KUBE_NAMESPACE} --ignore-not-found=true
  
  # Delete PVCs (this will also delete the persistent volumes and data)
  kubectl delete pvc explorer-db-pvc explorer-wallet-pvc --namespace=${KUBE_NAMESPACE} --ignore-not-found=true

  log "🧹 - Explorer cleanup completed"

  pop_fn
}
