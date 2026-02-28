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
        // "App/LoggingDemoViewModel.swift:79:5" → "LoggingDemoViewModel"
        let lastComponent = location.split(separator: "/").last.map(String.init) ?? location
        return lastComponent.split(separator: ".").first.map(String.init) ?? lastComponent
    }

    private func extractFuncName(from declaration: String) -> String {
        // "func fetchUser(id: Int) async throws -> String" → "fetchUser"
        // "func fetch<T: Decodable>(type: T.Type)" → "fetch"
        let afterFunc = declaration.hasPrefix("func ") ? String(declaration.dropFirst(5)) : declaration
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
        let isAsync  = declaration.range(of: #"\basync\b"#,  options: .regularExpression) != nil
        let isThrows = declaration.range(of: #"\bthrows\b"#, options: .regularExpression) != nil
        switch (isAsync, isThrows) {
        case (true, true):   return " async throws"
        case (true, false):  return " async"
        case (false, true):  return " throws"
        case (false, false): return ""
        }
    }
}
