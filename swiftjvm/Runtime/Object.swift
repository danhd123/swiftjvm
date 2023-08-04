//
//  Object.swift
//  swiftjvm
//
//  Created by Daniel DeCovnick on 8/2/23.
//

import Foundation

class Object {
    let clazz: ClassFile
    let fields: [Field]
    
    init(clazz: ClassFile) {
        self.clazz = clazz
        fields = []
    }
    
    
}
