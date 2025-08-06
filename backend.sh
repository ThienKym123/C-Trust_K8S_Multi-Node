#!/usr/bin/env bash

# SPDX-License-Identifier: Apache-2.0

set -e

# Load environment variables
. k8s-setup/envVar.sh

##############################
# Namespace Setup           #
##############################
setup_namespace() {
  echo "🔧 Ensuring namespace ${KUBE_NAMESPACE} exists..."
  kubectl get namespace ${KUBE_NAMESPACE} &> /dev/null || kubectl create namespace ${KUBE_NAMESPACE}
}

##############################
# MongoDB                   #
##############################
deploy_mongo() {
  echo "🗄️ Deploying MongoDB..."

  if ! kubectl get pvc mongo-pvc -n ${KUBE_NAMESPACE} &> /dev/null; then
    echo "📦 Creating PVC mongo-pvc..."
    kubectl apply -f kube/backend/mongo-pvc.yaml -n ${KUBE_NAMESPACE}
  fi

  if ! kubectl get deployment mongo -n ${KUBE_NAMESPACE} &> /dev/null; then
    kubectl apply -f kube/backend/mongo-deployment.yaml -n ${KUBE_NAMESPACE}
    echo "⏳ Waiting for MongoDB to be ready..."
    kubectl rollout status deployment/mongo -n ${KUBE_NAMESPACE} --timeout=120s
  else
    echo "✅ MongoDB already deployed."
  fi
}

clean_mongo() {
  echo "🧹 Cleaning MongoDB..."
  kubectl delete deployment mongo -n ${KUBE_NAMESPACE} --ignore-not-found
  kubectl delete svc mongo -n ${KUBE_NAMESPACE} --ignore-not-found
  kubectl delete pvc mongo-pvc -n ${KUBE_NAMESPACE} --ignore-not-found

  kubectl wait --for=delete pod -l app=mongo -n ${KUBE_NAMESPACE} --timeout=60s || true
}

##############################
# CouchDB Offchain          #
##############################
deploy_couchdb_offchain() {
  echo "🗄️ Deploying CouchDB offchain..."

  if ! kubectl get pvc couchdb-offchain-pvc -n ${KUBE_NAMESPACE} &> /dev/null; then
    echo "📦 Creating PVC couchdb-offchain-pvc..."
    kubectl apply -f kube/backend/couchdb-offchain-pvc.yaml -n ${KUBE_NAMESPACE}
  fi

  if ! kubectl get deployment couchdb-offchain -n ${KUBE_NAMESPACE} &> /dev/null; then
    kubectl apply -f kube/backend/couchdb-offchain.yaml -n ${KUBE_NAMESPACE}
    echo "⏳ Waiting for CouchDB offchain to be ready..."
    kubectl rollout status deployment/couchdb-offchain -n ${KUBE_NAMESPACE} --timeout=120s

    sleep 7
    kubectl exec -n ${KUBE_NAMESPACE} deploy/couchdb-offchain -- curl -X PUT http://admin:adminpw@localhost:5984/mychannel
    echo "✅ CouchDB Offchain initialized."
  else
    echo "✅ CouchDB offchain already deployed."
  fi
}

clean_couchdb_offchain() {
  echo "🧹 Cleaning CouchDB offchain..."
  kubectl delete deployment couchdb-offchain -n ${KUBE_NAMESPACE} --ignore-not-found
  kubectl delete svc couchdb-offchain -n ${KUBE_NAMESPACE} --ignore-not-found
  kubectl delete pvc couchdb-offchain-pvc -n ${KUBE_NAMESPACE} --ignore-not-found
  kubectl wait --for=delete pod -l app=couchdb-offchain -n ${KUBE_NAMESPACE} --timeout=60s || true
}

##############################
# Backend Deployment        #
##############################
deploy_backend_pvc() {
  if ! kubectl get pvc fabric-wallet -n ${KUBE_NAMESPACE} &> /dev/null; then
    echo "📦 Creating PVC fabric-wallet..."
    envsubst < kube/backend/fabric-wallet-pvc.yaml | kubectl apply -f -
  else
    echo "📦 PVC fabric-wallet already exists."
  fi
}

deploy_backend_resources() {
  echo "📁 Creating backend deployment, service, and ingress..."
  envsubst < kube/backend/backend-deployment.yaml | kubectl apply -f -
  envsubst < kube/backend/backend-service.yaml | kubectl apply -f -
  envsubst < kube/backend/backend-ingress.yaml | kubectl apply -f -
}

wait_for_backend_ready() {
  echo "⏳ Waiting for backend to be ready..."
  kubectl rollout status deployment/backend -n ${KUBE_NAMESPACE} --timeout=120s
  kubectl wait --for=condition=Ready pod -l app=backend -n ${KUBE_NAMESPACE} --timeout=60s
}

build_backend_image() {
  echo "🔨 Building and pushing backend Docker image..."
  cd backend
  ${CONTAINER_CLI} build -t test-network-backend:latest .
  ${CONTAINER_CLI} tag test-network-backend:latest ${CONTROL_PLANE_IP}:${LOCAL_REGISTRY_PORT}/test-network-backend:latest
  ${CONTAINER_CLI} push ${CONTROL_PLANE_IP}:${LOCAL_REGISTRY_PORT}/test-network-backend:latest
  cd ..
}

deploy_backend() {
  setup_namespace
  deploy_couchdb_offchain
  deploy_backend_pvc
  deploy_mongo
  build_backend_image
  deploy_backend_resources
  wait_for_backend_ready

  echo "✅ Backend deployed successfully!"
  echo "🌍 Access: https://backend.${DOMAIN}:${NGINX_HTTPS_PORT}/health"
}

clean_backend() {
  echo "🧹 Cleaning backend..."
  kubectl -n ${KUBE_NAMESPACE} exec deploy/backend -- sh -c 'rm -rf /fabric/application/wallet/*' || true

  kubectl delete deployment backend -n ${KUBE_NAMESPACE} --ignore-not-found
  kubectl delete svc backend -n ${KUBE_NAMESPACE} --ignore-not-found
  kubectl delete ingress backend-ingress -n ${KUBE_NAMESPACE} --ignore-not-found
  kubectl wait --for=delete pod -l app=backend -n ${KUBE_NAMESPACE} --timeout=60s || true

  kubectl delete pvc fabric-wallet -n ${KUBE_NAMESPACE} --ignore-not-found
  clean_mongo
  clean_couchdb_offchain

  echo "🗑 Removing local Docker images..."
  ${CONTAINER_CLI} rmi ${CONTROL_PLANE_IP}:${LOCAL_REGISTRY_PORT}/test-network-backend:latest || true
  ${CONTAINER_CLI} rmi test-network-backend:latest || true

  echo "✅ Backend cleanup completed!"
}

restart_backend() {
  echo "🔄 Restarting backend..."
  kubectl delete deployment backend -n ${KUBE_NAMESPACE} --ignore-not-found
  build_backend_image
  deploy_backend_resources
  wait_for_backend_ready
}
