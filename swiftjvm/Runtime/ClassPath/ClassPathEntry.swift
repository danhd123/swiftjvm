//
//  ClassPathEntry.swift
//  swiftjvm
//
//  Created by Daniel DeCovnick on 9/17/23.
//

import Foundation

protocol ClassPathEntry {
    func resolve(_ className: String) -> Result<Data, ClassPath.ClassLoadingError>
}

