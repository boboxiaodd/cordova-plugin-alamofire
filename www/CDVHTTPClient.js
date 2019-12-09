var exec = require('cordova/exec');

var PLUGIN_NAME = "CDVHTTPClient"; // This is just for code completion uses.

var CDVHTTPClient = function() {}; // This just makes it easier for us to export all of the functions at once.

CDVHTTPClient.request = function(onSuccess, onError , options) {
    exec(onSuccess, onError, PLUGIN_NAME, "request", [options]);
};
CDVHTTPClient.upload = function(onSuccess, onError , options) {
    exec(onSuccess, onError, PLUGIN_NAME, "upload", [options]);
};
CDVHTTPClient.checkcache = function(onSuccess,onError,url){
    exec(onSuccess,onError,PLUGIN_NAME,"checkcache",[url])
}
CDVHTTPClient.removecache = function(onSuccess,onError){
    exec(onSuccess,onError,PLUGIN_NAME,"removecache",[])
}
CDVHTTPClient.cachesize = function(onSuccess,onError){
    exec(onSuccess,onError,PLUGIN_NAME,"cachesize",[])
}
CDVHTTPClient.purchase = function(onSuccess,onError,param){
    exec(onSuccess,onError,PLUGIN_NAME,"purchase",[param]);
}
module.exports = CDVHTTPClient;
