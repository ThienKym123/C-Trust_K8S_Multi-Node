exports.home = function(req, res) {
    return res.render('./guest/index', {
        title: 'Trang chủ'
    })
}