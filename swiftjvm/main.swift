//
//  main.swift
//  swiftjvm
//
//  Created by Daniel DeCovnick on 7/26/23.
//

import Foundation

// Collect classpath from the directories containing each .class file argument
var classpathURLs: [URL] = []
var classFiles: [(URL, Data)] = []

for argument in CommandLine.arguments.dropFirst() {
    let url = URL(filePath: argument)
    guard url.pathExtension == "class",
          let data = try? Data(contentsOf: url) else { continue }
    let dir = url.deletingLastPathComponent()
    if !classpathURLs.contains(dir) {
        classpathURLs.append(dir)
    }
    classFiles.append((url, data))
}

Runtime.vm
var vm = VM(classpath: classpathURLs)

for (url, data) in classFiles {
    do {
        if let classFile = try ClassFile(withData: data) {
            vm.loadClass(classFile)
        }
    } catch let e as ClassFileError {
        fputs("warning: \(url.lastPathComponent): \(e)\n", stderr)
    }
}

vm.start()

