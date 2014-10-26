//
//  Result.swift
//  Stencil
//
//  Created by Marius Rackwitz on 26/10/14.
//  Copyright (c) 2014 Cocode. All rights reserved.
//

import Foundation

public protocol Error : Printable {
    
}

public func ==(lhs:Error, rhs:Error) -> Bool {
    return lhs.description == rhs.description
}

public enum Result : Equatable {
    case Success(string: String)
    case Error(error: Stencil.Error)
}

public func ==(lhs:Result, rhs:Result) -> Bool {
    switch (lhs, rhs) {
    case (.Success(let lhsValue), .Success(let rhsValue)):
        return lhsValue == rhsValue
    case (.Error(let lhsValue), .Error(let rhsValue)):
        return lhsValue == rhsValue
    default:
        return false
    }
}