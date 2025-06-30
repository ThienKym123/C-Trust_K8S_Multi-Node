var invokesvc = require('../../services/Invokecc.js');
var querysvc = require('../../services/Querycc.js');
var queryqsvc = require('../../services/Queryqscc.js');
var offchain = require('../../services/Offchain.js');
var logger = require('../../services/utils/utils').getLogger("Chaincode-Controller");
var User = require('../../services/models/inforUser')
const uniqid = require('uniqid');
//getErrorMessage: ham in thong tin loi
//      Input: 
//          file      : van bang duoi dang json
//      Output:
//          success : trang thai thuc hien
//          message : thong tin chi loi   
function getErrorMessage(field) {
	var response = {
		success: false,
		message: field + 'missing or Invalid in the request'
	};
	return response;
}

//create: Handler tiep nhan tac vu tao san pham
//      Input: 
//          tensanpham   : ten san pham tao ra
//          thoigian     : thoi gian tao san pham
//          diadiem      : dia diem thuc hien tao san pham
//          toado        : toa do dia diem tao san pham
//          mota         : mo ta bo xung san pham
//          trangthai    : trang thai hien tai cua san pham
//          formIDmoinhat: id form tren thiet bi di dong
//      Output:
//          success: trang thai thuc hien
//          message : 
//                  value   :  ket qua tra ve sau khi xu ly trong chaincode
//                  hashpbs :  gia tri bam cua toan bo mang truoc do
//                  profile :  thong tin cua nha san xuat
exports.create = async function(req, res, next) {
  try {
    logger.info('Running create product controller');

    const user = req.user.local.username;
    const fcn = 'Create';
    const id = uniqid.process();

    const args = {
      id,
      tensanpham: req.body.tensanpham,
      nhasanxuat: user,
      thoigian: req.body.thoigian,
      diadiem: req.body.diadiem,
      toado: req.body.toado,
      mota: req.body.mota,
      trangthai: req.body.trangthai,
      formIDmoinhat: req.body.formIDmoinhat,
    };

    if (!user) {
      return res.status(401).send(getErrorMessage('user'));
    }

    const invokeResult = await invokesvc.Invokecc(fcn, args, user);

    if (!invokeResult.success) {
      return res.status(400).send(invokeResult);
    }

    return res.status(201).send({
      success: true,
      message: 'Tạo sản phẩm thành công',
      productID: id
    });
  } catch (err) {
    console.error('Error in /contract/create:', err);
    return res.status(500).send({
      success: false,
      message: err && err.message ? err.message : err.toString(),
    });
  }
};

//update: Handler tiep nhan tac vu thay doi trang thai san pham
//      Input: 
//          id           : dinh danh san pham da ton tai
//          tensanpham   : ten san pham tao ra
//          thoigian     : thoi gian tao san pham
//          diadiem      : dia diem thuc hien tao san pham
//          toado        : toa do dia diem tao san pham
//          mota         : mo ta bo xung san pham
//          trangthai    : trang thai hien tai cua san pham
//          formIDmoinhat: id form tren thiet bi di dong
//      Output:
//          success: trang thai thuc hien
//          message : 
//                  value   :  ket qua tra ve sau khi xu ly trong chaincode
//                  hashpbs :  gia tri bam cua toan bo mang truoc do
//                  profile :  thong tin cua nha san xuat
exports.update = async function (req, res, next) {
  try{
    logger.info('Runninng update product controller');
    var fcn = 'Update';
    var args = {
      id : req.body.id,
      nhasanxuat : req.body.nhasanxuat,
      thoigian : req.body.thoigian,
      diadiem : req.body.diadiem,
      toado : req.body.toado,
      mota: req.body.mota,
      trangthai : req.body.trangthai,
      thuchien: req.user.local.username,
      formIDmoinhat: req.body.formIDmoinhat,
    }
    var user = req.user.local.username;
    if (!user){
      return res.status(401).send(getErrorMessage('user'));
    }
    let message = await invokesvc.Invokecc(fcn,args,user);

    if (message.message.Value.FormIDMoiNhat != undefined) {
      message.message.descrip = await offchain.offChainRead(message.message.Value.FormIDMoiNhat);
    }
    var query =  await User.findOne({
      'local.username':  message.message.Value.ThucHien
    },'local.displayname local.phonenumber local.address local.img.path').exec();
    message.message.profile = {
          displayname: query.local.displayname,
          phonenumber: query.local.phonenumber,
          url: query.local.img.path
    }
    if(message.success){
      return res.status(200).send(message);
    }else{
      throw(message);
    }
  }catch(err){
    res.status(500).send(err)
  }
}


//update: Handler tiep nhan tac vu thay doi trang thai san pham
//      Input: 
//          id               : dinh danh san pham da ton tai
//          tensanpham       : ten san pham tao ra
//          thoigian         : thoi gian tao san pham
//          diadiem          : dia diem thuc hien tao san pham
//          toado            : toa do dia diem tao san pham
//          mota             : mo ta bo xung san pham
//          trangthai        : trang thai hien tai cua san pham
//          formIDmoinhat    : id form tren thiet bi di dong
//          danhsachmadonggoi: danh sach ma tem dong goi
//          hoanthanhdonggoi : trang thai danh dau hoan thanh qua trinh
//          soluong          : so luong duoc dong goi
//          donvidosoluong   : don vi su dung trong qua trinh dong goi
//          hsd              : han su dung cua san pham da dong goi
//      Output:
//          success: trang thai thuc hien
//          message : 
//                  value   :  ket qua tra ve sau khi xu ly trong chaincode
//                  hashpbs :  gia tri bam cua toan bo mang truoc do
//                  profile :  thong tin cua nha san xuat
exports.dongGoi = async function (req, res, next) {
  try{
    logger.info('Runninng DongGoi product controller');
    var fcn = 'DongGoiSanPham';
    var args = {
      id : req.body.id,
      nhasanxuat : req.body.nhasanxuat,
      thoigian: req.body.thoigian,
      diadiem: req.body.diadiem,
      toado: req.body.toado,
      mota: req.body.mota,
      trangthai: req.body.trangthai,
      thuchien: req.user.local.username,
      formIDmoinhat: req.body.formIDmoinhat,
      danhsachmadonggoi: req.body.danhsachmadonggoi,
      hoanthanhdonggoi: req.body.hoanthanhdonggoi,
      soluong: req.body.soluong,
      donvidosoluong: req.body.donvidosoluong,
      hsd: req.body.hsd,
    }
    var user = req.user.local.username;
    if (!user){
      return res.status(401).send(getErrorMessage('user'));
    }
    let message = await invokesvc.Invokecc(fcn,args,user, next);
    console.log("Dong goi: ")
    console.log(message)
    if (message.message.Value.FormIDMoiNhat) {
      message.message.descrip = await offchain.offChainRead(message.message.Value.FormIDMoiNhat);
    }

    var query =  await User.findOne({
      'local.username':  message.message.Value.ThucHien
    },'local.displayname local.phonenumber local.address local.img.path').exec();
    message.message.profile = {
          displayname: query.local.displayname,
          phonenumber: query.local.phonenumber,
          url: query.local.img.path
    }
    if(message.success){
      return res.status(200).send(message);
    }else{
      return res.status(500).send(message);
    }
  }catch(err){
    return res.status(500).send({
      success: false,
      message: err,
    });
  }
}

//update: Handler tiep nhan tac vu thay doi trang thai san pham
//      Input: 
//          id               : dinh danh san pham da ton tai
//          tensanpham       : ten san pham tao ra
//          thoigian         : thoi gian tao san pham
//          diadiem          : dia diem thuc hien tao san pham
//          toado            : toa do dia diem tao san pham
//          thuchien         : ma dinh danh quyen so huu cua nguoi duoc chuyen tiep san pham
//      Output:
//          success: trang thai thuc hien
//          message : 
//                  hashpbs: gia tri bam cua trang thai toan he thong truoc do
exports.transfer = async function(req, res, next){
  try{
    logger.info('Runninng Transfer product controller');
    var fcn = 'Transfer';
    var user = req.user.local.username;
    var args = {
      id : req.body.id,
      nhasanxuat : req.body.nhasanxuat,
      thoigian: req.body.thoigian,
      diadiem: req.body.diadiem,
      toado: req.body.toado,
      thuchien: req.body.thuchien
    }
    
    if (!user){
      return res.status(401).send(getErrorMessage('user'));
    }
    let message = await invokesvc.Invokecc(fcn,args,user);
    if(message.success)
      return res.status(200).send(message);
    return res.status(500).send(message);
  }catch(err){
    return res.status(500).send({
      success: false,
      message: err,
    });
  }
}



//getById: Handler tiep nhan tac vu truy van thong tin san pham
//      Input: 
//          id               : dinh danh san pham da ton tai
//          nhasanxuat       : ten tai khoan cua nha san xuat dang so huu san pham
//      Output:
//          success: trang thai thuc hien
//          message : thong tin san pham duoc trich xuat tu so cai         
exports.getById = async function(req, res){
  try{
    logger.info('Runninng Query product controller');
    var fcn = 'Query';
    var args = {
      id : req.query.id,
      nhasanxuat  : req.query.nhasanxuat
    }
    var user = req.user.local.username;
    if (!user){
      return res.status(401).send(getErrorMessage('user'));
    }
    let message = await querysvc.Querycc(fcn,args,user);
    logger.info(message)
    let descrip = {};
    if(message.success){
      descrip = await offchain.offChainRead(message.message.FormIDMoiNhat);
      logger.info(descrip)
    }
    if(message.success && descrip.success){
      return res.status(200).send({
        success: true,
        message: message.message,
        descrip: {
          docs: descrip.message.docs,
          bookmark: descrip.message.bookmark
        }
      });
    }
    return res.status(404).send({
      success: false,
      message: "Not found",
    });
  }catch(err){
    return res.status(500).send({
      success: false,
      message: err,
    });
  }
}


//getHistoryById: Handler tiep nhan tac vu truy van lich su thong tin san pham
//      Input: 
//          id               : dinh danh san pham da ton tai
//          nhasanxuat       : ten tai khoan cua nha san xuat dang so huu san pham
//      Output:
//          success: trang thai thuc hien
//          message : thong tin lich su thay doi trang thai cua san pham duoc trich xuat tu so cai 
exports.getHistoryById = async function(req, res){
  try{
    logger.info('Runninng QueryHistory controller');
    var fcn = 'QueryHistory';
    var args = {
      id : req.query.id,
      nhasanxuat  : req.query.nhasanxuat
    }
    var user = req.user.local.username;
    if (!user){
      return res.status(401).send(getErrorMessage('user'));
    }
    let message = await querysvc.Querycc(fcn,args,user);
    if(!message.success){
      return res.status(404).send({
          success: false,
          message: message.message
      });
    }

    for (const i in message.message)
    {
      message.message[i].hashpbs = await (await querysvc.QueryByTxID('GetBlockByTxID',message.message[i].TxId,user)).message;
      console.log("index: " + i + " has hashpbs: " + message.message[i].hashpbs + "\n")
    }


    for (const i in message.message)
    {
      message.message[i].descrip = await offchain.offChainRead( message.message[i].Value.FormIDMoiNhat);
      console.log("index: " + i + " has offchain: " + message.message[i].descrip + "\n")
    }

    for (var i in message.message){

      var query =  await User.findOne({
        'local.username':  message.message[i].Value.ThucHien
      },'local.displayname local.phonenumber local.address local.img.path').exec();
      message.message[i].profile = {
            displayname: query.local.displayname,
            phonenumber: query.local.phonenumber,
            url: query.local.img.path
      }
    }
    console.log("data:")
    console.log(message.message)
    if(message.success)
      return res.status(200).send({
        success: true,
        message: message.message.reverse()
      });

    return res.status(404).send(message);
  }catch(err){
    return res.status(500).send({
      success: false,
      message: err,
    });
  }
}


//getHistoryByMaDongGoi: Handler tiep nhan tac vu truy van lich su thong tin san pham qua ma dong goi
//      Input: 
//          key              : ma dong goi cua san pham
//      Output:
//          success: trang thai thuc hien
//          message : thong tin lich su thay doi trang thai cua san pham duoc trich xuat tu so cai 
exports.getHistoryByMaDongGoi = async function(req, res){
  try{
    logger.info('Runninng QueryHistoryByMaDongGoi controller');
    var fcn = 'QueryHistoryByMaDongGoi';
    var args = {
      key: req.query.key
    }
    var user = req.user.local.username;
    if (!user){
      return res.status(401).json(getErrorMessage('user'));
    }
    let message = await querysvc.Querycc(fcn,args,user);

    logger.info(message)

    for (const i in message.message)
    {
      message.message[i].descrip = await offchain.offChainRead( message.message[i].Value.FormIDMoiNhat);
    }

    for (var i in message.message){
      var query =  await User.findOne({
        'local.username':  message.message[i].Value.ThucHien
      },'local.displayname local.phonenumber local.address local.img.path').exec();
      message.message[i].profile = {
            displayname: query.local.displayname,
            phonenumber: query.local.phonenumber,
            /*address: query.local.address,*/
            url: query.local.img.path
      }
    }

    for (const i in message.message)
    {
      message.message[i].hashpbs = await (await querysvc.QueryByTxID('GetBlockByTxID',message.message[i].TxId,user)).message;
    }

    if(message.success)
      return res.status(200).send({
        success: true,
        message: message.message.reverse()
      });
    return res.status(404).send(message);  
  }catch(err){
    return res.status(500).send({
      success: false,
      message: err,
    });
  }
}

//GetHashValue: Handler tiep nhan tac vu truy van trang thai san pham theo chi dinh
//      Input: 
//          id              : ma dinh danh san pham
//          query           : nha san xuat san pham
//          index           : thu tu trang thai muon tim kiem
//      Output:
//          success: trang thai thuc hien
//          message : thong tin  trang thai cua san pham duoc trich xuat tu so cai theo chi muc chi dinh
exports.GetHashValue = async function(req, res){
  try{
    logger.info('Runninng GetHashValue controller');
    var fcn = 'GetHashValue';
    var args = {
      id : req.query.id,
      nhasanxuat  : req.query.query,
      index : req.query.index
    }
    var user = req.user.local.username;
    if (!user){
      return res.status(401).send(getErrorMessage('user'));
    }
    let message = await querysvc.Querycc(fcn,args,user);
    if(message.success)
      return res.status(200).send(message);
    return res.status(404).send(message);
  }catch(err){
    return res.status(500).send({
      success: false,
      message: err,
    });
  }
}


//getByAuthor: Handler tiep nhan tac vu truy van trang thai san pham theo nha san xuat
//      Input: 
//          nhasanxuat              : ten nha san xuat san pham
//      Output:
//          success: trang thai thuc hien
//          message : thong tin  trang thai cua san pham duoc trich xuat tu so cai theo chi muc chi dinh
exports.getByAuthor = async function(req, res){
  try{
    logger.info('Runninng QueryByAuthor controller');
    var fcn = 'QueryByAuthor';
    var args = {
      nhasanxuat  : req.query.nhasanxuat
    }
    var user = req.user.local.username;
    if (!user){
      res.json(getErrorMessage('user'));
    }

    let message = await querysvc.Querycc(fcn,args,user);
    logger.info(message)
    for (const i in message.message)
    {
      message.message[i].descrip = await offchain.offChainRead( message.message[i].Value.FormIDMoiNhat);
    }

    if(message.success)
      return res.status(200).json(message);
    return res.status(404).json(message);
  }catch(err){
    return res.status(500).json({
      success: false,
      message: err,
    });
  }
}


//getListSanPham: Handler tiep nhan tac vu truy van danh sach san pham theo ten nha san xuat
//      Input: 
//          nhasanxuat              : ten nha san xuat san pham
//      Output:
//          success : trang thai thuc hien
//          message : 
//                   soluong         : so luong ban ghi tra ve
//                   cacbanghi       : thong tin  trang thai cua san pham duoc trich xuat tu so cai theo chi muc chi dinh   
exports.getListSanPham = async function(req, res){
  try{
    logger.info('Runninng getListSanPham controller');
    var fcn = 'QueryListSanPham';
    var args = {}
    var user = req.user.local.username;
    if (!user){
      res.json(getErrorMessage('user'));
    }
    logger.info(user);
    let message = await querysvc.Querycc(fcn,args,user);
    logger.info(message)
    if(!message.success){
      return res.status(200).send({
          success: false,
          message: [
            {
              "SoLuong": 0
            }
          ]
      });
    }
    
    for (const i in message.message)
    {
      if (i == 0){
        continue;
      }
      message.message[i].Value.descrip = await offchain.offChainRead( message.message[i].Value.FormIDMoiNhat);
    }


    if(message.success)
      return res.status(200).json(message);
  }catch(err){
    return res.status(500).json({
      success: false,
      message: err,
    });
  }
}


//queryOffchain: Handler tiep nhan tac vu truy van minh chung theo ma dinh danh form thuc hien
//      Input: 
//          uuid              : ma dinh danh form thiet bi di dong da thuc hien cap nhap trang thai
//      Output:
//          success : trang thai thuc hien
//          message : thong tin minh chung gom anh hoac video
exports.queryOffchain = async function(req, res){
  try{
    logger.info('Runninng queryOffchain controller');
    let message = await Offchain.offChainRead(req.body.uuid, user);
    if(message.success)
      return res.reques(200).json(message);
    return res.status(404).json(message);
  }catch(err){
    return res.status(500).json({
      success: false,
      message: err
    });
  }
}
//uploadDescriptions: Handler tiep nhan tac vu cap nhap minh chung trang thai
//      Input: 
//          formID              : ma dinh danh form thiet bi di dong da thuc hien cap nhap trang thai
//          contentType         : kieu du lieu minh chung
//          descriptions        : file minh chung cho trang thai
//          thumbnail           : thumnail cho dinh dang video
//      Output:
//          success : trang thai thuc hien
//          message : thong tin minh chung gom anh hoac video
exports.uploadDescriptions = async function (req, res, next) {
  try{
    logger.info('Runninng uploadDescriptions controller');
    if(!req.body.formID){
      return res.status(400).json({
        success: false,
        message: "Missing field"
      }); 
    }
    logger.info("starting upload")
    var result = await offchain.offChainWrite(req.body.formID,req.body.contentType,req.files);
    if(!result.success){
      return res.status(500).json(result)
    }
    return res.status(200).json({
        success: true,
        message: result
    })
  }catch(err){
    return res.status(500).json({
      success: false,
      message: err
  })
  }
}

//getListSanPhamChiaNho: Handler tiep nhan tac vu truy van thong tin san pham duoc chia nho theo trang
//      Input: 
//          pageindex        : chi muc trang 
//          pagesize         : kich co chia trang
//      Output:
//          success : trang thai thuc hien
//          message : 
//                   soluong         : so luong ban ghi tra ve
//                   cacbanghi       : thong tin  trang thai cua san pham duoc trich xuat tu so cai theo chi muc chi dinh   
exports.getListSanPhamChiaNho = async function(req, res){
  try{
    var fcn = 'QueryListSanPhamTheoPageIndexVaPageSize';
    var args = {
      pageindex : req.query.pageindex,
      pagesize  : req.query.pagesize
    }
    var user = req.user.local.username;
    if (!user){
      res.json(getErrorMessage('user'));
    }
    let message = await querysvc.Querycc(fcn,args,user);
    if(message.success){
    	for (const i in message.message)
    	{
      	if (i != 0)
      		message.message[i].Value.descrip = await offchain.offChainRead( message.message[i].Value.FormIDMoiNhat);
    	}

    	for (var i in message.message){
      		if (i != 0){
      			var query =  await User.findOne({
        		'local.username':  message.message[i].Value.ThucHien
      			},'local.displayname local.phonenumber local.address local.img.path').exec();
      			message.message[i].Value.profile = {
            			displayname: query.local.displayname,
            			phonenumber: query.local.phonenumber,
            			/*address: query.local.address,*/
            			url: query.local.img.path
     			}
      		}
    	}

    	return res.status(200).send(message);
   }
   return res.status(200).send({
       success: true,
       message: [{
          Soluong: 0
       }]
   });
  }catch(err){
    res.status(500).send({
      success: false,
      message: err,
    });
  }
}

//searchSanPham: Handler tiep nhan tac vu truy van thong tin san pham theo thong tin duoc cung cap
//      Input: 
//          keyword: tu khoa de tim kiem san pham
//      Output:
//          success : trang thai thuc hien
//          message : 
//                   soluong    : so luong ban ghi tra ve
//                   cacbanghi  : thong tin  trang thai cua san pham duoc trich xuat tu so cai theo chi muc chi dinh   
exports.searchSanPham = async function(req, res){
  try{
    var fcn = 'SearchSanPham';
    var args = {
      keyword: req.query.keyword
    }
    var user = req.user.local.username;
    if (!user){ 
      res.json(getErrorMessage('user'));
    }
    let message = await querysvc.Querycc(fcn,args,user);
    console.log(message)
    if(message.success)
      return res.status(200).send(message);
    console.log("pass")
    return res.status(200).send({
      success:false,
      message:""
    });
  }catch(err){
    return res.status(500).send({
      success: false,
      message: err,
    });
  }
}
//getBlockByTxID deprecated
exports.getBlockByTxID = async function(req, res){
  try{
    var fcn = 'GetBlockByTxID';
    var args = {
      txId: req.query.txId
    }
    var user = req.user.local.username;

    let message = await querysvc.QueryByTxID(fcn,args,user);

    if(message.success)
      return res.json(message);

    return res.send({
      success: false,
      message: "Not found",
    });
  }catch(err){
    throw({
      success: false,
      message: err,
    });
  }
}
