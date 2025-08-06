#!/bin/bash
#
# Velero Setup Script with External MinIO and Pre-installed Velero CLI
# 
# Prerequisites:
# 1. Source environment variables: source backup/env.sh
# 2. Ensure MinIO is running on external server
# 3. Ensure Velero CLI is installed
#
set -e

# Load environment variables and utilities
source backup/env.sh
source k8s-setup/envVar.sh
source k8s-setup/utils.sh

# Initialize logging (skip if called from main backup.sh)
if [[ "$SKIP_LOGGING_INIT" != "true" ]]; then
  logging_init
fi

# Check if environment variables are loaded
if [ -z "$MINIO_HOST" ]; then
    log "❌ Environment variables not loaded. Please run:"
    log "   source backup/env.sh"
    log "   ./backup/velero-setup.sh"
    exit 1
fi

log "Velero backup setup started with external MinIO at $MINIO_HOST:$MINIO_PORT"

# External MinIO Configuration (from env.sh)
MINIO_NAMESPACE="${VELERO_NAMESPACE:-velero}"
MINIO_EXTERNAL_HOST="$MINIO_HOST"
MINIO_EXTERNAL_PORT="$MINIO_PORT"
MINIO_ACCESS_KEY="$MINIO_ACCESS_KEY"
MINIO_SECRET_KEY="$MINIO_SECRET_KEY"
MINIO_BUCKET="$MINIO_BUCKET"
MINIO_ENDPOINT="http://${MINIO_EXTERNAL_HOST}:${MINIO_EXTERNAL_PORT}"
MINIO_USE_SSL="${MINIO_USE_SSL:-false}"

# Velero Configuration
VELERO_VERSION="${VELERO_VERSION:-v1.16.1}"

# Function to check prerequisites
check_prerequisites() {
    push_fn "Checking Velero setup prerequisites"
    
    # Check if kubectl is available
    if ! command -v kubectl >/dev/null 2>&1; then
        log "ERROR: kubectl is not installed or not in PATH"
        pop_fn 1
        exit 1
    fi
    
    # Check if cluster is accessible
    if ! kubectl cluster-info >/dev/null 2>&1; then
        log "ERROR: Cannot access Kubernetes cluster"
        pop_fn 1
        exit 1
    fi
    
    # Check if we can create namespaces
    if ! kubectl auth can-i create namespaces >/dev/null 2>&1; then
        log "WARNING: May not have permissions to create namespaces"
    fi
    
    pop_fn 0
}

# Function to check Velero CLI
check_velero_cli() {
    push_fn "Checking Velero CLI installation"
    
    if ! command -v velero >/dev/null 2>&1; then
        log "ERROR: Velero CLI is not installed or not in PATH"
        log "Please install Velero CLI manually using the following commands:"
        log "   wget https://github.com/vmware-tanzu/velero/releases/download/v1.16.1/velero-v1.16.1-linux-amd64.tar.gz"
        log "   tar -xvf velero-v1.16.1-linux-amd64.tar.gz"
        log "   mv velero-v1.16.1-linux-amd64/velero ~/bin/ (or add to PATH)"
        pop_fn 1
        exit 1
    fi
    
    local current_version=$(velero version --client-only 2>/dev/null | grep -oP 'Version: \K[^,]+')
    if [ "$current_version" != "$VELERO_VERSION" ]; then
        log "WARNING: Velero CLI version ($current_version) does not match expected version ($VELERO_VERSION)"
        log "Consider updating Velero CLI to match version $VELERO_VERSION"
    else
        log "Velero CLI is installed (version: $current_version)"
    fi
    
    pop_fn 0
}

# Function to validate external MinIO connectivity
validate_minio_connectivity() {
    push_fn "Validating external MinIO storage backend"
    
    # Create velero namespace
    kubectl create namespace $MINIO_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    
    # Validate external MinIO configuration
    if [ -z "$MINIO_EXTERNAL_HOST" ] || [ "$MINIO_EXTERNAL_HOST" = "minio.example.com" ]; then
        log "ERROR: MINIO_HOST environment variable must be set to your external MinIO server"
        log "Example: export MINIO_HOST=192.168.1.100"
        pop_fn 1
        exit 1
    fi
    
    # Test connectivity to external MinIO
    log "Testing connectivity to external MinIO at $MINIO_ENDPOINT"
    if timeout 10 bash -c "</dev/tcp/${MINIO_EXTERNAL_HOST}/${MINIO_EXTERNAL_PORT}" 2>/dev/null; then
        log "MinIO server is reachable at $MINIO_ENDPOINT"
    else
        log "ERROR: Cannot reach MinIO server at $MINIO_ENDPOINT"
        log "Please ensure:"
        log "  1. MinIO is running on $MINIO_EXTERNAL_HOST:$MINIO_EXTERNAL_PORT"
        log "  2. Firewall allows access from Kubernetes nodes"
        log "  3. Network connectivity is available"
        pop_fn 1
        exit 1
    fi
    
    # Save credentials for reference
    cat > /tmp/minio-credentials.env << EOF
MINIO_ACCESS_KEY=$MINIO_ACCESS_KEY
MINIO_SECRET_KEY=$MINIO_SECRET_KEY
MINIO_BUCKET=$MINIO_BUCKET
MINIO_ENDPOINT=$MINIO_ENDPOINT
MINIO_HOST=$MINIO_EXTERNAL_HOST
MINIO_PORT=$MINIO_EXTERNAL_PORT
MINIO_USE_SSL=$MINIO_USE_SSL
EOF
    
    log "MinIO credentials saved to /tmp/minio-credentials.env"
    log "External MinIO endpoint: $MINIO_ENDPOINT"
    pop_fn 0
}

# Function to create Velero backup storage location
create_backup_storage_location() {
    push_fn "Creating backup storage location"
    
    # Create credentials file for Velero
    cat > /tmp/velero-credentials << EOF
[default]
aws_access_key_id=$MINIO_ACCESS_KEY
aws_secret_access_key=$MINIO_SECRET_KEY
EOF
    
    log "Velero credentials file created"

    # Ensure the local backup bucket exists
    log "Ensuring MinIO bucket 'local' exists..."
    mc alias set velero http://${MINIO_HOST}:${MINIO_PORT} ${MINIO_ACCESS_KEY} ${MINIO_SECRET_KEY} >/dev/null
    mc mb velero/fabric-backup --ignore-existing
    mc mb velero/local --ignore-existing
    if [ $? -eq 0 ]; then
        log "MinIO bucket 'local' is ready."
    else
        log "ERROR: Failed to create or verify MinIO bucket 'local'."
        pop_fn 1
        exit 1
    fi

    pop_fn 0
}

# Function to install Velero with MinIO backend
install_velero() {
    push_fn "Installing Velero with external MinIO backend"
    
    # Set up S3 URL based on SSL setting
    local s3_url_scheme="http"
    if [ "$MINIO_USE_SSL" = "true" ]; then
        s3_url_scheme="https"
    fi
    local s3_url="${s3_url_scheme}://${MINIO_EXTERNAL_HOST}:${MINIO_EXTERNAL_PORT}"
    
    # Install Velero using the CLI
    velero install \
        --provider aws \
        --plugins velero/velero-plugin-for-aws:v1.10.0 \
        --bucket $MINIO_BUCKET \
        --secret-file /tmp/velero-credentials \
        --use-volume-snapshots=false \
        --use-node-agent \
        --default-volumes-to-fs-backup \
        --backup-location-config region=minio,s3ForcePathStyle="true",s3Url="$s3_url" \
        --namespace $MINIO_NAMESPACE
    
    if [ $? -eq 0 ]; then
        log "Velero installed successfully"
    else
        log "ERROR: Velero installation failed"
        pop_fn 1
        return 1
    fi
    
    # Wait for Velero deployment to be ready
    log "Waiting for Velero deployment to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/velero -n $MINIO_NAMESPACE
    
    # Wait for node-agent daemonset to be ready
    log "Waiting for Velero node-agent daemonset to be ready..."
    kubectl wait --for=condition=ready --timeout=300s pod -l name=node-agent -n $MINIO_NAMESPACE || true
    
    log "Velero is ready"
    pop_fn 0
}

# Main execution function
main() {
    log "
╔══════════════════════════════════════════════════════════════╗
║                    Velero Backup Setup                      ║
║    Using External MinIO Storage Backend and Pre-installed CLI ║
╚══════════════════════════════════════════════════════════════╝"

    log "Setup started at: $(date)"
    
    # Run setup steps
    check_prerequisites
    check_velero_cli
    validate_minio_connectivity
    create_backup_storage_location
    install_velero

    # Final status
    log "
╔══════════════════════════════════════════════════════════════╗
║              VELERO BACKUP SETUP COMPLETED                  ║
╚══════════════════════════════════════════════════════════════╝"

    log "📋 Next Steps:"
    log "   1. Create backup schedules: ./backup/schedule.sh"
    log "   2. Monitor backups: ./backup/monitor.sh"
    log "🔐 MinIO credentials saved to: /tmp/minio-credentials.env"
    log "📝 Detailed logs: $LOG_FILE and $DEBUG_LOG_FILE"
    log "🕐 Setup completed at: $(date)"
}

# Execute main function
main "$@"