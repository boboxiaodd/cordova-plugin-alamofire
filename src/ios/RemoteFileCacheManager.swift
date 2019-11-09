//
//  RemoteFileCacheManager.swift
//  WaiMeeting
//
//  Created by bobo on 2019/11/4.
//

import Foundation
import CommonCrypto

public class RemoteFileCacheManager
{
    /// a dictionary of all RemoteFileDownloaders currently being downloaded.  The remoteFileURL is used as the key.
    var inProgress:Dictionary<URL, RemoteFileDownloader>! = Dictionary()
    
    /// the folder to store the files in.
    public var fileDirectoryURL:URL!
    
    /// a dictionary that holds all currently active RemoteFilePriorityLevels for this service.  remoteFileURL is used as the key
//    public var filePriorities:Dictionary<URL,RemoteFilePriorityLevel>! = Dictionary()
    
    // -----------------------------------------------------------------------------
    //                          func init
    // -----------------------------------------------------------------------------
    /// initializer
    ///
    /// - parameters:
    ///     - subFolder: `(String)` - the subfolder (within the Documents directory) for storing these files... if the directory does not exist yet it will be created
    ///
    /// ----------------------------------------------------------------------------
    public init(subFolder:String! = "Cache")
    {
        // create folder if it does not already exist
        let paths = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.userDomainMask, true)
        let documentsDirectoryURL:URL = URL(fileURLWithPath: paths[0])
        fileDirectoryURL = documentsDirectoryURL.appendingPathComponent(subFolder)
        
        let fileManager = FileManager.default
        do
        {
            try fileManager.createDirectory(atPath: fileDirectoryURL.path, withIntermediateDirectories: false, attributes: nil)
        }
        catch let error as NSError
        {
            print(error.localizedDescription);
        }
    }
    
    // -----------------------------------------------------------------------------
    //                          func localURLFromRemoteURL
    // -----------------------------------------------------------------------------
    /// returns the full url for the location of a file
    ///
    /// - parameters:
    ///     - remoteURL: `(URL)` - the remote url of the download
    ///
    /// - returns:
    ///    `URL` - the full URL for the file's correct local location.  (Regardless of
    ///            whether or not the file exists.
    ///
    /// ----------------------------------------------------------------------------
    public func localURLFromRemoteURL(_ remoteURL:URL) -> URL
    {
        let ext = self.getUrlExt(remoteFileURL: remoteURL)
        let hash = remoteURL.absoluteString.md5
        let filename = "\(hash).\(ext)"
        return fileDirectoryURL.appendingPathComponent(filename)
    }
    
    // -----------------------------------------------------------------------------
    //                          func reportDownloadComplete
    // -----------------------------------------------------------------------------
    /// performs cleanup operations after a download has finished.  For now that means:
    ///
    ///     * removing the RemoteDownloader from the inProgress Dict
    ///
    /// - parameters:
    ///     - remoteURL: `(URL)` - the remoteURL of the completed download
    ///
    /// ----------------------------------------------------------------------------
    func reportDownloadComplete(_ remoteURL:URL)
    {
        self.inProgress.removeValue(forKey: remoteURL)
    }
    
    // -----------------------------------------------------------------------------
    //                          func pauseDownloads
    // -----------------------------------------------------------------------------
    /// suspends all downloads.  Current progress data is retained.
    ///
    /// ----------------------------------------------------------------------------
    public func pauseDownloads()
    {
        for (_, cachedObject) in self.inProgress
        {
            cachedObject.pauseDownload()
        }
    }
    
    // -----------------------------------------------------------------------------
    //                          func calculateFolderCacheSize
    // -----------------------------------------------------------------------------
    // adapted from http://stackoverflow.com/questions/32814535/how-to-get-directory-size-with-swift-on-os-x
    // -----------------------------------------------------------------------------
    /// calculates the total current size of the cache
    ///
    /// - returns:
    ///    `Int` - the folder size in Bytes
    ///
    /// ----------------------------------------------------------------------------
    func calculateFolderCacheSize() -> Int
    {
        // check if the url is a directory
        var bool: ObjCBool = false
        var folderFileSizeInBytes = 0
        
        if FileManager().fileExists(atPath: self.fileDirectoryURL.path, isDirectory: &bool)
        {
            if bool.boolValue
            {
                // lets get the folder files
                let fileManager =  FileManager.default
                let files = try! fileManager.contentsOfDirectory(at: self.fileDirectoryURL, includingPropertiesForKeys: nil, options: [])
                for file in files
                {
                    do {
                        let attr = try FileManager.default.attributesOfItem(atPath: file.path)
                        let fileSize = attr[FileAttributeKey.size] as! Int
                        folderFileSizeInBytes +=  fileSize
                    }catch{
                        print("get filesize error")
                    }
                }
                return folderFileSizeInBytes
            }
        }
        return folderFileSizeInBytes
    }
    
    // -----------------------------------------------------------------------------
    //                          func pruneCache
    // -----------------------------------------------------------------------------
    /// removes lower priority files until the overall folder size is less than
    /// the specified maxFolderSize
    ///
    /// ----------------------------------------------------------------------------
    public func pruneCache()
    {
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: fileDirectoryURL, includingPropertiesForKeys: nil)
            // process files
            for file in fileURLs {
                print("remove file: \(file.path)")
                self.deleteFile(file)
            }
        } catch {
            print("pruneCache fail")
        }
    }
    
    // -----------------------------------------------------------------------------
    //                          func deleteFile
    // -----------------------------------------------------------------------------
    /// deletes the file with the provided localURL
    ///
    /// - parameters:
    ///     - localURL: `(URL)` - the localURL of the file to delete
    ///
    /// ----------------------------------------------------------------------------
    public func deleteFile(_ localURL:URL)
    {
        // Create a FileManager instance
        let fileManager = FileManager.default
        
        do
        {
            try fileManager.removeItem(atPath: localURL.path)
        }
        catch let error as NSError
        {
            print("Error trying to delete file from audioCache: \(error)")
        }
    }
    
    
    
    // -----------------------------------------------------------------------------
    //                          func downloadFile
    // -----------------------------------------------------------------------------
    /// downloads a file
    ///
    /// - parameters:
    ///     - remoteURL: `(URL)` - the remote url of the file to download
    ///
    /// - returns:
    ///    `RemoteFileDownloader` - the RemoteFileDownloader managing the active download.
    ///
    /// ----------------------------------------------------------------------------
    public func downloadFile(_ remoteURL:URL) -> RemoteFileDownloader
    {
        // if a downloader is already in progress for that file
        if let downloader = self.inProgress[remoteURL]
        {
            downloader.resumeDownload()
            return downloader
        }
        let downloader = RemoteFileDownloader(remoteURL: remoteURL, localURL: self.localURLFromRemoteURL(remoteURL))
        .onCompletion
        {
            (downloader) -> Void in
            self.inProgress[downloader.remoteURL] = nil
        }
        
        
        downloader.beginDownload()
        self.inProgress[remoteURL] = downloader
        return downloader
    }
    
    // -----------------------------------------------------------------------------
    //                          func completeFileExists
    // -----------------------------------------------------------------------------
    /// checks for file existence based on remoteURL.
    ///
    /// - parameters:
    ///     - remoteURL: `(URL)` - the remote url of the file
    ///
    /// - returns:
    ///    `Bool` - true if the complete file exists
    /// ----------------------------------------------------------------------------
    public func completeFileExists(remoteFileURL:URL) -> Bool
    {
        let localURL = self.localURLFromRemoteURL(remoteFileURL)
        print("completeFileExists:\(localURL.path)")
        return FileManager.default.fileExists(atPath: localURL.path)
    }
    
    public func getUrlExt(remoteFileURL:URL) -> String
    {
        var ext = remoteFileURL.pathExtension.lowercased()

        print("getUrlExt\(remoteFileURL.absoluteString) ext:\(ext)");
        if remoteFileURL.query != nil {
            if ext == "mp4" { //video first frame
                ext = "jpg"
            }
        }
        return ext
    }
}

extension String {
    var md5: String {
        let data = Data(self.utf8)
        let hash = data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) -> [UInt8] in
            var hash = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
            CC_MD5(bytes.baseAddress, CC_LONG(data.count), &hash)
            return hash
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
