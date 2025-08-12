var express = require('express');
var router = express.Router();

/* GET home page. */
var home = require('../controllers/guest/home');
router.get('/', home.home);


// Trang Truy xuất nguồn gốc sản phẩm
var chi_tiet = require("../controllers/guest/chi-tiet")
router.get('/chi-tiet/:maSanPham', chi_tiet.getHistoryById);

var privacy = require("../controllers/guest/privacy")
router.get('/privacy', privacy.getPrivacy);



module.exports = router;
