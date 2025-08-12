/*
 * Copyright IBM Corp. All Rights Reserved.
 *
 * SPDX-License-Identifier: Apache-2.0
 */

'use strict';

const adminUserId = 'rcaadmin';
const adminUserPasswd = 'rcaadminpw';

/**
 *
 * @param {*} FabricCAServices
 * @param {*} ccp
 */
exports.buildCAClient = (FabricCAServices, ccp, caHostName) => {
	// Create a new CA client for interacting with the CA.
	const caInfo = ccp.certificateAuthorities[caHostName]; //lookup CA details from config
	const caTLSCACerts = caInfo.tlsCACerts.pem;
	const caClient = new FabricCAServices(caInfo.url, { trustedRoots: caTLSCACerts, verify: false }, caInfo.caName);

	console.log(`Built a CA Client named ${caInfo.caName}`);
	return caClient;
};

exports.enrollAdmin = async (caClient, wallet, orgMspId) => {
	try {
		// Check to see if we've already enrolled the admin user.
		const identity = await wallet.get(adminUserId);
		if (identity) {
			console.log('An identity for the admin user already exists in the wallet');
			return;
		}

		// Enroll the admin user, and import the new identity into the wallet.
		const enrollment = await caClient.enroll({ enrollmentID: adminUserId, enrollmentSecret: adminUserPasswd });
		const x509Identity = {
			credentials: {
				certificate: enrollment.certificate,
				privateKey: enrollment.key.toBytes(),
			},
			mspId: orgMspId,
			type: 'X.509',
		};
		await wallet.put(adminUserId, x509Identity);
		console.log('Successfully enrolled admin user and imported it into the wallet');
	} catch (error) {
		console.error(`Failed to enroll admin user : ${error}`);
	}
};

exports.registerAndEnrollUser = async (caClient, wallet, orgMspId, userId, affiliation) => {
	try {
		// Check to see if we've already enrolled the user
		const userIdentity = await wallet.get(userId);
		if (userIdentity) {
			console.log(`An identity for the user ${userId} already exists in the wallet`);
			return;
		}

		// Must use an admin to register a new user
		const adminIdentity = await wallet.get(adminUserId);
		if (!adminIdentity) {
			console.log('An identity for the admin user does not exist in the wallet');
			console.log('Enroll the admin user before retrying');
			return;
		}

		// build a user object for authenticating with the CA
		const provider = wallet.getProviderRegistry().getProvider(adminIdentity.type);
		const adminUser = await provider.getUserContext(adminIdentity, adminUserId);

		// Register the user, enroll the user, and import the new identity into the wallet.
		// if affiliation is specified by client, the affiliation value must be configured in CA
		const secret = await caClient.register({
			affiliation: affiliation,
			enrollmentID: userId,
			role: 'client'
		}, adminUser);
		const enrollment = await caClient.enroll({
			enrollmentID: userId,
			enrollmentSecret: secret
		});
		const x509Identity = {
			credentials: {
				certificate: enrollment.certificate,
				privateKey: enrollment.key.toBytes(),
			},
			mspId: orgMspId,
			type: 'X.509',
		};
		await wallet.put(userId, x509Identity);
		console.log(`Successfully registered and enrolled user ${userId} and imported it into the wallet`);
	} catch (error) {
		console.error(`Failed to register user : ${error}`);
	}
};

/**
 * Revoke a user's certificate using the CA client.
 * @param {*} caClient - The Fabric CA client
 * @param {*} wallet - The wallet instance
 * @param {*} userId - The user to revoke
 * @param {*} adminUserId - The admin identity in the wallet
 * @param {*} reason - Reason for revocation (optional)
 */
exports.revokeUser = async (caClient, wallet, userId, adminUserId, reason = 'cessationOfOperation') => {
	try {
		// Get admin identity
		const adminIdentity = await wallet.get(adminUserId);
		if (!adminIdentity) {
			throw new Error('Admin identity not found in wallet');
		}
		const provider = wallet.getProviderRegistry().getProvider(adminIdentity.type);
		const adminUser = await provider.getUserContext(adminIdentity, adminUserId);
		// Revoke the user
		await caClient.revoke({ enrollmentID: userId, reason }, adminUser);
		// Optionally remove from wallet
		await wallet.remove(userId);
		console.log(`Successfully revoked user ${userId}`);
	} catch (error) {
		console.error(`Failed to revoke user ${userId}:`, error);
		throw error;
	}
};

/**
 * Reenroll a user using the CA client.
 * @param {*} caClient - The Fabric CA client
 * @param {*} wallet - The wallet instance
 * @param {*} userId - The user to reenroll
 * @param {*} orgMspId - The MSP ID
 */
exports.reenrollUser = async (caClient, wallet, userId, orgMspId) => {
	try {
		const userIdentity = await wallet.get(userId);
		if (!userIdentity) {
			throw new Error(`Identity for user ${userId} not found in wallet`);
		}
		const provider = wallet.getProviderRegistry().getProvider(userIdentity.type);
		const user = await provider.getUserContext(userIdentity, userId);
		// Reenroll
		const enrollment = await caClient.reenroll(user);
		const x509Identity = {
			credentials: {
				certificate: enrollment.certificate,
				privateKey: enrollment.key.toBytes(),
			},
			mspId: orgMspId,
			type: 'X.509',
		};
		await wallet.put(userId, x509Identity);
		console.log(`Successfully reenrolled user ${userId}`);
	} catch (error) {
		console.error(`Failed to reenroll user ${userId}:`, error);
		throw error;
	}
};
