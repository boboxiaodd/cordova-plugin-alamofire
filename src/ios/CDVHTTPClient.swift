import Foundation
import Alamofire
import InAppPurchase
import StoreKit
/*
* Notes: The @objc shows that this class & function should be exposed to Cordova.
*/

final class StubPayment: SKPayment {
    private let _productIdentifier: String
    override var productIdentifier: String {
        return _productIdentifier
    }

    init(productIdentifier: String) {
        self._productIdentifier = productIdentifier
    }
}


@objc(CDVHTTPClient) class CDVHTTPClient : CDVPlugin {
    override func pluginInitialize() {
        let iap = InAppPurchase.default
        iap.addTransactionObserver(fallbackHandler: { (result) in
            print("addTransactionObserver")
        })
    }

    private func send_action(command:CDVInvokedUrlCommand,action:String,desc:String = ""){
        let json = ["action": action,"desc":desc] as [String:String]
        let pluginResult = CDVPluginResult (status: CDVCommandStatus_ERROR, messageAs: json)
        pluginResult?.setKeepCallbackAs(true)
        self.commandDelegate!.send(pluginResult, callbackId: command.callbackId)
    }

    @objc(purchase:)
    func purchase(command:CDVInvokedUrlCommand){
        let arg = command.arguments[0] as! [String:Any]
        let iap = InAppPurchase.default
        iap.purchase(productIdentifier: arg["product_id"] as! String , handler: { (result) in
            // This handler is called if the payment purchased, restored, deferred or failed.
            switch result {
            case .success(let state):
                switch state {
                    case .purchased(transaction: let trans):
                        if let appStoreReceiptURL = Bundle.main.appStoreReceiptURL,
                            FileManager.default.fileExists(atPath: appStoreReceiptURL.path) {
                                do {
                                    let receiptData = try Data(contentsOf: appStoreReceiptURL, options: .alwaysMapped)
                                    let receiptString = receiptData.base64EncodedString(options: [])
                                    // Read receiptData
                                    let json = ["action":"purchase_success",
                                                "transaction_id": trans.transactionIdentifier!,
                                                "receipt": receiptString] as [String:String]
                                    let pluginResult = CDVPluginResult (status: CDVCommandStatus_OK, messageAs: json)
                                    pluginResult?.setKeepCallbackAs(true)
                                    self.commandDelegate!.send(pluginResult, callbackId: command.callbackId)
                                }
                                catch {
                                    self.send_action(command: command, action: "purchase_fail", desc: error.localizedDescription)
                                }
                        }else{
                            self.send_action(command: command, action: "purchase_fail",desc: "can't find receiptData")
                        }
                        break
                    case .deferred:
                        self.send_action(command: command, action: "purchase_end",desc: "deferred")
                        break
                    case .restored:
                        self.send_action(command: command, action: "purchase_end",desc: "restored")
                        break
                }
                break
            case .failure(let error):
                self.send_action(command: command, action: "purchase_cancel",desc: error.localizedDescription)
                break
            }
        })
    }


    @objc(request:) // Declare your function name.
    func request(command: CDVInvokedUrlCommand) { // write the function code.
        let arg = command.arguments[0] as! [String:Any]
        let url = arg["url"] as! String
        let param = arg["param"] as? [String:Any]
        var headers:HTTPHeaders = HTTPHeaders();
        for item in arg["headers"] as! [String: String] {
            headers.add(name: item.key, value: item.value)
        }

        AF.request(url, method: .post,
                   parameters: param ,
                   encoding: JSONEncoding.default ,
                   headers: headers).responseJSON{res in
            switch(res.result){
            case .success(_):
                let respone = res.value as! [AnyHashable:Any] //String(data: res.data!, encoding: .utf8)
                let pluginResult = CDVPluginResult (status: CDVCommandStatus_OK, messageAs: respone)
                pluginResult?.setKeepCallbackAs(true)
                self.commandDelegate!.send(pluginResult, callbackId: command.callbackId)
            case let .failure(error):
                let json = ["error": error.errorDescription ?? "nothing"] as [String: Any]
                let pluginResult = CDVPluginResult (status: CDVCommandStatus_ERROR, messageAs: json)
                pluginResult?.setKeepCallbackAs(true)
                self.commandDelegate!.send(pluginResult, callbackId: command.callbackId)
            }
        }
    }

    @objc(upload:)
    func upload(command: CDVInvokedUrlCommand){
        let arg = command.arguments[0] as! [String:Any]
        let url = arg["url"] as! String
        let path = arg["path"] as! String
        var headers:HTTPHeaders = HTTPHeaders();
        for item in arg["headers"] as! [String: String] {
            headers.add(name: item.key, value: item.value)
        }

        AF.upload(multipartFormData: { multipartFormData in
            multipartFormData.append(URL(fileURLWithPath: path), withName: "file")
        }, to: url,headers: headers)
            .uploadProgress{ progress in

            }
            .responseJSON{ response in
                //print response.result
                let json = String(data: response.data!, encoding: .utf8)
                let pluginResult = CDVPluginResult (status: CDVCommandStatus_OK, messageAs: json)
                pluginResult?.setKeepCallbackAs(true)
                self.commandDelegate!.send(pluginResult, callbackId: command.callbackId)
            }
    }
}

