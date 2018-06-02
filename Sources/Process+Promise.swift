import Foundation
import PromiseKit
#if !CPKCocoaPods
import CancelForPromiseKit
#endif

#if os(macOS)

extension Process: CancellableTask {
    public func cancel() {
        interrupt()
    }
    
    public var isCancelled: Bool {
        return !isRunning
    }
}

/**
 To import the `Process` category:

    use_frameworks!
    pod "CancelForPromiseKit/Foundation"

 Or, `Process` is one of the categories imported by the umbrella pod:

    use_frameworks!
    pod "CancelForPromiseKit"
 
 And then in your sources:

    import PromiseKit
    import CancelForPromiseKit
 */
extension Process {
    /**
     Launches the receiver and resolves when it exits, or when the promise is cancelled.
     
         let proc = Process()
         proc.launchPath = "/bin/ls"
         proc.arguments = ["/bin"]
         let context = proc.launchCC(.promise).compactMap { std in
             String(data: std.out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
         }.then { stdout in
             print(str)
         }.cancelContext
         //…
         context.cancel()
     */
    public func launchCC(_: PMKNamespacer) -> CancellablePromise<(out: Pipe, err: Pipe)> {
        return CancellablePromise(task: self, self.launch(.promise))
    }
}

#endif
