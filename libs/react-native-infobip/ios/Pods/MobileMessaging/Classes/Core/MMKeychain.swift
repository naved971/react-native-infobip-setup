//
//  MMKeychain.swift
//
//  Created by okoroleva on 13.01.17.
//
//

class MMKeychain: KeychainSwift {
	var pushRegId: String? {
		get {
			let internalId = get(Consts.KeychainKeys.pushRegId)
			MMLogDebug("[Keychain] get internalId \(internalId.orNil)")
			return internalId
		}
		set {
			if let unwrappedValue = newValue {
				MMLogDebug("[Keychain] set internalId \(unwrappedValue)")
				set(unwrappedValue, forKey: Consts.KeychainKeys.pushRegId, withAccess: .accessibleWhenUnlockedThisDeviceOnly)
			}
		}
	}
	
	override init() {
		let prefix = Consts.KeychainKeys.prefix + "/" + (Bundle.main.bundleIdentifier ?? "")
		super.init(keyPrefix: prefix)
	}
	
	//MARK: private
	
	@discardableResult
	override func clear() -> Bool {
		MMLogDebug("[Keychain] clearing")
		let cleared = delete(Consts.KeychainKeys.pushRegId)
		if !cleared {
			MMLogError("[Keychain] clearing failure \(lastResultCode)")
		}
		return cleared
	}
}
