# Kubernetes Test Network 

This project re-establishes the Hyperledger [test-network](../test-network) as a _cloud native_ application.

### Objectives:

- Provide a simple, _one click_ activity for running the Fabric test network.
- Provide a reference guide for deploying _production-style_ networks on Kubernetes.
- Provide a _cloud ready_ platform for developing chaincode, Gateway, and blockchain apps.
- Provide a Kube supplement to the Fabric [CA Operations and Deployment](https://hyperledger-fabric-ca.readthedocs.io/en/latest/deployguide/ca-deploy.html) guides.
- Support a transition to [Chaincode as a Service](https://hyperledger-fabric.readthedocs.io/en/latest/cc_service.html).
- Support a transition from the Internal, Docker daemon to [External Chaincode](https://hyperledger-fabric.readthedocs.io/en/latest/cc_launcher.html) builders.
- Run on any Kube.

_Fabric, Ahoy!_ 


## Prerequisites:

- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [jq](https://stedolan.github.io/jq/)
- [envsubst](https://www.gnu.org/software/gettext/manual/html_node/envsubst-Invocation.html) (`brew install gettext` on OSX)

- K8s - either:
  - [KIND](https://kind.sigs.k8s.io/docs/user/quick-start/#installation) + [Docker](https://www.docker.com) (resources: 8 CPU / 8 GRAM) 
  - [Rancher Desktop](https://rancherdesktop.io) (resources: 8 CPU / 8GRAM, mobyd, and disable Traefik)

## Quickstart 

Create a KIND cluster:  
```shell
./network kind
./network cluster init
```
or for [Rancher / k3s](docs/KUBERNETES.md#rancher-desktop-and-k3s):
```shell
export TEST_NETWORK_CLUSTER_RUNTIME=k3s

./network cluster init
```
or for kubeadm 4 node (1 control plane + 3 worker node)
```shell

./start.sh cluster 
```

Launch the network, create a channel, and deploy the [basic-asset-transfer](../asset-transfer-basic) smart contract: 
```shell
./start.sh up

./start.sh channel create

./start.sh chaincode deploy asset-transfer-basic ../asset-transfer-basic/chaincode-go/

./start.sh chaincode deploy supplychain-cc ./chaincode-go/

./start.sh application
```

Launch backend:
```shell
./start.sh backend

```

Test API khi deploy chaincode "asset-transfer-basic":
https://.postman.co/workspace/My-Workspace~a44268f6-ecbd-4424-8a5f-2a9ad6206e40/collection/37567808-5821b3ec-a62e-4953-8612-74db15889cfc?action=share&creator=37567808

Test API khi deploy chaincode "supplychain-cc":
https://www.postman.com/research-administrator-81537314/workspace/c-trust/collection/37567808-6b97fada-a115-40f5-95eb-5870711fcc52?action=share&creator=37567808

Clean backend:
```shell
./start.sh backend-clean
```

Invoke and query chaincode:
```shell
./start.sh chaincode invoke asset-transfer-basic '{"Args":["InitLedger"]}'
./start.sh chaincode query asset-transfer-basic '{"Args":["ReadAsset","asset1"]}'
./start.sh chaincode query asset-transfer-basic '{"Args":["GetAllAssets"]}'
./start.sh chaincode invoke asset-transfer-basic '{"Args":["CreateAsset","asset8","green","200","user1","1000"]}'
./start.sh chaincode query asset-transfer-basic '{"Args":["ReadAsset","asset8"]}'
./start.sh chaincode invoke asset-transfer-basic '{"Args":["UpdateAsset","asset8","blue","150","user1","1200"]}'

```

Shut down the kubeadm multi node network: 

```shell
./start down 
./start clean
```

Access the blockchain with a [REST API](https://github.com/hyperledger/fabric-samples/tree/main/asset-transfer-basic/rest-api-typescript): 
```shell
./network rest-easy
```

Shut down the test network: 
```shell
./network down 
```

Tear down the cluster (KIND): 
```shell
./network unkind
```

For Rancher: Preferences -> Kubernetes Settings -> Reset Kubernetes  OR ...
```shell
./network cluster clean
```


## [Detailed Guides](docs/README.md)

- [Working with Kubernetes](docs/KUBERNETES.md)
- [Certificate Authorities](docs/CA.md)
- [Launching the Test Network](docs/TEST_NETWORK.md)
- [Working with Channels](docs/CHANNELS.md)
- [Working with Chaincode](docs/CHAINCODE.md)
- [Working with Applications](docs/APPLICATIONS.md)
- [Working with BFT Orderers](docs/BFT_ORDERERS.md)


### DNS Resolution on OSX

Fabric's OSX binaries have been statically linked with the golang `go` DNS resolver.  In some environments, this 
causes a brief but [noticeable delay](https://github.com/hyperledger/fabric/issues/3372) when issuing peer commands 
against the test network.

Workarounds to improve DNS resolution time on OSX: 

- Add manual DNS overrides for virtual hosts by adding to /etc/hosts:
```
127.0.0.1 org0-ca.localho.st
127.0.0.1 org1-ca.localho.st
127.0.0.1 org2-ca.localho.st
127.0.0.1 org0-orderer1.localho.st
127.0.0.1 org0-orderer2.localho.st
127.0.0.1 org0-orderer3.localho.st
127.0.0.1 org1-peer1.localho.st
127.0.0.1 org1-peer2.localho.st
127.0.0.1 org2-peer1.localho.st
127.0.0.1 org2-peer2.localho.st
```

- Reduce the system resolver timeout from the default 5s by adding to /etc/resolv.conf:
```shell
options: timeout 2
```

- Compile the [fabric binaries](https://github.com/hyperledger/fabric) on a Mac and copy `build/bin/*` outputs to 
  `test-network-k8s/bin`.  Mac native builds are linked against the `netdns=cgo` DNS resolver, and are not
  subject to the timeouts associated with the Golang DNS resolver.
