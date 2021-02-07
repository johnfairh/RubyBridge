//
//  TestErrors.swift
//  RubyGatewayTests
//
//  Distributed under the MIT license, see LICENSE
//

import XCTest
@testable /* ErrHistory internals */ import RubyGateway

/// Tedious tests for error + exception classes
class TestErrors: XCTestCase {

    /// Description vagueness
    func testErrorPrinting() {
        let errStr = "ErrStr"
        let err = RbError.setup(errStr)
        XCTAssertTrue(err.description.contains(errStr))

        let err2 = RbError.badType(errStr)
        XCTAssertTrue(err2.description.contains(errStr))

        let errStrId = "ErrId"
        let err3 = RbError.badIdentifier(type: errStr, id: errStrId)
        XCTAssertTrue(err3.description.contains(errStr) && err3.description.contains(errStrId))

        let err4 = RbError.duplicateKwArg(errStr)
        XCTAssertTrue(err4.description.contains(errStr))

        let err5 = RbError.badParameter(errStr)
        XCTAssertTrue(err5.description.contains(errStr))

        let tagVal = Int32(22)
        let jmpErr = RbError.rubyJump(tagVal)
        XCTAssertTrue(jmpErr.description.contains(String(tagVal)))
    }

    /// Need this to avoid nutty 'code will never be executed' warning triggered
    /// by "-> Never"...
    private func raise(error: RbError) throws {
        try RbError.raise(error: error)
    }

    /// Error history basic
    func testErrorHistory() {
        let errStr = "ErrStr"
        let err = RbError.setup(errStr)

        try! Ruby.setup()
        RbError.history.clear()

        XCTAssertEqual(0, RbError.history.errors.count)
        XCTAssertNil(RbError.history.mostRecent)

        try? raise(error: err)

        XCTAssertEqual(1, RbError.history.errors.count)

        guard case let .setup(str) = RbError.history.mostRecent!,
              str == errStr else {
            XCTFail("Most recent exception wrong.")
            return
        }

        RbError.history.clear()

        XCTAssertEqual(0, RbError.history.errors.count)
        XCTAssertNil(RbError.history.mostRecent)
    }

    /// Error history wrap
    func testErrorHistoryLen() {

        RbError.history.clear()

        let err = RbError.setup("")

        let MAX_ERRORS = 12

        for n in 1...MAX_ERRORS {
            try? raise(error: err)
            XCTAssertEqual(n, RbError.history.errors.count)
        }

        try? raise(error: RbError.duplicateKwArg(""))
        XCTAssertEqual(MAX_ERRORS, RbError.history.errors.count)

        guard case .duplicateKwArg(_) = RbError.history.mostRecent! else {
            XCTFail("Most recent exception wrong.")
            return
        }
    }

    /// Ruby exception details
    func testRubyException() {
        RbError.history.clear()

        doErrorFree {
            try Ruby.require(filename: Helpers.fixturePath("raising.rb"))

            do {
                try Ruby.call("raiseString")
                XCTFail("Didn't raise")
                return
            } catch RbError.rubyException(let exn) {
                let btstr = exn.backtrace
                XCTAssertTrue(btstr[0].contains("raiseString"))
                XCTAssertTrue(btstr[0].contains("raising.rb:2"))
                XCTAssertEqual("RuntimeError: string", exn.description)
            }
        }
    }

    /// Ruby stack overflow
    func testRubyStackOverflow() {
        doErrorFree {
            try Ruby.require(filename: Helpers.fixturePath("raising.rb"))

            doError {
                let v = try Ruby.call("stackSmash")
                XCTFail("Got past stack overflow: \(v)")
            }
        }
    }

    /// Ruby exit call
    func testRubyExit() {
        doErrorFree {
            try Ruby.require(filename: Helpers.fixturePath("raising.rb"))

            doError {
                let v = try Ruby.call("doExit")
                XCTFail("Got past exit call : \(v)")
            }

            // Just check we haven't exitted Ruby...
            testRubyStackOverflow()
        }
    }
}
