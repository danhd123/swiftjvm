//
//  Field.swift
//  swiftjvm
//
//  Created by Daniel DeCovnick on 8/3/23.
//

import Foundation

struct Field {
    let kind: FieldInfo
    var data: Data
    init(kind: FieldInfo) {
        self.kind = kind
        self.data = Data(capacity: Int(FieldDescriptor(constant: kind.descriptor).size))
    }
}
