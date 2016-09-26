//
//  String+Extensions.swift
//  Spelt
//
//  Created by Niels de Hoog on 24/11/15.
//  Copyright © 2015 Invisible Pixel. All rights reserved.
//

import Foundation

extension String {
    func findFirstNot(_ character: Character) -> String.Index? {
        var index = startIndex
        while index != endIndex {
            if character != self[index] {
                return index
            }
            index = self.index(after: index)
        }
        
        return nil
    }
    
    func findLastNot(_ character: Character) -> String.Index? {
        var index = characters.index(before: endIndex)
        while index != startIndex {
            if character != self[index] {
                return self.index(after: index)
            }
            index = self.index(before: index)
        }
        
        return nil
    }
    
    func trim(_ character: Character) -> String {
        guard let first = findFirstNot(character) else {
            return ""
        }
        
        let last = findLastNot(character) ?? endIndex
        return self[first..<last]
    }
    
    func split(_ separator: Character, respectQuotes: Bool = false) -> [String] {
        guard respectQuotes == true else {
            return characters.split(separator: separator).map(String.init)
        }
        
        // if respectQuotes is true, leave quoted phrases together
        var word = ""
        var components: [String] = []
        
        let scanner = Scanner(self)
        while !scanner.atEnd {
            let (match, result) = scanner.scan(until: [String(separator), "'", "\""])
            if let match = match {
                switch match {
                case "'", "\"":
                    word += result + match
                    _ = scanner.scan(until: match, returnUntil: true)
                    let result = scanner.scan(until: match, returnUntil: true)
                    if !result.isEmpty {
                        word += result
                    }
                    if scanner.atEnd {
                        components.append(word)
                    }
                case String(separator):
                    // add to components
                    word += result
                    components.append(word)
                    word = ""
                    _ = scanner.scan(until: String(separator), returnUntil: true)
                    break
                default:
                    break
                }
            }
            else {
                word += result
                components.append(word)
            }
        }
        
        return components
    }
    
    func splitAndTrimWhitespace(_ separator: Character, respectQuotes: Bool = false) -> [String] {
        return split(separator, respectQuotes: respectQuotes).map({ $0.trim(" ") })
    }
}
