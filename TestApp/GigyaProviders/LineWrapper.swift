//
//  LineWrapper.swift
//  GigyaSwift
//
//  Created by Shmuel, Sagi on 02/05/2019.
//  Copyright © 2019 Gigya. All rights reserved.
//

import Foundation
import LineSDK
import Gigya

class LineWrapper: NSObject, ProviderWrapperProtocol {

    var clientID: String? = {
        let config = (Bundle.main.infoDictionary?["LineSDKConfig"] as? [String: String])
        return config?["ChannelID"]
    }()

    lazy var line: LineSDKLogin = {
        return LineSDKLogin.sharedInstance()
    }()

    private var completionHandler: (_ jsonData: [String: Any]?, _ error: String?) -> Void = { _, _  in }

    required override init() {
        super.init()

        line.delegate = self
    }

    func login(params: [String: Any]? = nil, viewController: UIViewController? = nil,
               completion: @escaping (_ jsonData: [String: Any]?, _ error: String?) -> Void) {
        completionHandler = completion

        line.start()
    }
}

extension LineWrapper: LineSDKLoginDelegate {
    func didLogin(_ login: LineSDKLogin, credential: LineSDKCredential?, profile: LineSDKProfile?, error: Error?) {
        guard error == nil else {
            completionHandler(nil, error?.localizedDescription)
            return
        }

        let jsonData = ["accessToken": credential?.accessToken?.accessToken ?? "", "uid" : profile?.userID ?? ""]

        completionHandler(jsonData, nil)
    }
}