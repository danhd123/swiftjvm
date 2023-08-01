//
//  main.swift
//  swiftjvm
//
//  Created by Daniel DeCovnick on 7/26/23.
//

import Foundation

print("Hello, World!")
let url = URL.init(filePath: "/Users/danielhd/src/swiftjvm/swiftjvm/Tests/Complex.class")
let data = try! Data(contentsOf: url)
let complex = ClassFile(withData: data)
print("\(complex)")
