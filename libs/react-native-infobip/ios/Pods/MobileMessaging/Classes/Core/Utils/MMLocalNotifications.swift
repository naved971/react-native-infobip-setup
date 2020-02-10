//
//  MMLocalNotifications.swift
//
//  Created by Andrey K. on 12/09/16.
//
//

import Foundation
import UserNotifications

class LocalNotifications {
	class func presentLocalNotification(with message: MTMessage) {
        MobileMessaging.messageHandlingDelegate?.willScheduleLocalNotification?(for: message)
        if #available(iOS 10.0, *) {
            LocalNotifications.scheduleUserNotification(with: message)
        } else {
            MMLogDebug("[Local Notification] presenting notification for \(message.messageId)")
            MobileMessaging.application.presentLocalNotificationNow(UILocalNotification.make(with: message))
        }
	}
	
	@available(iOS 10.0, *)
	class func scheduleUserNotification(with message: MTMessage) {
		guard let txt = message.text else {
			return
		}
		let content = UNMutableNotificationContent()
		if let categoryId = message.aps.category {
			content.categoryIdentifier = categoryId
		}
		if let title = message.title {
			content.title = title
		}
		content.body = txt
		content.userInfo = message.originalPayload
		if let sound = message.sound {
			if sound == "default" {
				content.sound = UNNotificationSound.default
			} else {
				content.sound = UNNotificationSound.init(named: UNNotificationSoundName(rawValue: sound))
			}
		}
		
		message.downloadImageAttachment(completion: { (downloadedFileUrl, error) in
			if let downloadedFileUrl = downloadedFileUrl {
				do {
					let att = try UNNotificationAttachment(identifier: downloadedFileUrl.absoluteString, url: downloadedFileUrl)
					content.attachments = [att]
				} catch let e {
					MMLogError("Error while building local notification attachment: \(e as? String)")
				}
			}
			let req = UNNotificationRequest(identifier: message.messageId, content: content, trigger: nil)
			MMLogDebug("[Local Notification] scheduling notification for \(message.messageId)")
			UNUserNotificationCenter.current().add(req, withCompletionHandler: nil)
		})
	}
}

extension UILocalNotification {
	class func make(with message: MTMessage) -> UILocalNotification {
		let localNotification = UILocalNotification()
		localNotification.userInfo = message.originalPayload
		localNotification.alertBody = message.text
		localNotification.soundName = message.sound
		localNotification.alertTitle = message.title
		localNotification.category = message.aps.category
		return localNotification
	}
}
