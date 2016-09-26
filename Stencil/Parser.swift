public func until(_ tags: [String]) -> ((TokenParser, Token) -> Bool) {
    return { parser, token in
        if let name = token.components().first {
            for tag in tags {
                if name == tag {
                    return true
                }
            }
        }
        
        return false
    }
}

public enum Filter {
    case simpleFilter((Any?) throws -> Any?)
    case variadicFilter((Any?, [Any?]) throws -> Any?)
    
    public init(_ function: @escaping (Any?) throws -> Any?) {
        self = .simpleFilter(function)
    }
    
    public init(_ function: @escaping (Any?, [Any?]) throws -> Any?) {
        self = .variadicFilter(function)
    }
}

/// A class for parsing an array of tokens and converts them into a collection of Node's
public class TokenParser {
  public typealias TagParser = (TokenParser, Token) throws -> NodeType

  private var tokens: [Token]
  let namespace: Namespace

  public init(tokens: [Token], namespace: Namespace) {
    self.tokens = tokens
    self.namespace = namespace
  }

  /// Parse the given tokens into nodes
  public func parse() throws -> [NodeType] {
    return try parse(nil)
  }

  public func parse(_ parse_until:((TokenParser, Token) -> (Bool))?) throws -> [NodeType] {
    var nodes = [NodeType]()

    while tokens.count > 0 {
      let token = nextToken()!

      switch token {
      case .text(let text):
        nodes.append(TextNode(text: text))
      case .variable:
        nodes.append(VariableNode(variable: try compileFilter(token.contents)))
      case .block:
        let tag = token.components().first

        if let parse_until = parse_until , parse_until(self, token) {
          prependToken(token)
          return nodes
        }

        if let tag = tag {
          if let parser = namespace.tags[tag] {
            nodes.append(try parser(self, token))
          } else {
            throw TemplateSyntaxError("Unknown template tag '\(tag)'")
          }
        }
      case .comment:
        continue
      }
    }

    return nodes
  }

  @discardableResult public func nextToken() -> Token? {
    if tokens.count > 0 {
      return tokens.remove(at: 0)
    }

    return nil
  }

  public func prependToken(_ token:Token) {
    tokens.insert(token, at: 0)
  }

  public func findFilter(name: String) throws -> Filter {
    if let filter = namespace.filters[name] {
      return filter
    }

    throw TemplateSyntaxError("Invalid filter '\(name)'")
  }

  func compileFilter(_ token: String) throws -> Resolvable {
    return try FilterExpression(token: token, parser: self)
  }
}
