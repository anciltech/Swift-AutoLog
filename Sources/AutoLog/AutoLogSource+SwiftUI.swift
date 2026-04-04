#if canImport(SwiftUI)
import SwiftUI

// MARK: - Button.log

extension Button where Label == Text {
    /// Creates a button that automatically logs the interaction and
    /// propagates the source to all downstream `@Logged` function calls.
    @MainActor public static func log(
        _ title: String,
        role: ButtonRole? = nil,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column,
        action: @escaping @MainActor () -> Void
    ) -> some View {
        Button(title, role: role) {
            InteractionSource.button(title).log(
                fileID: fileID,
                line: line,
                column: column
            ) {
                action()
            }
        }
    }

    /// Async variant of ``log(_:role:fileID:line:column:action:)``.
    @MainActor public static func log(
        _ title: String,
        role: ButtonRole? = nil,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column,
        action: @escaping @Sendable () async -> Void
    ) -> some View {
        Button(title, role: role) {
            Task {
                await InteractionSource.button(title).log(
                    fileID: fileID,
                    line: line,
                    column: column
                ) { @Sendable in
                    await action()
                }
            }
        }
    }

    /// Backward-compatible alias for ``log(_:role:fileID:line:column:action:)``.
    @available(*, deprecated, renamed: "log(_:role:fileID:line:column:action:)")
    @MainActor public static func logged(
        _ title: String,
        role: ButtonRole? = nil,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column,
        action: @escaping @MainActor () -> Void
    ) -> some View {
        log(title, role: role, fileID: fileID, line: line, column: column, action: action)
    }

    /// Backward-compatible alias for ``log(_:role:fileID:line:column:action:)``.
    @available(*, deprecated, renamed: "log(_:role:fileID:line:column:action:)")
    @MainActor public static func logged(
        _ title: String,
        role: ButtonRole? = nil,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column,
        action: @escaping @Sendable () async -> Void
    ) -> some View {
        log(title, role: role, fileID: fileID, line: line, column: column, action: action)
    }
}

// MARK: - Binding.log

extension Binding {
    /// Returns a new binding that logs interactions when the value is set,
    /// propagating the source to all downstream `@Logged` function calls.
    ///
    /// Use the ``InteractionSource``-typed overload for dot-shorthand syntax:
    /// ```swift
    /// Toggle("Dark Mode", isOn: $vm.darkMode.log(.toggle("Dark Mode")))
    /// ```
    @MainActor public func log(
        _ source: InteractionSource,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column
    ) -> Binding {
        log(source as any Sourceable, fileID: fileID, line: line, column: column)
    }

    /// Returns a new binding that logs interactions when the value is set,
    /// using any custom ``Sourceable`` type.
    @MainActor public func log(
        _ source: any Sourceable,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column
    ) -> Binding {
        let current = self
        return Binding(
            get: { current.wrappedValue },
            set: { newValue in
                source.log(
                    fileID: fileID,
                    line: line,
                    column: column
                ) {
                    current.wrappedValue = newValue
                }
            }
        )
    }

    /// Backward-compatible alias for ``log(_:fileID:line:column:)``.
    @available(*, deprecated, renamed: "log(_:fileID:line:column:)")
    @MainActor public func logged(
        _ source: InteractionSource,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column
    ) -> Binding {
        log(source, fileID: fileID, line: line, column: column)
    }

    /// Backward-compatible alias for ``log(_:fileID:line:column:)``.
    @available(*, deprecated, renamed: "log(_:fileID:line:column:)")
    @MainActor public func logged(
        _ source: any Sourceable,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column
    ) -> Binding {
        log(source, fileID: fileID, line: line, column: column)
    }
}

#endif
