#!/bin/bash
#
# Production Backup Scheduler
# 3-level scheduling for hourly, daily, weekly backups
#

# Load environment variables
source backup/env.sh 2>/dev/null || {
  export MINIO_HOST="192.168.208.148"
  export MINIO_PORT="9000"
  export KUBE_NAMESPACE="test-network"
  export VELERO_NAMESPACE="velero"
}

source k8s-setup/utils.sh 2>/dev/null || {
  log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"; }
  push_fn() { log "▶️ $1"; }
  pop_fn() { log "✅ Completed"; }
}

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BACKUP_SCRIPT="$SCRIPT_DIR/backup.sh"

# Schedule configurations - 3 Level Strategy
declare -A SCHEDULES=(
    ["hourly"]="*-*-* *:00:00"
    ["daily"]="*-*-* 02:00:00"
    ["weekly"]="Sun *-*-* 03:00:00"
)

declare -A RETENTIONS=(
    ["hourly"]="168h"    # 7 days
    ["daily"]="720h"     # 30 days
    ["weekly"]="4320h"   # 180 days (extended for long-term)
)

# Backup level configurations - 3 Distinct Levels
declare -A BACKUP_LEVELS=(
    ["hourly"]="data-only"
    ["daily"]="namespace-full"
    ["weekly"]="cluster-complete"
)

declare -A BACKUP_DESCRIPTIONS=(
    ["hourly"]="Data-only backup (volumes and persistent data)"
    ["daily"]="Full namespace backup (all resources and volumes)"
    ["weekly"]="Complete cluster backup like backup.sh (full system)"
)

show_usage() {
    echo "3-Level Production Backup Scheduler"
    echo ""
    echo "Usage: $0 {hourly|daily|weekly|status|logs|remove|all}"
    echo ""
    echo "3-Level Backup Strategy:"
    echo "  hourly   - Data-only backup (volumes + persistent data, 7 days)"
    echo "  daily    - Full namespace backup (all resources + volumes, 30 days)"
    echo "  weekly   - Complete cluster backup like backup.sh (180 days)"
    echo "  all      - Setup complete 3-level strategy"
    echo ""
    echo "Management:"
    echo "  status   - Show scheduler status"
    echo "  logs     - View backup logs"
    echo "  remove   - Remove all schedulers"
    echo ""
    echo "Examples:"
    echo "  $0 all       # Setup complete 3-level strategy"
    echo "  $0 hourly    # Setup data-only hourly backups"
    echo "  $0 weekly    # Setup complete cluster backups"
    echo "  $0 status    # Check all schedules"
}

# Function to check if Velero is available
check_velero() {
    if ! command -v velero &> /dev/null; then
        log "❌ ERROR: Velero CLI not found"
        log "   Please install Velero CLI or run: ./backup.sh setup"
        exit 1
    fi

    if ! kubectl get deployment velero -n velero &> /dev/null; then
        log "❌ ERROR: Velero not deployed"
        log "   Please run: ./backup.sh setup"
        exit 1
    fi
}

setup_schedule() {
    local schedule_type="$1"
    check_velero

    if [[ ! "${SCHEDULES[$schedule_type]}" ]]; then
        log "❌ ERROR: Invalid schedule type: $schedule_type"
        show_usage
        exit 1
    fi

    push_fn "Setting up $schedule_type ${BACKUP_LEVELS[$schedule_type]} backup scheduling"

    local velero_schedule="fabric-$schedule_type"
    local backup_level="${BACKUP_LEVELS[$schedule_type]}"

    # Remove existing schedule if it exists
    log "🗑️  Removing existing $schedule_type schedule if present..."
    velero schedule delete "$velero_schedule" --confirm 2>/dev/null || true

    # Setup Velero schedule based on backup level
    log "📅 Creating $schedule_type schedule (${BACKUP_DESCRIPTIONS[$schedule_type]})..."

    local cron_schedule
    case "$schedule_type" in
        "hourly") cron_schedule="0 * * * *" ;;
        "daily") cron_schedule="0 2 * * *" ;;
        "weekly") cron_schedule="0 3 * * 0" ;;
    esac

    # Create schedule with 3 distinct backup levels
    case "$backup_level" in
        "data-only")
            # Hourly: Data-only backup (volumes and persistent data only)
            log "� Configuring data-only backup (volumes + persistent data)..."
            velero schedule create "$velero_schedule" \
                --schedule="$cron_schedule" \
                --include-namespaces="$KUBE_NAMESPACE" \
                --storage-location=default \
                --default-volumes-to-fs-backup=true \
                --include-resources="persistentvolumeclaims,persistentvolumes,secrets,configmaps" \
                --ttl="${RETENTIONS[$schedule_type]}" \
                --namespace="$VELERO_NAMESPACE"

            log "📋 Data-only backup includes:"
            log "   • Persistent Volume Claims (PVCs)"
            log "   • Persistent Volumes (PVs)"
            log "   • Secrets and ConfigMaps"
            log "   • Volume data and snapshots"
            ;;
        "namespace-full")
            # Daily: Complete namespace backup (all resources and volumes)
            log "📦 Configuring full namespace backup (all resources + volumes)..."
            velero schedule create "$velero_schedule" \
                --schedule="$cron_schedule" \
                --include-namespaces="$KUBE_NAMESPACE" \
                --storage-location=default \
                --default-volumes-to-fs-backup=true \
                --exclude-resources="events.v1.core,replicasets.v1.apps,endpoints.v1.core" \
                --ttl="${RETENTIONS[$schedule_type]}" \
                --namespace="$VELERO_NAMESPACE"

            log "📋 Full namespace backup includes:"
            log "   • All pods, services, deployments"
            log "   • All persistent volumes and data"
            log "   • All secrets, configmaps, and configs"
            log "   • Complete application state"
            ;;
        "cluster-complete")
            # Weekly: Complete cluster backup like backup.sh
            log "🏢 Configuring complete cluster backup (like backup.sh)..."
            velero schedule create "$velero_schedule" \
                --schedule="$cron_schedule" \
                --include-cluster-resources=true \
                --exclude-namespaces="velero" \
                --exclude-resources="events.v1.core,replicasets.v1.apps,endpoints.v1.core" \
                --storage-location=default \
                --default-volumes-to-fs-backup=true \
                --ttl="${RETENTIONS[$schedule_type]}" \
                --namespace="$VELERO_NAMESPACE"

            log "📋 Complete cluster backup includes:"
            log "   • All cluster resources and namespaces"
            log "   • All persistent volumes and data"
            log "   • Cluster-level configurations"
            log "   • Matches backup.sh comprehensive coverage"
            ;;
    esac

    log "
╔══════════════════════════════════════════════════════════════╗
║        $schedule_type ${backup_level^^} BACKUP COMPLETE     ║
╚══════════════════════════════════════════════════════════════╝"

    log "📅 Schedule: $cron_schedule"
    log "� Level: ${BACKUP_DESCRIPTIONS[$schedule_type]}"
    log "🗂️ Retention: ${RETENTIONS[$schedule_type]}"
    log "📦 Velero Schedule: $velero_schedule"

    pop_fn 0
}

# Function to setup complete multi-tier backup strategy
setup_all_schedules() {
    push_fn "Setting up 3-level backup strategy"

    log "🚀 Configuring 3-level backup strategy for optimal protection:"
    log "   � Hourly: Data-focused backups (volumes + persistent data)"
    log "   📦 Daily: Complete namespace backups (all resources + volumes)"
    log "   🏢 Weekly: Complete cluster backups (like backup.sh)"
    echo ""

    log "💡 This 3-level strategy provides:"
    log "   • Hourly protection of critical data and volumes"
    log "   • Daily complete application state backup"
    log "   • Weekly comprehensive cluster backup"
    log "   • Distinct backup levels with no redundancy"
    echo ""

    # Setup each schedule type
    for schedule_type in "hourly" "daily" "weekly"; do
        log "⏳ Setting up $schedule_type backup level..."
        setup_schedule "$schedule_type"
        echo ""
    done

    log "
╔══════════════════════════════════════════════════════════════╗
║            3-LEVEL BACKUP STRATEGY COMPLETE                 ║
╚══════════════════════════════════════════════════════════════╝"

    log "✅ All 3 backup levels configured successfully!"
    log "📊 3-Level Backup Coverage:"
    log "   � Hourly data-only backups (7 days retention)"
    log "   📦 Daily full namespace backups (30 days retention)"
    log "   🏢 Weekly complete cluster backups (180 days retention)"
    log ""
    log "🎯 Distinct Protection Benefits:"
    log "   • Critical data and volumes backed up every hour"
    log "   • Complete application state backed up daily"
    log "   • Full cluster backup weekly (like backup.sh)"
    log "   • No redundant backup levels"
    log ""
    log "🔍 Check status: $0 status"
    log "📋 View logs: $0 logs"

    pop_fn 0
}

show_status() {
    push_fn "Checking Velero backup scheduler status"

    echo "
╔══════════════════════════════════════════════════════════════╗
║                 VELERO BACKUP SCHEDULER STATUS              ║
╚══════════════════════════════════════════════════════════════╝"

    # Check Velero schedules
    if command -v velero &> /dev/null && kubectl get deployment velero -n velero &> /dev/null; then
        log "📅 Velero Schedules:"
        local schedules=$(velero schedule get --namespace="$VELERO_NAMESPACE" 2>/dev/null)

        if echo "$schedules" | grep -q "fabric-"; then
            echo "$schedules" | grep -E "(fabric-|NAME)"

            log ""
            log "📊 Schedule Details:"
            for schedule_type in "${!SCHEDULES[@]}"; do
                local velero_schedule="fabric-$schedule_type"
                if echo "$schedules" | grep -q "$velero_schedule"; then
                    log "  ✅ $schedule_type: Active (${RETENTIONS[$schedule_type]} retention)"
                fi
            done
        else
            log "   No Velero schedules found"
            log "   Run '$0 daily' to setup daily backups"
        fi
    else
        log "❌ Velero not available"
        log "   Run './backup.sh setup' to install Velero"
    fi

    # Show recent backups
    if command -v velero &> /dev/null; then
        log ""
        log "� Recent Backups:"
        velero backup get --namespace="$VELERO_NAMESPACE" 2>/dev/null | head -6 || log "   No backups found"
    fi

    pop_fn 0
}

remove_schedulers() {
    push_fn "Removing Velero backup schedulers"

    if command -v velero &> /dev/null && kubectl get deployment velero -n velero &> /dev/null; then
        for schedule_type in "${!SCHEDULES[@]}"; do
            local velero_schedule="fabric-$schedule_type"

            # Remove Velero schedule
            if velero schedule get "$velero_schedule" --namespace="$VELERO_NAMESPACE" &> /dev/null; then
                velero schedule delete "$velero_schedule" --confirm --namespace="$VELERO_NAMESPACE" 2>/dev/null || true
                log "🗑️  Removed $schedule_type Velero schedule"
            fi
        done

        log "✅ All Velero backup schedulers removed"
        log "📝 Note: Existing backups are preserved in storage"
    else
        log "❌ Velero not available"
        log "   No schedulers to remove"
    fi

    pop_fn 0
}

# Main execution
case "${1:-help}" in
    "hourly"|"daily"|"weekly")
        setup_schedule "$1"
        ;;
    "all")
        setup_all_schedules
        ;;
    "status")
        show_status
        ;;
    "remove")
        remove_schedulers
        ;;
    "help"|*)
        show_usage
        ;;
esac