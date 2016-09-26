import Foundation

struct FilterInvocation {
  let name: String
  let filter: Filter
  let arguments: [FilterArgument]
  
  func invoke(_ value: Any?, context: Context) throws -> Any? {
    switch filter {
    case .simpleFilter(let function):
        guard arguments.count == 0 else {
            throw TemplateSyntaxError("Filter '\(name)' expects no arguments. \(arguments.count) argument(s) received")
        }
        return try function(value)
    case .variadicFilter(let function):
        var resolvedArguments: [Any?] = []
        for argument in arguments {
            if let resolved = try argument.resolve(context) {
                resolvedArguments.append(resolved)
            }
            else {
                throw TemplateSyntaxError("Failed to resolve argument '\(argument.variable)' in \(name) filter")
            }
        }
        return try function(value, resolvedArguments)
    }
  }
}

class FilterExpression : Resolvable {
  let filterInvocations: [FilterInvocation]
  let variable: Variable

  init(token: String, parser: TokenParser) throws {
    let bits = token.splitAndTrimWhitespace("|", respectQuotes: true)
    if bits.isEmpty {
      filterInvocations = []
      variable = Variable("")
      throw TemplateSyntaxError("Variable tags must include at least 1 argument")
    }

    variable = Variable(bits[0])
    let filterBits = bits[bits.indices.suffix(from: 1)]

    do {
      filterInvocations = try filterBits.map { filterBit in
        let (name, arguments) = parseFilterComponents(filterBit)
        let filter = try parser.findFilter(name: name)
        return FilterInvocation(name: name, filter: filter, arguments: arguments)
      }
    } catch {
      filterInvocations = []
      throw error
    }
  }

  func resolve(_ context: Context) throws -> Any? {
    let result = try variable.resolve(context)

    return try filterInvocations.reduce(result) { x, y in
      return try y.invoke(x, context: context)
    }
  }
}

/// A structure used to represent a template variable, and to resolve it in a given context.
public struct Variable : Equatable, Resolvable {
  public let variable: String

  /// Create a variable with a string representing the variable
  public init(_ variable: String) {
    self.variable = variable
  }

  private func lookup() -> [String] {
    return variable.characters.split(separator: ".").map(String.init)
  }

  /// Resolve the variable in the given context
  public func resolve(_ context: Context) throws -> Any? {
    var current: Any? = context

    if (variable.hasPrefix("'") && variable.hasSuffix("'")) || (variable.hasPrefix("\"") && variable.hasSuffix("\"")) {
      // String literal
      return variable[variable.characters.index(after: variable.startIndex) ..< variable.characters.index(before: variable.endIndex)]
    }
    
    if let int = Int(variable) {
        // integer literal
        return int
    }
    
    if let double = Double(variable) {
        // double literal
        return double
    }

    for bit in lookup() {
      if let context = current as? Context {
        current = context[bit]
      } else if let dictionary = resolveDictionary(current) {
        current = dictionary[bit]
      } else if let array = resolveArray(current) {
        if let index = Int(bit) {
          current = array[index]
        } else if bit == "first" {
          current = array.first
        } else if bit == "last" {
          current = array.last
        } else if bit == "count" {
          current = array.count
        }
      } else {
        return nil
      }
    }

    return normalize(current)
  }
}

public func ==(lhs: Variable, rhs: Variable) -> Bool {
    return lhs.variable == rhs.variable
}

public struct FilterArgument: Equatable, Resolvable {
    public let variable: String
    
    /// Create a filter argument with a string representing the argument
    public init(_ variable: String) {
        self.variable = variable
    }
    
    public func resolve(_ context: Context) throws -> Any? {
        if let integer = Int(variable) {
            // if value is integer literal, return integer value
            return integer
        }
        else {
            // otherwise fall back to variable resolve
            return try Variable(variable).resolve(context)
        }
    }
}

public func ==(lhs: FilterArgument, rhs: FilterArgument) -> Bool {
    return lhs.variable == rhs.variable
}

func resolveDictionary(_ current: Any?) -> [String: Any]? {
  switch current {
  case let dictionary as [String: Any]:
      return dictionary
  case let dictionary as [String: AnyObject]:
      var result: [String: Any] = [:]
      for (k, v) in dictionary {
          result[k] = v as Any
      }
      return result
  case let dictionary as NSDictionary:
      var result: [String: Any] = [:]
      for (k, v) in dictionary {
          if let k = k as? String {
              result[k] = v as Any
          }
      }
      return result
  default:
      return nil
  }
}

func resolveArray(_ current: Any?) -> [Any]? {
  switch current {
  case let array as [Any]:
      return array
  case let array as [AnyObject]:
      return array.map { $0 as Any }
  case let array as NSArray:
      return array.map { $0 as Any }
  default:
      return nil
  }
}

func normalize(_ current: Any?) -> Any? {
  if let array = resolveArray(current) {
    return array
  }

  if let dictionary = resolveDictionary(current) {
    return dictionary
  }

  return current
}

func parseFilterComponents(_ token: String) -> (String, [FilterArgument]) {
    let components = token.splitAndTrimWhitespace(":", respectQuotes: true)
    if components.count == 1 {
        return (components[0], [])
    }
    else  {
        let arguments = components[1].splitAndTrimWhitespace(",", respectQuotes: true)
        let filterArguments = arguments.map({ FilterArgument($0) })
        return (components[0], filterArguments)
    }
}
