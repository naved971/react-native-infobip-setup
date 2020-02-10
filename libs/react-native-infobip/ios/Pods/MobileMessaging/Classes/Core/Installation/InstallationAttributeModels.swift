//
//  InstallationAttributeModels.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 29/11/2018.
//

import Foundation
import CoreLocation

struct DepersonalizationConsts {
	static var failuresNumberLimit = 3
}

@objc public enum SuccessPending: Int {
	case undefined = 0, pending, success
}

final class InternalData : NSObject, NSCoding, NSCopying, ArchivableCurrent {
	static var currentPath = getDocumentsDirectory(filename: "internal-data")
	static var cached = ThreadSafeDict<InternalData>()
	static var empty: InternalData {
		return InternalData(systemDataHash: 0, location: nil, badgeNumber: 0, applicationCode: nil, depersonalizeFailCounter: 0, currentDepersonalizationStatus: .undefined, registrationDate: nil)
	}
	func removeSensitiveData() {
		if MobileMessaging.privacySettings.applicationCodePersistingDisabled  {
			self.applicationCode = nil
		}
	}
	func handleCurrentChanges(old: InternalData, new: InternalData) {
		if old.currentDepersonalizationStatus != new.currentDepersonalizationStatus {
			MMLogDebug("[InternalData management] setting new depersonalize status: \(self.currentDepersonalizationStatus)")
			MobileMessaging.sharedInstance?.updateDepersonalizeStatusForSubservices()
		}
	}
	///
	var registrationDate: Date?
	var systemDataHash: Int64
	var location: CLLocation?
	var badgeNumber: Int
	var applicationCode: String?
	var depersonalizeFailCounter: Int
	var currentDepersonalizationStatus: SuccessPending

	func copy(with zone: NSZone? = nil) -> Any {
		let copy = InternalData(systemDataHash: systemDataHash, location: location, badgeNumber: badgeNumber, applicationCode: applicationCode, depersonalizeFailCounter: depersonalizeFailCounter, currentDepersonalizationStatus: currentDepersonalizationStatus, registrationDate: registrationDate)
		return copy
	}

	init(systemDataHash: Int64, location: CLLocation?, badgeNumber: Int, applicationCode: String?, depersonalizeFailCounter: Int, currentDepersonalizationStatus: SuccessPending, registrationDate: Date?) {
		self.systemDataHash = systemDataHash
		self.location = location
		self.badgeNumber = badgeNumber
		self.applicationCode = applicationCode
		self.depersonalizeFailCounter = depersonalizeFailCounter
		self.currentDepersonalizationStatus = currentDepersonalizationStatus
		self.registrationDate = registrationDate
	}

	required public init?(coder aDecoder: NSCoder) {
		systemDataHash = aDecoder.decodeInt64(forKey: "systemDataHash")
		location = aDecoder.decodeObject(forKey: "location") as? CLLocation
		badgeNumber = aDecoder.decodeInteger(forKey: "badgeNumber")
		applicationCode = aDecoder.decodeObject(forKey: "applicationCode") as? String
		depersonalizeFailCounter = aDecoder.decodeInteger(forKey: "depersonalizeFailCounter")
		currentDepersonalizationStatus = SuccessPending(rawValue: aDecoder.decodeInteger(forKey: "currentDepersonalizationStatus")) ?? .undefined
		registrationDate = aDecoder.decodeObject(forKey: "registrationDate") as? Date
	}

	func encode(with aCoder: NSCoder) {
		aCoder.encode(systemDataHash, forKey: "systemDataHash")
		aCoder.encode(location, forKey: "location")
		aCoder.encode(badgeNumber, forKey: "badgeNumber")
		aCoder.encode(applicationCode, forKey: "applicationCode")
		aCoder.encode(depersonalizeFailCounter, forKey: "depersonalizeFailCounter")
		aCoder.encode(currentDepersonalizationStatus.rawValue, forKey: "currentDepersonalizationStatus")
		aCoder.encode(registrationDate, forKey: "registrationDate")
	}
}

@objcMembers public final class Installation: NSObject, NSCoding, NSCopying, JSONDecodable, DictionaryRepresentable, Archivable {
	var version: Int = 0
	static var currentPath = getDocumentsDirectory(filename: "installation")
	static var dirtyPath = getDocumentsDirectory(filename: "dirty-installation")
	static var cached = ThreadSafeDict<Installation>()
	static var empty: Installation {
		let systemData = UserAgent().systemData
		return Installation(applicationUserId: nil, appVersion: systemData.appVer, customAttributes: [:], deviceManufacturer: systemData.deviceManufacturer, deviceModel: systemData.deviceModel, deviceName: systemData.deviceName, deviceSecure: systemData.deviceSecure, deviceTimeZone: systemData.deviceTimeZone, geoEnabled: false, isPrimaryDevice: false, isPushRegistrationEnabled: true, language: systemData.language, notificationsEnabled: systemData.notificationsEnabled, os: systemData.os, osVersion: systemData.OSVer, pushRegistrationId: nil, pushServiceToken: nil, pushServiceType: systemData.pushServiceType, sdkVersion: systemData.SDKVersion)
	}
	func removeSensitiveData() {
		//nothing is sensitive in installation
	}
	func handleCurrentChanges(old: Installation, new: Installation) {
		if old.pushRegistrationId != new.pushRegistrationId {
			UserEventsManager.postRegUpdatedEvent(pushRegistrationId)
		}
		if old.isPushRegistrationEnabled != new.isPushRegistrationEnabled {
			MobileMessaging.sharedInstance?.updateRegistrationEnabledSubservicesStatus()
		}
	}
	func handleDirtyChanges(old: Installation, new: Installation) {
		if old.isPushRegistrationEnabled != new.isPushRegistrationEnabled {
			MobileMessaging.sharedInstance?.updateRegistrationEnabledSubservicesStatus()
		}
	}
	
//
	static var delta: [String: Any] {
		guard let currentDict = MobileMessaging.sharedInstance?.currentInstallation().dictionaryRepresentation, let dirtyDict = MobileMessaging.sharedInstance?.dirtyInstallation().dictionaryRepresentation else {
			return [:]
		}
		return deltaDict(currentDict, dirtyDict)
	}

	/// If you have a users database where every user has a unique identifier, you would leverage our External User Id API to gather and link all users devices where your application is installed. However if you have several different applications that share a common user data base you would need to separate one push message destination from another (applications may be considered as destinations here). In order to do such message destination separation, you would need to provide us with a unique Application User Id.
	public var applicationUserId: String?

	/// Returns installations custom data. Arbitrary attributes that are related to the current installation. You can provide additional users information to the server, so that you will be able to send personalised targeted messages to exact user and other nice features.
	public var customAttributes: [String: AttributeType]

	/// Primary device setting
	/// Single user profile on Infobip Portal can have one or more mobile devices with the application installed. You might want to mark one of such devices as a primary device and send push messages only to this device (i.e. receive bank authorization codes only on one device).
	public var isPrimaryDevice: Bool

	/// Current push registration status.
	/// The status defines whether the device is allowed to be receiving push notifications (regular push messages/geofencing campaign messages/messages fetched from the server).
	/// MobileMessaging SDK has the push registration enabled by default.
	public var isPushRegistrationEnabled: Bool

	/// Unique push registration identifier issued by server. This identifier matches one to one with APNS cloud token of the particular application installation. This identifier is only available after `MMNotificationRegistrationUpdated` event.
	public internal(set) var pushRegistrationId: String?

	public internal(set) var appVersion: String?
	public internal(set) var deviceManufacturer: String?
	public internal(set) var deviceModel: String?
	public internal(set) var deviceName: String?
	public internal(set) var deviceSecure: Bool
	public internal(set) var deviceTimeZone: String?
	public internal(set) var geoEnabled: Bool
	public internal(set) var language: String?
	public internal(set) var notificationsEnabled: Bool
	public internal(set) var os: String?
	public internal(set) var osVersion: String?
	public internal(set) var pushServiceToken: String?
	public internal(set) var pushServiceType: String?
	public internal(set) var sdkVersion: String?
	// more properties needed? ok but look at the code below first.

	required public init?(coder aDecoder: NSCoder) {
		applicationUserId = aDecoder.decodeObject(forKey: "applicationUserId") as? String
		customAttributes = (aDecoder.decodeObject(forKey: "customAttributes") as? [String: AttributeType]) ?? [:]
		isPrimaryDevice = aDecoder.decodeBool(forKey: "isPrimary")
		isPushRegistrationEnabled = aDecoder.decodeBool(forKey: "regEnabled")
		pushRegistrationId = aDecoder.decodeObject(forKey: "pushRegId") as? String

		appVersion = aDecoder.decodeObject(forKey: "appVersion") as? String
		deviceManufacturer = aDecoder.decodeObject(forKey: "deviceManufacturer") as? String
		deviceModel = aDecoder.decodeObject(forKey: "deviceModel") as? String
		deviceName = aDecoder.decodeObject(forKey: "deviceName") as? String
		deviceSecure = aDecoder.decodeObject(forKey: "deviceSecure") as? Bool ?? false
		deviceTimeZone = aDecoder.decodeObject(forKey: "deviceTimeZone") as? String
		geoEnabled = aDecoder.decodeObject(forKey: "geoEnabled") as? Bool ?? false
		language = aDecoder.decodeObject(forKey: "language") as? String
		notificationsEnabled = aDecoder.decodeObject(forKey: "notificationsEnabled") as? Bool ?? true
		os = aDecoder.decodeObject(forKey: "os") as? String
		osVersion = aDecoder.decodeObject(forKey: "osVersion") as? String
		pushServiceToken = aDecoder.decodeObject(forKey: "pushServiceToken") as? String
		pushServiceType = aDecoder.decodeObject(forKey: "pushServiceType") as? String
		sdkVersion = aDecoder.decodeObject(forKey: "sdkVersion") as? String
	}

	public func encode(with aCoder: NSCoder) {
		aCoder.encode(applicationUserId, forKey: "applicationUserId")
		aCoder.encode(customAttributes, forKey: "customAttributes")
		aCoder.encode(isPrimaryDevice, forKey: "isPrimary")
		aCoder.encode(isPushRegistrationEnabled, forKey: "regEnabled")
		aCoder.encode(pushRegistrationId, forKey: "pushRegId")

		aCoder.encode(appVersion, forKey: "appVersion")
		aCoder.encode(deviceManufacturer, forKey: "deviceManufacturer")
		aCoder.encode(deviceModel, forKey: "deviceModel")
		aCoder.encode(deviceName, forKey: "deviceName")
		aCoder.encode(deviceSecure, forKey: "deviceSecure")
		aCoder.encode(deviceTimeZone, forKey: "deviceTimeZone")
		aCoder.encode(geoEnabled, forKey: "geoEnabled")
		aCoder.encode(language, forKey: "language")
		aCoder.encode(notificationsEnabled, forKey: "notificationsEnabled")
		aCoder.encode(os, forKey: "os")
		aCoder.encode(osVersion, forKey: "osVersion")
		aCoder.encode(pushServiceToken, forKey: "pushServiceToken")
		aCoder.encode(pushServiceType, forKey: "pushServiceType")
		aCoder.encode(sdkVersion, forKey: "sdkVersion")
	}

	convenience init?(json: JSON) {
		guard let pushRegId = json[Attributes.pushRegistrationId.rawValue].string else // a valid server response must contain pushregid
		{
			return nil
		}

		self.init(
			applicationUserId: json[Attributes.applicationUserId.rawValue].string,
			appVersion: json[Consts.SystemDataKeys.appVer].string,
			customAttributes: (json[Attributes.customAttributes.rawValue].dictionary ?? [:]).decodeCustomAttributesJSON,
			deviceManufacturer: json[Consts.SystemDataKeys.deviceManufacturer].string,
			deviceModel: json[Consts.SystemDataKeys.deviceModel].string,
			deviceName: json[Consts.SystemDataKeys.deviceName].string,
			deviceSecure: json[Consts.SystemDataKeys.deviceSecure].bool ?? false,
			deviceTimeZone: json[Consts.SystemDataKeys.deviceTimeZone].string,
			geoEnabled: json[Consts.SystemDataKeys.geofencingServiceEnabled].bool ?? false,
			isPrimaryDevice: json[Attributes.isPrimaryDevice.rawValue].bool ?? false,
			isPushRegistrationEnabled: json[Attributes.registrationEnabled.rawValue].bool ?? true,
			language: json[Consts.SystemDataKeys.language].string,
			notificationsEnabled: json[Consts.SystemDataKeys.notificationsEnabled].bool ?? true,
			os: json[Consts.SystemDataKeys.OS].string,
			osVersion: json[Consts.SystemDataKeys.osVer].string,
			pushRegistrationId: pushRegId,
			pushServiceToken: json[Attributes.pushServiceToken.rawValue].string,
			pushServiceType: json[Consts.SystemDataKeys.pushServiceType].string,
			sdkVersion: json[Consts.SystemDataKeys.sdkVersion].string
			)
	}

	init(applicationUserId: String?,
		 appVersion: String?,
		 customAttributes: [String: AttributeType],
		 deviceManufacturer: String?,
		 deviceModel: String?,
		 deviceName: String?,
		 deviceSecure: Bool,
		 deviceTimeZone: String?,
		 geoEnabled: Bool,
		 isPrimaryDevice: Bool,
		 isPushRegistrationEnabled: Bool,
		 language: String?,
		 notificationsEnabled: Bool,
		 os: String?,
		 osVersion: String?,
		 pushRegistrationId: String?,
		 pushServiceToken: String?,
		 pushServiceType: String?,
		 sdkVersion: String?)
	{
		self.applicationUserId = applicationUserId
		self.appVersion = appVersion
		self.customAttributes = customAttributes
		self.deviceManufacturer = deviceManufacturer
		self.deviceModel = deviceModel
		self.deviceName = deviceName
		self.deviceSecure = deviceSecure
		self.deviceTimeZone = deviceTimeZone
		self.geoEnabled = geoEnabled
		self.isPrimaryDevice = isPrimaryDevice
		self.isPushRegistrationEnabled = isPushRegistrationEnabled
		self.language = language
		self.notificationsEnabled = notificationsEnabled
		self.os = os
		self.osVersion = osVersion
		self.pushRegistrationId = pushRegistrationId
		self.pushServiceToken = pushServiceToken?.lowercased()
		self.pushServiceType = pushServiceType
		self.sdkVersion = sdkVersion
	}

	public override func isEqual(_ object: Any?) -> Bool {
		guard let object = object as? Installation else {
			return false
		}

		return self.applicationUserId == object.applicationUserId &&
			self.appVersion == object.appVersion &&
			self.customAttributes == object.customAttributes &&
			self.deviceManufacturer == object.deviceManufacturer &&
			self.deviceModel == object.deviceModel &&
			self.deviceName == object.deviceName &&
			self.deviceSecure == object.deviceSecure &&
			self.deviceTimeZone == object.deviceTimeZone &&
			self.geoEnabled == object.geoEnabled &&
			self.isPrimaryDevice == object.isPrimaryDevice &&
			self.isPushRegistrationEnabled == object.isPushRegistrationEnabled &&
			self.language == object.language &&
			self.notificationsEnabled == object.notificationsEnabled &&
			self.os == object.os &&
			self.osVersion == object.osVersion &&
			self.pushRegistrationId == object.pushRegistrationId &&
			self.pushServiceToken == object.pushServiceToken &&
			self.pushServiceType == object.pushServiceType &&
			self.sdkVersion == object.sdkVersion
	}

	// must be extracted to cordova plugin srcs
	public convenience init?(dictRepresentation dict: DictionaryRepresentation) {
		self.init(
			applicationUserId: dict["applicationUserId"] as? String,
			appVersion: dict["appVersion"] as? String,
			customAttributes: (dict["customAttributes"] as? [String: AttributeType]) ?? [:],
			deviceManufacturer: dict["deviceManufacturer"] as? String,
			deviceModel: dict["deviceModel"] as? String,
			deviceName: dict["deviceName"] as? String,
			deviceSecure: dict["deviceSecure"] as? Bool ?? false,
			deviceTimeZone: dict["deviceTimezoneOffset"] as? String,
			geoEnabled: dict["geoEnabled"] as? Bool ?? false,
			isPrimaryDevice: dict["isPrimaryDevice"] as? Bool ?? false,
			isPushRegistrationEnabled: dict["isPushRegistrationEnabled"] as? Bool ?? true,
			language: dict["language"] as? String,
			notificationsEnabled: dict["notificationsEnabled"] as? Bool ?? true,
			os: dict["os"] as? String,
			osVersion: dict["osVersion"] as? String,
			pushRegistrationId: dict["pushRegistrationId"] as? String,
			pushServiceToken: dict["pushServiceToken"] as? String,
			pushServiceType: dict["pushServiceType"] as? String,
			sdkVersion: dict["sdkVersion"] as? String
		)
	}

	// must be extracted to cordova plugin srcs
	public var dictionaryRepresentation: DictionaryRepresentation {
		var dict = DictionaryRepresentation()
		dict["applicationUserId"] = applicationUserId
		dict["appVersion"] = appVersion
		dict["customAttributes"] = UserDataMapper.makeCustomAttributesPayload(customAttributes)
		dict["deviceManufacturer"] = deviceManufacturer
		dict["deviceModel"] = deviceModel
		dict["deviceName"] = deviceName
		dict["deviceSecure"] = deviceSecure
		dict["deviceTimezoneOffset"] = deviceTimeZone
		dict["geoEnabled"] = geoEnabled
		dict["isPrimaryDevice"] = isPrimaryDevice
		dict["isPushRegistrationEnabled"] = isPushRegistrationEnabled
		dict["language"] = language
		dict["notificationsEnabled"] = notificationsEnabled
		dict["os"] = os
		dict["osVersion"] = osVersion
		dict["pushRegistrationId"] = pushRegistrationId
		dict["pushServiceToken"] = pushServiceToken
		dict["pushServiceType"] = pushServiceType
		dict["sdkVersion"] = sdkVersion
		return dict
	}

	public func copy(with zone: NSZone? = nil) -> Any {
		let copy = Installation(applicationUserId: applicationUserId, appVersion: appVersion, customAttributes: customAttributes, deviceManufacturer: deviceManufacturer, deviceModel: deviceModel, deviceName: deviceName, deviceSecure: deviceSecure, deviceTimeZone: deviceTimeZone, geoEnabled: geoEnabled, isPrimaryDevice: isPrimaryDevice, isPushRegistrationEnabled: isPushRegistrationEnabled, language: language, notificationsEnabled: notificationsEnabled, os: os, osVersion: osVersion, pushRegistrationId: pushRegistrationId, pushServiceToken: pushServiceToken, pushServiceType: pushServiceType, sdkVersion: sdkVersion)
		return copy
	}
}
