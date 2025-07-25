#!/bin/bash
#
# Auto Restore Script for Hyperledger Fabric Network
# Automatically restores from the latest backup or specified backup
# Handles both Kubernetes resources and local files
#

# Load environment variables and utilities
source backup/env.sh
source k8s-setup/envVar.sh
source k8s-setup/utils.sh

set -e

# Initialize logging
logging_init

VELERO_NAMESPACE="velero"
RESTORE_NAME="restore-$(date +%Y%m%d-%H%M%S)"

# Function to show usage
show_usage() {
    echo "Usage: $0 [BACKUP_NAME]"
    echo ""
    echo "Auto-restore Hyperledger Fabric network from backup"
    echo ""
    echo "Arguments:"
    echo "  BACKUP_NAME    Name of the backup to restore from (optional)"
    echo ""
    echo "Examples:"
    echo "  $0                                           # Restore from latest completed backup"
    echo "  $0 fabric-cluster-backup-20250725-155020     # Restore from specific backup"
    echo ""
    echo "Available backups:"
    velero backup get --no-headers 2>/dev/null | grep fabric-cluster-backup | grep Completed | head -5 || echo "  No completed backups found"
    echo ""
    exit 1
}

# Function to check prerequisites
check_prerequisites() {
    push_fn "Checking restore prerequisites"
    
    # Check Velero availability
    local velero_status=$(kubectl get deployment velero -n $VELERO_NAMESPACE -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    if [ "$velero_status" -eq 0 ]; then
        log "❌ Velero is not running in namespace $VELERO_NAMESPACE"
        log "   Please ensure Velero is properly installed and running"
        pop_fn 1
        exit 1
    else
        log "✅ Velero is running ($velero_status replicas ready)"
    fi
    
    # Check kubectl connectivity
    if ! kubectl cluster-info > /dev/null 2>&1; then
        log "❌ Cannot connect to Kubernetes cluster"
        pop_fn 1
        exit 1
    fi
    
    # Check if test-network namespace exists (should not exist for clean restore)
    if kubectl get namespace $KUBE_NAMESPACE > /dev/null 2>&1; then
        log "⚠️ Namespace $KUBE_NAMESPACE already exists"
        log "   Restore will overwrite existing resources"
    else
        log "✅ Clean environment - namespace $KUBE_NAMESPACE does not exist"
    fi
    
    log "✅ Prerequisites check completed"
    pop_fn 0
}

# Function to select backup
select_backup() {
    push_fn "Selecting backup to restore"
    
    if [ -n "$1" ]; then
        BACKUP_NAME="$1"
        log "📋 Using specified backup: $BACKUP_NAME"
    else
        # Get latest completed backup
        BACKUP_NAME=$(velero backup get --no-headers 2>/dev/null | grep fabric-cluster-backup | grep Completed | head -1 | awk '{print $1}')
        if [ -z "$BACKUP_NAME" ]; then
            log "❌ No completed fabric-cluster-backup found"
            log "Available backups:"
            velero backup get
            pop_fn 1
            exit 1
        fi
        log "📋 Using latest completed backup: $BACKUP_NAME"
    fi
    
    # Verify backup exists and is completed
    local backup_status=$(velero backup get $BACKUP_NAME 2>/dev/null | tail -n 1 | awk '{print $2}' || echo "NotFound")
    if [ "$backup_status" != "Completed" ]; then
        log "❌ Backup $BACKUP_NAME is not completed (status: $backup_status)"
        log "Available completed backups:"
        velero backup get | grep Completed
        pop_fn 1
        exit 1
    fi
    
    local backup_created=$(velero backup get $BACKUP_NAME 2>/dev/null | tail -n 1 | awk '{print $5 " " $6 " " $7}' || echo "Unknown")
    log "✅ Backup $BACKUP_NAME is ready for restore"
    log "   Status: $backup_status"
    log "   Created: $backup_created"
    
    # Validate backup name format
    if ! echo "$BACKUP_NAME" | grep -q '^fabric-cluster-backup-[0-9]\{8\}-[0-9]\{6\}$'; then
        log "❌ Invalid backup name format: $BACKUP_NAME"
        log "   Expected format: fabric-cluster-backup-YYYYMMDD-HHMMSS"
        pop_fn 1
        exit 1
    fi
    
    pop_fn 0
}

# Function to restore local files from MinIO
restore_local_files() {
    push_fn "Restoring local files from MinIO"
    
    # Extract timestamp from backup name (e.g., fabric-cluster-backup-20250725-155020)
    local backup_timestamp=$(echo $BACKUP_NAME | sed 's/fabric-cluster-backup-//')
    
    # Expected MinIO path for local backup
    local minio_path="local-backups/local-files-${backup_timestamp}.tar.gz"
    local local_backup_file="backup/local-files-${backup_timestamp}.tar.gz"
    
    log "☁️ Downloading local backup from MinIO..."
    log "   MinIO path: $minio_path"
    log "   Local path: $local_backup_file"
    
    # Create download job to get local backup from MinIO
    local job_name="download-local-backup-$(date +%H%M%S)"
    log "   Creating download job: $job_name"
    
    # Create the download job
    kubectl create job "$job_name" --image=amazon/aws-cli:latest -n $VELERO_NAMESPACE \
        --dry-run=client -o yaml | \
        sed "/spec:/a\\
  template:\\
    spec:\\
      restartPolicy: Never\\
      containers:\\
      - name: aws-cli\\
        image: amazon/aws-cli:latest\\
        env:\\
        - name: AWS_ACCESS_KEY_ID\\
          value: \"${MINIO_ACCESS_KEY:-minio}\"\\
        - name: AWS_SECRET_ACCESS_KEY\\
          value: \"${MINIO_SECRET_KEY:-minio123}\"\\
        - name: AWS_DEFAULT_REGION\\
          value: \"us-east-1\"\\
        command: [\"sh\", \"-c\"]\\
        args: [\"aws --endpoint-url=http://${MINIO_HOST:-192.168.208.148}:${MINIO_PORT:-9000} s3 cp s3://${MINIO_BUCKET:-fabric-backup}/${minio_path} /backup/$(basename $local_backup_file) && echo Download completed || echo Download failed\"]\\
        volumeMounts:\\
        - name: backup-volume\\
          mountPath: /backup\\
      volumes:\\
      - name: backup-volume\\
        hostPath:\\
          path: \"$(pwd)/backup\"" | \
    kubectl apply -f - 2>/dev/null
    
    if [ $? -eq 0 ]; then
        log "   Waiting for download to complete..."
        
        # Wait for job to complete (max 2 minutes)
        local timeout=120
        local elapsed=0
        while [ $elapsed -lt $timeout ]; do
            local job_status=$(kubectl get job "$job_name" -n $VELERO_NAMESPACE -o jsonpath='{.status.conditions[0].type}' 2>/dev/null || echo "")
            if [ "$job_status" = "Complete" ]; then
                log "✅ Download job completed successfully"
                break
            elif [ "$job_status" = "Failed" ]; then
                log "❌ Download job failed"
                pop_fn 1
                return 1
            fi
            sleep 5
            elapsed=$((elapsed + 5))
        done
        
        # Clean up the job
        kubectl delete job "$job_name" -n $VELERO_NAMESPACE 2>/dev/null || true
        
        # Check if file was downloaded
        if [ -f "$local_backup_file" ]; then
            log "✅ Local backup downloaded successfully: $local_backup_file"
            local backup_size=$(du -h "$local_backup_file" | cut -f1)
            log "   Backup size: $backup_size"
        else
            log "❌ Local backup file not found after download"
            log "   Checking for alternative local backups..."
            
            # Fallback to any existing local backup
            local_backup_file=$(ls backup/local-files-*.tar.gz 2>/dev/null | tail -1)
            if [ -n "$local_backup_file" ]; then
                log "⚠️ Using existing local backup: $local_backup_file"
                backup_timestamp=$(basename "$local_backup_file" | sed 's/local-files-//;s/.tar.gz//')
            else
                log "❌ No local backup files available"
                log "   Kubernetes restore will proceed, but build directory won't be restored"
                pop_fn 0
                return 0
            fi
        fi
    else
        log "❌ Failed to create download job"
        pop_fn 1
        return 1
    fi
    
    # Backup current build directory if it exists
    if [ -d "build" ]; then
        local backup_dir="build.backup.$(date +%Y%m%d-%H%M%S)"
        log "💾 Backing up current build directory to: $backup_dir"
        mv build "$backup_dir" || true
    fi
    
    # Extract local backup
    log "📂 Extracting local backup..."
    
    # Create temporary extraction directory
    local temp_dir="backup/temp_restore_$(date +%H%M%S)"
    mkdir -p "$temp_dir"
    
    # Extract the backup
    if tar -xzf "$local_backup_file" -C "$temp_dir" 2>/dev/null; then
        log "✅ Local backup extracted successfully"
        
        # Find the extracted directory
        local extracted_dir=$(find "$temp_dir" -maxdepth 1 -type d -name "local-files-*" | head -1)
        if [ -n "$extracted_dir" ] && [ -d "$extracted_dir/build" ]; then
            # Restore only the build directory
            cp -r "$extracted_dir/build" ./
            log "✅ Build directory restored (runtime-generated files only)"
            
            # Log what was restored
            if [ -d "build/enrollments" ]; then
                local cert_count=$(find build/enrollments -name "*.pem" 2>/dev/null | wc -l)
                log "   ✅ Certificates restored: $cert_count files"
            fi
            if [ -d "build/channel-msp" ]; then
                log "   ✅ Channel MSP restored"
            fi
            if [ -d "build/cas" ]; then
                log "   ✅ CA certificates restored"
            fi
        else
            log "❌ Build directory not found in backup"
        fi
        
        # Clean up temporary directory
        rm -rf "$temp_dir"
        
        log "✅ Local files restoration completed"
    else
        log "❌ Failed to extract local backup"
        rm -rf "$temp_dir"
        pop_fn 1
        return 1
    fi
    
    pop_fn 0
}

# Function to restore Kubernetes resources
restore_kubernetes_resources() {
    push_fn "Restoring Kubernetes resources from backup"
    
    log "🔄 Creating Velero restore: $RESTORE_NAME"
    log "📦 From backup: $BACKUP_NAME"
    
    # Create the restore
    if velero restore create $RESTORE_NAME --from-backup $BACKUP_NAME --wait; then
        log "✅ Kubernetes resources restored successfully"
        
        # Get restore status
        local restore_status=$(velero restore get $RESTORE_NAME -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
        local restore_errors=$(velero restore get $RESTORE_NAME -o jsonpath='{.status.errors}' 2>/dev/null || echo "0")
        local restore_warnings=$(velero restore get $RESTORE_NAME -o jsonpath='{.status.warnings}' 2>/dev/null || echo "0")
        
        log "📊 Restore Status: $restore_status"
        log "📊 Errors: $restore_errors, Warnings: $restore_warnings"
        
        if [ "$restore_errors" != "0" ]; then
            log "⚠️ Restore completed with errors. Check restore details:"
            log "   velero restore describe $RESTORE_NAME"
        fi
        
        pop_fn 0
        return 0
    else
        log "❌ Kubernetes restore failed"
        log "   Check restore status: velero restore describe $RESTORE_NAME"
        pop_fn 1
        return 1
    fi
}

# Function to wait for pods to be ready
wait_for_pods() {
    push_fn "Waiting for pods to be ready"
    
    log "⏳ Waiting for pods in namespace $KUBE_NAMESPACE..."
    
    # Wait up to 5 minutes for pods to be ready
    local timeout=300
    local elapsed=0
    local check_interval=10
    
    while [ $elapsed -lt $timeout ]; do
        local total_pods=$(kubectl get pods -n $KUBE_NAMESPACE --no-headers 2>/dev/null | wc -l)
        local ready_pods=$(kubectl get pods -n $KUBE_NAMESPACE --no-headers 2>/dev/null | grep -E "Running|Completed" | wc -l)
        
        if [ "$total_pods" -gt 0 ] && [ "$ready_pods" -eq "$total_pods" ]; then
            log "✅ All pods are ready ($ready_pods/$total_pods)"
            break
        fi
        
        log "⏳ Pods status: $ready_pods/$total_pods ready..."
        sleep $check_interval
        elapsed=$((elapsed + check_interval))
    done
    
    if [ $elapsed -ge $timeout ]; then
        log "⚠️ Timeout waiting for pods. Current status:"
        kubectl get pods -n $KUBE_NAMESPACE
    else
        log "📊 Final pod status:"
        kubectl get pods -n $KUBE_NAMESPACE
    fi
    
    pop_fn 0
}

# Function to verify restore
verify_restore() {
    push_fn "Verifying restore completion"
    
    # Check namespace exists
    if kubectl get namespace $KUBE_NAMESPACE > /dev/null 2>&1; then
        log "✅ Namespace $KUBE_NAMESPACE exists"
    else
        log "❌ Namespace $KUBE_NAMESPACE not found"
        pop_fn 1
        return 1
    fi
    
    # Check pods
    local pod_count=$(kubectl get pods -n $KUBE_NAMESPACE --no-headers 2>/dev/null | wc -l)
    if [ "$pod_count" -gt 0 ]; then
        log "✅ Found $pod_count pods in $KUBE_NAMESPACE"
        
        # List running pods
        kubectl get pods -n $KUBE_NAMESPACE --no-headers | while read name ready status restarts age; do
            if [ "$status" = "Running" ]; then
                log "  ✅ $name: $status ($ready ready)"
            else
                log "  ⚠️ $name: $status ($ready ready)"
            fi
        done
    else
        log "❌ No pods found in namespace $KUBE_NAMESPACE"
    fi
    
    # Check PVCs
    local pvc_count=$(kubectl get pvc -n $KUBE_NAMESPACE --no-headers 2>/dev/null | wc -l)
    if [ "$pvc_count" -gt 0 ]; then
        log "✅ Found $pvc_count PVCs in $KUBE_NAMESPACE"
    fi
    
    # Check local files - only build directory (runtime-generated files)
    if [ -d "build" ]; then
        log "✅ Build directory exists"
        local build_size=$(du -sh build 2>/dev/null | cut -f1 || echo "unknown")
        log "   Build directory size: $build_size"
        
        if [ -d "build/enrollments" ]; then
            local cert_count=$(find build/enrollments -name "*.pem" 2>/dev/null | wc -l)
            log "✅ Enrollments directory exists ($cert_count certificates)"
        fi
        if [ -d "build/channel-msp" ]; then
            log "✅ Channel MSP directory exists"
        fi
        if [ -d "build/cas" ]; then
            log "✅ CA certificates directory exists"
        fi
    else
        log "⚠️ Build directory not found"
        log "   This may indicate local files were not properly restored"
    fi
    
    log "✅ Restore verification completed"
    pop_fn 0
}

# Main function
main() {
    push_fn "Auto Restore - Hyperledger Fabric Network"
    
    # Show help if requested
    if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        show_usage
    fi
    
    log "
╔══════════════════════════════════════════════════════════════╗
║         Hyperledger Fabric AUTO RESTORE                     ║
║              From Velero + Local Backup                     ║
╚══════════════════════════════════════════════════════════════╝"

    log "🕐 Restore started at: $(date)"
    log "🎯 Target namespace: $KUBE_NAMESPACE"
    
    # Execute restore steps
    check_prerequisites
    select_backup "$1"
    restore_local_files
    restore_kubernetes_resources
    wait_for_pods
    verify_restore
    
    # Final summary
    log "
╔══════════════════════════════════════════════════════════════╗
║            AUTO RESTORE COMPLETED SUCCESSFULLY              ║
╚══════════════════════════════════════════════════════════════╝"

    log "📦 Restored from backup: $BACKUP_NAME"
    log "🏷️ Restore operation: $RESTORE_NAME"
    log "💾 Local files: Build directory restored from MinIO backup"
    log "🏠 Kubernetes resources: Restored from Velero backup"
    log "🔐 Runtime files: Certificates, MSP, and channel artifacts"
    log "🕐 Restore completed at: $(date)"
    
    log "
✅ VERIFICATION COMMANDS:
   Check pods: kubectl get pods -n $KUBE_NAMESPACE
   Check PVCs: kubectl get pvc -n $KUBE_NAMESPACE
   Check services: kubectl get svc -n $KUBE_NAMESPACE
   
✅ NEXT STEPS:
   Deploy chaincode: ./start.sh chaincode deploy supplychain-cc ./chaincode-go/
   Start applications: ./start.sh application
   Launch backend: ./start.sh backend
   Launch explorer: ./start.sh explorer"
    
    pop_fn 0
}

# Execute main function with all arguments
main "$@"