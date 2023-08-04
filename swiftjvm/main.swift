//
//  main.swift
//  swiftjvm
//
//  Created by Daniel DeCovnick on 7/26/23.
//

import Foundation

var vm = VM()

var mainFound = false
for argument in CommandLine.arguments {
    let url = URL.init(filePath: argument)
    if url.lastPathComponent == "swiftjvm" {
        continue
    }
    let data = try! Data(contentsOf: url)
    let classFile = ClassFile(withData: data)
    if let classFile {
        print("\(classFile)")
        vm.loadClass(classFile)
    }
    vm.start()
    
}
