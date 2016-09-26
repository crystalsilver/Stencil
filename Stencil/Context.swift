/// A container for template variables.
public class Context {
  var dictionaries:[[String: Any]]

  /// Initialise a Context with a dictionary
  public init(dictionary:[String: Any]) {
    dictionaries = [dictionary]
  }

  /// Initialise an empty Context
  public init() {
    dictionaries = []
  }

  public subscript(key: String) -> Any? {
    /// Retrieves a variable's value, starting at the current context and going upwards
    get {
      for dictionary in Array(dictionaries.reversed()) {
        if let value = dictionary[key] {
          return value
        }
      }

      return nil
    }

    /// Set a variable in the current context, deleting the variable if it's nil
    set(value) {
      if var dictionary = dictionaries.popLast() {
        dictionary[key] = value
        dictionaries.append(dictionary)
      }
    }
  }

  /// Push a new level into the Context
  public func push(_ dictionary: [String: Any]? = nil) {
    dictionaries.append(dictionary ?? [:])
  }

  /// Pop the last level off of the Context
  @discardableResult public func pop() -> [String: Any]? {
    return dictionaries.popLast()
  }

  /// Push a new level onto the context for the duration of the execution of the given closure
  public func push<Result>(_ dictionary: [String: Any]? = nil, closure: (() throws -> Result)) rethrows -> Result {
    push(dictionary)
    let result = try closure()
    pop()
    return result
  }
}
