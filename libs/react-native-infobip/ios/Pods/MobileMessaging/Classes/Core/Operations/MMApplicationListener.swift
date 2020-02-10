//
//  MMApplicationListener.swift
//  MobileMessaging
//
//  Created by Andrey K. on 24/02/16.
//  
//

import Foundation

final class MMApplicationListener: NSObject {
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
	init(mmContext: MobileMessaging) {
		self.mmContext = mmContext
        super.init()

		if !ProcessInfo.processInfo.arguments.contains("-IsStartedToRunTests") {
		NotificationCenter.default.addObserver(self, selector: #selector(MMApplicationListener.handleAppWillEnterForegroundNotification), name: UIApplication.willEnterForegroundNotification, object: nil)
		
		NotificationCenter.default.addObserver(self, selector: #selector(MMApplicationListener.handleAppDidFinishLaunchingNotification(n:)), name: UIApplication.didFinishLaunchingNotification, object: nil)
		
		NotificationCenter.default.addObserver(self, selector: #selector(MMApplicationListener.handleGeoServiceDidStartNotification), name: NSNotification.Name(rawValue: MMNotificationGeoServiceDidStart), object: nil)
		}
    }
	
	//MARK: Internal
	@objc func handleAppWillEnterForegroundNotification() {
		performPeriodicWork()
	}
	
	@objc func handleAppDidFinishLaunchingNotification(n: Notification) {
		guard n.userInfo?[UIApplication.LaunchOptionsKey.remoteNotification] == nil else {
			// we don't want to perfrom sync on launching when push received.
			return
		}
		performPeriodicWork()
	}
	
	@objc func handleGeoServiceDidStartNotification() {
		mmContext?.installationService?.syncSystemDataWithServer() { _ in }
	}
	
	//MARK: Private
	weak private var mmContext: MobileMessaging?

	private func performPeriodicWork() {
		guard let mm = mmContext else {
			return
		}
		mm.sync()
		if mm.internalData().currentDepersonalizationStatus == .pending {
			mm.installationService.depersonalize(completion: { _, _ in })
		}
	}
}
