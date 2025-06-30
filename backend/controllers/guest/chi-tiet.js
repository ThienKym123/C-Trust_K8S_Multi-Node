var querysvc = require('../../services/Querycc.js');
var offchain = require('../../services/Offchain.js');
var logger = require('../../services/utils/utils.js').getLogger("Network-Controller")
var User = require('../../services/models/inforUser')
var moment = require('moment');

exports.getHistoryById = async function(req, res) {
    try {

        logger.info("Running QueryHistory with front-web server");
        if (req.params.maSanPham && req.params.id) {
            var fcn = 'QueryHistoryByMaDongGoi';
            var queryChiTiet = req.params.maSanPham + req.params.id;
            var args = {
                key : queryChiTiet
            }
        } else {
            return res.status(404).send({
                success: false,
                message: message.message
            });
        }
        var user = "guest";
        let message = await querysvc.Querycc(fcn, args, user);
        if (!message.success) {
            return res.status(404).send({
                success: false,
                message: message.message
            });
        }
        for (const i in message.message) {
            message.message[i].descrip = await offchain.offChainRead(message.message[i].Value.FormIDMoiNhat);
            logger.info("Result infomation:");
            logger.info(message.message[i].descrip)
        }

        for (var i in message.message) {

            var query = await User.findOne({
                'local.username': message.message[i].Value.ThucHien
            }, 'local.displayname local.phonenumber local.address local.img.path').exec();
            message.message[i].profile = {
                displayname: query.local.displayname,
                phonenumber: query.local.phonenumber,
                url: query.local.img.path
            }
        }
        for (const i in message.message) {
            message.message[i].hashpbs = await (await querysvc.QueryByTxID('GetBlockByTxID', message.message[i].TxId, user)).message;
        }
        
        if (message.success)
            return res.status(200).render("./guest/chi-tiet", {
                data: message.message.reverse(),
                moment: moment
            });
        // return res.render("./guest/chi-tiet")
        return res.status(404).send(message);

    } catch (err) {
        return res.status(500).send({
            success: false,
            message: err,
        });
    }


}

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