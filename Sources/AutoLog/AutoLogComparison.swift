enum AutoLogComparison {
  static func normalize(_ string: String) -> String {
    let lowered = string.lowercased()
      .replacingOccurrences(of: #"\b0x[0-9a-f]+\b"#, with: " ", options: .regularExpression)
      .replacingOccurrences(
        of: #"\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b"#,
        with: " ",
        options: .regularExpression
      )
      .replacingOccurrences(of: #"\b\d{4,}\b"#, with: " ", options: .regularExpression)

    let collapsed = lowered.unicodeScalars.map { scalar -> Character in
      if CharacterSet.alphanumerics.contains(scalar) {
        return Character(scalar)
      }
      return " "
    }

    return String(collapsed)
      .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  static func summary(for value: Any) -> String {
    if let type = value as? Any.Type {
      return normalize(String(reflecting: type))
    }

    return normalize(String(describing: value))
  }

  static func errorSummary(_ error: any Error) -> String {
    normalize("\(String(reflecting: type(of: error))) \(String(describing: error))")
  }

  static func matches(all tokens: [String], in summary: String) -> Bool {
    let normalizedTokens = tokens.map(normalize).filter { !$0.isEmpty }
    guard !normalizedTokens.isEmpty else { return true }
    return normalizedTokens.allSatisfy(summary.contains)
  }
}
