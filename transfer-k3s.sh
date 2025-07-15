#!/bin/bash

# --- Config ---
CONTROL_PLANE_HOST="192.168.208.1"
CONTROL_PLANE_USER="kym"
CONTROL_PLANE_PASS="1" 
BASE_PATH=${PWD}

# Worker Nodes
WORKER_NODES=(
  "192.168.208.147:ad1:1:/home/ad1/fabric-samples/test-network-k8s"
  "192.168.208.145:ad2:2:/home/ad2/fabric-samples/test-network-k8s"
  "192.168.208.146:ad3:3:/home/ad3/fabric-samples/test-network-k8s"
)  # Format: IP:USER:PASS:DEST_DIR
FILES=("join-cluster.sh" "registry.crt")

echo "📦 Starting transfer to WORKER nodes..."

# Lặp qua từng worker node
for worker in "${WORKER_NODES[@]}"; do
    IFS=':' read -r WORKER_HOST WORKER_USER WORKER_PASS DEST_DIR <<< "$worker"
    echo "📦 Starting transfer to WORKER ($WORKER_HOST)..."

    # Lặp qua từng file và copy
    for file in "${FILES[@]}"; do
        echo "➡️ Copying $file ..."
        sshpass -p "$WORKER_PASS" scp -o StrictHostKeyChecking=no "${BASE_PATH}/${file}" "${WORKER_USER}@${WORKER_HOST}:${DEST_DIR}/"

        if [ $? -eq 0 ]; then
            echo "✅ $file copied successfully to $WORKER_HOST."
        else
            echo "❌ Failed to copy $file to $WORKER_HOST. Check paths or permissions."
            exit 1
        fi
    done

    echo "🎉 All files copied to $WORKER_HOST successfully!"
done

echo "🏁 Transfer to all worker nodes completed!"