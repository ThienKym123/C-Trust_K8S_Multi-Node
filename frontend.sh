#!/usr/bin/env bash

# SPDX-License-Identifier: Apache-2.0

# Load environment variables
. k8s-setup/envVar.sh

set -e

# Deploy frontend application
deploy_frontend() {
  echo "🚀 Deploying frontend to namespace ${KUBE_NAMESPACE}..."

  # Ensure namespace exists
  if ! kubectl get namespace ${KUBE_NAMESPACE} &> /dev/null; then
    echo "🔧 Creating namespace ${KUBE_NAMESPACE}..."
    kubectl create namespace ${KUBE_NAMESPACE}
  fi
  
  # Build Docker image
  echo "🔨 Building frontend Docker image..."
  cd frontend
  ${CONTAINER_CLI} build -t test-network-frontend:latest .
  
  # Push to local registry
  echo "📦 Pushing frontend image to local registry ${CONTROL_PLANE_IP}:${LOCAL_REGISTRY_PORT}..."
  ${CONTAINER_CLI} tag test-network-frontend:latest ${CONTROL_PLANE_IP}:${LOCAL_REGISTRY_PORT}/test-network-frontend:latest
  ${CONTAINER_CLI} push ${CONTROL_PLANE_IP}:${LOCAL_REGISTRY_PORT}/test-network-frontend:latest
  cd ..

  # Deploy frontend Deployment + Service + Ingress
  echo "📁 Creating frontend deployment, service, and ingress..."
  
  envsubst < kube/frontend-deployment.yaml | kubectl apply -f -
  envsubst < kube/frontend-service.yaml | kubectl apply -f -
  envsubst < kube/frontend-ingress.yaml | kubectl apply -f -

  # Wait for deployment to become ready
  echo "⏳ Waiting for frontend deployment to be ready..."
  kubectl rollout status deployment/frontend -n ${KUBE_NAMESPACE} --timeout=120s

  # Wait for pod to be running
  echo "🔍 Ensuring frontend pod is running..."
  kubectl wait --for=condition=Ready pod -l app=frontend -n ${KUBE_NAMESPACE} --timeout=60s

  echo "✅ Frontend deployed successfully!"
  kubectl get pods -n ${KUBE_NAMESPACE} -l app=frontend
  kubectl get svc -n ${KUBE_NAMESPACE} -l app=frontend
  kubectl get ingress -n ${KUBE_NAMESPACE} -l app=frontend

  echo ""
  echo "🌍 Access the frontend at: https://frontend.${DOMAIN}"
  echo "🔁 Example curl:"
  echo "curl -k https://frontend.${DOMAIN}"
}

# Clean up frontend resources
clean_frontend() {
  echo "🧹 Cleaning frontend deployment, services, ingress..."
  
  kubectl delete deployment frontend -n ${KUBE_NAMESPACE} --ignore-not-found
  kubectl delete svc frontend -n ${KUBE_NAMESPACE} --ignore-not-found
  kubectl delete ingress frontend-ingress -n ${KUBE_NAMESPACE} --ignore-not-found

  echo "⏳ Waiting for frontend resources to be terminated..."
  kubectl wait --for=delete pod -l app=frontend -n ${KUBE_NAMESPACE} --timeout=60s || true
  kubectl wait --for=delete svc/frontend -n ${KUBE_NAMESPACE} --timeout=30s || true
  kubectl wait --for=delete ingress/frontend-ingress -n ${KUBE_NAMESPACE} --timeout=30s || true

  echo "🗑 Removing frontend Docker images..."
  ${CONTAINER_CLI} rmi ${CONTROL_PLANE_IP}:${LOCAL_REGISTRY_PORT}/test-network-frontend:latest || true
  ${CONTAINER_CLI} rmi test-network-frontend:latest || true

  echo "✅ Frontend cleanup completed!"
}

# Run frontend outside of Kubernetes
run_frontend_local() {
  echo "🚀 Running frontend locally outside of Kubernetes..."
  
  # Change to frontend directory
  cd frontend
  
  # Check if node_modules exists, if not install dependencies
  if [ ! -d "node_modules" ]; then
    echo "📦 Installing frontend dependencies..."
    npm install
  fi
  
  # Check if backend is running (assuming it's running on the k8s cluster)
  BACKEND_URL="https://backend.${DOMAIN}:${NGINX_HTTPS_PORT}"
  echo "🔗 Backend URL: ${BACKEND_URL}"
  
  # Create .env file for local development
  echo "🔧 Creating environment configuration..."
  cat > .env.local << EOF
REACT_APP_API_URL=${BACKEND_URL}
REACT_APP_NETWORK_NAME=${NETWORK_NAME}
REACT_APP_DEBUG=true
REACT_APP_DEFAULT_MSP=Org1MSP
BROWSER=none
EOF
  
  # Set environment variables for local development
  export PORT=3000
  export BROWSER=none
  export REACT_APP_API_URL=${BACKEND_URL}
  export REACT_APP_NETWORK_NAME=${NETWORK_NAME}
  export REACT_APP_DEBUG=true
  
  echo "🌐 Starting React development server..."
  echo "Frontend will be available at: http://localhost:3000"
  echo "Backend API: ${BACKEND_URL}"
  echo ""
  echo "Press Ctrl+C to stop the frontend server"
  echo ""
  
  # Start the React development server
  npm start
  
  cd ..
}

# Stop frontend running locally
stop_frontend_local() {
  echo "🛑 Stopping local frontend..."
  
  # Kill any running React development server
  pkill -f "react-scripts start" || true
  pkill -f "node.*react-scripts" || true
  
  echo "✅ Local frontend stopped!"
}
