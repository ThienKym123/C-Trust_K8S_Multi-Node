var querysvc = require('../../services/Querycc.js');
var offchain = require('../../services/Offchain.js');
var logger = require('../../services/utils/utils.js').getLogger("Network-Controller")
var User = require('../../services/models/inforUser')
var moment = require('moment');

exports.getHistoryById = async function(req, res) {
    try {
        logger.info("Running QueryHistory with front-web server");

        const maSanPham = req.params.maSanPham;
        if (!maSanPham) {
        return res.status(400).send({
            success: false,
            message: "Thiếu mã đóng gói"
        });
        }

        const fcn = 'QueryHistoryByMaDongGoi';
        const args = { Key: maSanPham };
        const user = "guest";

        let message = await querysvc.Querycc(fcn, args, user);
        if (!message.success) {
        return res.status(404).send({
            success: false,
            message: message.message
        });
        }

        for (const item of message.message) {
        item.descrip = item.Value.FormIDMoiNhat 
            ? await offchain.offChainRead(item.Value.FormIDMoiNhat)
            : { success: false, message: "No description" };

        const query = await User.findOne(
            { 'local.username': item.Value.ThucHien || user },
            'local.displayname local.phonenumber local.address local.img.path'
        ).exec();
        item.profile = query ? {
            displayname: query.local.displayname,
            phonenumber: query.local.phonenumber,
            url: query.local.img.path
        } : {
            displayname: 'Unknown',
            phonenumber: 'N/A',
            url: ''
        };

        item.hashpbs = (await querysvc.QueryByTxID('GetBlockByTxID', item.TxId, user)).message;
        }

        return res.status(200).render("./guest/chi-tiet", {
        data: message.message.reverse(),
        moment: moment
        });
    } catch (err) {
        console.error('Error in getHistoryById:', err);
        return res.status(500).send({
        success: false,
        message: err.message || err.toString()
        });
    }
};

// exports.getHistoryById = async function(req, res) {
//     try {

//         logger.info("Running QueryHistory with front-web server");
//         if (req.query.id) {
//             var fcn = 'QueryHistory';
//             var args = {
//                 id: req.query.id,
//                 nhasanxuat: req.query.nhasanxuat
//             }
//         } else if (req.query.key) {
//             var fcn = 'QueryHistoryByMaDongGoi';
//             var args = {
//                 key: req.query.key
//             }
//         }
//         var user = "guest";
//         let message = await querysvc.Querycc(fcn, args, user);
//         if (!message.success) {
//             return res.status(404).send({
//                 success: false,
//                 message: message.message
//             });
//         }
//         for (const i in message.message) {
//             message.message[i].descrip = await offchain.offChainRead(message.message[i].Value.FormIDMoiNhat);
//         }

//         for (var i in message.message) {

//             var query = await User.findOne({
//                 'local.username': message.message[i].Value.ThucHien
//             }, 'local.displayname local.phonenumber local.address local.img.path').exec();
//             message.message[i].profile = {
//                 displayname: query.local.displayname,
//                 phonenumber: query.local.phonenumber,
//                 url: query.local.img.path
//             }
//         }
//         for (const i in message.message) {
//             message.message[i].hashpbs = await (await querysvc.QueryByTxID('GetBlockByTxID', message.message[i].TxId, user)).message;
//         }
//         // logger.info(message.message);
//         if (message.success)
//             return res.status(200).render("./guest/chi-tiet", {
//                 data: message.message.reverse(),
//                 moment: moment
//             });
//         // return res.render("./guest/chi-tiet")
//         return res.status(404).send(message);

//     } catch (err) {
//         return res.status(500).send({
//             success: false,
//             message: err,
//         });
//     }


// }