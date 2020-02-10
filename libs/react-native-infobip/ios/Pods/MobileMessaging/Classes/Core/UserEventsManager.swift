//
//  UserEventsManager.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 17/01/2019.
//


import Foundation

class UserEventsManager {

	class func postApiErrorEvent(_ error: NSError?) {
		if let error = error {
			post(MMNotificationAPIError, [MMNotificationKeyAPIErrorUserInfo: error])
		}
	}

	class func postRegUpdatedEvent(_ pushRegId: String?) {
		if let pushRegId = pushRegId {
			post(MMNotificationRegistrationUpdated, [MMNotificationKeyRegistrationInternalId: pushRegId])
		}
	}

	class func postDepersonalizedEvent() {
		post(MMNotificationDepersonalized)
	}

	class func postPersonalizedEvent() {
		post(MMNotificationPersonalized)
	}

	class func postUserSyncedEvent(_ user: User?) {
		if let user = user {
			post(MMNotificationUserSynced, [MMNotificationKeyUser: user])
		}
	}

	class func postMessageReceivedEvent(_ message: MTMessage) {
		post(MMNotificationMessageReceived, [MMNotificationKeyMessage: message])
	}

	class func postInstallationSyncedEvent(_ installation: Installation?) {
		if let installation = installation {
			post(MMNotificationInstallationSynced, [MMNotificationKeyInstallation: installation])
		}
	}

	class func postDLRSentEvent(_ messageIds: [String]) {
		if !messageIds.isEmpty {
			post(MMNotificationDeliveryReportSent, [MMNotificationKeyDLRMessageIDs: messageIds])
		}
	}

	class func postWillSendMessageEvent(_ messagesToSend: Array<MOMessage>) {
		if !messagesToSend.isEmpty {
			post(MMNotificationMessagesWillSend, [MMNotificationKeyMessageSendingMOMessages: messagesToSend])
		}
	}

	class func postMessageSentEvent(_ messages: [MOMessage]) {
		if !messages.isEmpty {
			post(MMNotificationMessagesDidSend, [MMNotificationKeyMessageSendingMOMessages: messages])
		}
	}

	class func postDeviceTokenReceivedEvent(_ tokenStr: String) {
		post(MMNotificationDeviceTokenReceived, [MMNotificationKeyDeviceToken: tokenStr])
	}

	class func postMessageTappedEvent(_ userInfo: [String: Any]) {
		post(MMNotificationMessageTapped, userInfo)
	}

	class func postActionTappedEvent(_ userInfo: [String: Any]) {
		post(MMNotificationActionTapped, userInfo)
	}

	class func postGeoServiceStartedEvent() {
		post(MMNotificationGeoServiceDidStart)
	}

	class func postNotificationCenterAuthRequestFinished(granted: Bool, error: Error?) {
		var userInfo: [String: Any] = [MMNotificationKeyGranted: granted]
		if let error = error {
			userInfo[MMNotificationKeyError] = error
		}
		post(MMNotificationCenterAuthRequestFinished, userInfo)
	}

	class func post(_ name: String, _ userInfo: [String: Any]? = nil) {
		MMQueue.Main.queue.executeAsync {
			NotificationCenter.default.post(name: NSNotification.Name(rawValue: name), object: self, userInfo: userInfo)
		}
	}
}
