//
//  NativeScreenSetsViewModel.swift
//  GigyaNss
//
//  Created by Shmuel, Sagi on 18/02/2020.
//  Copyright © 2020 Gigya. All rights reserved.
//

import Flutter
import Gigya

typealias NssHandler<T: GigyaAccountProtocol> = ((NssEvents<T>) -> Void)

class NativeScreenSetsViewModel<T: GigyaAccountProtocol>: NSObject, UIAdaptivePresentationControllerDelegate {
    
    var dismissClosure: () -> Void = {}
    var closeClosure: () -> Void = {}

    var screenChannel: ScreenChannel?
    var apiChannel: ApiChannel?
    var logChannel: LogChannel?

    let flowManager: FlowManager<T>

    var engine: FlutterEngine?

    var eventHandler: NssHandler<T>? = { _ in }

    init(mainChannel: ScreenChannel, apiChannel: ApiChannel, logChannel: LogChannel, flowManager: FlowManager<T>, eventHandler: NssHandler<T>?) {
        self.screenChannel = mainChannel
        self.apiChannel = apiChannel
        self.logChannel = logChannel
        self.flowManager = flowManager
        self.eventHandler = eventHandler
    }

    func loadChannels(with engine: FlutterEngine) {
        screenChannel?.initChannel(engine: engine)
        apiChannel?.initChannel(engine: engine)
        logChannel?.initChannel(engine: engine)

        screenChannel?.methodHandler(scheme: ScreenChannelEvent.self) { [weak self] method, data, response in
            guard let self = self, let method = method else {
                return
            }

            switch method {
            case .action:
                guard
                    let flowId = data?["actionId"] as? String,
                    let flow = NssAction(rawValue: flowId),
                    let screenId = data?["screenId"] as? String
                    else {
                    return
                }

                self.flowManager.setCurrent(action: flow, response: response)
                self.flowManager.currentScreenId = screenId

            case .link:
                guard let stringUrl = data?["url"] as? String,
                    let url = URL(string: stringUrl) else { return }

                UIApplication.shared.open(url)
            case .dismiss:
                self.dismissClosure()
                self.eventHandler?(.canceled)
            case .canceled:
                self.dismissClosure()
                self.eventHandler?(.canceled)
            }
        }

        apiChannel?.methodHandler(scheme: ApiChannelEvent.self) { [weak self] method, data, response in
            guard let self = self, let method = method else {
                return
            }
    
            self.flowManager.next(method: method, params: data, response: response)

            GigyaLogger.log(with: self, message: "next: \(method)")
        }

        logChannel?.methodHandler(scheme: LogChannelEvent.self, { [weak self] (method, data, response) in
            guard let self = self, let method = method else {
                return
            }

            switch method {
            case .debug:
                GigyaLogger.log(with: self, message: data?["message"] as? String ?? "")
            case .error:
                GigyaLogger.error(with: GigyaNss.self, message: data?["message"] as? String ?? "")
            }
        })
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        closeClosure()
    }

    deinit {
        GigyaLogger.log(with: self, message: "deinit")
    }
}
