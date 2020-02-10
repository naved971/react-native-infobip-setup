//
//  MMUtils.swift
//  MobileMessaging
//
//  Created by Andrey K. on 17/02/16.
//
//

import Foundation
import CoreData
import CoreLocation
import SystemConfiguration
import UserNotifications

public typealias DictionaryRepresentation = [String: Any]

func deltaDict(_ current: [String: Any], _ dirty: [String: Any]) -> [String: Any] {
	var ret:[String: Any] = [:]
	dirty.keys.forEach { (k) in
		let currentV = current[k] as Any
		let dirtyV = dirty[k] as Any
		if case Optional<Any>.none = dirtyV {
			if case Optional<Any>.none = currentV {
			} else {
				ret[k] = NSNull()
			}
		} else {
			if (currentV is [String : Any] && dirtyV is [String : Any]) {
				let currentDict = currentV as! [String : Any]
				let dirtyDict = dirtyV as! [String : Any]
				if currentDict.isEmpty && dirtyDict.isEmpty {
					ret[k] = nil
				} else {
					ret[k] = deltaDict(currentDict, dirtyDict)
				}
			} else {
				if currentV is AnyHashable && dirtyV is AnyHashable {
					if (currentV as! AnyHashable) != (dirtyV as! AnyHashable){
						ret[k] = dirtyV
					}
				} else {
					if case Optional<Any>.none = currentV {
						ret[k] = dirtyV
					} else {
						ret[k] = NSNull()
					}
				}
			}
		}
	}
	return ret
}

extension Dictionary where Key: ExpressibleByStringLiteral, Value: Any {
	var noNulls: [Key: Value] {
		return self.filter {
			let val = $0.1 as Any
			if case Optional<Any>.none = val {
				return false
			} else {
				return true
			}
		}
	}
}

extension MobileMessaging {
	class var currentInstallation: Installation? {
		return MobileMessaging.getInstallation()
	}
	class var currentUser: User? {
		return MobileMessaging.getUser()
	}
}

func contactsServiceDateEqual(_ l: Date?, _ r: Date?) -> Bool {
	switch (l, r) {
	case (.none, .none):
		return true
	case (.some, .none):
		return false
	case (.none, .some):
		return false
	case (.some(let left), .some(let right)):
		return DateStaticFormatters.ContactsServiceDateFormatter.string(from: left) == DateStaticFormatters.ContactsServiceDateFormatter.string(from: right)
	}
}

struct DateStaticFormatters {
	/**
	Desired format is GMT+03:00 and a special case for Greenwich Mean Time: GMT+00:00
	*/
	static var CurrentJavaCompatibleTimeZoneOffset: String {
		var gmt = DateStaticFormatters.TimeZoneOffsetFormatter.string(from: MobileMessaging.date.now)
		if gmt == "GMT" {
			gmt = gmt + "+00:00"
		}
		return gmt
	}
	/**
	Desired format is GMT+03:00, not GMT+3
	*/
	static var TimeZoneOffsetFormatter: DateFormatter = {
		let dateFormatter = DateFormatter()
		dateFormatter.locale = Locale(identifier: "en_US_POSIX")
		dateFormatter.dateFormat = "ZZZZ"
		dateFormatter.timeZone = MobileMessaging.timeZone
		return dateFormatter
	}()
	static var LoggerDateFormatter: DateFormatter = {
		let dateFormatter = DateFormatter()
		dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss:SSS"
		return dateFormatter
	}()
	static var ContactsServiceDateFormatter: DateFormatter = {
		let result = DateFormatter()
		result.locale = Locale(identifier: "en_US_POSIX")
		result.dateFormat = "yyyy-MM-dd"
		result.timeZone = TimeZone(secondsFromGMT: 0)
		return result
	}()
	static var ISO8601SecondsFormatter: DateFormatter = {
		let result = DateFormatter()
		result.locale = Locale(identifier: "en_US_POSIX")
		result.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
		result.timeZone = TimeZone(secondsFromGMT: 0)
		return result
	}()
	static var CoreDataDateFormatter: DateFormatter = {
		let result = DateFormatter()
		result.locale = Locale(identifier: "en_US_POSIX")
		result.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
		return result
	}()
	static var timeFormatter: DateFormatter = {
		let result = DateFormatter()
		result.dateStyle = DateFormatter.Style.none
		result.timeStyle = DateFormatter.Style.short
		return result
	}()
}

extension Dictionary where Key: ExpressibleByStringLiteral, Value: Hashable {
	var valuesStableHash: Int {
		return self.sorted { (kv1, kv2) -> Bool in
			if let key1 = kv1.key as? String, let key2 = kv2.key as? String {
				return key1.compare(key2) == .orderedAscending
			} else {
				return false
			}
		}.reduce("", {"\($0),\($1.1)"}).stableHash
	}
}

extension String {
	var stableHash: Int {
		let unicodeScalars = self.unicodeScalars.map { $0.value }
		return unicodeScalars.reduce(5381) {
			($0 << 5) &+ $0 &+ Int($1)
		}
	}
}

extension Dictionary where Key: ExpressibleByStringLiteral, Value: Any {
	var nilIfEmpty: [Key: Value]? {
		return self.isEmpty ? nil : self
	}
}

extension Data {
	var mm_toHexString: String {
		return reduce("") {$0 + String(format: "%02x", $1)}
	}
}

extension String {
	var safeUrl: URL? {
		return URL(string: self)
	}
	
	func mm_matches(toRegexPattern: String, options: NSRegularExpression.Options = []) -> Bool {
		if let regex = try? NSRegularExpression(pattern: toRegexPattern, options: options), let _ = regex.firstMatch(in: self, options: NSRegularExpression.MatchingOptions.withoutAnchoringBounds, range: NSRange(0..<self.count)) {
			return true
		} else {
			return false
		}
	}
	
	var mm_isSdkGeneratedMessageId: Bool {
		return mm_isUUID
	}
	
	var mm_isUUID: Bool {
		return mm_matches(toRegexPattern: Consts.UUIDRegexPattern, options: .caseInsensitive)
	}
	
	func mm_breakWithMaxLength(maxLenght: Int) -> String {
		var result: String = self
		let currentLen = self.count
		let doPutDots = maxLenght > 3
		if currentLen > maxLenght {
			if let index = self.index(self.startIndex, offsetBy: maxLenght - (doPutDots ? 3 : 0), limitedBy: self.endIndex) {
				result = self[..<index] + (doPutDots ? "..." : "")
			}
		}
		return result
	}
	
	var mm_toHexademicalString: String? {
		if let data: Data = self.data(using: String.Encoding.utf16) {
			return data.mm_toHexString
		} else {
			return nil
		}
	}
	
	var mm_fromHexademicalString: String? {
		if let data = self.mm_dataFromHexadecimalString {
			return String.init(data: data, encoding: String.Encoding.utf16)
		} else {
			return nil
		}
	}
	
	var mm_dataFromHexadecimalString: Data? {
		let trimmedString = self.trimmingCharacters(in: CharacterSet.init(charactersIn:"<> ")).replacingOccurrences(of: " ", with: "")
		
		// make sure the cleaned up string consists solely of hex digits, and that we have even number of them
		
		let regex = try! NSRegularExpression(pattern: "^[0-9a-f]*$", options: .caseInsensitive)
		
		let found = regex.firstMatch(in: trimmedString, options: [], range: NSMakeRange(0, trimmedString.count))
		if found == nil || found?.range.location == NSNotFound || trimmedString.count % 2 != 0 {
			return nil
		}
		
		// everything ok, so now let's build NSData
		var data = Data()
		
		var index = trimmedString.startIndex
		
		while index < trimmedString.endIndex {
			let range:Range<Index> = index..<trimmedString.index(index, offsetBy: 2)
			let byteString = trimmedString[range]
			let num = UInt8(byteString.withCString { strtoul($0, nil, 16) })
			data.append([num] as [UInt8], count: 1)
			index = trimmedString.index(index, offsetBy: 2)
		}
		
		return data
	}
	
	var mm_urlSafeString: String {
		let raw: String = self
		var urlFragmentAllowed = CharacterSet.urlFragmentAllowed
		urlFragmentAllowed.remove(charactersIn: "!*'();:@&=+$,/?%#[]")
		var result = String()
		if let str = raw.addingPercentEncoding(withAllowedCharacters: urlFragmentAllowed) {
			result = str
		}
		return result
	}
}

func += <Key, Value> (left: inout Dictionary<Key, Value>, right: Dictionary<Key, Value>?) {
	guard let right = right else {
		return
	}
	for (k, v) in right {
		left.updateValue(v, forKey: k)
	}
}

func + <Key, Value> (l: Dictionary<Key, Value>?, r: Dictionary<Key, Value>?) -> Dictionary<Key, Value>? {
	
	switch (l, r) {
	case (.none, .none):
		return nil
	case (.some(let left), .none):
		return left
	case (.none, .some(let right)):
		return right
	case (.some(let left), .some(let right)):
		var lMutable = left
		for (k, v) in right {
			lMutable[k] = v
		}
		return lMutable
	}
}

func + <Key, Value> (l: Dictionary<Key, Value>?, r: Dictionary<Key, Value>) -> Dictionary<Key, Value> {
	switch (l, r) {
	case (.none, _):
		return r
	case (.some(let left), _):
		var lMutable = left
		for (k, v) in r {
			lMutable[k] = v
		}
		return lMutable
	}
}

func + <Key, Value> (l: Dictionary<Key, Value>, r: Dictionary<Key, Value>) -> Dictionary<Key, Value> {
	var lMutable = l
	for (k, v) in r {
		lMutable[k] = v
	}
	return lMutable
}


func + <Element: Any>(l: Set<Element>?, r: Set<Element>?) -> Set<Element>? {
	switch (l, r) {
	case (.none, .none):
		return nil
	case (.some(let left), .none):
		return left
	case (.none, .some(let right)):
		return right
	case (.some(let left), .some(let right)):
		return left.union(right)
	}
}

func + <Element: Any>(l: [Element]?, r: [Element]?) -> [Element] {
	switch (l, r) {
	case (.none, .none):
		return [Element]()
	case (.some(let left), .none):
		return left
	case (.none, .some(let right)):
		return right
	case (.some(let left), .some(let right)):
		return left + right
	}
}

func ==(lhs : [AnyHashable : AttributeType], rhs: [AnyHashable : AttributeType]) -> Bool {
	return NSDictionary(dictionary: lhs).isEqual(to: rhs)
}

func ==(l : [String : AttributeType]?, r: [String : AttributeType]?) -> Bool {
	switch (l, r) {
	case (.none, .none):
		return true
	case (.some, .none):
		return false
	case (.none, .some):
		return false
	case (.some(let left), .some(let right)):
		return NSDictionary(dictionary: left).isEqual(to: right)
	}
}

func !=(lhs : [AnyHashable : AttributeType], rhs: [AnyHashable : AttributeType]) -> Bool {
	return !NSDictionary(dictionary: lhs).isEqual(to: rhs)
}

func isIOS9() -> Bool {
	if #available(iOS 9.0, *) {
		return true
	} else {
		return false
	}
}

protocol DictionaryRepresentable {
	init?(dictRepresentation dict: DictionaryRepresentation)
	var dictionaryRepresentation: DictionaryRepresentation {get}
}

extension Date {
	var timestampDelta: UInt {
		return UInt(max(0, MobileMessaging.date.now.timeIntervalSinceReferenceDate - self.timeIntervalSinceReferenceDate))
	}
}

var isTestingProcessRunning: Bool {
	return ProcessInfo.processInfo.arguments.contains("-IsStartedToRunTests")
}

extension Optional where Wrapped: Any {
	func ifSome<T>(_ block: (Wrapped) -> T?) -> T? {
		switch self {
		case .none:
			return nil
		case .some(let wr):
			return block(wr)
		}
	}
}

public class MobileMessagingService: NSObject {
	let mmContext: MobileMessaging
	let uniqueIdentifier: String
	var isRunning: Bool
	init(mmContext: MobileMessaging, id: String) {
		self.isRunning = false
		self.mmContext = mmContext
		self.uniqueIdentifier = id
		super.init()
		self.mmContext.registerSubservice(self)
	}
	func start(_ completion: @escaping (Bool) -> Void) {
		MMLogDebug("[\(uniqueIdentifier)] starting")
		isRunning = true
		completion(isRunning)
	}
	func stop(_ completion: @escaping (Bool) -> Void) {
		MMLogDebug("[\(uniqueIdentifier)] stopping")
		isRunning = false
		completion(isRunning)
	}
	func syncWithServer(_ completion: @escaping (NSError?) -> Void) { completion(nil) }
	
	/// A system data that is related to a particular subservice. For example for Geofencing service it is a key-value pair "geofencing: <bool>" that indicates whether the service is enabled or not
	var systemData: [String: AnyHashable]? { return nil }

	/// Called by message handling operation in order to fill the MessageManagedObject data by MobileMessaging subservices. Subservice must be in charge of fulfilling the message data to be stored on disk. You return `true` if message was changed by the method.
	func populateNewPersistedMessage(_ message: inout MessageManagedObject, originalMessage: MTMessage) -> Bool { return false }
	func handleNewMessage(_ message: MTMessage, completion: @escaping (MessageHandlingResult) -> Void) { completion(.noData) }
	func handleAnyMessage(_ message: MTMessage, completion: @escaping (MessageHandlingResult) -> Void) { completion(.noData) }
	func mobileMessagingWillStart(_ mmContext: MobileMessaging) {}
	func mobileMessagingDidStart(_ mmContext: MobileMessaging) {}
	func mobileMessagingWillStop(_ mmContext: MobileMessaging) {}
	func mobileMessagingDidStop(_ mmContext: MobileMessaging) {}
	func pushRegistrationStatusDidChange(_ mmContext: MobileMessaging) {}
	func depersonalizationStatusDidChange(_ mmContext: MobileMessaging) {}
	func depersonalizeService(_ mmContext: MobileMessaging, completion: @escaping () -> Void) {
		completion()
	}
}

public extension UIDevice {
	func SYSTEM_VERSION_LESS_THAN(_ version: String) -> Bool {
		return self.systemVersion.compare(version, options: .numeric) == .orderedAscending
	}
	
	@objc var IS_IOS_BEFORE_10: Bool { return SYSTEM_VERSION_LESS_THAN("10.0") }
}

class MMDate {
	var now: Date {
		return Date()
	}
	
	func timeInterval(sinceNow timeInterval: TimeInterval) -> Date {
		return Date(timeIntervalSinceNow: timeInterval)
	}
	
	func timeInterval(since1970 timeInterval: TimeInterval) -> Date {
		return Date(timeIntervalSince1970: timeInterval)
	}
	
	func timeInterval(sinceReferenceDate timeInterval: TimeInterval) -> Date {
		return Date(timeIntervalSinceReferenceDate: timeInterval)
	}
	
	func timeInterval(_ timeInterval: TimeInterval, since date: Date) -> Date {
		return Date(timeInterval: timeInterval, since: date)
	}
}

protocol UserNotificationCenterStorage {
	func getDeliveredMessages(completionHandler: @escaping ([MTMessage]) -> Swift.Void)
}

class DefaultUserNotificationCenterStorage : UserNotificationCenterStorage {
	func getDeliveredMessages(completionHandler: @escaping ([MTMessage]) -> Swift.Void) {
		if #available(iOS 10.0, *) {
			UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
				let messages = notifications
					.compactMap({
						MTMessage(payload: $0.request.content.userInfo,
								  deliveryMethod: .local,
								  seenDate: nil,
								  deliveryReportDate: nil,
								  seenStatus: .NotSeen,
								  isDeliveryReportSent: false)
					})
				completionHandler(messages)
			}
		} else {
			return completionHandler([])
		}
	}
}

protocol MMApplication {
	var applicationIconBadgeNumber: Int { get set }
	var applicationState: UIApplication.State { get }
	var isRegisteredForRemoteNotifications: Bool { get }
	func unregisterForRemoteNotifications()
	func registerForRemoteNotifications()
	func presentLocalNotificationNow(_ notification: UILocalNotification)
	func registerUserNotificationSettings(_ notificationSettings: UIUserNotificationSettings)
	var currentUserNotificationSettings: UIUserNotificationSettings? { get }
}

extension UIApplication: MMApplication {}

extension MMApplication {
	var isInForegroundState: Bool {
		return applicationState == .active
	}
}

class MainThreadedUIApplication: MMApplication {
	
	init() {
		
	}
	var app: UIApplication = UIApplication.shared
	var applicationIconBadgeNumber: Int {
		get {
			return getFromMain(getter: { app.applicationIconBadgeNumber })
		}
		set {
			inMainWait(block: { app.applicationIconBadgeNumber = newValue })
		}
	}
	
	var applicationState: UIApplication.State {
		return getFromMain(getter: { app.applicationState })
	}
	
	var isRegisteredForRemoteNotifications: Bool {
		return getFromMain(getter: { app.isRegisteredForRemoteNotifications })
	}
	
	func unregisterForRemoteNotifications() {
		inMainWait { app.unregisterForRemoteNotifications() }
	}
	
	func registerForRemoteNotifications() {
		inMainWait { app.registerForRemoteNotifications() }
	}
	
	func presentLocalNotificationNow(_ notification: UILocalNotification) {
		inMainWait { app.presentLocalNotificationNow(notification) }
	}
	
	func registerUserNotificationSettings(_ notificationSettings: UIUserNotificationSettings) {
		inMainWait { app.registerUserNotificationSettings(notificationSettings) }
	}
	
	var currentUserNotificationSettings: UIUserNotificationSettings? {
		return getFromMain(getter: { app.currentUserNotificationSettings })
	}
}

func getDocumentsDirectory(filename: String) -> String {
	let applicationSupportPaths = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)
	let basePath = applicationSupportPaths.first ?? NSTemporaryDirectory()
	return URL(fileURLWithPath: basePath).appendingPathComponent("com.mobile-messaging.\(filename)", isDirectory: false).path
}

func applicationCodeChanged(newApplicationCode: String) -> Bool {
	let currentApplicationCode = InternalData.unarchiveCurrent().applicationCode
	return currentApplicationCode != nil && currentApplicationCode != newApplicationCode
}

extension String {
	static func localizedUserNotificationStringOrFallback(key: String?, args: [String]?, fallback: String?) -> String? {
		let ret: String?
		if let key = key {
			if #available(iOS 10.0, *) {
				if let args = args {
					ret = NSString.localizedUserNotificationString(forKey: key, arguments: args)
				} else {
					ret = NSLocalizedString(key, comment: "") as String
				}
			} else {
				let localizedString = NSLocalizedString(key, comment: "")
				if let args = args {
					ret = String(format: localizedString as String, arguments: args)
				} else {
					ret = localizedString as String
				}
			}
		} else {
			ret = fallback
		}
		return ret
	}
}

enum MessageStorageKind: String {
	case messages = "messages", chat = "chat"
}

extension Dictionary where Key == String {
	var isChatMessage: Bool {
		return (self[Consts.CustomPayloadKeys.isChat] as? Bool) ?? false
	}
}

extension UIImage {
	convenience init?(mm_named: String) {
		if let url = MobileMessaging.bundle.url(forResource: "MobileMessaging", withExtension: "bundle") {
			let bundle = Bundle(url: url)
			self.init(named: mm_named, in: bundle, compatibleWith: nil)
		} else {
			return nil
		}
	}
}

let isDebug: Bool = {
	var isDebug = false
	// function with a side effect and Bool return value that we can pass into assert()
	func set(debug: Bool) -> Bool {
		isDebug = debug
		return isDebug
	}
	// assert:
	// "Condition is only evaluated in playgrounds and -Onone builds."
	// so isDebug is never changed to false in Release builds
	assert(set(debug: true))
	return isDebug
}()

protocol SingleKVStorage {
	associatedtype ValueType
	var backingStorage: KVOperations {set get}
	var key: String {get}
	func get() -> ValueType?
	func cleanUp()
	func set(_ value: ValueType)
}

extension SingleKVStorage {
	func get() -> ValueType? {
		return backingStorage.get(key: key) as? ValueType
	}
	
	func cleanUp() {
		backingStorage.cleanUp(forKey: key)
	}
	
	func set(_ value: ValueType) {
		backingStorage.set(value: value, key: key)
	}
}

protocol KVOperations {
	func get(key: String) -> Any?
	func cleanUp(forKey: String)
	func set(value: Any, key: String)
}

extension UserDefaults: KVOperations {
	func cleanUp(forKey key: String) {
		removeObject(forKey: key)
		synchronize()
	}
	
	func get(key: String) -> Any? {
		return object(forKey: key)
	}
	
	func set(value: Any, key: String) {
		set(value, forKey: key)
	}
}

func calculateAppCodeHash(_ appCode: String) -> String { return String(appCode.sha1().prefix(10)) }

extension Sequence {
	func forEachAsync(_ work: @escaping (Self.Iterator.Element, @escaping () -> Void) -> Void, completion: @escaping () -> Void) {
		let loopGroup = DispatchGroup()
		self.forEach { (el) in
			loopGroup.enter()
			work(el, {
				loopGroup.leave()
			})
		}
		
		loopGroup.notify(queue: DispatchQueue.global(qos: .default), execute: {
			completion()
		})
	}
}

extension UIColor {
	class func enabledCellColor() -> UIColor {
		return UIColor.white
	}
	class func disabledCellColor() -> UIColor {
		return UIColor.TABLEVIEW_GRAY().lighter(2)
	}
	
	func darker(_ percents: CGFloat) -> UIColor {
		let color = UIColor.purple
		var r:CGFloat = 0, g:CGFloat = 0, b:CGFloat = 0, a:CGFloat = 0
		self.getRed(&r, green: &g, blue: &b, alpha: &a)
		func reduce(_ value: CGFloat) -> CGFloat {
			let result: CGFloat = max(0, value - value * (percents/100.0))
			return result
		}
		return UIColor(red: reduce(r) , green: reduce(g), blue: reduce(b), alpha: a)
	}
	
	func lighter(_ percents: CGFloat) -> UIColor {
		let color = UIColor.purple
		var r:CGFloat = 0, g:CGFloat = 0, b:CGFloat = 0, a:CGFloat = 0
		self.getRed(&r, green: &g, blue: &b, alpha: &a)
		func reduce(_ value: CGFloat) -> CGFloat {
			let result: CGFloat = min(1, value + value * (percents/100.0))
			return result
		}
		return UIColor(red: reduce(r) , green: reduce(g), blue: reduce(b), alpha: a)
	}
	class func colorMod255(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> UIColor {
		return UIColor(red: r/255.0, green: g/255.0, blue: b/255.0, alpha: a)
	}
	class func TEXT_BLACK() -> UIColor {
		return UIColor.colorMod255(65, 65, 65)
	}
	class func TEXT_GRAY() -> UIColor {
		return UIColor.colorMod255(165, 165, 165)
	}
	class func TABBAR_TITLE_BLACK() -> UIColor {
		return UIColor.colorMod255(90, 90, 90)
	}
	class func ACTIVE_TINT() -> UIColor {
		return UIColor.MAIN()
	}
	class func TABLEVIEW_GRAY() -> UIColor {
		return UIColor.colorMod255(239, 239, 244)
	}
	class func MAIN() -> UIColor {
		#if IO
		return UIColor.colorMod255(234, 55, 203)
		#else
		return UIColor.colorMod255(239, 135, 51)
		#endif
	}
	class func MAIN_MED_DARK() -> UIColor {
		return UIColor.MAIN().darker(25)
	}
	class func MAIN_DARK() -> UIColor {
		return UIColor.MAIN().darker(50)
	}
	class func CHAT_MESSAGE_COLOR(_ isYours: Bool) -> UIColor {
		if (isYours == true) {
			return UIColor.colorMod255(253, 242, 229)
		} else {
			return UIColor.white
		}
	}
	class func CHAT_MESSAGE_FONT_COLOR(_ isYours: Bool) -> UIColor {
		if (isYours == true) {
			return UIColor.colorMod255(73, 158, 90)
		} else {
			return UIColor.darkGray
		}
	}
	class func TABLE_SEPARATOR_COLOR() -> UIColor {
		return UIColor.colorMod255(210, 209, 213)
	}
	class func GREEN() -> UIColor {
		return UIColor.colorMod255(127, 211, 33)
	}
	class func RED() -> UIColor {
		return UIColor.colorMod255(243, 27, 0)
	}
}

extension Optional {
	var orNil : String {
		if self == nil {
			return "nil"
		}
		if "\(Wrapped.self)" == "String" {
			return "\"\(self!)\""
		}
		return "\(self!)"
	}
}

extension URL {
	static func attachmentDownloadDestinationFolderUrl(appGroupId: String?) -> URL {
		let fileManager = FileManager.default
		let tempFolderUrl: URL
		if let appGroupId = appGroupId, let appGroupContainerUrl = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) {
			tempFolderUrl = appGroupContainerUrl.appendingPathComponent("Library/Caches")
		} else {
			tempFolderUrl = URL.init(fileURLWithPath: NSTemporaryDirectory())
		}

		var destinationFolderURL = tempFolderUrl.appendingPathComponent("com.mobile-messaging.rich-notifications-attachments", isDirectory: true)

		var isDir: ObjCBool = true
		if !fileManager.fileExists(atPath: destinationFolderURL.path, isDirectory: &isDir) {
			do {
				try fileManager.createDirectory(at: destinationFolderURL, withIntermediateDirectories: true, attributes: nil)
			} catch _ {
				destinationFolderURL = tempFolderUrl
			}
		}
		return destinationFolderURL
	}

	static func attachmentDownloadDestinatioUrl(sourceUrl: URL, appGroupId: String?) -> URL {
		return URL.attachmentDownloadDestinationFolderUrl(appGroupId:appGroupId).appendingPathComponent(sourceUrl.absoluteString.sha1() + "." + sourceUrl.pathExtension)
	}
}

extension Bundle {
	static var mainAppBundle: Bundle {
		var bundle = Bundle.main
		if bundle.bundleURL.pathExtension == "appex" {
			// Peel off two directory levels - MY_APP.app/PlugIns/MY_APP_EXTENSION.appex
			let url = bundle.bundleURL.deletingLastPathComponent().deletingLastPathComponent()
			if let otherBundle = Bundle(url: url) {
				bundle = otherBundle
			}
		}
		return bundle
	}
	var appGroupId: String? {
		return self.object(forInfoDictionaryKey: "com.mobilemessaging.app_group") as? String
	}
}

extension Array where Element: Hashable {
	var asSet: Set<Element> {
		return Set(self)
	}
}

extension Set {
	var asArray: Array<Element> {
		return Array(self)
	}
}

class ThreadSafeDict<T> {
	private var dict: [String: T] = [:]
	private var queue: DispatchQueue = DispatchQueue.init(label: "", qos: .default, attributes: DispatchQueue.Attributes.concurrent)
	func set(value: T?, forKey key: String) {
		queue.async(group: nil, qos: .default, flags: .barrier) {
			self.dict[key] = value
		}
	}

	func getValue(forKey key: String) -> T? {
		var ret: T?
		queue.sync {
			ret = dict[key]
		}
		return ret
	}
}
