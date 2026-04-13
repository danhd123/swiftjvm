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
    
    func loadClassNamed(_ name: String,) -> Class {
        let loadableClasses = Runtime.vm.methodArea
        for loadableClass in loadableClasses {
            let className = loadableClass.className
            guard name == className else { continue }
        }
    }
}
