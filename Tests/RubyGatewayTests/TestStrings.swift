//
//  TestStrings.swift
//  RubyGatewayTests
//
//  Distributed under the MIT license, see LICENSE
//

import XCTest
import RubyBridge
import CRuby

/// Tests for String helpers
class TestStrings: XCTestCase {

    private func doTestRoundTrip(_ string: String) {
        let rubyObj = RbObject(string)
        XCTAssertEqual(.T_STRING, rubyObj.rubyType)

        guard let backString = String(rubyObj) else {
            XCTFail("Oops, to_s failed??")
            return
        }
        XCTAssertEqual(string, backString)
    }

    func testEmpty() {
        doTestRoundTrip("")
    }

    func testAscii() {
        doTestRoundTrip("A test string")
    }

    func testUtf8() {
        doTestRoundTrip("abë🐽🇧🇷end")
    }

    func testUtf8WithNulls() {
        doTestRoundTrip("abë\0🐽🇧🇷en\0d")
    }

    func testFailedStringConversion() {
        try! Ruby.require(filename: Helpers.fixturePath("nonconvert.rb"))

        guard let instance = RbObject(ofClass: "Nonconvert") else {
            XCTFail("Couldn't create object")
            return
        }
        XCTAssertEqual(.T_OBJECT, instance.rubyType)
        
        if let str = String(instance) {
            XCTFail("Converted unconvertible: \(str)")
        }
        let descr = instance.description
        XCTAssertNotEqual("", descr)
    }

    // to_s, to_str, priority
    func testConversion() {
        try! Ruby.require(filename: Helpers.fixturePath("nonconvert.rb"))

        guard let i1 = RbObject(ofClass: "JustToS"),
              let i2 = RbObject(ofClass: "BothToSAndToStr") else {
            XCTFail("Couldn't create objects")
            return
        }

        guard let _ = String(i1) else {
            XCTFail("Couldn't convert JustToS")
            return
        }

        guard let s2 = String(i2) else {
            XCTFail("Couldn't convert BothToSAndToStr")
            return
        }

        XCTAssertEqual("to_str", s2)
    }

    func testLiteralPromotion() {
        let obj: RbObject = "test string"
        XCTAssertEqual("test string", String(obj))
    }

    static var allTests = [
        ("testEmpty", testEmpty),
        ("testAscii", testAscii),
        ("testUtf8", testUtf8),
        ("testUtf8WithNulls", testUtf8WithNulls),
        ("testFailedStringConversion", testFailedStringConversion),
        ("testConversion", testConversion),
        ("testLiteralPromotion", testLiteralPromotion)
    ]
}
