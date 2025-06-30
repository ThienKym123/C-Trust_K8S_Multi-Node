const fs = require('fs')
const {Gateway, Wallets,DefaultQueryHandlerStrategies} = require('fabric-network');
const path = require('path');
const {BlockDecoder} = require('fabric-common');
const utils = require('./utils/utils.js');
// Querycc: services thuc hien qua trinh truy van giao dich da thuc hien
// Input: (fcn, params, user)
//        fcn    : ten Contract su dung 
//        params : du lieu dau vao truoc xu ly cho chaincodes
//        user   : nguoi dung gui yeu cau toi sdk
// Output: (success, result)
//        success: trang thai thuc hien
//        result : Ket qua tra ve sau khi thuc hien chaincode
async function Querycc(fcn, params, user) {
    var gateway = new Gateway();
    try {
        var res = {
            success: false,
            message: ""
        };
        const org = process.env.ORG || 'org1';
        const ccpPath = `/fabric/application/gateways/${org}_ccp.json`;
        const ccp = JSON.parse(fs.readFileSync(ccpPath, 'utf-8'));
        const walletPath = `/fabric/application/wallet/${org}`;
        const wallet = await Wallets.newFileSystemWallet(walletPath);
        const identity = await wallet.get(user);
        if (!identity) {
            res.message = 'Identity user does not exist in system';
            return res;
        }
        const gatewayOptions=  {
          wallet,
          identity: user,
          discovery: {
            enabled: true,
            asLocalhost: false
          },
          queryHandlerOptions:{
            timeout: 60, 
            strategy: DefaultQueryHandlerStrategies.MSPID_SCOPE_ROUND_ROBIN
          }
        } 
        await gateway.connect(ccp,gatewayOptions);
        const network = await gateway.getNetwork('mychannel');
        const contract = await network.getContract('supplychain-cc');
        if (fcn === "QueryListSanPham" || fcn === "QueryListSanPhamTheoPageIndexVaPageSize") {
            params.username = user;
        }
        params = JSON.stringify(params);
        const result = await contract.evaluateTransaction(fcn, params);
        if (fcn === "GetID") {
            return {
                success: true,
                message: JSON.parse(`{\"ID\":\"${result.toString()}\"}`)
            }
        }
        if (result.toString() === "" || result.toString() === "[]") {
            res.success = false;
            res.message = JSON.parse("{\"Error\":\"Bản ghi không tồn tại\"}");
        } else {
            res.success = true;
            res.message = JSON.parse(result.toString());
        }
        return res;
    } catch (err) {
        var res = {
            success: false,
            message: err.toString(),
        }
        return res
    } finally {
        await gateway.disconnect();
    }
}


// QueryByTxID: services thuc hien qua trinh truy van giao dich da thuc hien thong qua qscc
// Input: (fcn, params, user)
//        fcn    : ten Contract su dung 
//        params : du lieu dau vao truoc xu ly cho chaincodes
//        user   : nguoi dung gui yeu cau toi sdk
// Output: (success, result)
//        success: trang thai thuc hien
//        result : Ket qua tra ve sau khi thuc hien chaincode
async function QueryByTxID(fcn,params,user){
    var gateway = new Gateway();
    try{
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
        var blocNum = parseInt(block.header.number,10) - 1
        const resultNum = await contract.evaluateTransaction('GetBlockByNumber','mychannel',blocNum.toString()); 
        const blockTarget = BlockDecoder.decode(resultNum);
        var hash = blockTarget.header.data_hash.toString("hex");

//        for (var i = 6; i < parseInt(block.header.number,10); i++){
//            const result = await contract.evaluateTransaction('GetBlockByNumber','mychannel',i.toString()); 
//            const block = BlockDecoder.decode(result);
//            hash += block.header.data_hash.toString("hex");
//            hash = utils.generateHash(hash);
//        }

        if(result.toString() === "" || result.toString() === "[]"){
            res.success = false;
            res.message =  JSON.parse("{\"Error\":\"Bản ghi không tồn tại\"}");
        }
        else{
            res.success = true;
            res.message = hash
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

//QueryByNum deprecated
async function QueryByNum(blockNumber,user){
    var gateway = new Gateway();
    try{
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
        const result = await contract.evaluateTransaction('getBlockByNumber','mychannel',blockNumber);
        const block = BlockDecoder.decode(result);
        if(result.toString() === "" || result.toString() === "[]"){
            res.success = false;
            res.message =  JSON.parse("{\"Error\":\"Bản ghi không tồn tại\"}");
        }
        else{
            res.success = true;
            res.message = block.header.data_hash.toString("base64")
        }
        return res;
    }catch(err){
        console.log(err)
        var res = {
            success: false,
            message: err.toString(),
        }
        return res
    }finally{
        await gateway.disconnect();
    }
}

exports.QueryByNum = QueryByNum;
exports.QueryByTxID = QueryByTxID;
exports.Querycc = Querycc;
