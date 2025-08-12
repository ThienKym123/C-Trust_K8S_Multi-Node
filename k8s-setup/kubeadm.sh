#!/usr/bin/env bash
#
# Copyright IBM Corp All Rights Reserved
#
# SPDX-License-License: Apache-2.0
#

source k8s-setup/check_pre.sh
source k8s-setup/envVar.sh
source k8s-setup/utils.sh

function generate_registry_certs() {
  push_fn "Generating TLS certificates for registry"

  sudo mkdir -p $CERT_DIR
  sudo openssl req -x509 -newkey rsa:4096 -nodes -days 365 \
    -keyout $CERT_DIR/$REGISTRY_KEY \
    -out $CERT_DIR/$REGISTRY_CERT \
    -subj "/CN=$LOCAL_REGISTRY_INTERFACE" \
    -addext "subjectAltName=IP:$LOCAL_REGISTRY_INTERFACE" >/dev/null 2>&1
  if [ $? -ne 0 ]; then
    log "ERROR: Failed to generate TLS certificates."
    exit 1
  fi

  sudo chmod 600 $CERT_DIR/$REGISTRY_KEY
  sudo chmod 644 $CERT_DIR/$REGISTRY_CERT

  sudo mkdir -p /etc/docker/certs.d/$LOCAL_REGISTRY_INTERFACE:$LOCAL_REGISTRY_PORT
  sudo cp $CERT_DIR/$REGISTRY_CERT /etc/docker/certs.d/$LOCAL_REGISTRY_INTERFACE:$LOCAL_REGISTRY_PORT/ca.crt

  pop_fn
}

function launch_docker_registry() {
  push_fn "Launching container registry \"${LOCAL_REGISTRY_NAME}\" at $LOCAL_REGISTRY_INTERFACE:${LOCAL_REGISTRY_PORT}"

  running="$($CONTAINER_CLI inspect -f '{{.State.Running}}' "${LOCAL_REGISTRY_NAME}" 2>/dev/null || true)"
  if [ "${running}" != 'true' ]; then
    $CONTAINER_CLI run \
      --detach \
      --restart always \
      --name "${LOCAL_REGISTRY_NAME}" \
      --publish "${LOCAL_REGISTRY_INTERFACE}:${LOCAL_REGISTRY_PORT}:5000" \
      -v $CERT_DIR:/certs \
      -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/$REGISTRY_CERT \
      -e REGISTRY_HTTP_TLS_KEY=/certs/$REGISTRY_KEY \
      registry:2 >/dev/null
    if [ $? -ne 0 ]; then
      log "ERROR: Failed to launch registry. Check Docker logs: $CONTAINER_CLI logs $LOCAL_REGISTRY_NAME"
      exit 1
    fi
  fi

  sleep 2
  curl -k https://$LOCAL_REGISTRY_INTERFACE:$LOCAL_REGISTRY_PORT/v2/ >/dev/null 2>&1
  if [ $? -ne 0 ]; then
    log "ERROR: Registry not accessible at https://$LOCAL_REGISTRY_INTERFACE:$LOCAL_REGISTRY_PORT"
    log "Check firewall (port 5000), certificates, or Docker logs: $CONTAINER_CLI logs $LOCAL_REGISTRY_NAME"
    exit 1
  fi

  pop_fn
}

function stop_docker_registry() {
  push_fn "Deleting container registry \"${LOCAL_REGISTRY_NAME}\" at $LOCAL_REGISTRY_INTERFACE:${LOCAL_REGISTRY_PORT}"

  $CONTAINER_CLI kill "${LOCAL_REGISTRY_NAME}" >/dev/null 2>&1 || true
  $CONTAINER_CLI rm "${LOCAL_REGISTRY_NAME}" >/dev/null 2>&1 || true

  pop_fn
}

# function init_control_plane() {
#   push_fn "Creating cluster \"${CLUSTER_NAME}\""

#   rm -rf $PWD/build
#   sudo kubeadm reset -f >/dev/null
#   sudo rm -rf /etc/kubernetes /var/lib/kubelet /var/lib/etcd $HOME/.kube

#   sudo kubeadm init \
#     --control-plane-endpoint "$LOCAL_REGISTRY_INTERFACE:6443" \
#     --pod-network-cidr="$POD_CIDR" \
#     --service-cidr="$SERVICE_CIDR" \
#     --kubernetes-version="$K8S_VERSION" \
#     --upload-certs \
#     --certificate-key "$(openssl rand -hex 32)" \
#     --ignore-preflight-errors=NumCPU,Mem
#   if [ $? -ne 0 ]; then
#     log "ERROR: kubeadm init failed. Check logs: journalctl -u kubelet"
#     exit 1
#   fi

#   mkdir -p $HOME/.kube
#   sudo cp -f /etc/kubernetes/admin.conf $HOME/.kube/config
#   sudo chown $(id -u):$(id -g) $HOME/.kube/config
#   chmod 600 $HOME/.kube/config
#   export KUBECONFIG=$HOME/.kube/config

#   kubectl get nodes >/dev/null 2>&1
#   if [ $? -ne 0 ]; then
#     log "ERROR: Control plane initialization failed. Check kubeadm logs: journalctl -u kubelet"
#     exit 1
#   fi

#   sudo sysctl net.ipv4.conf.all.route_localnet=1

#   pop_fn
# }

function init_control_plane() {
  push_fn "Creating cluster \"${CLUSTER_NAME}\""

  rm -rf $PWD/build
  sudo kubeadm reset -f >/dev/null
  sudo rm -rf /etc/kubernetes /var/lib/kubelet /var/lib/etcd $HOME/.kube

  # ensure hostname resolution maps to the intended IP (optional but recommended)
  # Replace with your real hostname if you prefer static mapping
  sudo sed -i "/$(hostname -s)/d" /etc/hosts || true
  echo "$LOCAL_REGISTRY_INTERFACE $(hostname -s)" | sudo tee -a /etc/hosts >/dev/null

  CERTIFICATE_KEY=$(openssl rand -hex 32)
  echo "$CERTIFICATE_KEY" > cert-key.txt

  sudo kubeadm init \
    --control-plane-endpoint "$LOCAL_REGISTRY_INTERFACE:6443" \
    --apiserver-advertise-address "$LOCAL_REGISTRY_INTERFACE" \
    --node-name "$(hostname -s)" \
    --apiserver-cert-extra-sans "$LOCAL_REGISTRY_INTERFACE" \
    --pod-network-cidr="$POD_CIDR" \
    --service-cidr="$SERVICE_CIDR" \
    --kubernetes-version="$K8S_VERSION" \
    --upload-certs \
    --certificate-key "$CERTIFICATE_KEY" \
    --ignore-preflight-errors=NumCPU,Mem
  if [ $? -ne 0 ]; then
    log "ERROR: kubeadm init failed. Check logs: journalctl -u kubelet"
    exit 1
  fi

  mkdir -p $HOME/.kube
  sudo cp -f /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config
  chmod 600 $HOME/.kube/config
  export KUBECONFIG=$HOME/.kube/config

  kubectl get nodes >/dev/null 2>&1
  if [ $? -ne 0 ]; then
    log "ERROR: Control plane initialization failed. Check kubeadm logs: journalctl -u kubelet"
    exit 1
  fi

  sudo sysctl net.ipv4.conf.all.route_localnet=1

  pop_fn
}



function delete_control_plane() {
  push_fn "Deleting cluster ${CLUSTER_NAME}"

  sudo kubeadm reset -f >/dev/null
  sudo rm -rf /etc/kubernetes /var/lib/kubelet /var/lib/etcd /etc/cni/net.d /var/lib/cni
  sudo ip link delete cni0 &>/dev/null || true
  sudo ip link delete flannel.1 &>/dev/null || true

  pop_fn
}

# function generate_join_command() {
#   push_fn "Generating join command for worker nodes"

#   JOIN_COMMAND=$(kubeadm token create --print-join-command)
#   if [ $? -ne 0 ]; then
#     log "ERROR: Failed to generate join command. Check kubeadm status."
#     exit 1
#   fi
#   echo "$JOIN_COMMAND" > join-cluster.sh
#   chmod +x join-cluster.sh
#   log "Join command saved to join-cluster.sh. Copy to worker nodes and run it."

#   pop_fn
# }

function generate_join_command() {
  push_fn "Generating join commands"

  JOIN_COMMAND=$(kubeadm token create --print-join-command)
  if [ $? -ne 0 ]; then
    log "ERROR: Failed to generate join command."
    exit 1
  fi
  
  echo "$JOIN_COMMAND" > join-worker.sh
  chmod +x join-worker.sh

  CERT_KEY=$(cat cert-key.txt)
  CA_HASH=$(openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //')
  TOKEN=$(kubeadm token create)
  
  echo "sudo kubeadm join $LOCAL_REGISTRY_INTERFACE:6443 --token $TOKEN --discovery-token-ca-cert-hash sha256:$CA_HASH --control-plane --certificate-key $CERT_KEY" > join-master.sh
  chmod +x join-master.sh

  log "Join commands saved to join-worker.sh and join-master.sh"

  pop_fn
}

# function kubeadm_init() {
#   log "Initializing Kubernetes cluster"
#   check_prerequisites_kubeadm
#   sudo swapoff -a
#   sudo sed -i '/ swap / s/^/#/' /etc/fstab
#   generate_registry_certs
#   launch_docker_registry
#   init_control_plane
#   generate_join_command
#   sudo cp /etc/docker/certs/$REGISTRY_CERT .
#   log "🏁 - Cluster control plane is ready"
# }

function kubeadm_init() {
  log "Initializing Kubernetes cluster"
  check_prerequisites_kubeadm
  sudo swapoff -a
  sudo sed -i '/ swap / s/^/#/' /etc/fstab
  generate_registry_certs
  launch_docker_registry
  init_control_plane
  generate_join_command
  sudo cp /etc/docker/certs/$REGISTRY_CERT .
  log "🏁 - Multi-master cluster ready"
  log "📋 - join-worker.sh: for workers | join-master.sh: for masters"
}

function kubeadm_clean() {
  log "Cleaning Kubernetes cluster"
  delete_control_plane
  stop_docker_registry
  rm -f join*.sh $REGISTRY_CERT cert-key.txt
  log "🏁 - Cluster is cleaned"
}

function kubeadm_restart() {
  sudo swapoff -a
  sudo sed -i '/ swap / s/^/#/' /etc/fstab
  sudo systemctl daemon-reexec
  sudo systemctl restart kubelet
}