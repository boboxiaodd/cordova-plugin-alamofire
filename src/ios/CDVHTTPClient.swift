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
    private var filecache:RemoteFileCacheManager!
    override func pluginInitialize() {
        filecache = RemoteFileCacheManager(subFolder: "cache")
        let iap = InAppPurchase.default
        iap.addTransactionObserver(fallbackHandler: { (result) in
            // Handle the result of payment added by Store
            // See also `InAppPurchase#purchase`
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
        let headers = arg["headers"] as? [String:String]

        Alamofire.request(url, method: .post, parameters: param ,encoding: JSONEncoding.default , headers: headers).responseJSON{res in
            if res.result.isFailure {
                let respone = String(data: res.data!, encoding: .utf8)
                let pluginResult = CDVPluginResult (status: CDVCommandStatus_ERROR, messageAs: respone)
                pluginResult?.setKeepCallbackAs(true)
                self.commandDelegate!.send(pluginResult, callbackId: command.callbackId)
            }else{
                let json = res.result.value as! [AnyHashable:Any]
                let pluginResult = CDVPluginResult (status: CDVCommandStatus_OK, messageAs: json)
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
        let headers = arg["headers"] as? [String:String]

        Alamofire.upload(multipartFormData: {multipartFormData in
            multipartFormData.append(URL(fileURLWithPath: path), withName: "file")
        }, to: url, method: .post, headers: headers){result in
            switch result {
               case .success(let upload, _, _):
                   upload.uploadProgress(closure: { (progress) in
                        let json = ["progress": progress.fractionCompleted] as [AnyHashable:Any]
                        let pluginResult = CDVPluginResult (status: CDVCommandStatus_OK, messageAs: json)
                        pluginResult?.setKeepCallbackAs(true)
                        self.commandDelegate!.send(pluginResult, callbackId: command.callbackId)
                   })
                   upload.responseJSON { response in
                       //print response.result
                        let json = response.result.value as! [AnyHashable:Any]
                        let pluginResult = CDVPluginResult (status: CDVCommandStatus_OK, messageAs: json)
                        pluginResult?.setKeepCallbackAs(true)
                        self.commandDelegate!.send(pluginResult, callbackId: command.callbackId)
                   }
               case .failure(let encodingError):
                   let pluginResult = CDVPluginResult (status: CDVCommandStatus_ERROR, messageAs: encodingError.localizedDescription)
                   pluginResult?.setKeepCallbackAs(true)
                   self.commandDelegate!.send(pluginResult, callbackId: command.callbackId)
            }
        }

    }

    @objc(removecache:)
    func removecache(command:CDVInvokedUrlCommand){
        filecache.pruneCache()
        let pluginResult = CDVPluginResult (status: CDVCommandStatus_OK, messageAs: "ok")
        pluginResult?.setKeepCallbackAs(true)
        self.commandDelegate!.send(pluginResult, callbackId: command.callbackId)
    }

    @objc(cachesize:)
    func cachesize(command:CDVInvokedUrlCommand){
        let size = filecache.calculateFolderCacheSize()
        let pluginResult = CDVPluginResult (status: CDVCommandStatus_OK, messageAs: size)
        pluginResult?.setKeepCallbackAs(true)
        self.commandDelegate!.send(pluginResult, callbackId: command.callbackId)
    }

    @objc(checkcache:)
    func checkcache(command:CDVInvokedUrlCommand){
        let arg = command.arguments[0] as! String
        let url = URL(string: arg)!
        if filecache.completeFileExists(remoteFileURL: url) {
            //如果存在返回local url
            print("cache exists")
            let localPath = filecache.localURLFromRemoteURL(url)
            let pluginResult = CDVPluginResult (status: CDVCommandStatus_OK, messageAs: localPath.lastPathComponent)
            pluginResult?.setKeepCallbackAs(true)
            self.commandDelegate!.send(pluginResult, callbackId: command.callbackId)
        }else{
            print("cache not exists")
            let my_downloader = filecache.downloadFile(url)
            my_downloader.onCompletion{ downloader in
                print("DOWNLOAD COMPLETE!\(downloader.localURL.lastPathComponent)")
                let pluginResult = CDVPluginResult (status: CDVCommandStatus_OK, messageAs: downloader.localURL.lastPathComponent)
                pluginResult?.setKeepCallbackAs(true)
                self.commandDelegate!.send(pluginResult, callbackId: command.callbackId)
            }

        }
    }
}

