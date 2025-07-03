const registerUser = require('../../services/RegisterUsers.js');
const User = require('../../services/models/inforUser');
const sharp = require('sharp');
const path = require('path');
const fs = require('fs');
const fsPromises = fs.promises;

const { buildCAClient, enrollAdmin, revokeUser, reenrollUser } = require('../../services/CAUtil');
const { buildCCPOrg1, buildCCPOrg2, buildWallet } = require('../../services/AppUtil');
const FabricCAServices = require('fabric-ca-client');
const { Wallets } = require('fabric-network');

const mspOrg1 = 'Org1MSP';
const mspOrg2 = 'Org2MSP';

var logger = require('../../services/utils/utils.js').getLogger("Network-Controller")
//registerUser: Handler tiep nhan tac vu dang ky nguoi dung
//      Output:
//          success: trang thai thuc hien
//          message: thong tin nguoi dung hien tai

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
        
        await fsPromises.mkdir(walletPath, { recursive: true });
        
        wallet = await buildWallet(Wallets, walletPath);

        await enrollAdmin(caClient, wallet, mspId);

        res.json({ message: `Enrolled admin for ${org} successfully` });
    } catch (error) {
        console.error('Error in enrollAdmin:', error);
        res.status(500).json({ error: error.message });
    }
};

exports.revokeUser = async (req, res) => {
    const { org, userId, reason } = req.body;
    try {
        if (org !== 'org1' && org !== 'org2') {
            return res.status(400).json({ error: 'Org must be org1 or org2' });
        }
        let ccp, caClient, wallet, walletPath, caName;
        if (org === 'org1') {
            ccp = buildCCPOrg1();
            caName = 'org1-ca';
        } else {
            ccp = buildCCPOrg2();
            caName = 'org2-ca';
        }
        caClient = buildCAClient(FabricCAServices, ccp, caName);
        walletPath = getWalletPath(org);
        await fsPromises.mkdir(walletPath, { recursive: true });
        wallet = await buildWallet(Wallets, walletPath);
        await revokeUser(caClient, wallet, userId, 'rcaadmin', reason);
        res.json({ message: `Revoked user ${userId} in ${org} successfully` });
    } catch (error) {
        console.error('Error in revokeUser:', error);
        res.status(500).json({ error: error.message });
    }
};

exports.reenrollUser = async (req, res) => {
    const { org, userId } = req.body;
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
        await fsPromises.mkdir(walletPath, { recursive: true });
        wallet = await buildWallet(Wallets, walletPath);
        await reenrollUser(caClient, wallet, userId, mspId);
        res.json({ message: `Reenrolled user ${userId} in ${org} successfully` });
    } catch (error) {
        console.error('Error in reenrollUser:', error);
        res.status(500).json({ error: error.message });
    }
};

exports.getUser = async function(req, res){
    try{
        logger.info('Runninng Get User controller');
        var query = await User.findOne({
            'local.username':req.user.local.username
        },'local.displayname local.phonenumber local.description local.address local.img.path').exec();

        return res.status(200).send({
            displayname: query.local.displayname,
            phonenumber: query.local.phonenumber,
            address: query.local.address,
            description: query.local.description,
            url: query.local.img.path
        });
    }catch(err){
        return res.status(500).send({
            success: false, 
            errors: err
        });
    }
}



exports.editProfile = async function(req, res){
    try{
        logger.info('Runninng edit User controller');
        if(req.file){
            var tranform = sharp(req.file.path);
            tranform = tranform.resize(220,220).toBuffer(function(err, buffer) {
                fsPromises.writeFile(req.file.path, buffer, function(e) {
                    var newpath = req.file.path + path.extname(req.file.originalname);
                    fsPromises.renameSync(req.file.path,newpath);
                });
            });
        }   
        await User.findOne({
            'local.username':req.user.local.username
          },function(err, user){
              if(err){
                return res.status(500).send({error: err});
              }
              if(req.body.displayname)
                user.local.displayname = req.body.displayname;
              if(req.body.phonenumber)
                user.local.phonenumber = req.body.phonenumber;
              if(req.body.description)
                user.local.description = req.body.description;
              if(req.body.address)
                user.local.address = req.body.address;
              if(req.file){
                user.local.img.path = 'images/avatar/' +req.file.filename + path.extname(req.file.originalname);
                user.local.img.contentType = req.file.mimetype;
              }
              user.save(function(err){
                if(err)
                    return res.status(500).send({error: err});
              });
          });

    

        var query = await User.findOne({
            'local.username':req.user.local.username
        },'local.displayname local.phonenumber local.description local.address local.img.path').exec();

        return res.status(200).send({
            success: true,
            message: {
                displayname: query.local.displayname,
                phonenumber: query.local.phonenumber,
                address: query.local.address,
                description: query.local.description,
                url: query.local.img.path
            }
        })  
    }catch(err){
        return res.status(500).send({
            success: false,
            message: err
        })
    }
}

exports.logout = async function(req, res){
    try{
        logger.info('Runninng logout controller');
        req.session.destroy((err) => {
            if(err) {
                return res.status(500).send({
                    success: true,
                    message: err
                });
            }
            res.status(200).send({
                success: true,
                message: "Logout"
            })
        });
    }catch(err){
        return res.status(500).send({
            success: false,
            message: err
        })
    }
}
//registerUser: Handler tiep nhan tac vu dang ky nguoi dung
//      Input: 
//          username    : ten tai khoan dang nhap
//          displayname : ten hien thi cua nha san xuat san pham
//          phonenumber : so dien thoai cua nha san xuat
//          description : mieu ta thong tin cua nha san xuat
//          address     : dia chi cua nha san xuat
//          password    : mat khau tai khoan
//      Output:
//          success: trang thai thuc hien
//          message: thong tin ket qua dang ky nguoi dung
exports.registerUser = async function(req, res){
    try{
        logger.info('Runninng register User controller');
        let message = await registerUser.RegisterUsers(req);
        return {success: true, message: message};
    }catch(err){
        return {
            success: false,
            message: err
        };
    }
}
