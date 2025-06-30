const mongoose = require('mongoose');


userSchema = mongoose.Schema({
    local:{
        userID: String,
        username: String,
        displayname: String,
        phonenumber: String,
        description: String,
        address: String,
        msp: String,
        img: 
        { 
            path: String,
            contentType: String 
        }
    }
});


module.exports = mongoose.model('UserInfo',userSchema);
