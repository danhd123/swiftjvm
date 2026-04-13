//
//  FileSystemClassPathEntry.swift
//  swiftjvm
//
//  Created by Daniel DeCovnick on 9/18/23.
//

import Foundation

class FileSystemClassPathEntry : ClassPathEntry {
    
    let basePath: URL
    
    init(basePath: URL) {
        self.basePath = basePath
    }
    
    func resolve(_ className: String) -> Result<Data, ClassPath.ClassLoadingError> {
        let pathURL = basePath.appending(path:className + ".class")
        let path = pathURL.path()
        if FileManager.default.fileExists(atPath: path) {
            do {
                return try .success(Data(contentsOf: pathURL))
            } catch {
                print("failed to laod class from disk \(error)")
                return .failure(.dataLoadingError(path))
            }
        } else {
            return .failure(.classFileNotFound(className))
        }
    }
    
    
    
    
}
