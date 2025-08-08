# Cài đặt Dependencies

## Gỡ bỏ Kubernetes (Nếu đã cài đặt)

```shell
# Gỡ bỏ đánh dấu giữ các gói Kubernetes
sudo apt-mark unhold kubelet kubeadm kubectl

# Đặt lại kubeadm
sudo kubeadm reset -f

# Xóa các gói Kubernetes
sudo apt-get purge -y kubeadm kubectl kubelet kubernetes-cni
sudo apt-get autoremove -y

# Xóa containerd và Docker
sudo apt-get purge -y containerd docker.io
sudo apt-get autoremove -y

# Xóa các file cấu hình
sudo rm -rf /etc/kubernetes /var/lib/kubelet /var/lib/etcd ~/.kube
sudo rm -rf /etc/cni /var/lib/cni /var/run/calico
sudo rm -rf /etc/containerd /var/lib/docker
sudo rm -rf /var/run/docker.sock
sudo systemctl daemon-reexec

# Xóa repository của Kubernetes
sudo rm -f /etc/apt/sources.list.d/kubernetes.list
sudo rm -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# Khởi động lại hệ thống để đảm bảo trạng thái sạch
sudo reboot
```

## Kiểm tra lại trạng thái sau khi gỡ bỏ
```shell
sudo systemctl status kubelet
sudo systemctl status containerd
sudo systemctl status docker
```

## Cài đặt các Dependencies cần thiết

```shell
# Cập nhật hệ thống và cài đặt công cụ cơ bản
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg

# Cài đặt Containerd
sudo apt-get install -y containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd

# Cài đặt Docker và Golang (cho Fabric)
sudo apt-get install git curl docker.io docker-compose golang-go jq -y
sudo systemctl start docker
sudo usermod -aG docker $USER

# Kiểm tra phiên bản Docker
docker --version
docker-compose --version

sudo systemctl enable docker
sudo reboot
```

## Cài NodeJS
```shell
# Cài đặt nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

nvm --version

# Cài đặt NodeJS
nvm install 23
nvm alias default 23
nvm use 23
```

## Cài đặt Hyperledger Fabric
```shell
curl -sSLO https://raw.githubusercontent.com/hyperledger/fabric/main/scripts/install-fabric.sh && chmod +x install-fabric.sh

./install-fabric.sh d s b
```

## Cài đặt công cụ Kubernetes (kubelet, kubeadm, kubectl)

```shell
# Thêm repository của Kubernetes
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.33/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.33/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Cài đặt các gói Kubernetes
sudo apt-get update
sudo apt-get install -y kubelet=1.33.0-1.1 kubeadm=1.33.0-1.1 kubectl=1.33.0-1.1

# Giữ các gói để tránh cập nhật không mong muốn
sudo apt-mark hold kubelet kubeadm kubectl
sudo systemctl enable kubelet
sudo systemctl start kubelet

# Cài helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```
## Cấu hình hệ thống
```shell
# Tắt swap
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# Tải các module kernel cần thiết
cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter

# Cấu hình sysctl cho Kubernetes
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
sudo sysctl --system
```

## Cài đặt NFS lưu trữ dữ liệu

- Trên máy chủ NFS (192.168.208.1)
```shell
sudo apt-get install nfs-kernel-server -y
sudo mkdir -p /mnt/nfs_share
sudo chmod -R 777 /mnt/nfs_share
echo '/mnt/nfs_share *(rw,sync,no_subtree_check,no_root_squash)' | sudo tee -a /etc/exports
sudo exportfs -a
sudo systemctl restart nfs-kernel-server
```

- Trên các workder node
```shell
sudo apt-get install nfs-common -y
sudo mkdir -p /mnt/nfs_clientshare
sudo mount 192.168.208.1:/mnt/nfs_share /mnt/nfs_clientshare
```

## Cài đặt MinIO: Trên 1 máy riêng biệt (192.168.208.148)
```shell
# Tải và cài đặt MinIO Binary
wget https://dl.min.io/server/minio/release/linux-amd64/minio
chmod +x minio
sudo mv minio /usr/local/bin/

# Tạo thư mục lưu trữ dữ liệu
sudo mkdir -p /data/minio
sudo chown -R $USER:$USER /data/minio
```
### Tạo MinIO Service (systemd)
```shell
sudo nano /etc/systemd/system/minio.service
```
#### Đoạn mã

[Unit]
Description=MinIO Object Storage
After=network.target

[Service]
User=ad4
Group=ad4
Environment="MINIO_ROOT_USER=minioadmin"
Environment="MINIO_ROOT_PASSWORD=minioadmin123"
ExecStart=/usr/local/bin/minio server /data/minio --address :9000 --console-address :9001
Restart=always
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target

### Kích hoạt MinIO Service
```shell
sudo systemctl daemon-reexec
sudo systemctl enable --now minio
sudo systemctl status minio
```

## Cài đặt MinIO Client (mc) trên toàn bộ cụm
```shell
wget https://dl.min.io/client/mc/release/linux-amd64/mc
chmod +x mc
sudo mv mc /usr/local/bin/

# Cấu hình MinIO Client Alias
mc alias set velero http://192.168.208.148:9000 minioadmin minioadmin123
mc alias set velero http://127.0.0.1:9000 minioadmin minioadmin123
```

