import Foundation

public struct TemplateSyntaxError : Error, Equatable, CustomStringConvertible {
  public let description:String

  public init(_ description:String) {
    self.description = description
  }
}

public func ==(lhs:TemplateSyntaxError, rhs:TemplateSyntaxError) -> Bool {
  return lhs.description == rhs.description
}

public protocol NodeType {
  /// Render the node in the given context
  func render(_ context:Context) throws -> String
}

/// Render the collection of nodes in the given context
public func renderNodes(_ nodes:[NodeType], _ context:Context) throws -> String {
  return try nodes.map { try $0.render(context) }.joined(separator: "")
}

public class SimpleNode : NodeType {
  let handler:(Context) throws -> String

  public init(handler:@escaping (Context) throws -> String) {
    self.handler = handler
  }

  public func render(_ context: Context) throws -> String {
    return try handler(context)
  }
}

public class TextNode : NodeType {
  public let text:String

  public init(text:String) {
    self.text = text
  }

  public func render(_ context:Context) throws -> String {
    return self.text
  }
}

public protocol Resolvable {
  func resolve(_ context: Context) throws -> Any?
}

public class VariableNode : NodeType {
  public let variable: Resolvable

  public init(variable: Resolvable) {
    self.variable = variable
  }

  public init(variable: String) {
    self.variable = Variable(variable)
  }

  public func render(_ context: Context) throws -> String {
    let result = try variable.resolve(context)

    if let result = result as? String {
      return result
    } else if let result = result as? CustomStringConvertible {
      return result.description
    } else if let result = result as? NSObject {
      return result.description
    }

    return ""
  }
}

public class NowNode : NodeType {
  public let format:Variable

  public class func parse(parser:TokenParser, token:Token) throws -> NodeType {
    var format:Variable?

    let components = token.components()
    guard components.count <= 2 else {
      throw TemplateSyntaxError("'now' tags may only have one argument: the format string `\(token.contents)`.")
    }
    if components.count == 2 {
      format = Variable(components[1])
    }

    return NowNode(format:format)
  }

  public init(format:Variable?) {
    self.format = format ?? Variable("\"yyyy-MM-dd 'at' HH:mm\"")
  }

  public func render(_ context: Context) throws -> String {
    let date = Date()
    let format = try self.format.resolve(context)
    var formatter:DateFormatter?

    if let format = format as? DateFormatter {
      formatter = format
    } else if let format = format as? String {
      formatter = DateFormatter()
      formatter!.dateFormat = format
    } else {
      return ""
    }

    return formatter!.string(from: date)
  }
}

public class ForNode : NodeType {
  let variable:Variable
  let loopVariable:String
  let nodes:[NodeType]
  let emptyNodes: [NodeType]
  let limit: Int?

  public class func parse(parser:TokenParser, token:Token) throws -> NodeType {
    let components = token.components()

    guard components[2] == "in" && (components.count == 4 || (components.count == 5 && components[4].hasPrefix("limit")))  else {
      throw TemplateSyntaxError("'for' statements should use the following 'for x in y (limit: n)' `\(token.contents)`.")
    }

    let loopVariable = components[1]
    let variable = components[3]

    var limit: Int? = nil
    if components.count == 5 {
        let limitComponents = components[4].splitAndTrimWhitespace(":")
        if limitComponents.count == 2 {
            limit = Int(limitComponents[1])
        }
    }
    
    var emptyNodes = [NodeType]()

    let forNodes = try parser.parse(until(["endfor", "empty"]))

    guard let token = parser.nextToken() else {
      throw TemplateSyntaxError("`endfor` was not found.")
    }

    if token.contents == "empty" {
      emptyNodes = try parser.parse(until(["endfor"]))
      parser.nextToken()
    }

    return ForNode(variable: variable, loopVariable: loopVariable, nodes: forNodes, emptyNodes:emptyNodes, limit: limit)
  }

  public init(variable:String, loopVariable:String, nodes:[NodeType], emptyNodes:[NodeType], limit: Int? = nil) {
    self.variable = Variable(variable)
    self.loopVariable = loopVariable
    self.nodes = nodes
    self.emptyNodes = emptyNodes
    self.limit = limit
  }

  public func render(_ context: Context) throws -> String {
    let values = try variable.resolve(context)

    if let values = values as? [Any] , values.count > 0 {
      let limitedValues: [Any]
      if let limit = limit {
        limitedValues = Array(values[0..<min(limit, values.count)])
      }
      else {
        limitedValues = values
      }
      return try limitedValues.map { item in
        try context.push([loopVariable: item]) {
          try renderNodes(nodes, context)
        }
      }.joined(separator: "")
    }

    return try context.push {
      try renderNodes(emptyNodes, context)
    }
  }
}

public class IfNode : NodeType {
  public let leftArgument:Variable
  public let rightArgument: Variable?
  let comparisonOperator: ComparisonOperatorType?
  public let trueNodes:[NodeType]
  public let falseNodes:[NodeType]

  public class func parse(parser:TokenParser, token:Token) throws -> NodeType {
    let components = token.components()
    guard components.count == 2 || components.count == 4 else {
      throw TemplateSyntaxError("'if' statements should use the following 'if value (== otherValue)', not: '\(token.contents)'.")
    }
    
    let leftArgument = components[1]
    let rightArgument: String? = components.count == 4 ? components[3] : nil
    let comparisonOperator: ComparisonOperatorType? = components.count == 4 ? ComparisonOperatorType(rawValue: components[2]) : nil
    
    guard (rightArgument != nil && comparisonOperator == nil) == false else {
        throw TemplateSyntaxError("\(components[2]) comparison operator is not (currently) supported.")
    }
    
    var trueNodes = [NodeType]()
    var falseNodes = [NodeType]()

    trueNodes = try parser.parse(until(["endif", "else"]))

    guard let token = parser.nextToken() else {
      throw TemplateSyntaxError("`endif` was not found.")
    }

    if token.contents == "else" {
      falseNodes = try parser.parse(until(["endif"]))
      parser.nextToken()
    }

    return IfNode(leftArgument: leftArgument, rightArgument: rightArgument, comparisonOperator: comparisonOperator, trueNodes: trueNodes, falseNodes: falseNodes)
  }

  public class func parse_ifnot(parser:TokenParser, token:Token) throws -> NodeType {
    let components = token.components()
    guard components.count == 2 else {
      throw TemplateSyntaxError("'ifnot' statements should use the following 'if condition' `\(token.contents)`.")
    }
    let variable = components[1]
    var trueNodes = [NodeType]()
    var falseNodes = [NodeType]()

    falseNodes = try parser.parse(until(["endif", "else"]))

    guard let token = parser.nextToken() else {
      throw TemplateSyntaxError("`endif` was not found.")
    }

    if token.contents == "else" {
      trueNodes = try parser.parse(until(["endif"]))
      parser.nextToken()
    }

    return IfNode(leftArgument: variable, trueNodes: trueNodes, falseNodes: falseNodes)
  }

  public init(leftArgument: String, rightArgument: String? = nil, comparisonOperator: ComparisonOperatorType? = nil, trueNodes:[NodeType], falseNodes:[NodeType]) {
    self.leftArgument = Variable(leftArgument)
    self.rightArgument = rightArgument.map() { Variable($0) }
    self.comparisonOperator = comparisonOperator
    self.trueNodes = trueNodes
    self.falseNodes = falseNodes
  }

  public func render(_ context: Context) throws -> String {
    let resolver = IfNodeResolver(leftArgument: leftArgument, rightArgument: rightArgument, comparisonOperator: comparisonOperator)
    context.push()
    let output:String
    if try resolver.isTruthy(context) {
      output = try renderNodes(trueNodes, context)
    } else {
      output = try renderNodes(falseNodes, context)
    }
    context.pop()

    return output
  }
}

public enum ComparisonOperatorType: String {
    case Equality = "=="
}

struct IfNodeResolver {
    let leftArgument: Variable
    let rightArgument: Variable?
    let comparisonOperator: ComparisonOperatorType?
    
    func isTruthy(_ context: Context) throws -> Bool {
        let resolvedLeftArgument = try leftArgument.resolve(context)
        if let rightArgument = rightArgument {
            let resolvedRightArgument = try rightArgument.resolve(context)
            return isTruthy(resolvedLeftArgument, rightArgument: resolvedRightArgument, comparisonOperator: comparisonOperator!)
        }
        else {
            return isTruthy(object: resolvedLeftArgument)
        }
    }
    
    private func isTruthy(object: Any?) -> Bool {
        guard let object = object else {
            return false
        }
        
        var truthy = true
        
        if let array = object as? [Any] {
            truthy = !array.isEmpty
        }
        else if let dictionary = object as? [String:Any] {
            truthy = !dictionary.isEmpty
        }
        else if let string = object as? String {
            truthy = !string.isEmpty
        }
        else if let bool = object as? Bool {
            truthy = bool
        }
        else if let int = object as? Int {
            truthy = (int > 0)
        }
        else if let double = object as? Double {
            truthy = (double > 0.0)
        }
        
        return truthy
    }
    
    private func isTruthy(_ leftArgument: Any?, rightArgument: Any?, comparisonOperator: ComparisonOperatorType) -> Bool {
        switch comparisonOperator {
        case .Equality:
            return isEqual(leftArgument, rightArgument)
        }
    }
    
    private func isEqual(_ leftArgument: Any?, _ rightArgument: Any?) -> Bool {
        guard let left = leftArgument, let right = rightArgument else {
            return (leftArgument == nil && rightArgument == nil)
        }
        
        if let leftArray = left as? [String] {
            if let rightArray = right as? [String] {
                return leftArray == rightArray
            }
        }
        else if let leftDictionary = left as? [String: String] {
            if let rightDictionary = right as? [String: String] {
                return leftDictionary == rightDictionary
            }
        }
        else if let leftString = left as? String {
            if let rightString = right as? String {
                return leftString == rightString
            }
        }
        else if let leftBool = left as? Bool {
            if let rightBool = right as? Bool {
                return leftBool == rightBool
            }
        }
        else if let leftInt = left as? Int {
            if let rightInt = right as? Int {
                return leftInt == rightInt
            }
        }
        else if let leftDouble = left as? Double {
            if let rightDouble = right as? Double {
                return leftDouble == rightDouble
            }
        }
        
        return false
    }
}
