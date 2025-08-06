#!/usr/bin/env bash
#
# Hyperledger Fabric Backup Management Script
# 3-Level Backup Strategy: Data-only (hourly) | Namespace (daily) | Cluster (weekly)
#
# SPDX-License-Identifier: Apache-2.0
#
set -o errexit

function print_help() {
  set +x
  log
  log "--- Backup System Information"
  log "MinIO Server       \t\t: ${MINIO_HOST:-192.168.208.148}:${MINIO_PORT:-9000}"
  log "MinIO Bucket       \t\t: ${MINIO_BUCKET:-fabric-backup}"
  log "Velero Version     \t\t: v1.16.1"
  log "Backup Namespace   \t\t: ${KUBE_NAMESPACE:-test-network}"
  log "Velero Namespace   \t\t: ${VELERO_NAMESPACE:-velero}"
  log
  log "--- 3-Level Backup Strategy"
  log "Level 1 (Hourly)   \t\t: Data-only backups (7 days retention)"
  log "Level 2 (Daily)    \t\t: Full namespace backups (30 days retention)"
  log "Level 3 (Weekly)   \t\t: Complete cluster backups (180 days retention)"
  log
  log "--- Cluster Information"
  log "Cluster runtime    \t\t: ${CLUSTER_RUNTIME:-kubeadm}"
  log "Cluster name       \t\t: ${CLUSTER_NAME:-fabric-cluster}"
  log "Cluster namespace  \t\t: ${NS:-test-network}"
  log "Network name       \t\t: ${NETWORK_NAME:-test-network}"
  log
  log "--- Script Information"
  log "Log file           \t\t: ${LOG_FILE:-network.log}"
  log "Backup directory   \t\t: $(pwd)/backup"
  log "Schedule script    \t\t: backup/schedule.sh"
  log
  log "Usage: $0 {setup|restore|schedule|monitor|list|strategy|uninstall|help}"
  log "3-Level Backup Strategy: Data-only (hourly) | Namespace (daily) | Cluster (weekly)"
  log
  log "SETUP COMMANDS:"
  log "  setup              - Install and configure Velero with MinIO"
  log "  uninstall          - Uninstall Velero and cleanup backup system"
  log
  log "RESTORE COMMANDS:"
  log "  restore            - Interactive restore from available backups"
  log "  restore <name>     - Restore from specific backup"
  log
  log "SCHEDULING COMMANDS:"
  log "  schedule all       - Setup 3-level backup strategy"
  log "  schedule hourly    - Setup data-only hourly backups"
  log "  schedule daily     - Setup full namespace backups"
  log "  schedule weekly    - Setup complete cluster backups"
  log "  schedule status    - Check scheduler status"
  log "  schedule logs      - View backup logs"
  log "  schedule remove    - Remove all schedulers"
  log
  log "MONITORING COMMANDS:"
  log "  list               - List all available backups"
  log "  strategy           - Show 3-level backup strategy information"
  log
  log "EXAMPLES:"
  log "  $0 setup                     # Initial setup"
  log "  $0 schedule all              # Setup 3-level backup strategy"
  log "  $0 schedule hourly           # Create data-only backup"
  log "  $0 schedule daily            # Create full namespace backup"
  log "  $0 schedule weekly           # Create complete cluster backup"
  log "  $0 list                      # List available backups"
  log "  $0 schedule status           # Check scheduler status"
  log "  $0 restore                   # Interactive restore"
}

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"; }
push_fn() { log "▶️ $1"; }
pop_fn() { log "✅ Completed"; }
logging_init() { :; }

# Set up logging environment
export LOG_FILE="${LOG_FILE:-network.log}"
export DEBUG_FILE="${DEBUG_FILE:-network-debug.log}"

# Load environment variables
source backup/env.sh 2>/dev/null || {
  echo "⚠️  backup/env.sh not found, using defaults"
  export MINIO_HOST="192.168.208.148"
  export MINIO_PORT="9000"
  export MINIO_BUCKET="fabric-backup"
  export KUBE_NAMESPACE="test-network"
  export VELERO_NAMESPACE="velero"
}

# Initialize logging
if command -v logging_init &> /dev/null; then
  logging_init
fi

# Parse mode
if [ $# -lt 1 ]; then
  print_help
  exit 0
fi

MODE="$1"
shift

case "${MODE}" in
  setup)
    push_fn "Setting up Velero backup system"
    if [[ -f "backup/setup.sh" ]]; then
      backup/setup.sh
      log "🏁 - Velero backup system is ready"
    else
      log "❌ Setup script not found: backup/setup.sh"
      pop_fn 1
      exit 1
    fi
    pop_fn 0
    ;;
  restore)
    push_fn "Restoring from backup"
    if [[ -f "backup/restore.sh" ]]; then
      backup/restore.sh "$@"
      log "🏁 - Restore operation completed"
    else
      log "❌ Restore script not found: backup/restore.sh"
      pop_fn 1
      exit 1
    fi
    pop_fn 0
    ;;
  schedule)
    push_fn "Managing backup schedules"
    if [[ -f "backup/schedule.sh" ]]; then
      backup/schedule.sh "$@"
      log "🏁 - Schedule operation completed"
    else
      log "❌ Schedule script not found: backup/schedule.sh"
      pop_fn 1
      exit 1
    fi
    pop_fn 0
    ;;
  list)
    push_fn "Listing available backups"
    if command -v velero &> /dev/null; then
      echo "" > /dev/tty
      echo "📋 Available Backups:" > /dev/tty
      echo "" > /dev/tty
      velero backup get --namespace="$VELERO_NAMESPACE" 2>/dev/null > /dev/tty || echo "   No backups found" > /dev/tty
      log "🏁 - Backup list displayed"
    else
      log "❌ Velero CLI not available"
      pop_fn 1
      exit 1
    fi
    pop_fn 0
    ;;
  strategy)
    push_fn "Showing 3-level backup strategy"
    echo "" > /dev/tty
    echo "╔══════════════════════════════════════════════════════════════╗" > /dev/tty
    echo "║                 3-LEVEL BACKUP STRATEGY                     ║" > /dev/tty
    echo "╚══════════════════════════════════════════════════════════════╝" > /dev/tty
    echo "" > /dev/tty
    echo "💾 Level 1 - Data-Only Backup:" > /dev/tty
    echo "   Command: $0 schedule hourly" > /dev/tty
    echo "   Scope: PVCs, PVs, Secrets, ConfigMaps, Volume data" > /dev/tty
    echo "   Schedule: Hourly (7 days retention)" > /dev/tty
    echo "" > /dev/tty
    echo "📦 Level 2 - Full Namespace Backup:" > /dev/tty
    echo "   Command: $0 schedule daily" > /dev/tty
    echo "   Scope: All namespace resources and volumes" > /dev/tty
    echo "   Schedule: Daily (30 days retention)" > /dev/tty
    echo "" > /dev/tty
    echo "🏢 Level 3 - Complete Cluster Backup:" > /dev/tty
    echo "   Command: $0 schedule weekly" > /dev/tty
    echo "   Scope: Complete cluster resources and data" > /dev/tty
    echo "   Schedule: Weekly (180 days retention)" > /dev/tty
    echo "" > /dev/tty
    echo "🚀 Setup Automated Scheduling:" > /dev/tty
    echo "   $0 schedule all      # Setup all 3 levels" > /dev/tty
    echo "   $0 schedule status   # Check scheduler status" > /dev/tty
    log "🏁 - Strategy information displayed"
    pop_fn 0
    ;;
  uninstall)
    push_fn "Uninstalling Velero backup system"
    if [[ -f "backup/uninstall.sh" ]]; then
      backup/uninstall.sh
      log "🏁 - Velero backup system uninstalled"
    else
      log "❌ Uninstall script not found: backup/uninstall.sh"
      pop_fn 1
      exit 1
    fi
    pop_fn 0
    ;;
  help|*)
    print_help
    exit 0
    ;;
esac
