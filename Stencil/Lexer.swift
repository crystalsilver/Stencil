public struct Lexer {
  public let templateString: String

  public init(templateString: String) {
    self.templateString = templateString
  }

  func createToken(_ string:String) -> Token {
    func strip() -> String {
      return string[string.index(string.startIndex, offsetBy: 2)..<string.index(string.endIndex, offsetBy: -2)].trim(" ")
    }

    // this cannot be a special tag unless it has more than 4 characters. (prevents crash on strip method for incomplete tags)
    if string.characters.count > 4 {
        if string.hasPrefix("{{") {
            return Token.variable(value: strip())
        } else if string.hasPrefix("{%") {
            return Token.block(value: strip())
        } else if string.hasPrefix("{#") {
            return Token.comment(value: strip())
        }
    }

    return Token.text(value: string)
  }

  /// Returns an array of tokens from a given template string.
  public func tokenize() -> [Token] {
    var tokens: [Token] = []

    let scanner = Scanner(templateString)

    let map = [
      "{{": "}}",
      "{%": "%}",
      "{#": "#}",
    ]

    var parseRaw = false
    
    func append(_ token: Token) {
        if case .block(let value) = token , value == "raw" {
            parseRaw = true
        }
        tokens.append(token)
    }
    
    func create(_ string: String) -> Token {
        let token = createToken(string)
        if case .block(let value) = token , value == "endraw" {
            parseRaw = false
        }
        else if parseRaw {
            return Token.text(value: string)
        }
        
        return token
    }
    
    while !scanner.atEnd {
      let (match, result)  = scanner.scan(until: ["{{", "{%", "{#"])
      if let match = match {
        if !result.isEmpty {
          append(create(result))
        }

        let end = map[match]!
        let result = scanner.scan(until: end, returnUntil: true)
        append(create(result))
      } else {
        append(create(result))
      }
    }

    return tokens
  }
}


class Scanner {
  let content: String

  init(_ content: String) {
    self.content = content
    self.scanLocation = content.startIndex
  }

  var atEnd: Bool {
    return scanLocation == content.endIndex
  }
    
  var scanLocation: String.Index

  func scan(until: String, returnUntil: Bool = false) -> String {
    if until.isEmpty {
      return ""
    }

    let currentStartLocation = scanLocation
    while scanLocation != content.endIndex {
        let substring = content.substring(with: scanLocation..<content.endIndex)
      if substring.hasPrefix(until) {
        let result = content.substring(with: currentStartLocation..<scanLocation)
        if returnUntil {
          scanLocation = content.index(scanLocation, offsetBy: until.characters.count)
          return result + until
        }
        return result
      }

        scanLocation = content.index(after: scanLocation)
    }

    return ""
  }

  func scan(until: [String]) -> (String?, String) {
    if until.isEmpty {
        return (nil, content.substring(with: scanLocation..<content.endIndex))
    }

    let currentStartLocation = scanLocation
    while scanLocation != content.endIndex {
        let substring = content.substring(with: scanLocation..<content.endIndex)
      for string in until {
        if substring.hasPrefix(string) {
            let result = content.substring(with: currentStartLocation..<scanLocation)
          return (string, result)
        }
      }

        scanLocation = content.index(after: scanLocation)
    }

    return (nil, content.substring(with: currentStartLocation..<scanLocation))
  }
}
