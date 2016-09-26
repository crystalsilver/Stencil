import Foundation

public enum Token : Equatable {
  /// A token representing a piece of text.
  case text(value: String)

  /// A token representing a variable.
  case variable(value: String)

  /// A token representing a comment.
  case comment(value: String)

  /// A token representing a template block.
  case block(value: String)

  /// Returns the underlying value as an array seperated by spaces
  public func components() -> [String] {
    switch self {
    case .block(let value):
      return value.splitAndTrimWhitespace(" ", respectQuotes: true)
    case .variable(let value):
        return value.splitAndTrimWhitespace(" ", respectQuotes: true)
    case .text(let value):
        return value.splitAndTrimWhitespace(" ", respectQuotes: true)
    case .comment(let value):
        return value.splitAndTrimWhitespace(" ", respectQuotes: true)
    }
  }

  public var contents: String {
    switch self {
    case .block(let value):
      return value
    case .variable(let value):
      return value
    case .text(let value):
      return value
    case .comment(let value):
      return value
    }
  }
}


public func == (lhs: Token, rhs: Token) -> Bool {
  switch (lhs, rhs) {
  case (.text(let lhsValue), .text(let rhsValue)):
    return lhsValue == rhsValue
  case (.variable(let lhsValue), .variable(let rhsValue)):
    return lhsValue == rhsValue
  case (.block(let lhsValue), .block(let rhsValue)):
    return lhsValue == rhsValue
  case (.comment(let lhsValue), .comment(let rhsValue)):
    return lhsValue == rhsValue
  default:
    return false
  }
}
