/*
 * Copyright IBM Corp. All Rights Reserved.
 *
 * SPDX-License-Identifier: Apache-2.0
 */

'use strict';

const fs = require('fs');
const path = require('path');

exports.buildCCPOrg1 = () => {
    const ccpPath = path.resolve('/fabric/application/gateways/org1_ccp.json');
    const fileExists = fs.existsSync(ccpPath);
    if (!fileExists) {
        throw new Error(`no such file or directory: ${ccpPath}`);
    }
    const contents = fs.readFileSync(ccpPath, 'utf8');
    const ccp = JSON.parse(contents);
    console.log(`Loaded the network configuration located at ${ccpPath}`);
    return ccp;
};

exports.buildCCPOrg2 = () => {
    const ccpPath = path.resolve('/fabric/application/gateways/org2_ccp.json');
    const fileExists = fs.existsSync(ccpPath);
    if (!fileExists) {
        throw new Error(`no such file or directory: ${ccpPath}`);
    }
    const contents = fs.readFileSync(ccpPath, 'utf8');
    const ccp = JSON.parse(contents);
    console.log(`Loaded the network configuration located at ${ccpPath}`);
    return ccp;
};

exports.buildWallet = async (Wallets, walletPath) => {
    let wallet;
    if (walletPath) {
        // Không tạo thư mục vì wallet đã được mount từ ConfigMap
        if (!fs.existsSync(walletPath)) {
            throw new Error(`Wallet path does not exist: ${walletPath}`);
        }
        wallet = await Wallets.newFileSystemWallet(walletPath);
        console.log(`Built a file system wallet at ${walletPath}`);
    } else {
        wallet = await Wallets.newInMemoryWallet();
        console.log('Built an in memory wallet');
    }
    return wallet;
};

exports.prettyJSONString = (inputString) => {
    if (inputString) {
         return JSON.stringify(JSON.parse(inputString), null, 2);
    }
    else {
         return inputString;
    }
}