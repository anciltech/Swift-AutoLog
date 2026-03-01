/// A type that formats a ``LoggableEvent`` into a printable string.
public protocol LoggableFormatter: Sendable {
    func format(event: LoggableEvent) -> String
}

/// A compact, single-line formatter that includes a depth arrow,
/// status emoji, type name, function signature, and optional return value.
///
/// Example output:
/// ```
/// --> 🟢 LoggingDemoViewModel.runAsyncScenario() async
/// --> 🟢 UserService.fetchUser(id: 1) async → "User1"
/// --> 🔴 UserService.fetchUser(id: 404) async
///          ↳ notFound [NetworkError]
/// ```
public struct CompactFormatter: LoggableFormatter {
    public let profile: DepthProfile

    public init(profile: DepthProfile = .mvvm) {
        self.profile = profile
    }

    public func format(event: LoggableEvent) -> String {
        let typeName   = extractTypeName(from: event.location)
        let arrow      = profile.arrow(for: typeName)
        let em         = emoji(for: event)

        // Interaction event: source present and declaration matches source description
        if let source = event.source, event.declaration == source.description {
            return "\(arrow) \(em) \(typeName).\(event.declaration)"
        }

        let funcName   = extractFuncName(from: event.declaration)
        let params     = formatParameters(event.parameters)
        let specifiers = effectSpecifiers(from: event.declaration)

        var line = "\(arrow) \(em) \(typeName).\(funcName)(\(params))\(specifiers)"

        // Inline return value on success for non-Void results
        if case .success(let value) = event.result, type(of: value) != Void.self {
            line += " → \(value)"
        }

        // Second line: error detail or tags
        if case .failure(let error) = event.result {
            let errorType = String(describing: type(of: error))
            let desc      = String(describing: error)
            line += "\n         ↳ \(desc) [\(errorType)]"
        } else if !event.tags.isEmpty {
            let tagList = event.tags.map { "\($0)" }.joined(separator: ", ")
            line += "\n         ↳ [\(tagList)]"
        }

        return line
    }

    // MARK: - Private helpers

    private func emoji(for event: LoggableEvent) -> String {
        // Source emoji takes priority when present
        if let source = event.source {
            return source.emoji
        }

        // Failure always wins
        if case .failure = event.result { return "🔴" }

        if let osLevel = event.level as? OSLogType {
            switch osLevel {
            case .error, .fault: return "🔴"
            case .default:       return "🟡"
            case .info, .debug:  return "🔵"
            default:
                // Unknown future OSLogType value; treated as success-green.
                return "🟢"
            }
        }
        return "🟢"
    }

    private func extractTypeName(from location: String) -> String {
        // Expected format: "Module/TypeName.swift:line:col"
        // Use ".swift" as boundary to handle names like "MyView+Extension.swift" correctly.
        let filename = location.split(separator: "/").last.map(String.init) ?? location
        let stem = filename.components(separatedBy: ".swift").first ?? filename
        return stem.isEmpty ? "Unknown" : stem
    }

    private func extractFuncName(from declaration: String) -> String {
        // "public mutating func deposit(amount: Int)" → "deposit"
        // "func fetch<T: Decodable>(type: T.Type)" → "fetch"
        let afterFunc: String
        if let range = declaration.range(of: "func ") {
            afterFunc = String(declaration[range.upperBound...])
        } else {
            afterFunc = declaration
        }
        let withoutGenerics = afterFunc.split(separator: "<").first.map(String.init) ?? afterFunc
        return withoutGenerics.split(separator: "(").first.map(String.init) ?? withoutGenerics
    }

    private func formatParameters(_ parameters: [String: Any]) -> String {
        guard !parameters.isEmpty else { return "" }
        // [String: Any] has no stable order; sort alphabetically for determinism.
        // Declaration order is not preserved — a future refactor to [String: Any] → [(String, Any)]
        // on LoggableEvent.parameters would allow order-preserving display.
        return parameters
            .sorted { $0.key < $1.key }
            .map { "\($0.key): \($0.value)" }
            .joined(separator: ", ")
    }

    private func effectSpecifiers(from declaration: String) -> String {
        let isAsync = declaration.range(of: #"\basync\b"#, options: .regularExpression) != nil
        return isAsync ? " async" : ""
    }
}
