# Hyperledger Fabric Complete Cluster Backup System

A comprehensive backup solution for Hyperledger Fabric networks running on Kubernetes that includes:
- **Velero**: Complete cluster and volume backup
- **etcd**: Kubernetes cluster state database backup  
- **PKI**: All certificates and cryptographic material
- **Control Plane**: API server, scheduler, controller-manager configurations

## 🚀 Quick Start

### 1. Setup External MinIO Storage
```bash
# Ensure your external MinIO server is running and accessible
# Default: 192.168.208.148:9000 (minioadmin/minioadmin123)
```

### 2. Install and Configure Velero
```bash
./backup/velero-setup.sh
```

### 3. Create Complete Cluster Backup
```bash
./backup/master_backup.sh
```

### 4. Setup Automated Backups (Optional)
```bash
./backup/setup_backup_scheduler.sh
```

## 📂 Essential Files

| File | Purpose |
|------|---------|
| `velero-setup.sh` | Install and configure Velero with MinIO backend |
| `master_backup.sh` | **Complete cluster backup** (Velero + etcd + PKI) |
| `etcd_backup.sh` | Standalone etcd database backup |
| `k8s_restore.sh` | Restore etcd and Kubernetes components |
| `velero-monitor.sh` | Monitor backup status and health |
| `velero-restore.sh` | Restore from Velero backup |
| `setup_backup_scheduler.sh` | Setup automated daily backups |
| `backup_dashboard.sh` | View backup status dashboard |

## 🔧 Backup Components

### Complete Cluster Backup (`master_backup.sh`)
- **All Kubernetes Namespaces**: Complete cluster state
- **etcd Database**: Kubernetes cluster state and configuration  
- **PKI Certificates**: All cluster certificates and keys
- **Control Plane**: API server, scheduler, controller-manager
- **Persistent Volumes**: Complete file system backup of ALL volumes
- **Custom Resources**: All CRDs and custom resource instances
- **RBAC**: All roles, bindings, service accounts
- **Network Policies**: All ingress and network configurations

### Individual Backup Scripts
- **etcd Only**: `./backup/etcd_backup.sh` - Creates etcd snapshot
- **Velero Only**: Velero handles application data and volumes
- **Certificates**: Included in Kubernetes components backup

## ⚙️ Configuration

The system uses external MinIO storage with these defaults:
- **MinIO Endpoint**: `192.168.208.148:9000`
- **Credentials**: `minioadmin/minioadmin123` 
- **Bucket**: `velero`
- **SSL**: Disabled (HTTP)

To modify these settings, edit `backup/env.sh`:

```bash
# MinIO Configuration
export MINIO_HOST="192.168.208.148"
export MINIO_PORT="9000"
export MINIO_ACCESS_KEY="minioadmin"
export MINIO_SECRET_KEY="minioadmin123"
export MINIO_BUCKET="velero"
export MINIO_USE_SSL="false"
## 🔄 Restoration Procedures

### Complete Cluster Restoration

#### 1. Restore etcd Database (Control Plane Only)
```bash
# Run on control plane node only
./backup/k8s_restore.sh --etcd-only /path/to/backup/directory

# Example
./backup/k8s_restore.sh --etcd-only /tmp/fabric-complete/20250723_123456
```

#### 2. Restore Application Data (Velero)
```bash
# Find available backups
velero backup get

# Restore specific backup
velero restore create restore-$(date +%Y%m%d-%H%M%S) \
    --from-backup fabric-cluster-backup-YYYYMMDD-HHMMSS \
    --wait
```

#### 3. Full Cluster Restoration
```bash
# Complete restoration (etcd + configuration + applications)
./backup/k8s_restore.sh --full /tmp/fabric-complete/20250723_123456

# Then restore Velero backup
./backup/velero-restore.sh fabric-cluster-backup-YYYYMMDD-HHMMSS
```

### Partial Restoration Options

#### etcd Only
```bash
./backup/etcd_backup.sh  # Create standalone etcd backup
./backup/k8s_restore.sh --etcd-only /backup/path
```

#### Configuration Only  
```bash
./backup/k8s_restore.sh --config-only /backup/path
```

#### Application Data Only
```bash
./backup/velero-restore.sh <backup-name>
```

## 🛡️ Disaster Recovery Scenarios

### Scenario 1: Complete Cluster Loss
1. **Setup new Kubernetes cluster**
2. **Install Velero**: `./backup/velero-setup.sh`
3. **Restore etcd**: `./backup/k8s_restore.sh --etcd-only`
4. **Restore applications**: `./backup/velero-restore.sh`

### Scenario 2: Control Plane Failure
1. **Restore etcd on control plane**: `./backup/k8s_restore.sh --etcd-only`
2. **Restart Kubernetes services**
3. **Verify cluster health**

### Scenario 3: Application Data Loss
1. **Use Velero restore only**: `./backup/velero-restore.sh`
2. **No cluster restart required**

### Scenario 4: Certificate/PKI Issues
1. **Restore configuration**: `./backup/k8s_restore.sh --config-only`
2. **May require cluster recreation for PKI**

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│               Kubernetes Cluster (Complete Backup)             │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌────────┐ │
│  │  Peers  │  │Orderers │  │   CAs   │  │ CouchDB │  │  Apps  │ │
│  └─────────┘  └─────────┘  └─────────┘  └─────────┘  └────────┘ │
├─────────────────────────────────────────────────────────────────┤
│                    Control Plane Components                    │
│  ┌─────────┐  ┌─────────┐  ┌──────────┐  ┌─────────────────┐   │
│  │  etcd   │  │API Srvr │  │Scheduler │  │Controller Mgr   │   │
│  └─────────┘  └─────────┘  └──────────┘  └─────────────────┘   │
├─────────────────────────────────────────────────────────────────┤
│                   Comprehensive Backup System                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐  │
│  │Velero Backup │  │ etcd Backup  │  │  PKI & Config       │  │
│  │(Apps+Volumes)│  │ (Cluster     │  │  Backup             │  │
│  │              │  │  State)      │  │                     │  │
│  └──────────────┘  └──────────────┘  └──────────────────────┘  │
└────────────────────────────────┬────────────────────────────────┘
                                 │ S3 Protocol + Direct File Copy
                                 │
┌────────────────────────────────▼────────────────────────────────┐
│                    External MinIO Server                       │
│               (192.168.208.148:9000)                          │
│  ┌─────────────┐       ┌─────────────┐       ┌─────────────┐   │
│  │   MinIO     │       │   Bucket:   │       │ Management  │   │
│  │   Server    │◄──────┤   velero    │──────►│   Console   │   │
│  └─────────────┘       └─────────────┘       └─────────────┘   │
│                                                                │
│  ┌─────────────┐       ┌─────────────┐       ┌─────────────┐   │
│  │ Velero Data │       │etcd Snapshots│       │PKI Certs &  │   │
│  │(PV Backups) │       │ (Cluster    │       │Configurations│   │
│  │             │       │  State)     │       │             │   │
│  └─────────────┘       └─────────────┘       └─────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

## 🔧 Core Components

### Backup Scripts
- **`master_backup.sh`**: **Complete cluster backup** (Velero + etcd + PKI + Control Plane)
- **`etcd_backup.sh`**: Standalone etcd database backup with snapshots
- **`k8s_restore.sh`**: Comprehensive Kubernetes component restoration
- **`velero-setup.sh`**: Installs and configures Velero with MinIO backend
- **`velero-monitor.sh`**: Monitors backup status and provides health checks
- **`velero-restore.sh`**: Handles Velero backup restoration procedures

### Management Scripts  
- **`setup_backup_scheduler.sh`**: Sets up automated daily backups via systemd
- **`backup_dashboard.sh`**: Interactive dashboard for backup status monitoring

### Configuration Files
- **`env.sh`**: Environment variables for MinIO connection and backup settings

### Backup Coverage
- **✅ etcd Database**: Complete Kubernetes cluster state and configuration
- **✅ Persistent Volumes**: All application data with file system backup
- **✅ PKI Certificates**: All cluster certificates and cryptographic keys
- **✅ Control Plane**: API server, scheduler, controller-manager configurations
- **✅ Custom Resources**: All CRDs and custom resource instances
- **✅ RBAC**: All roles, bindings, service accounts across all namespaces
- **✅ Network Policies**: All ingress controllers and network configurations
- **✅ System Components**: All kube-system and control plane configurations
- **`README.md`**: This documentation file
- **`VELERO-BACKUP-GUIDE.md`**: Detailed Velero setup and usage guide
./backup/fabric-backup.sh monitor
```

## 📋 Available Commands

### Setup and Management
```bash
./backup/fabric-backup.sh setup               # Setup Velero with MinIO
./backup/fabric-backup.sh status              # Check system status
./backup/fabric-backup.sh cleanup             # Clean old backups
./backup/fabric-backup.sh help                # Show help
```

### Backup Operations
```bash
./backup/fabric-backup.sh backup              # Hybrid backup (default)
./backup/fabric-backup.sh backup-velero       # Velero-only backup
./backup/fabric-backup.sh backup-legacy       # Legacy scripts only
```

### Monitoring and Restore
```bash
./backup/fabric-backup.sh monitor             # Monitor backup status
./backup/fabric-backup.sh restore             # Show restore options
./backup/fabric-backup.sh schedule list       # List backup schedules
```

### Advanced Options
```bash
# Backup with custom retention
./backup/fabric-backup.sh backup --retention=168h

# Different backup modes
./backup/fabric-backup.sh backup --mode=velero-only

# Dry run to see what would happen
./backup/fabric-backup.sh backup --dry-run
```

## 🔧 Backup Modes

### 1. Hybrid Mode (Recommended)
- **Velero**: Captures Kubernetes resources, PVs, cluster state
- **Legacy Scripts**: Captures crypto material and database exports
- **Best For**: Complete disaster recovery coverage

### 2. Velero-Only Mode
- **Velero**: Full Kubernetes-native backup
- **Coverage**: All K8s resources, volumes, configurations
- **Best For**: Fast backup/restore, cluster migrations
## 📊 Usage Examples

### Basic Operations
```bash
# Create manual backup
./backup/master_backup.sh

# Check backup status
./backup/velero-monitor.sh

# View backup dashboard
./backup/backup_dashboard.sh

# List all Velero backups
kubectl get backups -n velero
```

### Automated Scheduling
```bash
# Setup daily automated backups
./backup/setup_backup_scheduler.sh

# Check systemd timer status
systemctl status fabric-backup.timer

# View backup service logs
journalctl -u fabric-backup.service
```

### Restoration
```bash
# List available backups for restore
./backup/velero-restore.sh list

# Restore from specific backup
./backup/velero-restore.sh restore <backup-name>

# Check restore status
./backup/velero-restore.sh status
```

## 🗄️ Storage Backend (External MinIO)

### MinIO Server Configuration
- **Endpoint**: `192.168.208.148:9000` (default)
- **Access Key**: `minioadmin`
- **Secret Key**: `minioadmin123`
- **Bucket**: `velero`
- **Protocol**: HTTP (SSL disabled)

### MinIO Console Access
Access the MinIO web console at: `http://192.168.208.148:9001`

### Storage Management
```bash
# View backup data using mc client (from MinIO server)
mc ls local/velero/backups/

# Check storage usage
mc du local/velero/

# Download backup data
mc cp --recursive local/velero/backups/ ./local-backup/
```
## 🛡️ Security & Best Practices

### Backup Security
- MinIO credentials stored as Kubernetes secrets
- External storage isolation from cluster
- Backup data contains sensitive crypto material
- Consider encryption for long-term storage

### Network Security
- External MinIO server accessible only from cluster nodes
- Use firewall rules to restrict MinIO access
- Consider TLS/SSL for production environments

## 🔧 Troubleshooting

### Common Issues
```bash
# Velero pod not starting
kubectl describe pod -n velero -l app.kubernetes.io/name=velero

# MinIO connection issues
kubectl logs deployment/velero -n velero | grep -i minio

# Backup stuck in progress
kubectl get backup <backup-name> -n velero -o yaml

# Check Velero system status
./backup/velero-monitor.sh
```

### Log Locations
- **Velero logs**: `kubectl logs deployment/velero -n velero`
- **Backup service logs**: `journalctl -u fabric-backup.service`
- **System logs**: `tail -f /var/log/syslog`

## 📚 Additional Resources

### Documentation Files
- `VELERO-BACKUP-GUIDE.md` - Detailed Velero setup and usage
- `EXTERNAL-MINIO-DEPLOYMENT.md` - MinIO server installation guide

### External Links
- [Velero Documentation](https://velero.io/docs/)
- [MinIO Documentation](https://docs.min.io/)
- [Hyperledger Fabric Documentation](https://hyperledger-fabric.readthedocs.io/)

## 📊 System Information

| Component | Version | Notes |
|-----------|---------|-------|
| Hyperledger Fabric | 2.5.11 | Network components |
| Velero | 1.16.1 | Backup system |
| Kubernetes | 1.33.0 | Cluster version |
| MinIO | Latest | S3-compatible storage |

---

## 📞 Support & Maintenance

### Regular Tasks
- Monitor backup success daily via dashboard
- Review storage usage weekly
- Test restore procedures monthly
- Update retention policies quarterly

### Emergency Contacts
For critical backup/restore issues:
1. Check service status: `systemctl status fabric-backup.timer`
2. Review recent logs: `journalctl -u fabric-backup.service -n 50`
3. Verify MinIO connectivity: `telnet 192.168.208.148 9000`

---

**Last Updated**: July 23, 2025  
**System**: Hyperledger Fabric + Velero Backup Solution -f
```

### Network Requirements
- Kubernetes nodes must have network access to MinIO server
- MinIO server ports (9000, 9001) must be accessible from K8s cluster
- Firewall rules should allow traffic from Kubernetes subnet
- Stable IP address or hostname for MinIO server

## 🔍 Monitoring and Troubleshooting

### Check Backup System Health
```bash
# Overall system status
./backup/fabric-backup.sh status

# Detailed Velero status
./backup/velero-monitor.sh status

# Check individual backup details
./backup/velero-monitor.sh details <backup-name>
```

### Common Troubleshooting
```bash
# Check Velero logs
kubectl logs deployment/velero -n velero

# Check MinIO status
kubectl get pods -n velero

# Verify backup storage location
velero get backup-locations -n velero

# Check failed backups
velero get backups -n velero | grep -i failed
```

## 🛡️ Security Considerations

### Backup Security
- MinIO credentials are stored as Kubernetes secrets
- Backups contain sensitive crypto material
- Access to backup storage should be restricted
- Consider encrypting backups for long-term storage

### RBAC Configuration
```bash
# Velero uses cluster-admin permissions by default
# Review and customize RBAC as needed
kubectl get clusterrolebinding | grep velero
```

### Network Security
- MinIO traffic is internal to cluster
- Use network policies to restrict access
- Consider TLS encryption for MinIO

## 📊 Backup Coverage

### What's Backed Up by Velero
- ✅ All Kubernetes resources (Pods, Services, ConfigMaps, Secrets)
- ✅ PersistentVolumes and PersistentVolumeClaims
- ✅ Custom Resource Definitions (CRDs)
- ✅ RBAC configurations
- ✅ Network policies and ingress rules

### What's Backed Up by Legacy Scripts
- ✅ Cryptographic material and certificates
- ✅ Database exports (MongoDB, CouchDB, PostgreSQL)
- ✅ Application source code and configurations
- ✅ Chaincode and smart contract source
- ✅ Custom configuration files

### Combined Coverage
The hybrid approach ensures complete coverage:
- **Infrastructure**: Velero handles all Kubernetes infrastructure
- **Data**: Legacy scripts handle application-specific data
- **Crypto**: Redundant backup of cryptographic material
- **State**: Complete ledger and state database backup

## 🔧 Configuration Files

### Key Configuration Files
- `backup/velero-setup.sh` - Velero installation and setup
- `backup/fabric-backup.sh` - Main backup management script
- `backup/velero-monitor.sh` - Backup monitoring utilities
- `backup/velero-restore.sh` - Restore operations
- `kube/velero-minio.yaml` - Velero namespace and configuration manifests
- `backup/VELERO-BACKUP-GUIDE.md` - Detailed backup guide
- `backup/EXTERNAL-MINIO-DEPLOYMENT.md` - Manual MinIO setup guide

### Environment Variables
```bash
# Key environment variables (from k8s-setup/envVar.sh)
KUBE_NAMESPACE="test-network"        # Fabric namespace
NETWORK_NAME="test-network"          # Network name
CLUSTER_NAME="fabric-cluster"        # Cluster name
STORAGE_CLASS="local-path"           # Storage class for PVCs
```

## 🚨 Disaster Recovery Scenarios

### Complete Cluster Loss
1. **Setup new cluster** with same specifications
2. **Install Velero** with same MinIO configuration
3. **Restore system components** from weekly system backup
4. **Restore Fabric network** from latest daily backup
5. **Verify network functionality** and resume operations

### Namespace Corruption
1. **Stop applications** that might be writing data
2. **Delete corrupted namespace**
3. **Restore from latest backup**
4. **Verify data integrity** and restart applications

### Individual Component Failure
1. **Identify failed component** (peer, orderer, CA)
2. **Scale down deployment** to prevent data corruption
3. **Restore specific resources** using Velero filters
4. **Verify component health** and resume operations

## 📈 Performance and Optimization

### Backup Performance
- **Parallel operations**: Velero and legacy scripts can run concurrently
- **Incremental backups**: Velero supports incremental volume snapshots
- **Compression**: Backups are compressed by default
- **Deduplication**: MinIO provides data deduplication

### Storage Optimization
- **Retention policies**: Automatic cleanup of old backups
- **Compression**: Reduce storage usage
- **Lifecycle policies**: Move old backups to cheaper storage

### Network Optimization
- **Internal traffic**: Backups use cluster-internal networking
- **Bandwidth limiting**: Configure limits during peak hours
- **Scheduling**: Use off-peak hours for large backups

## 🔄 Migration and Upgrades

### Cluster Migration
```bash
# Export backup from source cluster
velero backup download <backup-name> -o backup.tar.gz

# Import to target cluster
velero restore create migration-restore --from-backup <backup-name>
```

### Fabric Version Upgrades
1. **Create pre-upgrade backup**
2. **Test upgrade in staging environment**
3. **Perform production upgrade**
4. **Keep backup available for rollback**

## 📚 Additional Resources

### Documentation
- `backup/VELERO-BACKUP-GUIDE.md` - Comprehensive backup guide
- [Velero Documentation](https://velero.io/docs/) - Official Velero docs
- [MinIO Documentation](https://docs.min.io/) - MinIO configuration guide

### Community
- [Hyperledger Fabric Community](https://wiki.hyperledger.org/display/fabric)
- [Velero Community](https://github.com/vmware-tanzu/velero)
- [Kubernetes Backup Best Practices](https://kubernetes.io/docs/concepts/cluster-administration/backup/)

## 🏷️ Version Information

- **Fabric Version**: 2.5.11
- **Velero Version**: 1.15.0
- **MinIO Version**: RELEASE.2024-08-17T01-24-54Z
- **Kubernetes**: 1.33.0+

---

## 📞 Support

For issues and questions:

1. **Check system status**: `./backup/fabric-backup.sh status`
2. **Review logs**: `kubectl logs deployment/velero -n velero`
3. **Consult documentation**: `backup/VELERO-BACKUP-GUIDE.md`
4. **Community support**: Hyperledger Fabric and Velero communities

---

**Last Updated**: July 17, 2025  
**Environment**: Hyperledger Fabric on Kubernetes with Velero Backup System
