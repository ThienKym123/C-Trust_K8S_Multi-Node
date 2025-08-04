#!/usr/bin/env bash

# Copyright IBM Corp
# SPDX-License-Identifier: Apache-2.0

# ---- Configuration ----
K8S_VERSION="1.33.0"
CONTROL_PLANE_IP="192.168.208.1"
LOCAL_REGISTRY_PORT="5000"
REGISTRY_HOST="$CONTROL_PLANE_IP:$LOCAL_REGISTRY_PORT"
CERT_DIR="/etc/docker/certs.d/$REGISTRY_HOST"
REGISTRY_CERT="registry.crt"
JOIN_SCRIPT="join-cluster.sh"
CONTAINER_CLI="docker"

# ---- Utility functions ----
function log() {
  echo "[$(date +%F\ %T)] $@"
}

function fail() {
  log "❌ ERROR: $1"
  exit 1
}

function push_fn() { log "▶ $1"; }
function pop_fn() { log "✔ $1"; }

# ---- Prerequisites check ----
function check_prerequisites() {
  push_fn "Checking prerequisites"

  for cmd in $CONTAINER_CLI kubeadm kubelet; do
    if ! command -v $cmd &>/dev/null; then
      fail "$cmd not installed. Please install it."
    fi
  done

  local version
  version=$(kubeadm version -o short | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
  if [[ "$version" != "$K8S_VERSION" ]]; then
    fail "kubeadm version $version ≠ required $K8S_VERSION"
  fi

  # Ensure container runtime is running
  sudo systemctl is-active $CONTAINER_CLI &>/dev/null || {
    log "Container runtime is not running. Starting..."
    sudo systemctl start $CONTAINER_CLI
    sleep 2
    sudo systemctl is-active $CONTAINER_CLI &>/dev/null || fail "$CONTAINER_CLI failed to start"
  }

  # Disable swap
  sudo swapoff -a
  sudo sed -i '/ swap / s/^/#/' /etc/fstab

  pop_fn "Prerequisites verified"
}

# ---- Install Registry Cert ----
function install_registry_cert() {
  push_fn "Installing registry certificate"

  if [ ! -f "$REGISTRY_CERT" ]; then
    fail "Registry cert $REGISTRY_CERT not found. Copy it from control-plane."
  fi

  sudo mkdir -p "$CERT_DIR"
  sudo cp "$REGISTRY_CERT" "$CERT_DIR/ca.crt"
  sudo chmod 644 "$CERT_DIR/ca.crt"

  sudo mkdir -p /usr/local/share/ca-certificates/registry
  sudo cp "$REGISTRY_CERT" /usr/local/share/ca-certificates/registry/registry.crt
  echo "registry/registry.crt" | sudo tee -a /etc/ca-certificates.conf >/dev/null || true
  sudo update-ca-certificates || fail "Failed to update CA certificates"

  # Restart container runtime
  sudo systemctl restart $CONTAINER_CLI
  sleep 2
  sudo systemctl is-active $CONTAINER_CLI &>/dev/null || fail "$CONTAINER_CLI failed to restart"

  pop_fn "Registry certificate installed"
}

# ---- Optional: Add Insecure Registry ----
function configure_insecure_registry() {
  push_fn "Configuring insecure registry"

  local docker_config="/etc/docker/daemon.json"
  if [ ! -f "$docker_config" ]; then
    echo '{ "insecure-registries": ["'"$REGISTRY_HOST"'"] }' | sudo tee "$docker_config" >/dev/null
  else
    sudo jq --arg reg "$REGISTRY_HOST" '.["insecure-registries"] += [$reg]' "$docker_config" |
      sudo tee "$docker_config" >/dev/null
  fi

  sudo systemctl restart $CONTAINER_CLI
  sleep 2
  sudo systemctl is-active $CONTAINER_CLI &>/dev/null || fail "$CONTAINER_CLI failed to restart"

  pop_fn "Insecure registry configured"
}

# ---- Join cluster ----
function join_cluster() {
  push_fn "Joining Kubernetes cluster"

  [ -f "$JOIN_SCRIPT" ] || fail "$JOIN_SCRIPT not found. Copy it from control-plane."
  sudo bash "$JOIN_SCRIPT" >/dev/null || fail "Failed to join cluster"

  pop_fn "Cluster joined"
}

# ---- Clean node ----
function cluster_clean() {
  push_fn "Resetting node"

  sudo kubeadm reset -f
  sudo rm -rf /etc/kubernetes /var/lib/kubelet $CERT_DIR
  sudo ip link delete cni0 &>/dev/null || true
  sudo ip link delete flannel.1 &>/dev/null || true
  sudo rm -rf /var/lib/cni/ /run/flannel/ /etc/cni/net.d/*

  pop_fn "Node cleaned"
}

# ---- Restart node services ----
function restart_node() {
  push_fn "Restarting node services"

  sudo systemctl restart $CONTAINER_CLI
  sudo systemctl enable --now kubelet
  sudo systemctl restart kubelet
  sleep 3

  systemctl is-active --quiet kubelet || fail "kubelet is not running"

  pop_fn "Node services restarted"
}

# ---- Main Command ----
function cluster_command_group() {
  local cmd="${1:-init}"
  shift || true

  case "$cmd" in
    init)
      check_prerequisites
      install_registry_cert
      # configure_insecure_registry # Uncomment if registry is HTTP only
      join_cluster
      log "🎉 Worker node successfully joined cluster"
      ;;
    clean)
      check_prerequisites
      cluster_clean
      log "🧹 Worker node cleaned"
      ;;
    restart)
      check_prerequisites
      restart_node
      log "🔄 Node restarted"
      ;;
    *)
      log "Usage: $0 [init|clean|restart]"
      exit 1
      ;;
  esac
}

cluster_command_group "$@"
