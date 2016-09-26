import Foundation
import PathKit

/// A class representing a template
public class Template {
  let tokens: [Token]

  /// Create a template with the given name inside the given bundle
  public convenience init(named:String, inBundle bundle:Bundle? = nil) throws {
    let useBundle = bundle ??  Bundle.main
    guard let url = useBundle.url(forResource: named, withExtension: nil) else {
      throw NSError(domain: NSCocoaErrorDomain, code: NSFileNoSuchFileError, userInfo: nil)
    }

    try self.init(URL:url)
  }

  /// Create a template with a file found at the given URL
  public convenience init(URL: URL) throws {
    try self.init(path: Path(URL.path))
  }

  /// Create a template with a file found at the given path
  public convenience init(path:Path) throws {
    self.init(templateString: try path.read())
  }

  /// Create a template with a template string
  public init(templateString:String) {
    let lexer = Lexer(templateString: templateString)
    tokens = lexer.tokenize()
  }

  /// Render the given template
  public func render(_ context: Context? = nil, namespace: Namespace? = nil) throws -> String {
    let parser = TokenParser(tokens: tokens, namespace: namespace ?? Namespace())
    let nodes = try parser.parse()
    return try renderNodes(nodes, context ?? Context())
  }
}
