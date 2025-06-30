const log4js = require('log4js');
const logger = log4js.getLogger('routes');
var ccctrl = require('./../controllers/chaincode-controllers/controllers.js');
var sysctrl = require('./../controllers/network-controllers/controllers.js');

var UserInfo = require('../services/models/inforUser');

const uploaddes = require("multer")({
    dest: './public/images/descriptions',
    limits: {
        fileSize: 100 * 1024 * 1024
    }
});

const uploadavatar = require("multer")({
    dest: './public/images/avatar',
    limits: {
        fileSize: 100 * 1024 * 1024
    }
});


module.exports = function(app, passport) {

    app.get('/auth/google',passport.authenticate('google',{ scope: ['profile', 'email'] }),async function(req,res){
        console.log('request: ');
        console.log(req)
        return res.status(200).send({
            message: 'Done'
        })
    });

    // app.get('/auth/google/callback', passport.authenticate('google'));

    // app.get('/confirmation/:token', ccctrl.verification);

    app.post('/login',
        passport.authenticate('login', { session: false }), async function(req, res) {
            try{
	    if (!req.user) {
                return res.status(404).json({ success: false, message: 'User not Found' })
            }
            logger.info(req.user.username)
            var query = await UserInfo.findOne({
                'local.username': req.user.username
            }, 'local.displayname local.phonenumber local.description local.address local.img.path local.msp local.userID').exec();

            return res.status(200).json({
                success: true,
                message: {
                    message: {
                        userId: query.local.userID,
                        displayname: query.local.displayname,
                        phonenumber: query.local.phonenumber,
                        address: query.local.address,
                        description: query.local.description,
                        msp: query.local.msp,
                        url: query.local.img.path,
                    },
                    token: req.user.token
                }
            })
            }catch (err){   
                return res.status(500).json({
                    success: false,
                    message: err
                })
            }
        });


    app.post('/logout', sysctrl.logout);

    app.post('/enrollAdmin', sysctrl.enrollAdmin);

    app.post('/register', (req, res, next) => {
        passport.authenticate('SignUp', async function(err, user, info) {
            logger.info(`register user:`, user, 'err:', err, 'info:', info);
            if (err) {
                return res.status(400).json({ errors: err, info });
            }
            if (!user) {
                // Nếu user đã tồn tại hoặc lỗi khác
                return res.status(400).json({ error: 'User already exists or invalid data', info });
            }
            var message = await sysctrl.registerUser(req);
            if (!(message.success)) {
                return res.status(400).json({ message: message.message })
            }
            return res.status(200).json({ success: 'Logged', message: message })
        })(req, res, next);
    });

    app.post('/user/edit', passport.authenticate('org1', { session: false }), uploadavatar.single('avatar'), sysctrl.editProfile);

    app.get('/user', passport.authenticate('org1', { session: false }), sysctrl.getUser);


    app.post('/contract/create', passport.authenticate('org1', { session: false }), ccctrl.create);

    app.post('/contract/update', passport.authenticate('org1', { session: false }), ccctrl.update);

    app.post('/contract/dongGoi', passport.authenticate('org1', { session: false }), ccctrl.dongGoi);

    app.post('/contract/tranfer', passport.authenticate('org1', { session: false }), ccctrl.transfer);


  
    app.get('/contract/get', passport.authenticate('org1', { session: false }), ccctrl.getById);

    app.get('/contract/getHashValue', passport.authenticate('org1', { session: false }), ccctrl.GetHashValue);

    app.get('/contract/getListSanPham', passport.authenticate('org1', { session: false }), ccctrl.getListSanPham);

    app.get('/contract/getListSanPhamChiaNho', passport.authenticate('org1', { session: false }), ccctrl.getListSanPhamChiaNho);

    app.get('/contract/searchSanPham', passport.authenticate('org1', { session: false }), ccctrl.searchSanPham);

    app.get('/contract/history', passport.authenticate('org1', { session: false }), ccctrl.getHistoryById);

    app.get('/contract/history/complete', passport.authenticate('org1', { session: false }), ccctrl.getHistoryByMaDongGoi);

    app.post('/offchain/uploadDescriptions', uploaddes.fields([{ name: 'descriptions', maxCount: 1 }, { name: 'thumbnail', maxCount: 1 }]), ccctrl.uploadDescriptions);

    // app.get('/qscc/getBlockbyNum',passport.authenticate('org1', { session: false }),ccctrl.getBlockbyNum);

    // app.get('/qscc/getBlockbyTxid', passport.authenticate('org1', { session: false }), ccctrl.getBlockByTxID);

}
