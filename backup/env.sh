#!/bin/bash
#
# Environment Variables for Velero Backup System
# Source this file before running velero-setup.sh
#
# Usage: source backup/env.sh
#

# External MinIO Server Configuration
# Replace with your actual MinIO server details
export MINIO_HOST="192.168.208.148"          # IP address of your external MinIO server
export MINIO_PORT="9000"                     # MinIO server port (default: 9000)
export MINIO_ACCESS_KEY="minioadmin"         # MinIO access key
export MINIO_SECRET_KEY="minioadmin123"      # MinIO secret key
export MINIO_BUCKET="fabric-backup"          # Bucket name for backups
export MINIO_USE_SSL="false"                 # Set to "true" if using HTTPS

# Kubernetes Configuration
export KUBE_NAMESPACE="test-network"         # Fabric network namespace to backup
export VELERO_NAMESPACE="velero"             # Velero deployment namespace

# Network Configuration
export NETWORK_NAME="mychannel"              # Fabric network name
export CLUSTER_NAME="fabric-cluster"         # Kubernetes cluster name

# Backup Configuration
export BACKUP_RETENTION_HOURLY="168h0m0s"   # 7 days
export BACKUP_RETENTION_DAILY="720h0m0s"    # 30 days
export BACKUP_RETENTION_WEEKLY="2160h0m0s"  # 90 days

# Velero Version
export VELERO_VERSION="v1.16.1"

# Color codes for output (optional)
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export NC='\033[0m'

echo "✅ Environment variables loaded for Velero backup system"
echo "🗄️  MinIO Server: ${MINIO_HOST}:${MINIO_PORT}"
echo "🪣 Backup Bucket: ${MINIO_BUCKET}"
echo "🏷️  Fabric Namespace: ${KUBE_NAMESPACE}"
echo "📦 Velero Namespace: ${VELERO_NAMESPACE}"
echo ""
echo "To apply these settings, run:"
echo "  source backup/env.sh"
echo "  ./backup/velero-setup.sh"
