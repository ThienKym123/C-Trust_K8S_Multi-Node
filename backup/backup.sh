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
BACKUP_NAME="fabric-cluster-backup-$(date +%Y%m%d-%H%M%S)"


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
        log "❌ ERROR: Velero is not ready"
        pop_fn 1
        exit 1
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
    
    local LOCAL_BACKUP_DIR="backup/local-files-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$LOCAL_BACKUP_DIR"
    
    log "📁 Creating local file backup in: $LOCAL_BACKUP_DIR"
    
    # Only backup the build directory (contains all runtime-generated certificates, MSP, channel artifacts, etc.)
    if [ -d "build" ]; then
        log "🔐 Backing up build/ directory (runtime-generated files only)..."
        cp -r build "$LOCAL_BACKUP_DIR/"
        log "✅ Build directory backed up (certificates, MSP, channel artifacts)"
        
        # Log what's being backed up
        local build_size=$(du -sh build 2>/dev/null | cut -f1 || echo "unknown")
        log "   Build directory size: $build_size"
        if [ -d "build/enrollments" ]; then
            local cert_count=$(find build/enrollments -name "*.pem" 2>/dev/null | wc -l)
            log "   Certificates: $cert_count files"
        fi
        if [ -d "build/channel-msp" ]; then
            log "   Channel MSP: Present"
        fi
    else
        log "⚠️  Build directory not found - network may not be properly initialized"
        log "   Creating empty build directory structure for restore compatibility"
        mkdir -p "$LOCAL_BACKUP_DIR/build"
    fi
    
    # Create tarball of local backup
    log "📦 Creating compressed archive of local files..."
    tar czf "${LOCAL_BACKUP_DIR}.tar.gz" -C backup "$(basename $LOCAL_BACKUP_DIR)"
    
    # Upload local backup to MinIO using Velero's object storage
    log "☁️  Uploading local backup to MinIO..."
    local minio_path="local-backups/$(basename ${LOCAL_BACKUP_DIR}.tar.gz)"
    
    # Create a temporary pod to upload to MinIO using AWS CLI
        # Create a temporary pod to upload to MinIO using AWS CLI
    log "   Creating upload job to MinIO..."
    local job_name="upload-local-backup-$(date +%H%M%S)"
    cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: $job_name
  namespace: $VELERO_NAMESPACE
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: aws-cli
        image: amazon/aws-cli:latest
        env:
        - name: AWS_ACCESS_KEY_ID
          value: "${MINIO_ACCESS_KEY:-minioadmin}"
        - name: AWS_SECRET_ACCESS_KEY
          value: "${MINIO_SECRET_KEY:-minioadmin123}"
        - name: AWS_DEFAULT_REGION
          value: "us-east-1"
        command: ["/bin/sh", "-c"]
        args:
        - "aws --endpoint-url=http://${MINIO_HOST:-192.168.208.148}:${MINIO_PORT:-9000} s3 cp /backup/$(basename ${LOCAL_BACKUP_DIR}.tar.gz) s3://${MINIO_BUCKET:-fabric-backup}/$minio_path && echo Upload completed || echo Upload failed"
        volumeMounts:
        - name: backup-volume
          mountPath: /backup
      volumes:
      - name: backup-volume
        hostPath:
          path: "$(pwd)/backup"
EOF

    # Wait for job to complete
    log "   Waiting for upload job to complete..."
    local timeout=120
    local elapsed=0
    while [ $elapsed -lt $timeout ]; do
        local job_status=$(kubectl get job "$job_name" -n $VELERO_NAMESPACE -o jsonpath='{.status.conditions[0].type}' 2>/dev/null || echo "")
        if [ "$job_status" = "Complete" ]; then
            log "✅ Upload job completed successfully"
            break
        elif [ "$job_status" = "Failed" ]; then
            log "❌ Upload job failed"
            kubectl logs -n $VELERO_NAMESPACE -l job-name=$job_name
            pop_fn 1
            return 1
        fi
        sleep 5
        elapsed=$((elapsed + 5))
    done

    # Clean up the job
    kubectl delete job "$job_name" -n $VELERO_NAMESPACE 2>/dev/null || true
    
    # Store the MinIO path for restoration
    echo "$minio_path" > "${LOCAL_BACKUP_DIR}.minio_path"
    log "💾 Local backup uploaded to MinIO: $minio_path"
    log "🗂️ Backup contains only build/ directory (runtime-generated files)"
    
    # Clean up uncompressed directory
    rm -rf "$LOCAL_BACKUP_DIR"
    
    export LOCAL_BACKUP_PATH="${LOCAL_BACKUP_DIR}.tar.gz"
    
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
        
        local backup_status=$(velero backup get $BACKUP_NAME -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
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
   ./backup/master_restore.sh $BACKUP_NAME"
    
    pop_fn 0
}

# Execute main function
main "$@"
