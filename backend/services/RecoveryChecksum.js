const fs = require('fs')
const {Gateway, Wallets} = require('fabric-network');
const path = require('path');
const {BlockDecoder} = require('fabric-common');
const utils = require('./utils/utils.js');

// recovery: ham phuc hoi checksum va ma toan he thong
async function recovery(){
    var gateway = new Gateway();
    try{
        if (fs.existsSync(configPath)) {
            hashPBs = fs.readFileSync(configPath, 'utf8');
        }else{
            fs.writeFileSync(configPath, hashPBs);
        }
        var res = {
            success: false,
            message: ""
        };
        const org = process.env.ORG || 'org1';
        const ccpPath = `/fabric/application/gateways/${org}_ccp.json`;
        const ccp = JSON.parse(fs.readFileSync(ccpPath,'utf-8'));
        const walletPath = `/fabric/application/wallet/${org}`;
        const wallet = await Wallets.newFileSystemWallet(walletPath);
        const identity = await wallet.get(user);
        if(!identity){
            res.message = 'Identity user does not exist in system';
            return res;
        }
        await gateway.connect(ccp,{
            wallet,
            identity: user,
            discovery: {
            enabled: true,
            asLocalhost: false
            }
        });
        const network = await gateway.getNetwork('mychannel');
        const contract = await network.getContract('qscc');
        const result = await contract.evaluateTransaction(fcn,'mychannel',params);
        const block = BlockDecoder.decode(result);
        var hash = "";
        for (var i = 6; i < parseInt(block.header.number,10); i++){
            const result = await contract.evaluateTransaction('GetBlockByNumber','mychannel',i.toString()); 
            const block = BlockDecoder.decode(result);
            hash += block.header.data_hash.toString("hex");
            hash = utils.generateHash(hash);
        }
        if(result.toString() === "" || result.toString() === "[]"){
            res.success = false;
            res.message =  JSON.parse("{\"Error\":\"Bản ghi không tồn tại\"}");
        }
        else{
            if(hash === hashPBs){
                res.success = true;
                res.message = "Checksum is correct"
            }else{
                fs.writeFileSync(configPath, hash)
                res.success = true;
                res.message = "Recoverry successsfull"
            }
        }
        return res;
    }catch(err){
        var res = {
          success: false,
          message: err.toString(),
        }
        return res
    }finally{
        await gateway.disconnect();
    }
}

exports.recovery = recovery;