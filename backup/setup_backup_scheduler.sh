#!/bin/bash
#
# Backup Scheduler Setup Script
# Sets up automated backups using systemd timers
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Function to create systemd service
create_backup_service() {
    cat > /tmp/fabric-backup.service << EOF
[Unit]
Description=Hyperledger Fabric Complete Backup
After=network.target

[Service]
Type=oneshot
User=root
WorkingDirectory=$PROJECT_DIR
ExecStart=/bin/bash $PROJECT_DIR/backup/master_backup.sh
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    sudo mv /tmp/fabric-backup.service /etc/systemd/system/
    echo "✅ Backup service created"
}

# Function to create systemd timer
create_backup_timer() {
    cat > /tmp/fabric-backup.timer << EOF
[Unit]
Description=Run Hyperledger Fabric Backup
Requires=fabric-backup.service

[Timer]
# Run daily at 2:00 AM
OnCalendar=daily
Persistent=true
RandomizedDelaySec=300

[Install]
WantedBy=timers.target
EOF

    sudo mv /tmp/fabric-backup.timer /etc/systemd/system/
    echo "✅ Backup timer created"
}

# Function to create weekly full backup timer
create_weekly_backup_timer() {
    cat > /tmp/fabric-backup-weekly.timer << EOF
[Unit]
Description=Run Hyperledger Fabric Weekly Full Backup
Requires=fabric-backup.service

[Timer]
# Run weekly on Sunday at 1:00 AM
OnCalendar=weekly
Persistent=true
RandomizedDelaySec=600

[Install]
WantedBy=timers.target
EOF

    sudo mv /tmp/fabric-backup-weekly.timer /etc/systemd/system/
    echo "✅ Weekly backup timer created"
}

# Function to create backup retention script
create_retention_script() {
    cat > "$PROJECT_DIR/backup/cleanup_old_backups.sh" << 'EOF'
#!/bin/bash
#
# Backup Retention Policy Script
# Automatically removes old backups based on retention policy
#

set -e

# Retention policy (days)
LOCAL_RETENTION_DAYS=7
NFS_RETENTION_DAYS=30

echo "🧹 Starting backup cleanup process..."

# Clean local backups older than 7 days
if [ -d "/backup" ]; then
    find /backup -type d -name "fabric-*" -mtime +$LOCAL_RETENTION_DAYS -exec rm -rf {} \; 2>/dev/null || true
    echo "✅ Local backups older than $LOCAL_RETENTION_DAYS days removed"
fi

# Clean NFS backups older than 30 days
if mountpoint -q /mnt/nfs_share 2>/dev/null && [ -d "/mnt/nfs_share/backups" ]; then
    find /mnt/nfs_share/backups -type d -name "fabric-*" -mtime +$NFS_RETENTION_DAYS -exec rm -rf {} \; 2>/dev/null || true
    echo "✅ NFS backups older than $NFS_RETENTION_DAYS days removed"
fi

echo "🧹 Backup cleanup completed"
EOF

    chmod +x "$PROJECT_DIR/backup/cleanup_old_backups.sh"
    echo "✅ Retention script created"
}

# Function to create backup monitoring script
create_monitoring_script() {
    cat > "$PROJECT_DIR/backup/backup_monitor.sh" << 'EOF'
#!/bin/bash
#
# Backup Monitoring Script
# Checks backup status and sends alerts if needed
#

set -e

source k8s-setup/envVar.sh

BACKUP_STATUS_FILE="/tmp/last_backup_status"
ALERT_EMAIL="admin@example.com"  # Configure this

# Function to check last backup
check_last_backup() {
    local last_backup_dir=$(find /backup -maxdepth 1 -name "fabric-complete-*" -type d | sort | tail -1)
    
    if [ -n "$last_backup_dir" ]; then
        local backup_date=$(basename "$last_backup_dir" | sed 's/fabric-complete-//')
        local backup_timestamp=$(date -d "${backup_date:0:8} ${backup_date:9:2}:${backup_date:11:2}:${backup_date:13:2}" +%s 2>/dev/null || echo 0)
        local current_timestamp=$(date +%s)
        local hours_since_backup=$(( (current_timestamp - backup_timestamp) / 3600 ))
        
        echo "Last backup: $backup_date ($hours_since_backup hours ago)"
        
        if [ $hours_since_backup -gt 25 ]; then
            echo "⚠️  Warning: Last backup is over 25 hours old"
            return 1
        else
            echo "✅ Backup is recent"
            return 0
        fi
    else
        echo "❌ No backups found"
        return 1
    fi
}

# Function to check backup integrity
check_backup_integrity() {
    local last_backup_dir=$(find /backup -maxdepth 1 -name "fabric-complete-*" -type d | sort | tail -1)
    
    if [ -n "$last_backup_dir" ]; then
        # Check if all expected components exist
        local expected_components=("fabric-ledger" "fabric-crypto" "fabric-databases" "fabric-application")
        local missing_components=()
        
        for component in "${expected_components[@]}"; do
            if ! find "$last_backup_dir" -name "${component}-*" -type d | grep -q .; then
                missing_components+=("$component")
            fi
        done
        
        if [ ${#missing_components[@]} -eq 0 ]; then
            echo "✅ All backup components present"
            return 0
        else
            echo "❌ Missing backup components: ${missing_components[*]}"
            return 1
        fi
    else
        echo "❌ No backups to check"
        return 1
    fi
}

# Function to check NFS backup sync
check_nfs_sync() {
    if mountpoint -q /mnt/nfs_share 2>/dev/null; then
        local local_count=$(find /backup -name "fabric-complete-*" -type d | wc -l)
        local nfs_count=$(find /mnt/nfs_share/backups -name "fabric-complete-*" -type d 2>/dev/null | wc -l)
        
        if [ "$local_count" -eq "$nfs_count" ]; then
            echo "✅ NFS backup sync is up to date ($local_count backups)"
            return 0
        else
            echo "⚠️  NFS backup sync issue: Local=$local_count, NFS=$nfs_count"
            return 1
        fi
    else
        echo "⚠️  NFS not mounted - remote backup not available"
        return 1
    fi
}

# Main monitoring function
main_monitor() {
    echo "🔍 Fabric Backup Health Check - $(date)"
    echo "=============================================="
    
    local status=0
    
    # Check last backup
    if ! check_last_backup; then
        status=1
    fi
    
    echo ""
    
    # Check backup integrity
    if ! check_backup_integrity; then
        status=1
    fi
    
    echo ""
    
    # Check NFS sync
    if ! check_nfs_sync; then
        status=1
    fi
    
    # Record status
    echo "$status" > "$BACKUP_STATUS_FILE"
    
    if [ $status -eq 0 ]; then
        echo ""
        echo "✅ All backup checks passed"
    else
        echo ""
        echo "❌ Some backup checks failed"
        # You can add email alerting here
        # echo "Backup health check failed" | mail -s "Fabric Backup Alert" $ALERT_EMAIL
    fi
    
    return $status
}

# Execute monitoring
main_monitor
EOF

    chmod +x "$PROJECT_DIR/backup/backup_monitor.sh"
    echo "✅ Monitoring script created"
}

# Function to setup systemd services
setup_systemd_services() {
    echo "⚙️ Setting up systemd services..."
    
    create_backup_service
    create_backup_timer
    create_weekly_backup_timer
    
    # Reload systemd daemon
    sudo systemctl daemon-reload
    
    # Enable and start timers
    sudo systemctl enable fabric-backup.timer
    sudo systemctl enable fabric-backup-weekly.timer
    sudo systemctl start fabric-backup.timer
    sudo systemctl start fabric-backup-weekly.timer
    
    echo "✅ Systemd services configured and started"
}

# Function to create cron backup alternative
create_cron_backup() {
    cat > "$PROJECT_DIR/backup/setup_cron.sh" << 'EOF'
#!/bin/bash
#
# Cron Backup Setup (Alternative to systemd)
# Use this if systemd timers are not available
#

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Add backup jobs to crontab
(crontab -l 2>/dev/null; echo "# Hyperledger Fabric Backup Jobs") | crontab -
(crontab -l 2>/dev/null; echo "0 2 * * * $PROJECT_DIR/backup/master_backup.sh >> /var/log/fabric-backup.log 2>&1") | crontab -
(crontab -l 2>/dev/null; echo "0 3 * * 0 $PROJECT_DIR/backup/cleanup_old_backups.sh >> /var/log/fabric-backup.log 2>&1") | crontab -
(crontab -l 2>/dev/null; echo "0 6 * * * $PROJECT_DIR/backup/backup_monitor.sh >> /var/log/fabric-backup.log 2>&1") | crontab -

echo "✅ Cron jobs added:"
echo "  - Daily backup at 2:00 AM"
echo "  - Weekly cleanup on Sunday at 3:00 AM"
echo "  - Daily monitoring at 6:00 AM"
echo ""
echo "View logs: tail -f /var/log/fabric-backup.log"
EOF

    chmod +x "$PROJECT_DIR/backup/setup_cron.sh"
    echo "✅ Cron setup script created"
}

# Function to create backup dashboard
create_backup_dashboard() {
    cat > "$PROJECT_DIR/backup/backup_dashboard.sh" << 'EOF'
#!/bin/bash
#
# Backup Dashboard
# Shows backup status and statistics
#

set -e

source k8s-setup/envVar.sh

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║               Hyperledger Fabric Backup Dashboard           ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

show_backup_status() {
    echo -e "${BLUE}📊 Backup Status${NC}"
    echo "=============================================="
    
    # Count backups
    local local_backups=$(find /backup -name "fabric-complete-*" -type d 2>/dev/null | wc -l)
    local nfs_backups=0
    
    if mountpoint -q /mnt/nfs_share 2>/dev/null; then
        nfs_backups=$(find /mnt/nfs_share/backups -name "fabric-complete-*" -type d 2>/dev/null | wc -l)
    fi
    
    echo "Local Backups: $local_backups"
    echo "NFS Backups: $nfs_backups"
    
    # Last backup info
    local last_backup=$(find /backup -name "fabric-complete-*" -type d | sort | tail -1)
    if [ -n "$last_backup" ]; then
        local backup_date=$(basename "$last_backup" | sed 's/fabric-complete-//')
        local backup_size=$(du -sh "$last_backup" | cut -f1)
        echo "Last Backup: $backup_date ($backup_size)"
    else
        echo -e "${RED}No backups found${NC}"
    fi
}

show_storage_usage() {
    echo ""
    echo -e "${BLUE}💾 Storage Usage${NC}"
    echo "=============================================="
    
    # Local storage
    if [ -d "/backup" ]; then
        local backup_size=$(du -sh /backup 2>/dev/null | cut -f1 || echo "0")
        echo "Local Backup Storage: $backup_size"
    fi
    
    # NFS storage
    if mountpoint -q /mnt/nfs_share 2>/dev/null && [ -d "/mnt/nfs_share/backups" ]; then
        local nfs_size=$(du -sh /mnt/nfs_share/backups 2>/dev/null | cut -f1 || echo "0")
        echo "NFS Backup Storage: $nfs_size"
    fi
    
    # Available space
    local available=$(df -h / | awk 'NR==2 {print $4}')
    echo "Available Space: $available"
}

show_recent_backups() {
    echo ""
    echo -e "${BLUE}📅 Recent Backups${NC}"
    echo "=============================================="
    
    find /backup -name "fabric-complete-*" -type d | sort | tail -5 | while read backup_dir; do
        if [ -n "$backup_dir" ]; then
            local backup_name=$(basename "$backup_dir")
            local backup_date=$(echo "$backup_name" | sed 's/fabric-complete-//')
            local backup_size=$(du -sh "$backup_dir" | cut -f1)
            local formatted_date=$(date -d "${backup_date:0:8} ${backup_date:9:2}:${backup_date:11:2}:${backup_date:13:2}" +"%Y-%m-%d %H:%M" 2>/dev/null || echo "$backup_date")
            echo "  $formatted_date - $backup_size"
        fi
    done
}

show_service_status() {
    echo ""
    echo -e "${BLUE}⚙️ Service Status${NC}"
    echo "=============================================="
    
    # Check systemd timers
    if systemctl is-active fabric-backup.timer >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Daily backup timer: Active${NC}"
    else
        echo -e "${YELLOW}⚠️  Daily backup timer: Inactive${NC}"
    fi
    
    if systemctl is-active fabric-backup-weekly.timer >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Weekly backup timer: Active${NC}"
    else
        echo -e "${YELLOW}⚠️  Weekly backup timer: Inactive${NC}"
    fi
    
    # Check last service run
    local last_run=$(systemctl show fabric-backup.service --property=ActiveEnterTimestamp --value 2>/dev/null || echo "Unknown")
    echo "Last Service Run: $last_run"
}

show_network_status() {
    echo ""
    echo -e "${BLUE}🌐 Network Status${NC}"
    echo "=============================================="
    
    local pods_running=$(kubectl get pods -n ${KUBE_NAMESPACE} --no-headers 2>/dev/null | grep Running | wc -l)
    local pods_total=$(kubectl get pods -n ${KUBE_NAMESPACE} --no-headers 2>/dev/null | wc -l)
    
    echo "Running Pods: $pods_running/$pods_total"
    
    if [ $pods_running -gt 0 ]; then
        echo -e "${GREEN}✅ Network is active${NC}"
    else
        echo -e "${YELLOW}⚠️  Network appears to be down${NC}"
    fi
}

show_commands() {
    echo ""
    echo -e "${BLUE}🔧 Available Commands${NC}"
    echo "=============================================="
    echo "Manual Backup:     ./backup/master_backup.sh"
    echo "Monitor Health:    ./backup/backup_monitor.sh"
    echo "Cleanup Old:       ./backup/cleanup_old_backups.sh"
    echo "View Logs:         journalctl -u fabric-backup.service"
    echo "Timer Status:      systemctl status fabric-backup.timer"
}

# Main dashboard
main() {
    clear
    print_header
    show_backup_status
    show_storage_usage
    show_recent_backups
    show_service_status
    show_network_status
    show_commands
    echo ""
}

main "$@"
EOF

    chmod +x "$PROJECT_DIR/backup/backup_dashboard.sh"
    echo "✅ Backup dashboard created"
}

# Main setup function
main() {
    echo "🚀 Setting up Hyperledger Fabric Backup Scheduler..."
    echo "Project Directory: $PROJECT_DIR"
    echo ""
    
    # Create backup scripts directory if it doesn't exist
    mkdir -p "$PROJECT_DIR/backup"
    
    # Create additional backup utilities
    create_retention_script
    create_monitoring_script
    create_cron_backup
    create_backup_dashboard
    
    # Setup systemd services (with error handling)
    if command -v systemctl >/dev/null 2>&1; then
        setup_systemd_services
    else
        echo "⚠️  systemctl not available, use setup_cron.sh for cron-based scheduling"
    fi
    
    echo ""
    echo "✅ Backup scheduler setup completed!"
    echo ""
    echo "📋 Next Steps:"
    echo "1. Test manual backup: $PROJECT_DIR/backup/master_backup.sh"
    echo "2. Check dashboard: $PROJECT_DIR/backup/backup_dashboard.sh"
    echo "3. Monitor health: $PROJECT_DIR/backup/backup_monitor.sh"
    echo "4. View timer status: systemctl status fabric-backup.timer"
    echo ""
    echo "📅 Scheduled Backups:"
    echo "   - Daily: 02:00 AM (fabric-backup.timer)"
    echo "   - Weekly: Sunday 01:00 AM (fabric-backup-weekly.timer)"
    echo "   - Cleanup: Automatic (7 days local, 30 days NFS)"
    echo ""
    echo "📂 Backup Locations:"
    echo "   - Local: /backup/fabric-complete-*"
    echo "   - NFS: /mnt/nfs_share/backups/fabric-complete-*"
}

# Execute main function
main "$@"
