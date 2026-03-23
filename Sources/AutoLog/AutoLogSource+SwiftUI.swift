#if canImport(SwiftUI)
import SwiftUI

// MARK: - Button.logged

extension Button where Label == Text {
    /// Creates a button that automatically logs the interaction and
    /// propagates the source to all downstream `@Logged` function calls.
    @MainActor public static func logged(
        _ title: String,
        role: ButtonRole? = nil,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column,
        action: @escaping @MainActor () -> Void
    ) -> some View {
        Button(title, role: role) {
            AutoLogSource.run(
                InteractionSource.button(title),
                fileID: fileID,
                line: line,
                column: column
            ) {
                action()
            }
        }
    }

    /// Async variant of ``logged(_:role:fileID:line:column:action:)``.
    @MainActor public static func logged(
        _ title: String,
        role: ButtonRole? = nil,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column,
        action: @escaping @Sendable () async -> Void
    ) -> some View {
        Button(title, role: role) {
            Task {
                await AutoLogSource.run(
                    InteractionSource.button(title),
                    fileID: fileID,
                    line: line,
                    column: column
                ) { @Sendable in
                    await action()
                }
            }
        }
    }
}

// MARK: - Binding.logged

extension Binding {
    /// Returns a new binding that logs interactions when the value is set,
    /// propagating the source to all downstream `@Logged` function calls.
    ///
    /// Use the ``InteractionSource``-typed overload for dot-shorthand syntax:
    /// ```swift
    /// Toggle("Dark Mode", isOn: $vm.darkMode.logged(.toggle("Dark Mode")))
    /// ```
    @MainActor public func logged(
        _ source: InteractionSource,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column
    ) -> Binding {
        logged(source as any Sourceable, fileID: fileID, line: line, column: column)
    }

    /// Returns a new binding that logs interactions when the value is set,
    /// using any custom ``Sourceable`` type.
    @MainActor public func logged(
        _ source: any Sourceable,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column
    ) -> Binding {
        let current = self
        return Binding(
            get: { current.wrappedValue },
            set: { newValue in
                AutoLogSource.run(
                    source,
                    fileID: fileID,
                    line: line,
                    column: column
                ) {
                    current.wrappedValue = newValue
                }
            }
        )
    }
}

#endif
