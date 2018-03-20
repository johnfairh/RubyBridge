//
//  RbNumericConversions.swift
//  RubyGateway
//
//  Distributed under the MIT license, see LICENSE
//

// This file has tedious repetitions of the numeric convertible conformance
// and their doc comments for the fixed-width integer types and float.

// MARK: - Fixed-width Unsigned Integer

extension UInt64: RbObjectConvertible {
    /// Try to get a 64-bit unsigned integer representation of an `RbObject`.
    ///
    /// It fails if the Ruby value:
    /// 1. Is numeric and negative; or
    /// 2. Is numeric, positive, and does not fit into the Swift type; or
    /// 3. Cannot be made into a suitable numeric via `to_int` or `to_i`.
    ///
    /// See `RbError.history` to find out why a conversion failed.
    ///
    /// If the Ruby value is floating-point then the integer part is used.
    public init?(_ value: RbObject) {
        guard let actual = UInt(value) else {
            return nil
        }
        self.init(actual)
    }

    /// A Ruby object for the number.
    public var rubyObject: RbObject {
        return UInt(self).rubyObject
    }
}

extension UInt32: RbObjectConvertible {
    /// Try to get a 32-bit unsigned integer representation of an `RbObject`.
    ///
    /// It fails if the Ruby value:
    /// 1. Is numeric and negative; or
    /// 2. Is numeric, positive, and does not fit into the Swift type; or
    /// 3. Cannot be made into a suitable numeric via `to_int` or `to_i`.
    ///
    /// See `RbError.history` to find out why a conversion failed.
    ///
    /// If the Ruby value is floating-point then the integer part is used.
    public init?(_ value: RbObject) {
        guard let actual = UInt(value) else {
            return nil
        }
        self.init(exactly: actual)
    }

    /// A Ruby object for the number.
    public var rubyObject: RbObject {
        return UInt(self).rubyObject
    }
}

extension UInt16: RbObjectConvertible {
    /// Try to get a 16-bit unsigned integer representation of an `RbObject`.
    ///
    /// It fails if the Ruby value:
    /// 1. Is numeric and negative; or
    /// 2. Is numeric, positive, and does not fit into the Swift type; or
    /// 3. Cannot be made into a suitable numeric via `to_int` or `to_i`.
    ///
    /// See `RbError.history` to find out why a conversion failed.
    ///
    /// If the Ruby value is floating-point then the integer part is used.
    public init?(_ value: RbObject) {
        guard let actual = UInt(value) else {
            return nil
        }
        self.init(exactly: actual)
    }

    /// A Ruby object for the number.
    public var rubyObject: RbObject {
        return UInt(self).rubyObject
    }
}

extension UInt8: RbObjectConvertible {
    /// Try to get an 8-bit unsigned integer representation of an `RbObject`.
    ///
    /// It fails if the Ruby value:
    /// 1. Is numeric and negative; or
    /// 2. Is numeric, positive, and does not fit into the Swift type; or
    /// 3. Cannot be made into a suitable numeric via `to_int` or `to_i`.
    ///
    /// See `RbError.history` to find out why a conversion failed.
    ///
    /// If the Ruby value is floating-point then the integer part is used.
    public init?(_ value: RbObject) {
        guard let actual = UInt(value) else {
            return nil
        }
        self.init(exactly: actual)
    }

    /// A Ruby object for the number.
    public var rubyObject: RbObject {
        return UInt(self).rubyObject
    }
}

// MARK: - Fixed-width Signed Integer

extension Int64: RbObjectConvertible {
    /// Try to get a 64-bit signed integer representation of an `RbObject`.
    ///
    /// It fails if the Ruby value:
    /// 1. Is numeric and does not fit into the Swift type; or
    /// 2. Cannot be made into a suitable numeric via `to_int` or `to_i`.
    ///
    /// See `RbError.history` to find out why a conversion failed.
    ///
    /// If the Ruby value is floating-point then the integer part is used.
    public init?(_ value: RbObject) {
        guard let actual = Int(value) else {
            return nil
        }
        self.init(exactly: actual)
    }

    /// A Ruby object for the number.
    public var rubyObject: RbObject {
        return Int(self).rubyObject
    }
}

extension Int32: RbObjectConvertible {
    /// Try to get a 32-bit signed integer representation of an `RbObject`.
    ///
    /// It fails if the Ruby value:
    /// 1. Is numeric and does not fit into the Swift type; or
    /// 2. Cannot be made into a suitable numeric via `to_int` or `to_i`.
    ///
    /// See `RbError.history` to find out why a conversion failed.
    ///
    /// If the Ruby value is floating-point then the integer part is used.
    public init?(_ value: RbObject) {
        guard let actual = Int(value) else {
            return nil
        }
        self.init(exactly: actual)
    }

    /// A Ruby object for the number.
    public var rubyObject: RbObject {
        return Int(self).rubyObject
    }
}

extension Int16: RbObjectConvertible {
    /// Try to get a 16-bit signed integer representation of an `RbObject`.
    ///
    /// It fails if the Ruby value:
    /// 1. Is numeric and does not fit into the Swift type; or
    /// 2. Cannot be made into a suitable numeric via `to_int` or `to_i`.
    ///
    /// See `RbError.history` to find out why a conversion failed.
    ///
    /// If the Ruby value is floating-point then the integer part is used.
    public init?(_ value: RbObject) {
        guard let actual = Int(value) else {
            return nil
        }
        self.init(exactly: actual)
    }

    /// A Ruby object for the number.
    public var rubyObject: RbObject {
        return Int(self).rubyObject
    }
}

extension Int8: RbObjectConvertible {
    /// Try to get an 8-bit signed integer representation of an `RbObject`.
    ///
    /// It fails if the Ruby value:
    /// 1. Is numeric and does not fit into the Swift type; or
    /// 2. Cannot be made into a suitable numeric via `to_int` or `to_i`.
    ///
    /// See `RbError.history` to find out why a conversion failed.
    ///
    /// If the Ruby value is floating-point then the integer part is used.
    public init?(_ value: RbObject) {
        guard let actual = Int(value) else {
            return nil
        }
        self.init(exactly: actual)
    }

    /// A Ruby object for the number.
    public var rubyObject: RbObject {
        return Int(self).rubyObject
    }
}

// MARK: - Float

extension Float: RbObjectConvertible {
    /// Try to get a `Float` floating-point representation of an `RbObject`.
    ///
    /// It fails if the Ruby value:
    /// 1. Is numeric and does not fit into the Swift type; or
    /// 2. Cannot be made into a suitable numeric via `to_f`.
    ///
    /// See `RbError.history` to find out why a conversion failed.
    ///
    /// Flavors of NaN are not preserved across the Ruby<->Swift interface.
    public init?(_ value: RbObject) {
        guard let actual = Double(value) else {
            return nil
        }
        if actual.isNaN {
            self.init()
            self = .nan
        } else {
            self.init(exactly: actual)
        }
    }

    /// A Ruby object for the number.
    public var rubyObject: RbObject {
        return Double(self).rubyObject
    }
}
