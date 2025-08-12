const log4js = require('log4js');
const crypto = require('crypto');

var getLogger = function(moduleName) {
    var logger = log4js.getLogger(moduleName);
    logger.level = 'debug';
    return logger;
}


function generateHash(value) {
    return crypto.createHash('sha256').update(value).digest('hex')
}


async function getListener(hashPBs, network, start, stop) {
    try {
        await network.addBlockListener(
            async(event) => {
                hashPBs = event.blockData.header.data_hash.toString('hex');
            }, {
                startBlock: start,
            }
        );
        return hashPBs
    } catch (err) {
        throw err
    }
}


exports.getListener = getListener;
exports.generateHash = generateHash;
exports.getLogger = getLogger;