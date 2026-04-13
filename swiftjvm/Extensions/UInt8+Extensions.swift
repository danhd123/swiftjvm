//
//  UInt8+Extensions.swift
//  swiftjvm
//
//  Created by Daniel DeCovnick on 4/13/26.
//


extension UInt8: @retroactive ExpressibleByExtendedGraphemeClusterLiteral {}
extension UInt8: @retroactive ExpressibleByUnicodeScalarLiteral {}
extension UInt8 : @retroactive ExpressibleByStringLiteral {
    public typealias ExtendedGraphemeClusterLiteralType = String
    public typealias UnicodeScalarLiteralType = String

    public init(stringLiteral value: StringLiteralType){
        self.init(([UInt8]() + value.utf8)[0])
    }

    public init(extendedGraphemeClusterLiteral value: String){
        self.init(([UInt8]() + value.utf8)[0])
    }

    public init(unicodeScalarLiteral value: String){
        self.init(([UInt8]() + value.utf8)[0])
    }
}
