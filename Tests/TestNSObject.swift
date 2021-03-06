import CPKFoundation
import Foundation
import CancelForPromiseKit
import XCTest

class NSObjectTests: XCTestCase {
    func testCancelKVO() {
        let ex = expectation(description: "")

        let foo = Foo()
        foo.observeCC(.promise, keyPath: "bar").done { newValue in
            XCTAssertEqual(newValue as? String, "moo")
            XCTFail()
            // ex.fulfill()
        }.catch(policy: .allErrors) {
            $0.isCancelled ? ex.fulfill() : XCTFail()
        }.cancel()
        foo.bar = "moo"

        waitForExpectations(timeout: 1)
    }

     func testCancelKVO2() {
        let ex = expectation(description: "")

        let foo = Foo()
        let p = foo.observeCC(.promise, keyPath: "bar").done { newValue in
            XCTAssertEqual(newValue as? String, "moo")
            XCTFail()
            // ex.fulfill()
        }.catch(policy: .allErrors) {
            $0.isCancelled ? ex.fulfill() : XCTFail()
        }
        foo.bar = "moo"
        p.cancel()

        waitForExpectations(timeout: 1)
    }

   func testCancelAfterlife() {
        let ex = expectation(description: "")
        var killme: NSObject!

        autoreleasepool {
            var p: CancellableFinalizer!
            func innerScope() {
                killme = NSObject()
                p = afterCC(life: killme).done { _ in
                    XCTFail()
                }.catch(policy: .allErrors) {
                    $0.isCancelled ? ex.fulfill() : XCTFail()
                }
            }

            innerScope()

            after(.milliseconds(200)).done {
                killme = nil
                p.cancel()
            }
        }

        waitForExpectations(timeout: 1)
    }

    func testCancelMultiObserveAfterlife() {
        let ex1 = expectation(description: "")
        let ex2 = expectation(description: "")
        var killme: NSObject!

        autoreleasepool {
            var p1, p2: CancellableFinalizer!
            func innerScope() {
                killme = NSObject()
                p1 = afterCC(life: killme).done { _ in
                    XCTFail()
                }.catch(policy: .allErrors) {
                    $0.isCancelled ? ex1.fulfill() : XCTFail()
                }
                p2 = afterCC(life: killme).done { _ in
                    XCTFail()
                }.catch(policy: .allErrors) {
                    $0.isCancelled ? ex2.fulfill() : XCTFail()
                }
            }

            innerScope()

            after(.milliseconds(200)).done {
                p1.cancel()
                p2.cancel()
                killme = nil
            }
        }

        waitForExpectations(timeout: 1)
    }
}

private class Foo: NSObject {
    @objc dynamic var bar: String = "bar"
}
