//
//  LogoutOperation.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 03/04/2018.
//

import CoreData

class DepersonalizeOperation: Operation {
	let mmContext: MobileMessaging
	let finishBlock: ((SuccessPending, NSError?) -> Void)?
	let pushRegistrationId: String?
	let applicationCode: String
	
	init(mmContext: MobileMessaging, finishBlock: ((SuccessPending, NSError?) -> Void)? = nil) {
		self.finishBlock = finishBlock
		self.mmContext = mmContext
		self.pushRegistrationId = mmContext.resolveInstallation().pushRegistrationId
		self.applicationCode = mmContext.applicationCode
		super.init()
	}
	
	override func execute() {
		MMLogDebug("[Depersonalize] starting...")
		DepersonalizeOperation.depersonalizeSubservices(mmContext: mmContext)
		self.sendRequest()
	}
	
	private func sendRequest() {
		guard !isCancelled else {
			finish()
			return
		}
		if let pushRegistrationId = pushRegistrationId {
			MMLogDebug("[Depersonalize] performing request...")
			mmContext.remoteApiProvider.depersonalize(applicationCode: self.applicationCode, pushRegistrationId: pushRegistrationId, pushRegistrationIdToDepersonalize: pushRegistrationId, completion: { result in
				self.handleResult(result)
				self.finishWithError(result.error)
			})
		} else {
			finishWithError(NSError(type: .NoRegistration))
		}
	}
	
	private func handleResult(_ result: DepersonalizeResult) {
		switch result {
		case .Success:
			MMLogDebug("[Depersonalize] request secceeded")
			DepersonalizeOperation.handleSuccessfulDepersonalize(mmContext: self.mmContext)
		case .Failure(let error):
			MMLogError("[Depersonalize] request failed with error: \(error.orNil)")
			DepersonalizeOperation.handleFailedDepersonalize(mmContext: self.mmContext)
		case .Cancel:
			MMLogWarn("[Depersonalize] request cancelled.")
		}
	}

	class func handleSuccessfulDepersonalize(mmContext: MobileMessaging) {
		switch mmContext.internalData().currentDepersonalizationStatus {
		case .pending:
			MMLogDebug("[Depersonalize] current depersonalize status: pending")

			let id = mmContext.internalData()
			id.currentDepersonalizationStatus = .success
			id.archiveCurrent()

			mmContext.apnsRegistrationManager.registerForRemoteNotifications()
			
			UserEventsManager.postDepersonalizedEvent()

		case .success, .undefined:
			MMLogDebug("[Depersonalize] current depersonalize status: undefined/succesful")
		}
	}

	class func handleFailedDepersonalize(mmContext: MobileMessaging) {

		let id = mmContext.internalData()
		id.depersonalizeFailCounter = id.depersonalizeFailCounter + 1

		switch id.currentDepersonalizationStatus {
		case .pending:
			MMLogDebug("[Depersonalize] current depersonalize status: pending")
			if id.depersonalizeFailCounter >= DepersonalizationConsts.failuresNumberLimit {

				id.currentDepersonalizationStatus = .undefined
				id.archiveCurrent()

				mmContext.apnsRegistrationManager.registerForRemoteNotifications()
			}

		case .success, .undefined:
			MMLogDebug("[Depersonalize] current depersonalize status: undefined/successful")

			id.currentDepersonalizationStatus = .pending
			id.archiveCurrent()

			mmContext.apnsRegistrationManager.unregister()
		}
	}

	class func depersonalizeSubservices(mmContext: MobileMessaging) {
		switch mmContext.internalData().currentDepersonalizationStatus {
		case .pending: break
		case .success, .undefined:
			let loopGroup = DispatchGroup()
			MMLogDebug("[Depersonalize] depersonalizing subservices...")
			mmContext.subservices.values.forEach { subservice in
				loopGroup.enter()
				subservice.depersonalizeService(mmContext, completion: {
					loopGroup.leave()
				})
			}

			_ = loopGroup.wait(timeout: DispatchTime.now() + .seconds(10))
		}
	}
	
	override func finished(_ errors: [NSError]) {
		MMLogDebug("[Depersonalize] finished with errors: \(errors)")
		finishBlock?(mmContext.internalData().currentDepersonalizationStatus, errors.first)
	}
}
