import Foundation
import Alamofire
/*
* Notes: The @objc shows that this class & function should be exposed to Cordova.
*/

@objc(CDVHTTPClient) class CDVHTTPClient : CDVPlugin {
    private var filecache:RemoteFileCacheManager!
    override func pluginInitialize() {
        filecache = RemoteFileCacheManager(subFolder: "cache")
    }

    @objc(request:) // Declare your function name.
    func request(command: CDVInvokedUrlCommand) { // write the function code.
        let arg = command.arguments[0] as! [String:Any]
        let url = arg["url"] as! String
        let param = arg["param"] as? [String:Any]
        let headers = arg["headers"] as? [String:String]

        Alamofire.request(url, method: .post, parameters: param ,encoding: JSONEncoding.default , headers: headers).responseJSON{res in
            if res.result.isFailure {
                let pluginResult = CDVPluginResult (status: CDVCommandStatus_ERROR, messageAs: "BAD JSON")
                pluginResult?.setKeepCallbackAs(true)
                self.commandDelegate!.send(pluginResult, callbackId: command.callbackId)
            }else{
                let json = res.result.value as! [AnyHashable:Any]
                let pluginResult = CDVPluginResult (status: CDVCommandStatus_OK, messageAs: json)
                pluginResult?.setKeepCallbackAs(true)
                self.commandDelegate!.send(pluginResult, callbackId: command.callbackId)
            }
        }.responseString{ body in
            print(body)
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
                        let json = ["progress": progress] as [AnyHashable:Any]
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
            let pluginResult = CDVPluginResult (status: CDVCommandStatus_OK, messageAs: localPath.absoluteString)
            pluginResult?.setKeepCallbackAs(true)
            self.commandDelegate!.send(pluginResult, callbackId: command.callbackId)
        }else{
            print("cache not exists")
            let _ = filecache.downloadFile(url)
            let pluginResult = CDVPluginResult (status: CDVCommandStatus_OK, messageAs: url.absoluteString)
            pluginResult?.setKeepCallbackAs(true)
            self.commandDelegate!.send(pluginResult, callbackId: command.callbackId)
        }
    }
}

