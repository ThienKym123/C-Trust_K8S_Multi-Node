/*
SPDX-License-Identifier: Apache-2.0
*/

package main

import (
	"log"

	"github.com/ThienKym123/fabric-k8s-multinode/chaincode-go/chaincode"
	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

func main() {
	chaincode, err := contractapi.NewChaincode(&chaincode.SmartContract{})
	if err != nil {
		log.Panicf("Error creating supplychain chaincode: %v", err)
	}

	if err := chaincode.Start(); err != nil {
		log.Panicf("Error starting supplychain chaincode: %v", err)
	}
}
