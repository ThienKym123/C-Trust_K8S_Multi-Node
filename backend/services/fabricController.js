const { buildCAClient, enrollAdmin, registerAndEnrollUser } = require('./CAUtil');
const { buildCCPOrg1, buildCCPOrg2, buildWallet } = require('./AppUtil');
const FabricCAServices = require('fabric-ca-client');
const { Wallets } = require('fabric-network');
const path = require('path');
const fs = require('fs').promises;

const mspOrg1 = 'Org1MSP';
const mspOrg2 = 'Org2MSP';

function getWalletPath(org) {
    return path.join('/fabric/application/wallet', org);
}

exports.enrollAdmin = async (req, res) => {
    const { org } = req.body;

    try {
        if (org !== 'org1' && org !== 'org2') {
            return res.status(400).json({ error: 'Org must be org1 or org2' });
        }

        let ccp, caClient, wallet, walletPath, mspId, caName;

        if (org === 'org1') {
            ccp = buildCCPOrg1();
            caName = 'org1-ca';
            mspId = mspOrg1;
        } else {
            ccp = buildCCPOrg2();
            caName = 'org2-ca';
            mspId = mspOrg2;
        }

        caClient = buildCAClient(FabricCAServices, ccp, caName);
        walletPath = getWalletPath(org);
        
        await fs.mkdir(walletPath, { recursive: true });
        
        wallet = await buildWallet(Wallets, walletPath);

        await enrollAdmin(caClient, wallet, mspId);

        res.json({ message: `Enrolled admin for ${org} successfully` });
    } catch (error) {
        console.error('Error in enrollAdmin:', error);
        res.status(500).json({ error: error.message });
    }
};

exports.registerUser = async (req, res) => {
    const { org, userId } = req.body;

    try {
        if (org !== 'org1' && org !== 'org2') {
            return res.status(400).json({ error: 'Org must be org1 or org2' });
        }

        if (!userId) {
            return res.status(400).json({ error: 'Missing userId' });
        }

        let ccp, caClient, wallet, walletPath, mspId, caName, affiliation;

        if (org === 'org1') {
            ccp = buildCCPOrg1();
            caName = 'org1-ca';
            mspId = mspOrg1;
            affiliation = 'org1.department1';
        } else {
            ccp = buildCCPOrg2();
            caName = 'org2-ca';
            mspId = mspOrg2;
            affiliation = 'org2.department1';
        }

        caClient = buildCAClient(FabricCAServices, ccp, caName);
        walletPath = getWalletPath(org);
        
        await fs.mkdir(walletPath, { recursive: true });
        
        wallet = await buildWallet(Wallets, walletPath);

        await registerAndEnrollUser(caClient, wallet, mspId, userId, affiliation);

        res.json({ message: `Registered user ${userId} in ${org} successfully` });
    } catch (error) {
        console.error('Error in registerUser:', error);
        res.status(500).json({ error: error.message });
    }
};
