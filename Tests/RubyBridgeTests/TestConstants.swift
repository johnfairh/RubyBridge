//
//  TestConstants.swift
//  RubyBridgeTests
//
//  Distributed under the MIT license, see LICENSE
//

import XCTest
@testable import RubyBridge

/// Some misc primitives
class TestConstants: XCTestCase {

    func testNilConstants() {
        let nilVal = Qnil
        let falseVal = Qfalse
        let trueVal = Qtrue

        XCTAssertTrue(RB_NIL_P(nilVal))
        XCTAssertFalse(RB_NIL_P(falseVal))
        XCTAssertFalse(RB_NIL_P(trueVal))

        XCTAssertFalse(RB_TEST(nilVal))
        XCTAssertFalse(RB_TEST(falseVal))
        XCTAssertTrue(RB_TEST(trueVal))

        XCTAssertEqual(.T_NIL, TYPE(nilVal))
        XCTAssertEqual(.T_FALSE, TYPE(falseVal))
        XCTAssertEqual(.T_TRUE, TYPE(trueVal))
    }

    static var allTests = [
        ("testNilConstants", testNilConstants),
    ]
}
