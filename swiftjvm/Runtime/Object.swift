//
//  Object.swift
//  swiftjvm

import Foundation

class Object {
    let clazz: Class
    var instanceFields: [String: Value]

    init(clazz: Class) {
        self.clazz = clazz
        var fields: [String: Value] = [:]
        for field in clazz.allInstanceFields() {
            let desc = field.descriptor.string as String
            let defaultValue: Value
            switch desc.first {
            case "J":        defaultValue = .long(0)
            case "F":        defaultValue = .float(0)
            case "D":        defaultValue = .double(0)
            case "L", "[":   defaultValue = .reference(nil)
            default:         defaultValue = .int(0)   // I B C S Z
            }
            fields[field.name.string as String] = defaultValue
        }
        self.instanceFields = fields
    }
}
