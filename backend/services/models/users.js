var mongooes = require('mongoose');
var bcrypt = require('bcryptjs');
const mongoose = require('mongoose');
const saltRound = 8;


userSchema = mongoose.Schema({
    local:{
        username: String,
        password: String,
    }
});

userSchema.methods.generateHash = function(password){
    return bcrypt.hashSync(password,bcrypt.genSaltSync(saltRound));
}

userSchema.methods.validPassword = function(password){
    return bcrypt.compareSync(password,this.local.password);
}

module.exports = mongooes.model('User',userSchema);