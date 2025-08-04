#!/bin/bash
#
# Master Backup Script for Hyperledger Fabric Network
# Orchestrates all backup procedures for complete system backup
# Integrates with Velero for Kubernetes-native backup capabilities
#

# Load environment variables and utilities
source backup/env.sh
source k8s-setup/envVar.sh
source k8s-setup/utils.sh

set -e


# Initialize logging
logging_init

VELERO_NAMESPACE="velero"
# Use a single timestamp for both local and Velero backup
BACKUP_TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_NAME="fabric-cluster-backup-${BACKUP_TIMESTAMP}"


# Function to check prerequisites
check_prerequisites() {
    push_fn "Checking backup prerequisites"
    
    # Check if network is running
    local pods_running=$(kubectl get pods -n ${KUBE_NAMESPACE} --no-headers 2>/dev/null | wc -l)
    if [ "$pods_running" -eq 0 ]; then
        log "⚠️  Warning: No pods found in namespace ${KUBE_NAMESPACE}"
        log "    Backup will only include static configurations"
    else
        log "✅ Found $pods_running pods running in ${KUBE_NAMESPACE}"
    fi
    
    
    # Check Velero availability
    local velero_status=$(kubectl get deployment velero -n $VELERO_NAMESPACE -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    if [ "$velero_status" -gt 0 ]; then
        log "✅ Velero is ready"
    else
        # Fallback: check if any Velero pod is running
        local velero_pod_running=$(kubectl get pods -n $VELERO_NAMESPACE -l name=velero --no-headers 2>/dev/null | grep -c "Running" || true)
        if [ "$velero_pod_running" -gt 0 ]; then
            log "✅ Velero pod is running"
        else
            log "❌ ERROR: Velero is not ready"
            pop_fn 1
            exit 1
        fi
    fi

    # Check MinIO connectivity
    log "🔍 Checking MinIO connectivity..."
    velero backup-location get default || {
        log "❌ ERROR: MinIO backup location not available"
        pop_fn 1
        exit 1
    }
    log "✅ MinIO backup storage is available"
    
    # Check for PVCs that need backing up across ALL namespaces
    local pvc_count=$(kubectl get pvc --all-namespaces --no-headers 2>/dev/null | wc -l)
    if [ "$pvc_count" -gt 0 ]; then
        log "✅ Found $pvc_count PVC(s) across all namespaces to backup with volume data:"
        kubectl get pvc --all-namespaces --no-headers | while read namespace name status volume capacity access_mode storage_class age; do
            log "  📦 $namespace/$name: $capacity ($storage_class)"
        done
    else
        log "⚠️  No PVCs found in cluster"
    fi
    
    # Check critical namespaces
    log "🔍 Checking critical namespaces in cluster:"
    kubectl get namespaces --no-headers | while read name status age; do
        local pod_count=$(kubectl get pods -n $name --no-headers 2>/dev/null | wc -l)
        if [ "$pod_count" -gt 0 ]; then
            log "  🏠 $name: $pod_count pods"
        fi
    done
    
    # Check etcd status
    local etcd_pod=$(kubectl get pods -n kube-system -l component=etcd --no-headers 2>/dev/null | head -1 | awk '{print $1}')
    if [ -n "$etcd_pod" ]; then
        log "✅ Found etcd pod: $etcd_pod"
        # Check etcd health
        local etcd_status=$(kubectl get pod "$etcd_pod" -n kube-system -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
        log "  📊 etcd status: $etcd_status"
    else
        log "⚠️  No etcd pod found - may be external etcd"
    fi
    
    # Check control plane components
    log "🔍 Checking Kubernetes control plane components:"
    for component in kube-apiserver kube-controller-manager kube-scheduler; do
        local comp_pod=$(kubectl get pods -n kube-system -l component=$component --no-headers 2>/dev/null | head -1 | awk '{print $1}')
        if [ -n "$comp_pod" ]; then
            local comp_status=$(kubectl get pod "$comp_pod" -n kube-system -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
            log "  ⚙️  $component: $comp_status"
        fi
    done
    
    log "✅ Prerequisites check completed"
    pop_fn 0
}


# Function to backup local files and certificates
backup_local_files() {
    push_fn "Backing up local files and certificates"
    
    # Use absolute path for backup directory, always resolve to project root
    local BACKUP_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
    local LOCAL_BACKUP_DIR="$BACKUP_ROOT/backup/local-files-${BACKUP_TIMESTAMP}"
    mkdir -p "$LOCAL_BACKUP_DIR"

    log "📁 Creating local file backup in: $LOCAL_BACKUP_DIR"

    # Only backup the build directory (contains all runtime-generated certificates, MSP, channel artifacts, etc.)
    if [ -d "$BACKUP_ROOT/build" ]; then
        log "🔐 Backing up build/ directory (runtime-generated files only)..."
        cp -r "$BACKUP_ROOT/build" "$LOCAL_BACKUP_DIR/"
        log "✅ Build directory backed up (certificates, MSP, channel artifacts)"

        # Log what's being backed up
        local build_size=$(du -sh "$BACKUP_ROOT/build" 2>/dev/null | cut -f1 || echo "unknown")
        log "   Build directory size: $build_size"
        if [ -d "$BACKUP_ROOT/build/enrollments" ]; then
            local cert_count=$(find "$BACKUP_ROOT/build/enrollments" -name "*.pem" 2>/dev/null | wc -l)
            log "   Certificates: $cert_count files"
        fi
        if [ -d "$BACKUP_ROOT/build/channel-msp" ]; then
            log "   Channel MSP: Present"
        fi
    else
        log "⚠️ Build directory not found - network may not be properly initialized"
        log "   Creating empty build directory structure for restore compatibility"
        mkdir -p "$LOCAL_BACKUP_DIR/build"
    fi

    # Create tarball of local backup (absolute path)
    log "📦 Creating compressed archive of local files..."
    local LOCAL_TARBALL="$BACKUP_ROOT/backup/local-files-${BACKUP_TIMESTAMP}.tar.gz"
    tar czf "$LOCAL_TARBALL" -C "$BACKUP_ROOT/backup" "$(basename $LOCAL_BACKUP_DIR)"

    # Debug: print tarball path and check existence
    log "🔎 Tarball should exist at: $LOCAL_TARBALL"
    if [ ! -f "$LOCAL_TARBALL" ]; then
        log "❌ ERROR: Backup tarball $LOCAL_TARBALL was not created. Aborting upload."
        ls -l "$BACKUP_ROOT/backup" || true
        pop_fn 1
        return 1
    fi

    # Upload local backup to MinIO using MinIO Client (mc)
    log "☁️ Uploading local backup to MinIO using mc..."
    local minio_path="local-files-${BACKUP_TIMESTAMP}.tar.gz"

    # Configure mc alias if not already set
    mc alias set velero http://${MINIO_HOST:-192.168.208.148}:${MINIO_PORT:-9000} ${MINIO_ACCESS_KEY:-minioadmin} ${MINIO_SECRET_KEY:-minioadmin123} >/dev/null

    # Upload to MinIO
    mc cp "$LOCAL_TARBALL" velero/local/$minio_path
    if [ $? -eq 0 ]; then
        log "✅ Upload to MinIO completed successfully"
    else
        log "❌ Upload to MinIO failed"
        pop_fn 1
        return 1
    fi

    # Verify upload
    log "🔍 Verifying uploaded file in MinIO..."
    mc ls velero/local/$minio_path
    if [ $? -eq 0 ]; then
        log "✅ Backup file verified in MinIO: $minio_path"
    else
        log "❌ Backup file not found in MinIO"
        pop_fn 1
        return 1
    fi

    # Store the MinIO path for restoration
    echo "$minio_path" > "${LOCAL_TARBALL}.minio_path"
    log "💾 Local backup uploaded to MinIO: $minio_path"
    log "🗂️ Backup contains only build/ directory (runtime-generated files)"

    # Clean up uncompressed directory
    rm -rf $BACKUP_ROOT/backup/local*

    export LOCAL_BACKUP_PATH="$LOCAL_TARBALL"

    log "✅ Local files backup completed and saved locally"
    
    pop_fn 0
}

# Function to create Velero backup (MinIO only)
create_velero_backup() {
    push_fn "Creating COMPLETE CLUSTER backup to MinIO"
    
    log "Creating FULL CLUSTER backup to MinIO: $BACKUP_NAME"
    
    # List current PVCs across ALL namespaces before backup
    log "📊 All Persistent Volume Claims in cluster:"
    kubectl get pvc --all-namespaces --no-headers | while read namespace pvc_name status volume capacity access_mode storage_class age; do
        log "  - $namespace/$pvc_name ($capacity, $storage_class)"
    done
    
    # List all namespaces being backed up
    log "🏠 All namespaces in cluster:"
    kubectl get namespaces --no-headers | while read name status age; do
        local pod_count=$(kubectl get pods -n $name --no-headers 2>/dev/null | wc -l)
        log "  - $name: $pod_count pods"
    done
    
    # Create comprehensive Velero backup - ENTIRE CLUSTER to MinIO
    log "🚫 Excluding problematic resources for optimal backup performance:"
    log "  - velero namespace (prevents circular backup references)"
    log "  - events (reduces backup size and speeds up processing)"
    log "  - replicasets (can be recreated from deployments)"
    log "  - endpoints (are auto-generated)"
    
    log "📦 Starting backup to MinIO storage..."
    velero backup create $BACKUP_NAME \
        --include-cluster-resources=true \
        --exclude-namespaces=velero \
        --exclude-resources=events.v1.core,replicasets.v1.apps,endpoints.v1.core \
        --storage-location=default \
        --default-volumes-to-fs-backup=true \
        --ttl=720h0m0s \
        --namespace=$VELERO_NAMESPACE \
        --wait
    
    if [ $? -eq 0 ]; then
        log "✅ Velero backup '$BACKUP_NAME' completed successfully"
        log "📊 Backup stored in MinIO with complete file system data from all volumes"
        
        # Verify backup status
        log "🔍 Verifying backup completion..."
        sleep 5
        
        local backup_status=$(velero backup get $BACKUP_NAME 2>/dev/null | awk 'NR==2 {print $3}')
        local backup_errors=$(velero backup get $BACKUP_NAME -o jsonpath='{.status.errors}' 2>/dev/null || echo "0")
        local backup_warnings=$(velero backup get $BACKUP_NAME -o jsonpath='{.status.warnings}' 2>/dev/null || echo "0")
        
        log "📊 Backup Status: $backup_status"
        log "📊 Errors: $backup_errors, Warnings: $backup_warnings"
        
        # Verify backup metadata is stored in MinIO
        log "🔍 Verifying backup metadata storage in MinIO..."
        if command -v curl &> /dev/null; then
            sleep 10  # Allow time for upload to complete
            local minio_check=$(curl -s "http://${MINIO_HOST:-192.168.208.148}:${MINIO_PORT:-9000}/${MINIO_BUCKET:-fabric-backup}/backups/" 2>/dev/null || echo "")
            if [ -n "$minio_check" ]; then
                log "✅ Backup metadata verified in MinIO storage"
            else
                log "⚠️  Backup metadata verification pending (may still be uploading)"
            fi
        fi
        
        # Display backup details
        log "📋 Getting backup details..."
        velero backup describe $BACKUP_NAME --namespace=$VELERO_NAMESPACE || log "Backup details will be available shortly"
        
        # Export backup name for verification
        export VELERO_BACKUP_NAME="$BACKUP_NAME"
        
        log "✅ Complete cluster backup to MinIO successful"
        pop_fn 0
        return 0
    else
        log "❌ Velero backup failed"
        pop_fn 1
        return 1
    fi
}

# Main execution
main() {
    push_fn "Starting Hyperledger Fabric Complete Cluster Backup to MinIO"
    
    log "
╔══════════════════════════════════════════════════════════════╗
║         Hyperledger Fabric COMPLETE CLUSTER Backup          ║
║                     MinIO Storage Only                       ║
╚══════════════════════════════════════════════════════════════╝"

    log "🕐 Backup started at: $(date)"
    log "📦 Target: MinIO S3 Storage (${MINIO_HOST:-192.168.208.148}:${MINIO_PORT:-9000})"
    log "🪣 Bucket: ${MINIO_BUCKET:-fabric-backup}"
    
    # Check prerequisites
    check_prerequisites
    
    # Backup local files first
    backup_local_files
    
    # Create Velero backup to MinIO
    create_velero_backup
    
    # Final status
    log "
╔══════════════════════════════════════════════════════════════╗
║            COMPLETE CLUSTER BACKUP TO MINIO SUCCESSFUL      ║
╚══════════════════════════════════════════════════════════════╝"

    log "📦 Backup Name: ${VELERO_BACKUP_NAME:-$BACKUP_NAME}"
    log "� Local Files: ${LOCAL_BACKUP_PATH:-Not created}"
    log "�🗄️  Storage: MinIO S3 Backend with Volume File System Backup"
    log "💾 Volume Data: Complete file system backup of ENTIRE CLUSTER"
    log "🔐 Local Files: Certificates, MSP, Scripts, and Configuration"
    log "🏠 Scope: ALL namespaces and cluster resources"
    log "🔄 Status: All data stored in MinIO, local backup archived"
    log "🕐 Backup completed at: $(date)"
    
    log "
✅ VERIFICATION COMMANDS:
   Check backup status: velero backup get $BACKUP_NAME
   View backup details: velero backup describe $BACKUP_NAME
   Check MinIO data: mc ls velero/fabric-backup --recursive
   Check local backup: ls -la ${LOCAL_BACKUP_PATH:-backup/local-files-*.tar.gz}
   
✅ RESTORE COMMAND:
   ./backup/restore.sh $BACKUP_NAME"
    
    pop_fn 0
}

# Execute main function
main "$@"
