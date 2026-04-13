//
//  LocalVariable.swift
//  swiftjvm
//
//  Created by Daniel DeCovnick on 8/2/23.
//

struct LocalVariable {
    var value: Value?

    init(_ value: Value? = nil) {
        self.value = value
    }
}
