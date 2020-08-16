//
// FavIcon
// Copyright © 2016 Leon Breedt
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import Foundation

#if os(iOS)
    import UIKit
    /// Alias for the iOS image type (`UIImage`).
    public typealias ImageType = UIImage
#elseif os(OSX)
    import Cocoa
    /// Alias for the OS X image type (`NSImage`).
    public typealias ImageType = NSImage
#endif

/// Represents the result of attempting to download an icon.
public enum IconDownloadResult {

    /// Download successful.
    ///
    /// - parameter image: The `ImageType` for the downloaded icon.
    case success(image: ImageType)

    /// Download failed for some reason.
    ///
    /// - parameter error: The error which can be consulted to determine the root cause.
    case failure(error: Error)

}

//@objc public final class URLSessionDelegateIgnoreSSLProblems : NSObject {
//}

class AuthSessionDelegate: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
//
//        let authMethod = challenge.protectionSpace.authenticationMethod
//
//        guard challenge.previousFailureCount < 1, authMethod == NSURLAuthenticationMethodServerTrust,
//            let trust = challenge.protectionSpace.serverTrust else {
//            completionHandler(.performDefaultHandling, nil)
//            return
//        }
        
        completionHandler(.useCredential, URLCredential(trust: challenge.protectionSpace.serverTrust!))
    }
}
    
/// Responsible for detecting all of the different icons supported by a given site.
@objc public final class FavIcon : NSObject {

    // swiftlint:disable function_body_length

    /// Scans a base URL, attempting to determine all of the supported icons that can
    /// be used for favicon purposes.
    ///
    /// It will do the following to determine possible icons that can be used:
    ///
    /// - Check whether or not `/favicon.ico` exists.
    /// - If the base URL returns an HTML page, parse the `<head>` section and check for `<link>`
    ///   and `<meta>` tags that reference icons using Apple, Microsoft and Google
    ///   conventions.
    /// - If _Web Application Manifest JSON_ (`manifest.json`) files are referenced, or
    ///   _Microsoft browser configuration XML_ (`browserconfig.xml`) files
    ///   are referenced, download and parse them to check if they reference icons.
    ///
    ///  All of this work is performed in a background queue.
    ///
    /// - parameter url: The base URL to scan.
    /// - parameter completion: A closure to call when the scan has completed. The closure will be call
    ///                         on the main queue.
    @objc public static func scan(_ url: URL,
                                  on queue: OperationQueue? = nil,
                                  favIcon: Bool = true,
                                  scanHtml: Bool = true,
                                  duckDuckGo: Bool = true,
                                  google: Bool = true,
                                  allowInvalidSSLCerts: Bool = false,
                                  completion: @escaping ([DetectedIcon], [String:String]) -> Void) throws {
        let syncQueue = DispatchQueue(label: "org.bitserf.FavIcon", attributes: [])
        var icons: [DetectedIcon] = []
        var additionalDownloads: [URLRequestWithCallback] = []
        let urlSession = allowInvalidSSLCerts ? insecureUrlSessionProvider() : urlSessionProvider()
        var meta: [String:String] = [:]
      
        var operations: [URLRequestWithCallback] = []
        
        if(scanHtml) {
            let downloadHTMLOperation = DownloadTextOperation(url: url, session: urlSession)
            let downloadHTML = urlRequestOperation(downloadHTMLOperation) { result in
                if case let .textDownloaded(actualURL, text, contentType) = result {
                    if contentType == "text/html" {
                        let document = HTMLDocument(string: text)

                        let htmlIcons = extractHTMLHeadIcons(document, baseURL: actualURL)
                        let htmlMeta = examineHTMLMeta(document, baseURL: actualURL)
                        syncQueue.sync {
                            icons.append(contentsOf: htmlIcons)
                            meta = htmlMeta
                        }

                        for manifestURL in extractWebAppManifestURLs(document, baseURL: url) {
                            let downloadOperation = DownloadTextOperation(url: manifestURL,
                                                                                  session: urlSession)
                            let download = urlRequestOperation(downloadOperation) { result in
                                if case .textDownloaded(_, let manifestJSON, _) = result {
                                    let jsonIcons = extractManifestJSONIcons(
                                        manifestJSON,
                                        baseURL: actualURL
                                    )
                                    syncQueue.sync {
                                        icons.append(contentsOf: jsonIcons)
                                    }
                                }
                            }
                            additionalDownloads.append(download)
                        }

                        let browserConfigResult = extractBrowserConfigURL(document, baseURL: url)
                        if let browserConfigURL = browserConfigResult.url, !browserConfigResult.disabled {
                            let downloadOperation = DownloadTextOperation(url: browserConfigURL,
                                                                          session: urlSession)
                            let download = urlRequestOperation(downloadOperation) { result in
                                if case let .textDownloaded(_, browserConfigXML, _) = result {
                                    let document = LBXMLDocument(string: browserConfigXML)
                                    let xmlIcons = extractBrowserConfigXMLIcons(
                                        document,
                                        baseURL: actualURL
                                    )
                                    syncQueue.sync {
                                        icons.append(contentsOf: xmlIcons)
                                    }
                                }
                            }
                            additionalDownloads.append(download)
                        }
                    }
                }
            }

            operations.append(downloadHTML);
        }

        if(favIcon) {
            let commonFiles : [String] = [  "favicon.ico",
                                            "apple-touch-icon.png",
                                            "apple-icon-57x57.png",
                                            "apple-icon-60x60.png",
                                            "apple-icon-72x72.png",
                                            "apple-icon-76x76.png",
                                            "apple-icon-114x114.png",
                                            "apple-icon-120x120.png",
                                            "apple-icon-144x144.png",
                                            "apple-icon-152x152.png",
                                            "apple-icon-180x180.png",
                                            "android-icon-192x192.png",
                                            "favicon-32x32.png",
                                            "favicon-96x96.png",
                                            "favicon-16x16.png",
                                            "ms-icon-144x144.png"];
                                            
            for commonFile in commonFiles {
                //print("Checking: ", commonFile)
                
                let favIconURL = URL(string: commonFile, relativeTo: url as URL)!.absoluteURL
                let checkFavIconOperation = CheckURLExistsOperation(url: favIconURL, session: urlSession)
                let checkFavIcon = urlRequestOperation(checkFavIconOperation) { result in
                    if case let .success(actualURL) = result {
                        print("Common File Success: ", actualURL)
                        syncQueue.sync {
                            icons.append(DetectedIcon(url: actualURL, type: .classic))
                        }
                    }
                }
                operations.append(checkFavIcon);
            }
        }

        var components = URLComponents(url: url, resolvingAgainstBaseURL: false);
        components?.path = ""; //@"";
        components?.query = nil; //@"";
        components?.user = nil; //@"";
        components?.password = nil; //@"";
        components?.fragment = nil; //@"";
        
        let domain = components?.host ?? url.absoluteString;
        let blah = String(format: "https://icons.duckduckgo.com/ip3/%@.ico" , domain.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)!)
        
        if(duckDuckGo) {
            let ddgUrl = URL(string: blah);
            
            if (ddgUrl != nil) {
                let duckDuckGoURL = ddgUrl!.absoluteURL
                let checkDuckDuckGoURLOperation = CheckURLExistsOperation(url: duckDuckGoURL, session: urlSession)
                let checkDuckDuckGoURL = urlRequestOperation(checkDuckDuckGoURLOperation) { result in
                    if case let .success(actualURL) = result {
                        syncQueue.sync {
                            icons.append(DetectedIcon(url: actualURL, type: .classic)) // TODO: Classic?
                        }
                    }
                }
                
                operations.append(checkDuckDuckGoURL);
            }
        }
        
        //

        if(google) {
            let blah2 = String(format: "https://www.google.com/s2/favicons?domain=%@" , domain.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)!)
            let googleURL = URL(string: blah2)?.absoluteURL
            if (googleURL != nil) {
                let checkGoogleUrlOperation = CheckURLExistsOperation(url: googleURL!, session: urlSession)
                let checkGoogleUrl = urlRequestOperation(checkGoogleUrlOperation) { result in
                    if case let .success(actualURL) = result {
                        syncQueue.sync {
                            icons.append(DetectedIcon(url: actualURL, type: .classic)) // TODO: Classic?
                        }
                    }
                }
                
                operations.append(checkGoogleUrl);
            }
        }

        if(operations.count == 0) {
            DispatchQueue.main.async {
                completion(icons, meta)
            }
        }
        
        executeURLOperations(operations, on: queue) {
            if additionalDownloads.count > 0 {
                executeURLOperations(additionalDownloads, on: queue) {
                    DispatchQueue.main.async {
                        completion(icons, meta)
                    }
                }
            } else {
                DispatchQueue.main.async {
                    completion(icons, meta)
                }
            }
        }
    }
    // swiftlint:enable function_body_length

    /// Downloads an array of detected icons in the background.
    ///
    /// - parameter icons: The icons to download.
    /// - parameter completion: A closure to call when all download tasks have
    ///                         results available (successful or otherwise). The closure
    ///                         will be called on the main queue.
    @objc public static func download(_ icons: [DetectedIcon], completion: @escaping ([ImageType]) -> Void) {
        let urlSession = urlSessionProvider()
        let operations: [DownloadImageOperation] =
            icons.map { DownloadImageOperation(url: $0.url, session: urlSession) }

        executeURLOperations(operations) { results in
            let downloadResults: [ImageType] = results.compactMap { result in
                switch result {
                case .imageDownloaded(_, let image):
                  return image;
                case .failed(_):
                  return nil;
                default:
                  return nil;
                }
            }

            DispatchQueue.main.async {
                completion(downloadResults)
            }
        }
    }

    enum MyError: Error {
        case runtimeError(String)
    }
    
    @objc public static func downloadAll(_ url: URL,
                                         favIcon: Bool,
                                          scanHtml: Bool,
                                          duckDuckGo: Bool,
                                          google: Bool,
                                          allowInvalidSSLCerts: Bool,
                                          completion: @escaping ([ImageType]?) -> Void)  throws {
        do {
            try scan(url, favIcon: favIcon, scanHtml: scanHtml, duckDuckGo: duckDuckGo, google: google, allowInvalidSSLCerts: allowInvalidSSLCerts ) { icons, meta in
                let iconMap = icons.reduce(into: [URL:DetectedIcon](), { current,icon in
                    current[icon.url] = icon
                })
                
                let uniqueIcons = Array(iconMap.values);
                dl(uniqueIcons) { downloaded in
                    let blah = Array(downloaded.values)
                    DispatchQueue.main.async {
                        completion(blah)
                    }
                }
            }
        }
        catch {
            DispatchQueue.main.async {
                completion([])
            }
        }
    }

    @objc public static func dl(_ icons: [DetectedIcon], on queue: OperationQueue? = nil, completion: @escaping ([URL: ImageType]) -> Void) {
        let urlSession = urlSessionProvider()
        let operations: [DownloadImageOperation] =
            icons.map { DownloadImageOperation(url: $0.url, session: urlSession) }
        
        var myDictionary =  [URL: ImageType]()
        
        executeURLOperations(operations, on: queue) { results in
            for result in results {
                switch result {
                case let .imageDownloaded(url, image):
                    myDictionary[url] = image
                default:
                    continue;
                }
            }
            
            DispatchQueue.main.async {
                completion(myDictionary)
            }
        }
    }

    typealias URLSessionProvider = () -> URLSession
    @objc static var urlSessionProvider: URLSessionProvider = FavIcon.createDefaultURLSession
    @objc static var insecureUrlSessionProvider: URLSessionProvider = FavIcon.createInsecureURLSession

    @objc static func createDefaultURLSession() -> URLSession {
        return URLSession.shared
    }
    
    @objc static func createInsecureURLSession() -> URLSession {
        return URLSession (configuration: URLSessionConfiguration.default, delegate: AuthSessionDelegate (), delegateQueue: nil);
    }
}

/// Enumerates errors that can be thrown while detecting or downloading icons.
enum IconError: Error {
    /// The base URL specified is not a valid URL.
    case invalidBaseURL
    /// At least one icon to must be specified for downloading.
    case atLeastOneOneIconRequired
    /// Unexpected response when downloading
    case invalidDownloadResponse
    /// No icons were detected, so nothing could be downloaded.
    case noIconsDetected
}

extension DetectedIcon {
    /// The area of a detected icon, if known.
    var area: Int? {
        if let width = width, let height = height {
            return width * height
        }
        return nil
    }
}


