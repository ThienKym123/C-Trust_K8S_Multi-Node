const {Gateway, Wallets, DefaultEventHandlerStrategies} = require('fabric-network');
const fs = require('fs');
const path = require('path');
const utils = require('./utils/utils.js');
var offchain = require('./Offchain.js');
var hashPBs = "";
// Invokecc: services thuc hien qua trinh xu ly giao dich gay thay doi trang thai
// Input: (fcn, params, user)
//        fcn   : ten Contract su dung 
//        params: du lieu dau vao truoc xu ly cho chaincodes
//        user  : nguoi dung gui yeu cau toi sdk
// Output: (success, result)
//        success: trang thai thuc hien
//        result : Ket qua tra ve sau khi thuc hien chaincode
async function Invokecc(fcn,params,user){
  var gateway = new Gateway();
  try {
    console.log("=== INVOKECC DEBUG ===");
    console.log("Function:", fcn);
    console.log("Params:", JSON.stringify(params, null, 2));
    console.log("User:", user);
    
    const org = process.env.ORG || 'org1';
    const ccpPath = `/fabric/application/gateways/${org}_ccp.json`;
    const ccp = JSON.parse(fs.readFileSync(ccpPath,'utf-8'));
    const walletPath = `/fabric/application/wallet/${org}`;
    const wallet = await Wallets.newFileSystemWallet(walletPath);
    const identity = await wallet.get(user);
    
    console.log("=== WALLET DEBUG ===");
    console.log("Wallet path:", walletPath);
    console.log("User identity exists:", !!identity);
    if (identity) {
      console.log("Identity type:", identity.type);
      console.log("Identity MSP:", identity.mspId);
    }
    
    const gatewayOptions=  {
      wallet,
      identity: user,
      discovery: {
        enabled: true,
        asLocalhost: false
      },
      eventHandlerOptions:{
        strategy: DefaultEventHandlerStrategies.NONE
      }
    } 
    await gateway.connect(ccp,gatewayOptions);
    const network = await gateway.getNetwork('mychannel');
    const contract = await network.getContract('supplychain-cc');
    var hashOff = ""
    console.log("hashPbs: " + hashPBs)
    HashValueOffchain = await offchain.offChainRead(params.formIDmoinhat);
    if(HashValueOffchain)
      HashValueOffchain.message.docs.forEach(element => {
        hashOff += element.hash
    }); 
    console.log("hash ValueOffchain: ")
    console.log(HashValueOffchain)
    hashPBs = await utils.getListener(hashPBs, network);
    console.log("hashPBs before : " + hashPBs)
    hashOff = await utils.generateHash(hashOff);
    console.log("hashOff: " + hashOff)
    params.HashValueOffchain = hashOff
    params.hashvalue = utils.generateHash(hashPBs + hashOff);
    console.log("hashvalue: " + params.hashvalue)
    var response ;
    if (fcn === "Transfer")
    {
      var name = user;
      await contract.submitTransaction(fcn, JSON.stringify(params),name);
    }else if (fcn === "ThanhToanSanPham") {
      const { data, uuid } = params;
      if (!data || !uuid) {
        throw new Error("Missing data or uuid parameter");
      }
      await contract.submitTransaction(fcn, data, uuid); // Truyen data la mang JSON string
    }else{
      console.log("=== CHAINCODE EXECUTION DEBUG ===");
      console.log("Submitting transaction with params:", JSON.stringify(params));
      var result = await contract.submitTransaction(fcn, JSON.stringify(params));
      console.log("Raw chaincode result:", result.toString());
      var response = JSON.parse(new Buffer.from(result).toString())
      console.log("Parsed chaincode response:", JSON.stringify(response, null, 2));
    }
    console.log(fcn)
    return {
      success : true,
      message:{
        Value : response,
        hashpbs :hashPBs
      }   
    }
  }catch(err){
    console.log("=== INVOKECC ERROR DEBUG ===");
    console.log("Error in Invokecc:", err);
    return {
      success : false,
      message : err
    }
  }finally{
    await gateway.disconnect();
  }
}

exports.Invokecc = Invokecc
