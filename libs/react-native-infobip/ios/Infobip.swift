//
//  Infobip.swift
//  Infobip
//
//  Created by Naved khan on 11/02/20.
//  Copyright © 2020 Facebook. All rights reserved.
//

import Foundation
import MobileMessaging

@objc(Infobip)
class ReactNativeMobileMessaging: NSObject {
    @objc
    static func requiresMainQueueSetup() -> Bool {
        return true
    }
    
    @objc(init:)
    func start(config: NSDictionary) {
        guard let config = config as? [String : AnyObject], let configuration = MMConfiguration(rawConfig: config) else { return }
        MobileMessaging.logger = MMDefaultLogger()
        MobileMessaging.withApplicationCode(configuration.appCode, notificationType: configuration.notificationType)?.start()
    }
}

//TODO: refactor, following part is duplicated in cordova plugin
class MMConfiguration {
    struct Keys {
        static let privacySettings = "privacySettings"
        static let userDataPersistingDisabled = "userDataPersistingDisabled"
        static let carrierInfoSendingDisabled = "carrierInfoSendingDisabled"
        static let systemInfoSendingDisabled = "systemInfoSendingDisabled"
        static let applicationCodePersistingDisabled = "applicationCodePersistingDisabled"
        static let geofencingEnabled = "geofencingEnabled"
        static let applicationCode = "applicationCode"
        static let forceCleanup = "forceCleanup"
        static let logging = "logging"
        static let defaultMessageStorage = "defaultMessageStorage"
        static let notificationTypes = "notificationTypes"
        static let messageStorage = "messageStorage"
        static let cordovaPluginVersion = "cordovaPluginVersion"
        static let notificationCategories = "notificationCategories"
    }
    
    let appCode: String
    let geofencingEnabled: Bool
    let messageStorageEnabled: Bool
    let defaultMessageStorage: Bool
    let notificationType: UserNotificationType
    let forceCleanup: Bool
    let logging: Bool
    let privacySettings: [String: Any]
    let cordovaPluginVersion: String
    let categories: [NotificationCategory]?
    
    init?(rawConfig: [String: AnyObject]) {
        guard let appCode = rawConfig[MMConfiguration.Keys.applicationCode] as? String,
            let ios = rawConfig["ios"] as? [String: AnyObject] else
        {
            return nil
        }
        
        self.appCode = appCode
        self.geofencingEnabled = rawConfig[MMConfiguration.Keys.geofencingEnabled].unwrap(orDefault: false)
        self.forceCleanup = ios[MMConfiguration.Keys.forceCleanup].unwrap(orDefault: false)
        self.logging = ios[MMConfiguration.Keys.logging].unwrap(orDefault: false)
        self.defaultMessageStorage = rawConfig[MMConfiguration.Keys.defaultMessageStorage].unwrap(orDefault: false)
        self.messageStorageEnabled = rawConfig[MMConfiguration.Keys.messageStorage] != nil ? true : false
        
        if let rawPrivacySettings = rawConfig[MMConfiguration.Keys.privacySettings] as? [String: Any] {
            var ps = [String: Any]()
            ps[MMConfiguration.Keys.userDataPersistingDisabled] = rawPrivacySettings[MMConfiguration.Keys.userDataPersistingDisabled].unwrap(orDefault: false)
            ps[MMConfiguration.Keys.carrierInfoSendingDisabled] = rawPrivacySettings[MMConfiguration.Keys.carrierInfoSendingDisabled].unwrap(orDefault: false)
            ps[MMConfiguration.Keys.systemInfoSendingDisabled] = rawPrivacySettings[MMConfiguration.Keys.systemInfoSendingDisabled].unwrap(orDefault: false)
            ps[MMConfiguration.Keys.applicationCodePersistingDisabled] = rawPrivacySettings[MMConfiguration.Keys.applicationCodePersistingDisabled].unwrap(orDefault: false)
            
            privacySettings = ps
        } else {
            privacySettings = [:]
        }
        
        self.cordovaPluginVersion = rawConfig[MMConfiguration.Keys.cordovaPluginVersion].unwrap(orDefault: "unknown")
        
        self.categories = (rawConfig[MMConfiguration.Keys.notificationCategories] as? [[String: Any]])?.compactMap(NotificationCategory.init)
        
        if let notificationTypeNames =  ios[MMConfiguration.Keys.notificationTypes] as? [String] {
            let options = notificationTypeNames.reduce([], { (result, notificationTypeName) -> [UserNotificationType] in
                var result = result
                switch notificationTypeName {
                case "badge": result.append(UserNotificationType.badge)
                case "sound": result.append(UserNotificationType.sound)
                case "alert": result.append(UserNotificationType.alert)
                default: break
                }
                return result
            })
            
            self.notificationType = UserNotificationType(options: options)
        } else {
            self.notificationType = UserNotificationType.none
        }
    }
}

extension Optional {
    func unwrap<T>(orDefault fallbackValue: T) -> T {
        switch self {
        case .some(let val as T):
            return val
        default:
            return fallbackValue
        }
    }
}

