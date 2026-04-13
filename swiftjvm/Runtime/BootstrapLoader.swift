//
//  BoostrapLoader.swift
//  swiftjvm
//
//  Created by Daniel DeCovnick on 8/4/23.
//

import Foundation

class BootstrapLoader : Loader {
//    static func == (lhs: BoostrapLoader, rhs: BoostrapLoader) -> Bool {
//        return true
//    }
    
    func loadClassNamed(_ name: String) -> Class {
        if let cls = Runtime.vm.classLoader.loadedClasses[name] {
            return cls
        }
        fatalError("Class not found: \(name)")
    }
}
