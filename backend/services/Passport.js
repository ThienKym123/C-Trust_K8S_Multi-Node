var LocalStrategy = require('passport-local').Strategy;
var BearerStrategy = require('passport-http-bearer').Strategy;
var jwt = require('jsonwebtoken');
var User = require('./models/users');
var UserInfo = require('./models/inforUser');
const secret = require('./utils/config.js').Token_key;

module.exports = function(passport) {

    passport.serializeUser((user, done) => {
        done(null, user.id);
      });
      
    passport.deserializeUser((id, done) => {
    Profile.findById(id)
        .then(user => {
        done(null, user);
        })
    });

    passport.use('login', new LocalStrategy({
            usernameField: 'username',
            passwordField: 'password'
        },
        async function(username, password, done) {
            try {
                const user = await User.findOne({ 'local.username': username });
                if (!user) {
                    return done(null, false);
                }
                if (!user.validPassword(password))
                    return done(null, false);
                return done(null, {
                    username: user.local.username,
                    token: jwt.sign({
                            username: user.local.username
                        },
                        secret, { expiresIn: 36000000 })
                });
            } catch (err) {
                return done(err);
            }
        }
    ));

    passport.use('SignUp', new LocalStrategy({
            usernameField: 'username',
            passwordField: 'password'
        },
        async function(username, password, done) {
            try {
                const user = await User.findOne({ 'local.username': username });
                if (user) {
                    return done(null, false);
                } else {
                    var newUser = new User();
                    newUser.local.username = username;
                    newUser.local.password = newUser.generateHash(password);
                    await newUser.save();
                    return done(null, newUser);
                }
            } catch (err) {
                return done(err);
            }
        }
    ));

    passport.use('org1', new BearerStrategy(async (token, done) => {
        try {
            var decode = jwt.verify(token, secret);
            const user = await UserInfo.findOne({ 'local.username': decode.username });
            if (!user) {
                return done(null, false);
            }
            return done(null, user, { scope: 'org1' });
        } catch (err) {
            return done(err);
        }
    }));
}