'use strict';

const crypto = require('crypto');
const path = require('path');
const fs = require('fs');

var logger = require('./utils.js').getLogger("Offchain-Service")

exports.createDatabaseIfNotExists = function(nano, dbname) {

    return new Promise((async(resolve, reject) => {
        await nano.db.get(dbname, async function(err, body) {
            if (err) {
                if (err.statusCode == 404) {
                    nano.auth('admin', 'adminpw', async function(err, body) {
                        await nano.db.create(dbname, function(err, body) {
                            if (!err) {
                                resolve(true);
                            } else {
                                logger.error(`reject with ${err}`);
                                reject(err);
                            }
                        });
                    });
                } else {
                    reject(err);
                }
            } else {
                resolve(true);
            }
        });
    }));
}

exports.writeToCouchDB = async function(nano, dbname, key, value) {

    return new Promise((async(resolve, reject) => {

        try {
            await this.createDatabaseIfNotExists(nano, dbname);
        } catch (error) {

        }

        var file = fs.readFileSync(value.file["descriptions"][0].path);
        var doc = crypto.createHash('sha256').update(file.toString('base64')).digest('hex');

        var newpath = value.file["descriptions"][0].path + path.extname(value.file["descriptions"][0].originalname);
        fs.renameSync(value.file["descriptions"][0].path, newpath);

        const db = nano.use(dbname);
        var data = {
            path: 'images/descriptions/' + value.file["descriptions"][0].filename + path.extname(value.file["descriptions"][0].originalname),
            form_id: value.formId,
            content_type: value.contentType,
            hash: doc
        }

        if (value.file["thumbnail"]) {
            fs.renameSync(value.file["thumbnail"][0].path, value.file["thumbnail"][0].path + path.extname(value.file["thumbnail"][0].originalname));
            data.thumbnail = value.file["thumbnail"][0];
            data.thumbnail.path = 'images/descriptions/' + data.thumbnail.filename + path.extname(data.thumbnail.originalname);
            logger.info(data.thumbnail.path)
        }

        await db.insert(data, doc + key, async function(err, body, header) {
            if (err) {
                logger.error(err)
                reject(err);
            }

            await db.attachment.insert(key, value.file["descriptions"][0].filename, file, value.file["descriptions"][0].mimetype).then((body) => {});
        });
        resolve(true);

    }));
}

exports.queryFromCouchDB = async function(nano, dbname, key) {

    return new Promise((async(resolve, reject) => {

        const db = nano.use(dbname);
        if (!db) {
            reject(err)
        }

        var query = {
            selector: {
                form_id: { "$eq": key }
            },
            fields: ["path", "form_id", "content_type", "thumbnail.path", "hash"],
            limit: 50
        };

        var result = await db.find(query, async function(err, body, header) {
            if (err) {
                logger.error(err);
                reject(err);
            }
            resolve(body);
        });

    }));
}


// exports.writeReviewToCouchDB = async function (nano, dbname, key, value) {

//   return new Promise((async (resolve, reject) => {

//       try {
//           await this.createDatabaseIfNotExists(nano, dbname);
//       } catch (error) {

//       }

//       var file = fs.readFileSync(value.file["descriptions"][0].path);
//       var doc = crypto.createHash('sha256').update(file.toString('base64')).digest('base64') + key;

//       var newpath = value.file["descriptions"][0].path + path.extname(value.file["descriptions"][0].originalname);
//       fs.renameSync(value.file["descriptions"][0].path,newpath);

//       const db = nano.use(dbname);
//       var data = {
//         path: 'images/descriptions/' + value.file["descriptions"][0].filename  + path.extname(value.file["descriptions"][0].originalname),
//         form_id: value.formId,
//         content_type: value.contentType,
//       }

//       if(value.file["thumbnail"]){
//         fs.renameSync(value.file["thumbnail"][0].path,value.file["thumbnail"][0].path + path.extname(value.file["thumbnail"][0].originalname));
//         data.thumbnail= value.file["thumbnail"][0];
//         data.thumbnail.path = 'images/descriptions/' + data.thumbnail.filename + path.extname(data.thumbnail.originalname);
//         logger.info(data.thumbnail.path)
//       }

//       await db.insert(data,doc, async function (err, body, header){
//           if(err){
//             logger.error(err)
//             reject(err);
//           }

//         await db.attachment.insert(key, value.file["descriptions"][0].filename , file, value.file["descriptions"][0].mimetype).then((body)=>{
//             console.log(body)
//         });
//       });
//       resolve(true);

//   }));
// }


// exports.queryReviewFromCouchDB = async function (nano, dbname, key) {

//   return new Promise((async (resolve, reject) => {

//       const db = nano.use(dbname);
//       if(!db){
//         reject(err)
//       }

//       var query = {
//         selector:{
//           form_id: {"$eq":key}
//         },
//         fields: [ "path", "form_id","content_type","thumbnail.path"],
//         limit:50
//       };

//       var result = await db.find(query, async function (err, body, header){
//           if(err){
//             logger.error(err);
//             reject(err);
//           }
//           resolve(body);
//       });

//   }));
// }