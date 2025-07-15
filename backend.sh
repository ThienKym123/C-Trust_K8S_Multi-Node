#!/usr/bin/env bash

# SPDX-License-Identifier: Apache-2.0

# Load environment variables
. k8s-setup/envVar.sh

set -e

# Deploy MongoDB (PVC + deployment + service)
deploy_mongo() {
  echo "🗄️ Deploying MongoDB..."
  if ! kubectl get deployment mongo -n ${KUBE_NAMESPACE} &> /dev/null; then
    # Deploy PVC cho MongoDB nếu chưa có
    if ! kubectl get pvc mongo-pvc -n ${KUBE_NAMESPACE} &> /dev/null; then
      echo "📦 Creating PVC mongo-pvc..."
      kubectl apply -f kube/mongo-pvc.yaml -n ${KUBE_NAMESPACE}
    else
      echo "📦 PVC mongo-pvc already exists."
    fi
    kubectl apply -f kube/mongo-deployment.yaml -n ${KUBE_NAMESPACE}
    echo "⏳ Waiting for MongoDB to be ready..."
    kubectl rollout status deployment/mongo -n ${KUBE_NAMESPACE} --timeout=120s
  else
    echo "🗄️ MongoDB already deployed."
  fi
}

# Deploy CouchDB offchain (PVC + deployment + service)
deploy_couchdb_offchain() {
  echo "🗄️ Deploying CouchDB offchain..."
  if ! kubectl get deployment couchdb-offchain -n ${KUBE_NAMESPACE} &> /dev/null; then
    if ! kubectl get pvc couchdb-offchain-pvc -n ${KUBE_NAMESPACE} &> /dev/null; then
      echo "📦 Creating PVC couchdb-offchain-pvc..."
      kubectl apply -f kube/couchdb-offchain-pvc.yaml -n ${KUBE_NAMESPACE}
    else
      echo "📦 PVC couchdb-offchain-pvc already exists."
    fi
    kubectl apply -f kube/couchdb-offchain.yaml -n ${KUBE_NAMESPACE}
    echo "⏳ Waiting for CouchDB offchain to be ready..."
    kubectl rollout status deployment/couchdb-offchain -n ${KUBE_NAMESPACE} --timeout=120s

    sleep 3

    kubectl exec -n ${KUBE_NAMESPACE} deploy/couchdb-offchain --   curl -X PUT http://admin:adminpw@localhost:5984/mychannel
    echo "CouchDB Offchain deployed."
  else
    echo "🗄️ CouchDB offchain already deployed."
  fi
}


# Deploy backend pod, service, ingress
deploy_backend() {
  echo "🚀 Deploying backend to namespace ${KUBE_NAMESPACE}..."

  # Ensure namespace exists
  if ! kubectl get namespace ${KUBE_NAMESPACE} &> /dev/null; then
    echo "🔧 Creating namespace ${KUBE_NAMESPACE}..."
    kubectl create namespace ${KUBE_NAMESPACE}
  fi

  # Deploy CouchDB offchain trước
  deploy_couchdb_offchain

  # Deploy PVC fabric-wallet (if not exist)
  if ! kubectl get pvc fabric-wallet -n ${KUBE_NAMESPACE} &> /dev/null; then
    echo "📦 Creating PVC fabric-wallet..."
    envsubst < kube/fabric-wallet-pvc.yaml | kubectl apply -f -
  else
    echo "📦 PVC fabric-wallet already exists."
  fi

  # Deploy MongoDB first
  deploy_mongo

  # Build Docker image
  echo "🔨 Building backend Docker image..."
  cd backend
  ${CONTAINER_CLI} build -t test-network-backend:latest .
  
  # Push to local registry
  echo "📦 Pushing image to local registry ${CONTROL_PLANE_IP}:${LOCAL_REGISTRY_PORT}..."
  ${CONTAINER_CLI} tag test-network-backend:latest ${CONTROL_PLANE_IP}:${LOCAL_REGISTRY_PORT}/test-network-backend:latest
  ${CONTAINER_CLI} push ${CONTROL_PLANE_IP}:${LOCAL_REGISTRY_PORT}/test-network-backend:latest
  cd ..

  # Deploy backend Deployment + Service + Ingress
  echo "📁 Creating backend deployment, service, and ingress..."

  envsubst < kube/backend-deployment.yaml | kubectl apply -f -
  envsubst < kube/backend-service.yaml | kubectl apply -f -
  envsubst < kube/backend-ingress.yaml | kubectl apply -f -

  # Wait for deployment to become ready
  echo "⏳ Waiting for backend deployment to be ready..."
  kubectl rollout status deployment/backend -n ${KUBE_NAMESPACE} --timeout=120s

  # Wait for pod to be running
  echo "🔍 Ensuring backend pod is running..."
  kubectl wait --for=condition=Ready pod -l app=backend -n ${KUBE_NAMESPACE} --timeout=60s

  echo "✅ Backend deployed successfully!"
  kubectl get pods -n ${KUBE_NAMESPACE} -l app=backend
  kubectl get svc -n ${KUBE_NAMESPACE} -l app=backend
  kubectl get ingress -n ${KUBE_NAMESPACE} -l app=backend
  
  echo ""
  echo "🌍 Access the backend at: https://backend.${DOMAIN}/health"
  echo "🔁 Example curl:"
  echo "curl -k https://backend.${DOMAIN}/health"
}

# Clean up backend resources
clean_backend() {

  echo "🧹 Cleaning all identities from wallet (PVC fabric-wallet)..."
  kubectl -n ${KUBE_NAMESPACE} exec deploy/backend -- sh -c 'rm -rf /fabric/application/wallet/*'

  echo "🧹 Cleaning backend deployment, services, ingress..."

  kubectl delete deployment backend -n ${KUBE_NAMESPACE} --ignore-not-found
  kubectl delete svc backend -n ${KUBE_NAMESPACE} --ignore-not-found
  kubectl delete ingress backend-ingress -n ${KUBE_NAMESPACE} --ignore-not-found

  echo "⏳ Waiting for resources to be terminated..."
  kubectl wait --for=delete pod -l app=backend -n ${KUBE_NAMESPACE} --timeout=60s || true
  kubectl wait --for=delete svc/backend -n ${KUBE_NAMESPACE} --timeout=30s || true
  kubectl wait --for=delete ingress/backend-ingress -n ${KUBE_NAMESPACE} --timeout=30s || true
  kubectl delete pvc fabric-wallet -n ${KUBE_NAMESPACE} --ignore-not-found

  # Clean MongoDB resources
  echo "🧹 Cleaning MongoDB deployment and service..."
  kubectl delete deployment mongo -n ${KUBE_NAMESPACE} --ignore-not-found
  kubectl delete svc mongo -n ${KUBE_NAMESPACE} --ignore-not-found
  kubectl delete pvc mongo-pvc -n ${KUBE_NAMESPACE} --ignore-not-found
  echo "⏳ Waiting for MongoDB resources to be terminated..."
  kubectl wait --for=delete pod -l app=mongo -n ${KUBE_NAMESPACE} --timeout=60s || true
  kubectl wait --for=delete svc/mongo -n ${KUBE_NAMESPACE} --timeout=30s || true
  kubectl wait --for=delete pvc/mongo-pvc -n ${KUBE_NAMESPACE} --timeout=30s || true

  # Clean CouchDB offchain resources
  clean_couchdb_offchain

  echo "🗑 Removing local Docker images..."
  ${CONTAINER_CLI} rmi ${CONTROL_PLANE_IP}:${LOCAL_REGISTRY_PORT}/test-network-backend:latest || true
  ${CONTAINER_CLI} rmi test-network-backend:latest || true

  echo "✅ Backend cleanup completed!"
}

clean_couchdb_offchain() {
  echo "🧹 Cleaning CouchDB offchain deployment and service..."
  kubectl delete deployment couchdb-offchain -n ${KUBE_NAMESPACE} --ignore-not-found
  kubectl delete svc couchdb-offchain -n ${KUBE_NAMESPACE} --ignore-not-found
  kubectl delete pvc couchdb-offchain-pvc -n ${KUBE_NAMESPACE} --ignore-not-found
  echo "⏳ Waiting for CouchDB offchain resources to be terminated..."
  kubectl wait --for=delete pod -l app=couchdb-offchain -n ${KUBE_NAMESPACE} --timeout=60s || true
  kubectl wait --for=delete svc/couchdb-offchain -n ${KUBE_NAMESPACE} --timeout=30s || true
  kubectl wait --for=delete pvc/couchdb-offchain-pvc -n ${KUBE_NAMESPACE} --timeout=30s || true
}

clean_explorer() {
  echo "🧹 Cleaning Fabric Explorer deployment and service..."
  kubectl delete deployment fabric-explorer -n ${KUBE_NAMESPACE} --ignore-not-found
  kubectl delete svc fabric-explorer -n ${KUBE_NAMESPACE} --ignore-not-found
  kubectl delete pvc fabric-explorer-pvc -n ${KUBE_NAMESPACE} --ignore-not-found
  echo "⏳ Waiting for Fabric Explorer resources to be terminated..."
  kubectl wait --for=delete pod -l app=fabric-explorer -n ${KUBE_NAMESPACE} --timeout=60s || true
  kubectl wait --for=delete svc/fabric-explorer -n ${KUBE_NAMESPACE} --timeout=30s || true
  kubectl wait --for=delete pvc/fabric-explorer-pvc -n ${KUBE_NAMESPACE} --timeout=30s || true
}

build_explorer_image() {
  echo "🔨 Building Hyperledger Fabric Explorer Docker image..."

  # Clone the Fabric Explorer repository if not already cloned
  if [ ! -d "fabric-explorer" ]; then
    echo "📁 Cloning Fabric Explorer repository..."
    git clone https://github.com/hyperledger/blockchain-explorer.git fabric-explorer
  fi

  # Build the Docker image
  cd fabric-explorer
  ${CONTAINER_CLI} build -t hyperledger/fabric-explorer:latest .

  # Push to local registry
  echo "📦 Pushing image to local registry ${CONTROL_PLANE_IP}:${LOCAL_REGISTRY_PORT}..."
  ${CONTAINER_CLI} tag hyperledger/fabric-explorer:latest ${CONTROL_PLANE_IP}:${LOCAL_REGISTRY_PORT}/hyperledger/fabric-explorer:latest
  ${CONTAINER_CLI} push ${CONTROL_PLANE_IP}:${LOCAL_REGISTRY_PORT}/hyperledger/fabric-explorer:latest
  cd ..

  echo "✅ Hyperledger Fabric Explorer image built and pushed successfully!"
}
