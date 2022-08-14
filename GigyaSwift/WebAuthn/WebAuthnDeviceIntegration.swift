//
//  WebAuthnDeviceIntegration.swift
//  Gigya
//
//  Created by Sagi Shmuel on 30/06/2022.
//  Copyright © 2022 Gigya. All rights reserved.
//

import Foundation
import AuthenticationServices

class WebAuthnDeviceIntegration: NSObject {
    @available(iOS 15.0, *)
    typealias WebAuthnIntegrationHandler = (ResponseType) -> Void

    @available(iOS 15.0, *)
    enum ResponseType {
        case register(ASAuthorizationPlatformPublicKeyCredentialRegistration)
        case securityRegister(ASAuthorizationSecurityKeyPublicKeyCredentialRegistration)
        case login(ASAuthorizationPlatformPublicKeyCredentialAssertion)
        case securityLogin(ASAuthorizationSecurityKeyPublicKeyCredentialAssertion)
        case canceled
        case error
    }
    
    var vc: UIViewController?
    
    var data: Data?
    
    var handler: Any = { }
    
    @available(iOS 15.0, *)
    func register(viewController: UIViewController, options: WebAuthnInitRegisterResponseModel, handler: @escaping WebAuthnIntegrationHandler) {
        self.vc = viewController
        self.handler = handler
        
        let publicKeyCredentialProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: options.options.rp.id) // regular

        let securityKeyProvider = ASAuthorizationSecurityKeyPublicKeyCredentialProvider(relyingPartyIdentifier: options.options.rp.id)

        let challenge = options.options.challenge.decodeBase64Url()!

        let userID = options.options.user.id.decodeBase64Url()!

        let securityRequest = securityKeyProvider.createCredentialRegistrationRequest(challenge: challenge, displayName: options.options.user.displayName, name: options.options.user.name, userID: userID)

        // unknown
        securityRequest.credentialParameters = [ ASAuthorizationPublicKeyCredentialParameters(algorithm: ASCOSEAlgorithmIdentifier.ES256) ]

        let assertionRequest = publicKeyCredentialProvider.createCredentialRegistrationRequest(challenge: challenge, name: options.options.user.name, userID: userID)


        if let userVerification = options.options.authenticatorSelection.userVerification {
            securityRequest.userVerificationPreference = ASAuthorizationPublicKeyCredentialUserVerificationPreference.init(rawValue: userVerification)
            assertionRequest.userVerificationPreference = ASAuthorizationPublicKeyCredentialUserVerificationPreference.init(rawValue: userVerification)

        }
        // platform = device, cross-platform = both (device & external)
        var authorizationRequests: [ASAuthorizationRequest] = []
//        let authenticatorAttachment = options.options.authenticatorSelection.authenticatorAttachment ?? .unspecified
        let authenticatorAttachment: WebAuthnAuthenticatorSelectionType = .unspecified

        switch authenticatorAttachment {
        case .platform:
            authorizationRequests.append(assertionRequest)
        case .crossPlatform:
            authorizationRequests.append(securityRequest)
        case .unspecified:
            authorizationRequests.append(assertionRequest)
            authorizationRequests.append(securityRequest)
        }
        
        let authController = ASAuthorizationController(authorizationRequests: authorizationRequests )
        authController.delegate = self
        authController.presentationContextProvider = self
        authController.performRequests()
    }
    
    @available(iOS 15.0, *)
    func login(viewController: UIViewController, options: WebAuthnGetOptionsResponseModel, handler: @escaping WebAuthnIntegrationHandler) {
        self.vc = viewController
        self.handler = handler
        
        let publicKeyCredentialProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: options.options.rpId) // regular

        let securityKeyProvider = ASAuthorizationSecurityKeyPublicKeyCredentialProvider(relyingPartyIdentifier: options.options.rpId)

        let challenge = options.options.challenge.decodeBase64Url()!

        let securityRequest = securityKeyProvider.createCredentialAssertionRequest(challenge: challenge)
        
        let dd = Data(base64Encoded: "Q6A2Zws87xiQjOWDWKx2DgCMN/xGN6lQC5sbbs6YQLJqlWfKY54xZ5VVkGGRJPggJoDGQ1mQ3Z68d1jMOsJwgA==")
        securityRequest.allowedCredentials = [ASAuthorizationSecurityKeyPublicKeyCredentialDescriptor(credentialID: dd!, transports: ASAuthorizationSecurityKeyPublicKeyCredentialDescriptor.Transport.allSupported)]
        
        let assertionRequest = publicKeyCredentialProvider.createCredentialAssertionRequest(challenge: challenge)

        assertionRequest.allowedCredentials = [.init(credentialID: Data(base64Encoded: "Js5zZ/GQmoA8iKZfl7aMrwq0pdk=")!)]
        if let userVerification = options.options.userVerification {
            securityRequest.userVerificationPreference = ASAuthorizationPublicKeyCredentialUserVerificationPreference.init(rawValue: userVerification)
            assertionRequest.userVerificationPreference = ASAuthorizationPublicKeyCredentialUserVerificationPreference.init(rawValue: userVerification)
        }
        
        // platform = device, cross-platform = both (device & external)
        var authorizationRequests: [ASAuthorizationRequest] = []
        let authenticatorAttachment: WebAuthnAuthenticatorSelectionType = .unspecified // options.options.authenticatorSelection.authenticatorAttachment
        switch authenticatorAttachment {
        case .platform:
            authorizationRequests.append(assertionRequest)
        case .crossPlatform:
            authorizationRequests.append(securityRequest)
        case .unspecified:
            authorizationRequests.append(assertionRequest)
            authorizationRequests.append(securityRequest)
        }
        
        let authController = ASAuthorizationController(authorizationRequests: authorizationRequests )
        authController.delegate = self
        authController.presentationContextProvider = self
        authController.performRequests()
    }
    
    
    deinit {
        GigyaLogger.log(with: self, message: "deinit")
    }
}

@available(iOS 15.0, *)
extension WebAuthnDeviceIntegration: ASAuthorizationControllerPresentationContextProviding, ASAuthorizationControllerDelegate {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return vc!.view.window!
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        guard let authorizationError = ASAuthorizationError.Code(rawValue: (error as NSError).code) else {
            print("Unexpected authorization error: \(error.localizedDescription)")
            return
        }

        if authorizationError == .canceled {
            // Either no credentials were found and the request silently ended, or the user canceled the request.
            // Consider asking the user to create an account.
            print("Request canceled.")
            (handler as! WebAuthnIntegrationHandler)(.canceled)
        } else {
            // Other ASAuthorization error.
            // The userInfo dictionary should contain useful information.
            print("Error: \((error as NSError).userInfo)")
            (handler as! WebAuthnIntegrationHandler)(.error)
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        switch authorization.credential {
        case let secCredentialRegistrations as ASAuthorizationSecurityKeyPublicKeyCredentialRegistration:
            GigyaLogger.log(with: self, message: "A new cross-platform credential was registered: \(secCredentialRegistrations)")
            self.data = secCredentialRegistrations.credentialID
            (handler as! WebAuthnIntegrationHandler)(.securityRegister(secCredentialRegistrations))
        case let credentialRegistration as ASAuthorizationPlatformPublicKeyCredentialRegistration:
            GigyaLogger.log(with: self, message: "A new platform credential was registered: \(credentialRegistration)")

            (handler as! WebAuthnIntegrationHandler)(.register(credentialRegistration))
        case let credentialAssertion as ASAuthorizationPlatformPublicKeyCredentialAssertion:
            GigyaLogger.log(with: self, message: "A platform credential was used to authenticate: \(credentialAssertion)")
            
            (handler as! WebAuthnIntegrationHandler)(.login(credentialAssertion))

        case let credentialAssertion as ASAuthorizationSecurityKeyPublicKeyCredentialAssertion:
            GigyaLogger.log(with: self, message: "A cross-platform credential was used to authenticate: \(credentialAssertion)")
            
            (handler as! WebAuthnIntegrationHandler)(.securityLogin(credentialAssertion))
            
        default:
            (handler as! WebAuthnIntegrationHandler)(.error)
            GigyaLogger.log(with: self, message: "Received unknown authorization type")
        }
    }

}
