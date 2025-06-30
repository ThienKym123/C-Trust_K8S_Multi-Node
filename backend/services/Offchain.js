const couchdbutil = require('./utils/couchdbUtils.js');

const config = require('./utils/config.js');
const channelid = config.channelid;
const use_couchdb = config.use_couchdb;
const couchdb_address = config.couchdb_address;

const nano = require('nano')(couchdb_address);

var logger = require('./utils/utils.js').getLogger("Offchain-Service")

// offChainWrite: services thuc hien doc thong tin cua du lieu luu ngoai mang
// Input: (formID)
//        formID     : ma dinh danh form thiet bi luu minh chung
//        contentType: dinh dang du lieu luu tru
//        file       : du lieu minh chung can luu tru
// Output: (success, result)
//        success: trang thai thuc hien
//        result : hinh anh, video minh chung da duoc tai len he thong
async function offChainWrite(formID, contentType, file) {
    try {
        logger.info('offchain service write %s, %s', formID, contentType);
        const writeObject = new Object();
        writeObject.formID = formID;
        writeObject.contentType = contentType;
        writeObject.file = file;

        if (use_couchdb) {
            await writeValuesToCouchDB(nano, channelid, writeObject);
        }
        return {
            success: true,
            message: "Add record to database successfully"
        }
    } catch (error) {
        return res = {
            success: false,
            message: error
        }
    }
}

// offChainRead: services thuc hien doc thong tin cua du lieu luu ngoai mang
// Input: (formID)
//        formID   : ma dinh danh form thiet bi luu minh chung
// Output: (success, result)
//        success: trang thai thuc hien
//        result : hinh anh, video minh chung da duoc tai len he thong
async function offChainRead(formID) {
    try {
        logger.info('offchain service read %s', formID);
        const writeObject = new Object();

        writeObject.formID = formID;

        if (use_couchdb) {
            var result = await readValuesFromCouchDB(nano, channelid, writeObject);
        }
        return {
            success: true,
            message: result
        }
    } catch (error) {
        logger.error(`Failed to evaluate transaction: ${error}`);
        return {
            success: false,
            message: error
        }
    }
}

// writeValuesToCouchDB: services thuc hien luu thong tin cua du lieu luu ngoai mang
// Input: (formID)
//        channelname   : ma dinh danh form thiet bi luu minh chung
//        writeObject   : du lieu luu tru ben ngoai mang
// Output: (success, result)
//        success: trang thai thuc hien
//        result : hinh anh, video minh chung da duoc tai len he thong
async function writeValuesToCouchDB(nano, channelname, writeObject) {

    return new Promise((async(resolve, reject) => {

        try {
            const dbname = channelname;

            const key = writeObject.formID;
            const values = {
                formId: writeObject.formID,
                contentType: writeObject.contentType,
                file: writeObject.file
            }

            try {

                await couchdbutil.writeToCouchDB(
                    nano,
                    dbname,
                    key,
                    values
                );
            } catch (error) {
                logger.error(error);
                reject(error);
            }

        } catch (error) {
            logger.error(`Failed to write to couchdb: ${error}`);
            reject(error);
        }

        resolve(true);

    }));

}
// readValuesFromCouchDB: services thuc hien doc thong tin cua du lieu luu ngoai mang
// Input: (formID)
//        channelname   : ma dinh danh form thiet bi luu minh chung
//        writeObject   : du lieu luu tru ben ngoai mang
// Output: (success, result)
//        success: trang thai thuc hien
//        result : hinh anh, video minh chung da duoc tai len he thong
async function readValuesFromCouchDB(nano, channelname, writeObject) {
    return new Promise((async(resolve, reject) => {

        try {
            const dbname = channelname;

            const key = writeObject.formID;

            try {
                var result = await couchdbutil.queryFromCouchDB(
                    nano,
                    dbname,
                    key
                );

            } catch (error) {
                logger.error(error);
                reject(error);
            }

        } catch (error) {
            logger.error(`Failed to write to couchdb: ${error}`);
            reject(error);
        }

        resolve(result);

    }));
}

exports.offChainWrite = offChainWrite;
exports.offChainRead = offChainRead;