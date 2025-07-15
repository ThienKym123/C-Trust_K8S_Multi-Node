
## Dependencies
Follow [Guide](./dependencies.md)

## Quickstart 

For kubeadm 4 node (1 control plane + 3 worker node):

- 🖥️ Control Plane: kym
- 👷 Worker Nodes: admin1, admin2, admin3

⚠️ If you are using different hostnames or IP addresses, make sure to update all relevant files

### Create k8s cluster

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
./setup_worker.sh clean
```

- On Control Plane node:

```shell
./start.sh cluster 
```

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

If any worker node shut down: 
```shell
./setup_worker.sh restart
```

The system continues to function normally after a worker node restarts, as long as the pods are running stably
