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
WORKER_JOIN_SCRIPT="join-worker.sh"
MASTER_JOIN_SCRIPT="join-master.sh"
CONTAINER_CLI="docker"

# ---- Utility functions ----
function log() { echo "[$(date +%F\ %T)] $@"; }
function fail() { log "❌ ERROR: $1"; exit 1; }
function push_fn() { log "▶ $1"; }
function pop_fn() { log "✔ $1"; }

# ---- Prerequisites check ----
function check_prerequisites() {
  push_fn "Checking prerequisites"

  for cmd in $CONTAINER_CLI kubeadm kubelet; do
    command -v $cmd &>/dev/null || fail "$cmd not installed"
  done

  local version=$(kubeadm version -o short | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
  [[ "$version" == "$K8S_VERSION" ]] || fail "kubeadm version $version ≠ required $K8S_VERSION"

  sudo systemctl is-active $CONTAINER_CLI &>/dev/null || {
    sudo systemctl start $CONTAINER_CLI
    sleep 2
    sudo systemctl is-active $CONTAINER_CLI &>/dev/null || fail "$CONTAINER_CLI failed to start"
  }

  sudo swapoff -a
  sudo sed -i '/ swap / s/^/#/' /etc/fstab

  pop_fn "Prerequisites verified"
}

# ---- Install Registry Cert ----
function install_registry_cert() {
  push_fn "Installing registry certificate"

  [ -f "$REGISTRY_CERT" ] || fail "Registry cert $REGISTRY_CERT not found"

  sudo mkdir -p "$CERT_DIR"
  sudo cp "$REGISTRY_CERT" "$CERT_DIR/ca.crt"
  sudo chmod 644 "$CERT_DIR/ca.crt"

  sudo mkdir -p /usr/local/share/ca-certificates/registry
  sudo cp "$REGISTRY_CERT" /usr/local/share/ca-certificates/registry/registry.crt
  echo "registry/registry.crt" | sudo tee -a /etc/ca-certificates.conf >/dev/null || true
  sudo update-ca-certificates || fail "Failed to update CA certificates"

  sudo systemctl restart $CONTAINER_CLI
  sleep 2
  sudo systemctl is-active $CONTAINER_CLI &>/dev/null || fail "$CONTAINER_CLI failed to restart"

  pop_fn "Registry certificate installed"
}

# ---- Join as worker ----
function join_worker() {
  push_fn "Joining as worker node"
  [ -f "$WORKER_JOIN_SCRIPT" ] || fail "$WORKER_JOIN_SCRIPT not found"
  sudo bash "$WORKER_JOIN_SCRIPT" >/dev/null || fail "Failed to join as worker"
  pop_fn "Worker node joined"
}

# ---- Join as master ----
function join_master() {
  push_fn "Joining as master node"
  [ -f "$MASTER_JOIN_SCRIPT" ] || fail "$MASTER_JOIN_SCRIPT not found"
  sudo bash "$MASTER_JOIN_SCRIPT" >/dev/null || fail "Failed to join as master"
  
  # Setup kubeconfig for master
  mkdir -p $HOME/.kube
  sudo cp -f /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config
  chmod 600 $HOME/.kube/config

  # # Untaint only this node
  # NODE_NAME=$(hostname -s)
  # log "Removing taints from $NODE_NAME"
  # kubectl taint nodes $NODE_NAME node.kubernetes.io/not-ready:NoSchedule- || true
  # kubectl taint nodes $NODE_NAME node-role.kubernetes.io/control-plane- || true

  pop_fn "Master node joined"
}

# ---- Clean node ----
function cluster_clean() {
  push_fn "Resetting node"

  sudo kubeadm reset -f
  sudo rm -rf /etc/kubernetes /var/lib/kubelet /var/lib/etcd /etc/cni/net.d /var/lib/cni
  sudo ip link delete cni0 2>/dev/null || true
  sudo ip link delete flannel.1 2>/dev/null || true

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
function main() {
  case "$1" in
    worker)
      check_prerequisites
      install_registry_cert
      join_worker
      log "🎉 Worker node joined cluster"
      ;;
    master)
      check_prerequisites
      install_registry_cert
      join_master
      log "🎉 Master node joined cluster"
      ;;
    clean)
      check_prerequisites
      cluster_clean
      log "🧹 Node cleaned"
      ;;
    restart)
      check_prerequisites
      restart_node
      log "🔄 Node restarted"
      ;;
    *)
      log "Usage: $0 [worker|master|clean|restart]"
      exit 1
      ;;
  esac
}

main "$@"