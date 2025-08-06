
## Dependencies
Follow [Guide](./dependencies.md)

## Note 

For kubeadm 4 node (1 control plane + 3 worker node):

- 🖥️ Control Plane: kym (4-6GB RAM - 30-40GB ROM)
- 👷 Worker Nodes: admin1, admin2, admin3 (2-3GB RAM - 20-25GB ROM each node)
- Backup node: admin4 (512GB RAM - 10GB ROM)

⚠️ If you are using different hostnames or IP addresses, make sure to update all relevant files

## Create k8s cluster

- On Control Plane Node:

Set up k8s cluster:

Edit Control plane IP in [envVar.sh](./k8s-setup/envVar.sh) to correct with your IP
```shell
./start.sh init 
```

Edit transfer-k3s.sh to transfer [registry.crt](./registry.crt) and [join-command.sh](./join-command.sh) to worker node can join k8s cluster. Then run script

```shell
./transfer-k3s.sh 
```

- On Worker node:

Edit Control plane IP in [setup_worker.sh](./k8s-setup/setup-worker.sh) and copy to locate in fabric-samples/test-network-k8s and run on 3 worker node

```shell
./setup_worker.sh init
```

- On Control Plane node:

```shell
./start.sh cluster 
```

## Launch the Fabric network

Launch the network, create a channel, and deploy the smart contract: 
```shell
./start.sh up

./start.sh channel create

./start.sh chaincode deploy supplychain-cc ./chaincode-go/

./start.sh application
```

Launch backend:
```shell
./start.sh backend
```

Launch explorer:
```shell
./start.sh explorer
```

Test API khi deploy chaincode "supplychain-cc": [C-trust_API](https://www.postman.com/research-administrator-81537314/workspace/c-trust/collection/37567808-6b97fada-a115-40f5-95eb-5870711fcc52?action=share&creator=37567808)

> Guest can scan QR to query history of product

## Backup:

Install velero:
```shell
./backup setup
```

1. Backup all k8s cluster:
```shell
./backup schedule all
```

2. Schedule backup:
- Backup-quick:
```shell
./backup schedule hourly
```
- Backup-full:
```shell
./backup schedule daily
```
- Backup-comprehensive:
```shell
./backup schedule weekly
```

Restore:
```shell
./backup.sh list

./backup.sh restore <backup-name>
```

The restore process may take a few minutes. You can check the status of the restore process by running the following command:
```shell
velero restore get

velero restore describe <restore-name>
```

The fabric network may take around 10 minutes to be fully restored. You can check the status of the fabric network by running the following command:
```shell
kubectl -n test-network get pod
```

## Down network
> Note: It will clean all data in k8s cluster

Clean explorer:
```shell
./start.sh explorer-clean
```

Clean backend:
```shell
./start.sh backend-clean
```

Shut down the kubeadm multi node network: 

```shell
./start down 

./start clean
```

- On Worker node:
```shell
./setup_worker.sh clean
```

## Error handle

If entire k8s cluster down:
- On control plane node:
```shell
./start.sh restart
```

- On each worker node : 
```shell
./setup_worker.sh restart
```

The system continues to function normally after a worker node restarts, as long as the pods are running stably
