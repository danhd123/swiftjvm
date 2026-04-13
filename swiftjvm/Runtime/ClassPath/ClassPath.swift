//
//  ClassPath.swift
//  swiftjvm
//
//  Created by Daniel DeCovnick on 9/17/23.
//

import Foundation

class ClassPath {
    
    class Entry {
        
    }
    
    enum ClassLoadingError: Error {
        case classFileNotFound(String)
        case dataLoadingError(String)
        case invalidEntry(String)
    }

    var entries : [Entry]

    init(entries: [Entry] = []) {
        self.entries = entries
    }
}
