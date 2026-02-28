public struct DepthProfile: Sendable {
    public let suffixDepths: [(suffix: String, depth: Int)]

    public init(suffixDepths: [(suffix: String, depth: Int)]) {
        self.suffixDepths = suffixDepths
    }

    public static let mvvm = DepthProfile(suffixDepths: [
        ("ViewModel", 2),
        ("View", 1),
        ("Model", 3),
        ("Service", 3),
    ])

    public static let cleanArchitecture = DepthProfile(suffixDepths: [
        ("ViewController", 1),
        ("View", 1),
        ("ViewModel", 2),
        ("Presenter", 2),
        ("UseCase", 3),
        ("Interactor", 3),
        ("Repository", 4),
        ("DataSource", 5),
        ("Network", 5),
    ])

    public func depth(for typeName: String) -> Int? {
        suffixDepths
            .sorted { $0.suffix.count > $1.suffix.count }
            .first { typeName.hasSuffix($0.suffix) }?
            .depth
    }

    public func arrow(for typeName: String) -> String {
        let d = depth(for: typeName) ?? 1
        return String(repeating: "-", count: d) + ">"
    }
}
