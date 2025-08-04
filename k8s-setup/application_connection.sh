#!/usr/bin/env bash
#
# Copyright IBM Corp All Rights Reserved
#
# SPDX-License-Identifier: Apache-2.0
#

. k8s-setup/envVar.sh
. k8s-setup/utils.sh

function app_one_line_pem {
    echo "`awk 'NF {sub(/\\n/, ""); printf "%s\\\\\\\n",$0;}' $1`"
}

# Tạo JSON CCP với các biến động
function app_json_ccp {
    local ORG=$1
    local PEER_PEM=$2
    local CA_PEM=$3
    
    # Set the correct namespace for each organization
    local ORG_NS
    if [ "$ORG" = "1" ]; then
        ORG_NS=$ORG1_NS
    elif [ "$ORG" = "2" ]; then
        ORG_NS=$ORG2_NS
    else
        echo "Error: Invalid organization $ORG"
        exit 1
    fi
    
    local PP=$(app_one_line_pem "$PEER_PEM")
    local CP=$(app_one_line_pem "$CA_PEM")
    
    sed -e "s/\${ORG}/$ORG/" \
        -e "s/\${NS}/$NS/" \
        -e "s/\${ORG_NS}/$ORG_NS/" \
        -e "s/\${DOMAIN}/$DOMAIN/" \
        -e "s#\${PEERPEM}#$PP#" \
        -e "s#\${CAPEM}#$CP#" \
        k8s-setup/config/ccp-template.json
}

function app_id {
    local MSP=$1
    local CERT=$(app_one_line_pem $2)
    local PK=$(app_one_line_pem $3)
    sed -e "s#\${CERTIFICATE}#$CERT#" \
        -e "s#\${PRIVATE_KEY}#$PK#" \
        -e "s#\${MSPID}#$MSP#" \
        k8s-setup/config/appuser.id.template
}

function construct_application_configmap() {
    push_fn "Constructing application connection profiles"

    ENROLLMENT_DIR=${TEMP_DIR}/enrollments
    CHANNEL_MSP_DIR=${TEMP_DIR}/channel-msp

    mkdir -p build/application/wallet
    mkdir -p build/application/gateways

    # Org1 CCP
    local peer_pem=$CHANNEL_MSP_DIR/peerOrganizations/org1/msp/tlscacerts/tlsca-signcert.pem
    local ca_pem=$CHANNEL_MSP_DIR/peerOrganizations/org1/msp/cacerts/ca-signcert.pem
    echo "$(app_json_ccp 1 "$peer_pem" "$ca_pem")" > build/application/gateways/org1_ccp.json

    # Org2 CCP
    peer_pem=$CHANNEL_MSP_DIR/peerOrganizations/org2/msp/tlscacerts/tlsca-signcert.pem
    ca_pem=$CHANNEL_MSP_DIR/peerOrganizations/org2/msp/cacerts/ca-signcert.pem
    echo "$(app_json_ccp 2 "$peer_pem" "$ca_pem")" > build/application/gateways/org2_ccp.json

    pop_fn

    push_fn "Getting Application Identities"

    local cert=$ENROLLMENT_DIR/org1/users/org1admin/msp/signcerts/cert.pem
    local pk=$ENROLLMENT_DIR/org1/users/org1admin/msp/keystore/key.pem
    echo "$(app_id Org1MSP $cert $pk)" > build/application/wallet/appuser_org1.id

    cert=$ENROLLMENT_DIR/org2/users/org2admin/msp/signcerts/cert.pem
    pk=$ENROLLMENT_DIR/org2/users/org2admin/msp/keystore/key.pem
    echo "$(app_id Org2MSP $cert $pk)" > build/application/wallet/appuser_org2.id

    pop_fn

    push_fn "Creating ConfigMap \"app-fabric-tls-v1-map\" with TLS certificates for the application"
    kubectl -n $NS delete configmap app-fabric-tls-v1-map || true
    kubectl -n $NS create configmap app-fabric-tls-v1-map --from-file=$CHANNEL_MSP_DIR/peerOrganizations/org1/msp/tlscacerts
    pop_fn

    push_fn "Creating ConfigMap \"app-fabric-ids-v1-map\" with identities for the application"
    kubectl -n $NS delete configmap app-fabric-ids-v1-map || true
    kubectl -n $NS create configmap app-fabric-ids-v1-map --from-file=./build/application/wallet
    pop_fn

    push_fn "Creating ConfigMap \"app-fabric-ccp-v1-map\" with ConnectionProfile for the application"
    kubectl -n $NS delete configmap app-fabric-ccp-v1-map || true
    kubectl -n $NS create configmap app-fabric-ccp-v1-map --from-file=./build/application/gateways
    pop_fn

    push_fn "Creating ConfigMap \"app-fabric-org1-v1-map\" with Organization 1 information for the application"
    cat <<EOF > build/app-fabric-org1-v1-map.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-fabric-org1-v1-map
data:
  fabric_channel: ${CHANNEL_NAME}
  fabric_contract: ${CHAINCODE_NAME}
  fabric_wallet_dir: /fabric/application/wallet
  fabric_gateway_hostport: org1-peer-gateway-svc.localho.st:30443
  fabric_gateway_sslHostOverride: org1-peer1.test-network.svc.cluster.local
  fabric_user: appuser_org1
  fabric_gateway_tlsCertPath: /fabric/tlscacerts/tlsca-signcert.pem
EOF
    kubectl -n $NS apply -f build/app-fabric-org1-v1-map.yaml
    pop_fn

    push_fn "Creating ConfigMap \"app-fabric-org2-v1-map\" with Organization 2 information for the application"
    cat <<EOF > build/app-fabric-org2-v1-map.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-fabric-org2-v1-map
data:
  fabric_channel: ${CHANNEL_NAME}
  fabric_contract: ${CHAINCODE_NAME}
  fabric_wallet_dir: /fabric/application/wallet
  fabric_gateway_hostport: org2-peer-gateway-svc.localho.st:30443
  fabric_gateway_sslHostOverride: org2-peer1.test-network.svc.cluster.local
  fabric_user: appuser_org2
  fabric_gateway_tlsCertPath: /fabric/tlscacerts/tlsca-signcert.pem
EOF
    kubectl -n $NS apply -f build/app-fabric-org2-v1-map.yaml
    pop_fn
}

function application_connection() {
    construct_application_configmap
}