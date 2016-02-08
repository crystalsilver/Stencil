public struct Lexer {
  public let templateString: String

  public init(templateString: String) {
    self.templateString = templateString
  }

  func createToken(string:String) -> Token {
    func strip() -> String {
      return string[string.startIndex.successor().successor()..<string.endIndex.predecessor().predecessor()].trim(" ")
    }

    // this cannot be a special tag unless it has more than 4 characters. (prevents crash on strip method for incomplete tags)
    if string.characters.count > 4 {
        if string.hasPrefix("{{") {
            return Token.Variable(value: strip())
        } else if string.hasPrefix("{%") {
            return Token.Block(value: strip())
        } else if string.hasPrefix("{#") {
            return Token.Comment(value: strip())
        }
    }

    return Token.Text(value: string)
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
    
    func append(token: Token) {
        if case .Block(let value) = token where value == "raw" {
            parseRaw = true
        }
        tokens.append(token)
    }
    
    func create(string: String) -> Token {
        let token = createToken(string)
        if case .Block(let value) = token where value == "endraw" {
            parseRaw = false
        }
        else if parseRaw {
            return Token.Text(value: string)
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

  func scan(until until: String, returnUntil: Bool = false) -> String {
    if until.isEmpty {
      return ""
    }

    let currentStartLocation = scanLocation
    while scanLocation != content.endIndex {
      let substring = content[scanLocation..<content.endIndex]
      if substring.hasPrefix(until) {
        let result = content[currentStartLocation..<scanLocation]
        if returnUntil {
          scanLocation = scanLocation.advancedBy(until.characters.count)
          return result + until
        }
        return result
      }

        scanLocation = scanLocation.successor()
    }

    return ""
  }

  func scan(until until: [String]) -> (String?, String) {
    if until.isEmpty {
        return (nil, content[scanLocation..<content.endIndex])
    }

    let currentStartLocation = scanLocation
    while scanLocation != content.endIndex {
      let substring = content[scanLocation..<content.endIndex]
      for string in until {
        if substring.hasPrefix(string) {
          let result = content[currentStartLocation..<scanLocation]
          return (string, result)
        }
      }

      scanLocation = scanLocation.successor()
    }

    return (nil, content[currentStartLocation..<scanLocation])
  }
}
