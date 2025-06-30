const FabricCaServices = require('fabric-ca-client');
const { Wallets } = require('fabric-network');
var querysvc = require('./Querycc.js');
const User = require('./models/inforUser.js');
const fs = require('fs');
const path = require('path');

// RegisterUsers: services thuc hien qua trinh dang ky nguoi dung trong mang blockchain va tren he thong
// Input: (req)
//        req    : thong tin nguoi dung yeu cau dang ky
// Output: (success, result)
//        success: trang thai thuc hien
//        message : Ket qua tra ve sau khi dang ky nguoi dung
async function RegisterUsers(req) {
    const res = {
        success: false,
        message: ""
    };
    try {
        // 1. Kiểm tra đầu vào
        const requiredFields = ["username", "displayname", "phonenumber", "description", "address"];
        for (const field of requiredFields) {
            if (!req.body[field]) {
                res.message = `Missing required field: ${field}`;
                return res;
            }
        }
        const org = req.body.org || process.env.ORG || 'org1';
        if (org !== 'org1') {
            res.message = 'Registration is only allowed for org1.';
            return res;
        }
        // 2. Kiểm tra user đã tồn tại trong MongoDB
        const userExistDB = await User.findOne({ 'local.username': req.body.username });
        if (userExistDB) {
            res.message = 'User already exists in the database';
            return res;
        }
        // 3. Kiểm tra user đã tồn tại trong wallet
        const ccpPath = `/fabric/application/gateways/${org}_ccp.json`;
        let ccp;
        try {
            ccp = JSON.parse(fs.readFileSync(ccpPath, 'utf-8'));
        } catch (e) {
            res.message = 'Cannot read connection profile: ' + e.toString();
            return res;
        }
        const caName = `${org}-ca`;
        const caUrl = ccp.certificateAuthorities[caName].url;
        const ca = new FabricCaServices(caUrl);
        const walletPath = `/fabric/application/wallet/${org}`;
        const wallet = await Wallets.newFileSystemWallet(walletPath);
        const userExist = await wallet.get(req.body.username);
        if (userExist) {
            res.message = 'An identity for the user already exists in the wallet';
            return res;
        }
        // 4. Kiểm tra admin identity
        const adminIdentity = await wallet.get('rcaadmin');
        if (!adminIdentity) {
            res.message = 'An identity for the admin user "rcaadmin" does not exist in the wallet';
            return res;
        }
        // 5. Đăng ký/enroll với CA
        let secret, enrollment;
        try {
            const provider = wallet.getProviderRegistry().getProvider(adminIdentity.type);
            const adminUser = await provider.getUserContext(adminIdentity, 'rcaadmin');
            const affiliation = org === 'org1' ? 'org1.department1' : 'org2.department1';
            const mspId = org === 'org1' ? 'Org1MSP' : 'Org2MSP';
            secret = await ca.register({
                affiliation: affiliation,
                enrollmentID: req.body.username,
                role: 'client'
            }, adminUser);
            enrollment = await ca.enroll({
                enrollmentID: req.body.username,
                enrollmentSecret: secret
            });
            const X509Identity = {
                credentials: {
                    certificate: enrollment.certificate,
                    privateKey: enrollment.key.toBytes(),
                },
                mspId: mspId,
                type: 'X.509',
            };
            await wallet.put(req.body.username, X509Identity);
            // 6. Lấy ID từ chaincode
            var params = { init: "init" };
            var id = await querysvc.Querycc("GetID", params, req.body.username);
            // 7. Lưu user vào MongoDB
            const newUser = new User();
            newUser.local.userID = id.message.ID;
            newUser.local.username = req.body.username;
            newUser.local.displayname = req.body.displayname;
            newUser.local.phonenumber = req.body.phonenumber;
            newUser.local.description = req.body.description;
            newUser.local.address = req.body.address;
            newUser.local.msp = X509Identity.mspId;
            newUser.local.img.path = 'images/avatar/default_avatar.png';
            newUser.local.img.contentType = 'image/png';
            try {
                await newUser.save();
            } catch (err) {
                res.message = 'Failed to save user to database: ' + err.toString();
                return res;
            }
            res.success = true;
            res.message = "Success";
            return res;
        } catch (e) {
            res.message = 'CA or wallet error: ' + e.toString();
            return res;
        }
    } catch (err) {
        res.message = err.toString();
        return res;
    }
}

exports.RegisterUsers = RegisterUsers;