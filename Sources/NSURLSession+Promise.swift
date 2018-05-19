import Foundation
import PromiseKit
#if !CPKCocoaPods
import CancelForPromiseKit
#endif

extension URLSessionTask: CancellableTask {
    public var isCancelled: Bool {
        return state == .canceling
    }
}

/**
 To import the `NSURLSession` category:

    use_frameworks!
    pod "CancellablePromiseKit/Foundation"

 Or `NSURLSession` is one of the categories imported by the umbrella pod:

    use_frameworks!
    pod "CancellablePromiseKit"

 And then in your sources:

    import PromiseKit
    import CancellablePromiseKit
*/
extension URLSession {
    /**
     Example usage with explicit cancel context:

         let context = CancelContext()
         firstlyCC(cancel: context) {
             URLSession.shared.dataTaskCC(.promise, with: rq)
         }.compactMapCC { data, _ in
             try JSONSerialization.jsonObject(with: data) as? [String: Any]
         }.thenCC { json in
             //…
         }
         //…
         context.cancel()

     Example usage with implicit cancel context:
     
         let promise = firstlyCC {
             URLSession.shared.dataTaskCC(.promise, with: rq)
         }.compactMapCC { data, _ in
             try JSONSerialization.jsonObject(with: data) as? [String: Any]
         }.thenCC { json in
             //…
         }
         //…
         promise.cancel()
     
     We recommend the use of [OMGHTTPURLRQ] which allows you to construct correct REST requests:

         firstlyCC(cancel: context) {
             let rq = OMGHTTPURLRQ.POST(url, json: parameters)
             URLSession.shared.dataTaskCC(.promise, with: rq)
         }.thenCC { data, urlResponse in
             //…
         }
         //…
         context.cancel()

     We provide a convenience initializer for `String` specifically for this promise:
     
         let context = CancelContext()
         firstlyCC(cancel: context) {
             URLSession.shared.dataTaskCC(.promise, with: rq)
         }.compactMapCC(String.init).thenCC { string in
             // decoded per the string encoding specified by the server
         }.thenCC { string in
             print("response: string")
         }
         //…
         context.cancel()
     
     Other common types can be easily decoded using compactMap also:
     
         let context = CancelContext()
         firstlyCC(cancel: context) {
             URLSession.shared.dataTaskCC(.promise, with: rq)
         }.compactMapCC {
             UIImage(data: $0)
         }.thenCC {
             self.imageView.image = $0
         }
         //…
         context.cancel()

     Though if you do decode the image this way, we recommend inflating it on a background thread
     first as this will improve main thread performance when rendering the image:
     
         let context = CancelContext()
         firstlyCC(cancel: context) {
             URLSession.shared.dataTaskCC(.promise, with: rq)
         }.compactMapCC(on: QoS.userInitiated) { data, _ in
             guard let img = UIImage(data: data) else { return nil }
             _ = cgImage?.dataProvider?.data
             return img
         }.thenCC {
             self.imageView.image = $0
         }
         //…
         context.cancel()

     - Parameter convertible: A URL or URLRequest.
     - Returns: A promise that represents the URL request.
     - SeeAlso: [OMGHTTPURLRQ]
     - Remark: We deliberately don’t provide a `URLRequestConvertible` for `String` because in our experience, you should be explicit with this error path to make good apps.
     
     [OMGHTTPURLRQ]: https://github.com/mxcl/OMGHTTPURLRQ
     */
    public func dataTaskCC(_: PMKNamespacer, with convertible: URLRequestConvertible, cancel: CancelContext? = nil) -> Promise<(data: Data, response: URLResponse)> {
        var task: URLSessionTask!
        var reject: ((Error) -> Void)!

        let promise = Promise<(data: Data, response: URLResponse)> {
            reject = $0.reject
            task = self.dataTask(with: convertible.pmkRequest, completionHandler: adapter($0))
            task.resume()
        }

        let cancelContext = cancel ?? CancelContext()
        promise.cancelContext = cancelContext
        cancelContext.append(task: task, reject: reject, description: PromiseDescription(promise))
        return promise
    }

    public func uploadTaskCC(_: PMKNamespacer, with convertible: URLRequestConvertible, from data: Data, cancel: CancelContext? = nil) -> Promise<(data: Data, response: URLResponse)> {
        var task: URLSessionTask!
        var reject: ((Error) -> Void)!
        
        let promise = Promise<(data: Data, response: URLResponse)> {
            reject = $0.reject
            task = self.uploadTask(with: convertible.pmkRequest, from: data, completionHandler: adapter($0))
            task.resume()
        }

        let cancelContext = cancel ?? CancelContext()
        promise.cancelContext = cancelContext
        cancelContext.append(task: task, reject: reject, description: PromiseDescription(promise))
        return promise
    }

    public func uploadTaskCC(_: PMKNamespacer, with convertible: URLRequestConvertible, fromFile file: URL, cancel: CancelContext? = nil) -> Promise<(data: Data, response: URLResponse)> {
        var task: URLSessionTask!
        var reject: ((Error) -> Void)!

        let promise = Promise<(data: Data, response: URLResponse)> {
            reject = $0.reject
            task = self.uploadTask(with: convertible.pmkRequest, fromFile: file, completionHandler: adapter($0))
            task.resume()
        }

        let cancelContext = cancel ?? CancelContext()
        promise.cancelContext = cancelContext
        cancelContext.append(task: task, reject: reject, description: PromiseDescription(promise))
        return promise
    }

    /// - Remark: we force a `to` parameter because Apple deletes the downloaded file immediately after the underyling completion handler returns.
    public func downloadTaskCC(_: PMKNamespacer, with convertible: URLRequestConvertible, to saveLocation: URL, cancel: CancelContext? = nil) -> Promise<(saveLocation: URL, response: URLResponse)> {
        var task: URLSessionTask!
        var reject: ((Error) -> Void)!

        let promise = Promise<(saveLocation: URL, response: URLResponse)> { seal in
            reject = seal.reject
            task = self.downloadTask(with: convertible.pmkRequest, completionHandler: { tmp, rsp, err in
                if let error = err {
                    seal.reject(error)
                } else if let rsp = rsp, let tmp = tmp {
                    do {
                        try FileManager.default.moveItem(at: tmp, to: saveLocation)
                        seal.fulfill((saveLocation, rsp))
                    } catch {
                        seal.reject(error)
                    }
                } else {
                    seal.reject(PMKError.invalidCallingConvention)
                }
            })
            task.resume()
        }

        let cancelContext = cancel ?? CancelContext()
        promise.cancelContext = cancelContext
        cancelContext.append(task: task, reject: reject, description: PromiseDescription(promise))
        return promise
    }
}

private func adapter<T, U>(_ seal: Resolver<(data: T, response: U)>) -> (T?, U?, Error?) -> Void {
    return { t, u, e in
        if let t = t, let u = u {
            seal.fulfill((t, u))
        } else if let e = e {
            seal.reject(e)
        } else {
            seal.reject(PMKError.invalidCallingConvention)
        }
    }
}
