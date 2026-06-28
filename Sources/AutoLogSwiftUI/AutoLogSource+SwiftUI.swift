#if canImport(SwiftUI)
@_exported import AutoLog
import SwiftUI
import Combine

// MARK: - Button.log

private func autoLogButtonName<S: StringProtocol>(
    _ title: S,
    logName: String?
) -> String {
    logName ?? String(title)
}

private func autoLogButtonName(_ title: StaticString) -> String {
    String(describing: title)
}

extension Button {
    /// Creates a custom-label button that automatically logs the interaction and
    /// propagates the source to all downstream `@AutoLog` function calls.
    ///
    /// The `name` should be a stable interaction identifier, not localized
    /// display text from the label.
    @MainActor public static func log(
        _ name: String,
        action: @escaping @MainActor () -> Void,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column,
        @ViewBuilder label: () -> Label
    ) -> Button<Label> {
        Button {
            AutoLogInteraction.button(name).log(
                fileID: fileID,
                line: line,
                column: column
            ) {
                action()
            }
        } label: {
            label()
        }
    }

    /// Creates a role-based custom-label button that automatically logs the
    /// interaction and propagates the source to downstream `@AutoLog` calls.
    @MainActor public static func log(
        _ name: String,
        role: ButtonRole?,
        action: @escaping @MainActor () -> Void,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column,
        @ViewBuilder label: () -> Label
    ) -> Button<Label> {
        Button(role: role) {
            AutoLogInteraction.button(name).log(
                fileID: fileID,
                line: line,
                column: column
            ) {
                action()
            }
        } label: {
            label()
        }
    }

    /// Async variant of ``log(_:action:fileID:line:column:label:)``.
    @MainActor public static func log(
        _ name: String,
        action: @escaping @Sendable () async -> Void,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column,
        @ViewBuilder label: () -> Label
    ) -> Button<Label> {
        Button {
            Task {
                await AutoLogInteraction.button(name).log(
                    fileID: fileID,
                    line: line,
                    column: column
                ) { @Sendable in
                    await action()
                }
            }
        } label: {
            label()
        }
    }

    /// Async variant of ``log(_:role:action:fileID:line:column:label:)``.
    @MainActor public static func log(
        _ name: String,
        role: ButtonRole?,
        action: @escaping @Sendable () async -> Void,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column,
        @ViewBuilder label: () -> Label
    ) -> Button<Label> {
        Button(role: role) {
            Task {
                await AutoLogInteraction.button(name).log(
                    fileID: fileID,
                    line: line,
                    column: column
                ) { @Sendable in
                    await action()
                }
            }
        } label: {
            label()
        }
    }

    /// Compatibility overload for the original custom-label parameter order.
    @available(*, deprecated, renamed: "log(_:role:action:fileID:line:column:label:)")
    @_disfavoredOverload
    @MainActor public static func log(
        _ name: String,
        role: ButtonRole? = nil,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column,
        action: @escaping @MainActor () -> Void,
        @ViewBuilder label: () -> Label
    ) -> Button<Label> {
        log(name, role: role, action: action, fileID: fileID, line: line, column: column, label: label)
    }

    /// Compatibility overload for the original async custom-label parameter order.
    @available(*, deprecated, renamed: "log(_:role:action:fileID:line:column:label:)")
    @_disfavoredOverload
    @MainActor public static func log(
        _ name: String,
        role: ButtonRole? = nil,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column,
        action: @escaping @Sendable () async -> Void,
        @ViewBuilder label: () -> Label
    ) -> Button<Label> {
        log(name, role: role, action: action, fileID: fileID, line: line, column: column, label: label)
    }
}

extension Button where Label == Text {
    /// Creates a button that automatically logs the interaction and
    /// propagates the source to all downstream `@AutoLog` function calls.
    ///
    /// String literals are treated as localized string keys, matching SwiftUI's
    /// `Button(_:action:)` behavior while using the key as the stable log name.
    @MainActor public static func log(
        _ titleKey: StaticString,
        action: @escaping @MainActor () -> Void,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column
    ) -> Button<Text> {
        let logName = autoLogButtonName(titleKey)
        return Button(LocalizedStringKey(logName)) {
            AutoLogInteraction.button(logName).log(
                fileID: fileID,
                line: line,
                column: column
            ) {
                action()
            }
        }
    }

    /// Creates a button from dynamic string text and logs the interaction.
    @_disfavoredOverload
    @MainActor public static func log<S>(
        _ title: S,
        logName: String? = nil,
        action: @escaping @MainActor () -> Void,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column
    ) -> Button<Text> where S: StringProtocol {
        Button(title) {
            AutoLogInteraction.button(autoLogButtonName(title, logName: logName)).log(
                fileID: fileID,
                line: line,
                column: column
            ) {
                action()
            }
        }
    }

    /// Creates a localized-title button that logs with a stable source name.
    @MainActor public static func log(
        _ titleKey: LocalizedStringKey,
        logName: String,
        action: @escaping @MainActor () -> Void,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column
    ) -> Button<Text> {
        Button(titleKey) {
            AutoLogInteraction.button(logName).log(
                fileID: fileID,
                line: line,
                column: column
            ) {
                action()
            }
        }
    }

    /// Creates a localized-resource title button that logs with a stable source name.
    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
    @MainActor public static func log(
        _ titleResource: LocalizedStringResource,
        logName: String,
        action: @escaping @MainActor () -> Void,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column
    ) -> Button<Text> {
        Button(titleResource) {
            AutoLogInteraction.button(logName).log(
                fileID: fileID,
                line: line,
                column: column
            ) {
                action()
            }
        }
    }

    /// Creates a role-based title button that logs the interaction.
    ///
    /// String literals are treated as localized string keys, matching SwiftUI's
    /// `Button(_:role:action:)` behavior while using the key as the stable log name.
    @MainActor public static func log(
        _ titleKey: StaticString,
        role: ButtonRole?,
        action: @escaping @MainActor () -> Void,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column
    ) -> Button<Text> {
        let logName = autoLogButtonName(titleKey)
        return Button(LocalizedStringKey(logName), role: role) {
            AutoLogInteraction.button(logName).log(
                fileID: fileID,
                line: line,
                column: column
            ) {
                action()
            }
        }
    }

    /// Creates a role-based dynamic-string title button that logs the interaction.
    @_disfavoredOverload
    @MainActor public static func log<S>(
        _ title: S,
        logName: String? = nil,
        role: ButtonRole?,
        action: @escaping @MainActor () -> Void,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column
    ) -> Button<Text> where S: StringProtocol {
        Button(title, role: role) {
            AutoLogInteraction.button(autoLogButtonName(title, logName: logName)).log(
                fileID: fileID,
                line: line,
                column: column
            ) {
                action()
            }
        }
    }

    /// Creates a role-based localized-title button that logs with a stable source name.
    @MainActor public static func log(
        _ titleKey: LocalizedStringKey,
        logName: String,
        role: ButtonRole?,
        action: @escaping @MainActor () -> Void,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column
    ) -> Button<Text> {
        Button(titleKey, role: role) {
            AutoLogInteraction.button(logName).log(
                fileID: fileID,
                line: line,
                column: column
            ) {
                action()
            }
        }
    }

    /// Creates a role-based localized-resource title button that logs with a stable source name.
    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
    @MainActor public static func log(
        _ titleResource: LocalizedStringResource,
        logName: String,
        role: ButtonRole?,
        action: @escaping @MainActor () -> Void,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column
    ) -> Button<Text> {
        Button(titleResource, role: role) {
            AutoLogInteraction.button(logName).log(
                fileID: fileID,
                line: line,
                column: column
            ) {
                action()
            }
        }
    }

    /// Async variant of ``log(_:logName:action:fileID:line:column:)``.
    @MainActor public static func log(
        _ titleKey: StaticString,
        action: @escaping @Sendable () async -> Void,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column
    ) -> Button<Text> {
        let logName = autoLogButtonName(titleKey)
        return Button(LocalizedStringKey(logName)) {
            Task {
                await AutoLogInteraction.button(logName).log(
                    fileID: fileID,
                    line: line,
                    column: column
                ) { @Sendable in
                    await action()
                }
            }
        }
    }

    /// Async variant for dynamic string text.
    @_disfavoredOverload
    @MainActor public static func log<S>(
        _ title: S,
        logName: String? = nil,
        action: @escaping @Sendable () async -> Void,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column
    ) -> Button<Text> where S: StringProtocol {
        Button(title) {
            Task {
                await AutoLogInteraction.button(autoLogButtonName(title, logName: logName)).log(
                    fileID: fileID,
                    line: line,
                    column: column
                ) { @Sendable in
                    await action()
                }
            }
        }
    }

    /// Async localized-title variant that logs with a stable source name.
    @MainActor public static func log(
        _ titleKey: LocalizedStringKey,
        logName: String,
        action: @escaping @Sendable () async -> Void,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column
    ) -> Button<Text> {
        Button(titleKey) {
            Task {
                await AutoLogInteraction.button(logName).log(
                    fileID: fileID,
                    line: line,
                    column: column
                ) { @Sendable in
                    await action()
                }
            }
        }
    }

    /// Async localized-resource title variant that logs with a stable source name.
    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
    @MainActor public static func log(
        _ titleResource: LocalizedStringResource,
        logName: String,
        action: @escaping @Sendable () async -> Void,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column
    ) -> Button<Text> {
        Button(titleResource) {
            Task {
                await AutoLogInteraction.button(logName).log(
                    fileID: fileID,
                    line: line,
                    column: column
                ) { @Sendable in
                    await action()
                }
            }
        }
    }

    /// Async role-based title variant that logs the interaction.
    @MainActor public static func log(
        _ titleKey: StaticString,
        role: ButtonRole?,
        action: @escaping @Sendable () async -> Void,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column
    ) -> Button<Text> {
        let logName = autoLogButtonName(titleKey)
        return Button(LocalizedStringKey(logName), role: role) {
            Task {
                await AutoLogInteraction.button(logName).log(
                    fileID: fileID,
                    line: line,
                    column: column
                ) { @Sendable in
                    await action()
                }
            }
        }
    }

    /// Async role-based dynamic-string title variant.
    @_disfavoredOverload
    @MainActor public static func log<S>(
        _ title: S,
        logName: String? = nil,
        role: ButtonRole?,
        action: @escaping @Sendable () async -> Void,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column
    ) -> Button<Text> where S: StringProtocol {
        Button(title, role: role) {
            Task {
                await AutoLogInteraction.button(autoLogButtonName(title, logName: logName)).log(
                    fileID: fileID,
                    line: line,
                    column: column
                ) { @Sendable in
                    await action()
                }
            }
        }
    }

    /// Async role-based localized-title variant that logs with a stable source name.
    @MainActor public static func log(
        _ titleKey: LocalizedStringKey,
        logName: String,
        role: ButtonRole?,
        action: @escaping @Sendable () async -> Void,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column
    ) -> Button<Text> {
        Button(titleKey, role: role) {
            Task {
                await AutoLogInteraction.button(logName).log(
                    fileID: fileID,
                    line: line,
                    column: column
                ) { @Sendable in
                    await action()
                }
            }
        }
    }

    /// Async role-based localized-resource title variant that logs with a stable source name.
    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
    @MainActor public static func log(
        _ titleResource: LocalizedStringResource,
        logName: String,
        role: ButtonRole?,
        action: @escaping @Sendable () async -> Void,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column
    ) -> Button<Text> {
        Button(titleResource, role: role) {
            Task {
                await AutoLogInteraction.button(logName).log(
                    fileID: fileID,
                    line: line,
                    column: column
                ) { @Sendable in
                    await action()
                }
            }
        }
    }

    /// Compatibility overload for the original text-button parameter order.
    @available(*, deprecated, renamed: "log(_:logName:role:action:fileID:line:column:)")
    @_disfavoredOverload
    @MainActor public static func log(
        _ title: String,
        role: ButtonRole? = nil,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column,
        action: @escaping @MainActor () -> Void
    ) -> Button<Text> {
        log(title, role: role, action: action, fileID: fileID, line: line, column: column)
    }

    /// Compatibility overload for the original async text-button parameter order.
    @available(*, deprecated, renamed: "log(_:logName:role:action:fileID:line:column:)")
    @_disfavoredOverload
    @MainActor public static func log(
        _ title: String,
        role: ButtonRole? = nil,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column,
        action: @escaping @Sendable () async -> Void
    ) -> Button<Text> {
        log(title, role: role, action: action, fileID: fileID, line: line, column: column)
    }

    /// Backward-compatible alias for ``log(_:role:fileID:line:column:action:)``.
    @available(*, deprecated, renamed: "log(_:logName:action:fileID:line:column:)")
    @MainActor public static func logged(
        _ title: String,
        role: ButtonRole? = nil,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column,
        action: @escaping @MainActor () -> Void
    ) -> some View {
        log(title, role: role, action: action, fileID: fileID, line: line, column: column)
    }

    /// Backward-compatible alias for ``log(_:logName:action:fileID:line:column:)``.
    @available(*, deprecated, renamed: "log(_:logName:action:fileID:line:column:)")
    @MainActor public static func logged(
        _ title: String,
        role: ButtonRole? = nil,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column,
        action: @escaping @Sendable () async -> Void
    ) -> some View {
        log(title, role: role, action: action, fileID: fileID, line: line, column: column)
    }
}

extension Button where Label == SwiftUI.Label<Text, Image> {
    /// Creates a label-style button with a system image and logged interaction.
    @MainActor public static func log(
        _ titleKey: StaticString,
        systemImage: String,
        action: @escaping @MainActor () -> Void,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column
    ) -> Button<SwiftUI.Label<Text, Image>> {
        let logName = autoLogButtonName(titleKey)
        return Button(LocalizedStringKey(logName), systemImage: systemImage) {
            AutoLogInteraction.button(logName).log(
                fileID: fileID,
                line: line,
                column: column
            ) {
                action()
            }
        }
    }

    /// Creates a dynamic-string label-style button with a system image and logged interaction.
    @_disfavoredOverload
    @MainActor public static func log<S>(
        _ title: S,
        systemImage: String,
        logName: String? = nil,
        action: @escaping @MainActor () -> Void,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column
    ) -> Button<SwiftUI.Label<Text, Image>> where S: StringProtocol {
        Button(title, systemImage: systemImage) {
            AutoLogInteraction.button(autoLogButtonName(title, logName: logName)).log(
                fileID: fileID,
                line: line,
                column: column
            ) {
                action()
            }
        }
    }

    /// Creates a localized label-style button with a system image and stable log name.
    @MainActor public static func log(
        _ titleKey: LocalizedStringKey,
        systemImage: String,
        logName: String,
        action: @escaping @MainActor () -> Void,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column
    ) -> Button<SwiftUI.Label<Text, Image>> {
        Button(titleKey, systemImage: systemImage) {
            AutoLogInteraction.button(logName).log(
                fileID: fileID,
                line: line,
                column: column
            ) {
                action()
            }
        }
    }

    /// Creates a localized-resource label-style button with a system image and stable log name.
    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
    @MainActor public static func log(
        _ titleResource: LocalizedStringResource,
        systemImage: String,
        logName: String,
        action: @escaping @MainActor () -> Void,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column
    ) -> Button<SwiftUI.Label<Text, Image>> {
        Button(titleResource, systemImage: systemImage) {
            AutoLogInteraction.button(logName).log(
                fileID: fileID,
                line: line,
                column: column
            ) {
                action()
            }
        }
    }

    /// Creates a role-based label-style button with a system image and logged interaction.
    @MainActor public static func log(
        _ titleKey: StaticString,
        systemImage: String,
        role: ButtonRole?,
        action: @escaping @MainActor () -> Void,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column
    ) -> Button<SwiftUI.Label<Text, Image>> {
        let logName = autoLogButtonName(titleKey)
        return Button(LocalizedStringKey(logName), systemImage: systemImage, role: role) {
            AutoLogInteraction.button(logName).log(
                fileID: fileID,
                line: line,
                column: column
            ) {
                action()
            }
        }
    }

    /// Creates a role-based dynamic-string label-style button with a system image.
    @_disfavoredOverload
    @MainActor public static func log<S>(
        _ title: S,
        systemImage: String,
        logName: String? = nil,
        role: ButtonRole?,
        action: @escaping @MainActor () -> Void,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column
    ) -> Button<SwiftUI.Label<Text, Image>> where S: StringProtocol {
        Button(title, systemImage: systemImage, role: role) {
            AutoLogInteraction.button(autoLogButtonName(title, logName: logName)).log(
                fileID: fileID,
                line: line,
                column: column
            ) {
                action()
            }
        }
    }

    /// Creates a role-based localized label-style button with a system image and stable log name.
    @MainActor public static func log(
        _ titleKey: LocalizedStringKey,
        systemImage: String,
        logName: String,
        role: ButtonRole?,
        action: @escaping @MainActor () -> Void,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column
    ) -> Button<SwiftUI.Label<Text, Image>> {
        Button(titleKey, systemImage: systemImage, role: role) {
            AutoLogInteraction.button(logName).log(
                fileID: fileID,
                line: line,
                column: column
            ) {
                action()
            }
        }
    }

    /// Creates a role-based localized-resource label-style button with a system image and stable log name.
    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
    @MainActor public static func log(
        _ titleResource: LocalizedStringResource,
        systemImage: String,
        logName: String,
        role: ButtonRole?,
        action: @escaping @MainActor () -> Void,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column
    ) -> Button<SwiftUI.Label<Text, Image>> {
        Button(titleResource, systemImage: systemImage, role: role) {
            AutoLogInteraction.button(logName).log(
                fileID: fileID,
                line: line,
                column: column
            ) {
                action()
            }
        }
    }

    /// Async label-style button with a system image and logged interaction.
    @MainActor public static func log(
        _ titleKey: StaticString,
        systemImage: String,
        action: @escaping @Sendable () async -> Void,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column
    ) -> Button<SwiftUI.Label<Text, Image>> {
        let logName = autoLogButtonName(titleKey)
        return Button(LocalizedStringKey(logName), systemImage: systemImage) {
            Task {
                await AutoLogInteraction.button(logName).log(
                    fileID: fileID,
                    line: line,
                    column: column
                ) { @Sendable in
                    await action()
                }
            }
        }
    }

    /// Async dynamic-string label-style button with a system image.
    @_disfavoredOverload
    @MainActor public static func log<S>(
        _ title: S,
        systemImage: String,
        logName: String? = nil,
        action: @escaping @Sendable () async -> Void,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column
    ) -> Button<SwiftUI.Label<Text, Image>> where S: StringProtocol {
        Button(title, systemImage: systemImage) {
            Task {
                await AutoLogInteraction.button(autoLogButtonName(title, logName: logName)).log(
                    fileID: fileID,
                    line: line,
                    column: column
                ) { @Sendable in
                    await action()
                }
            }
        }
    }

    /// Async localized label-style button with a system image and stable log name.
    @MainActor public static func log(
        _ titleKey: LocalizedStringKey,
        systemImage: String,
        logName: String,
        action: @escaping @Sendable () async -> Void,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column
    ) -> Button<SwiftUI.Label<Text, Image>> {
        Button(titleKey, systemImage: systemImage) {
            Task {
                await AutoLogInteraction.button(logName).log(
                    fileID: fileID,
                    line: line,
                    column: column
                ) { @Sendable in
                    await action()
                }
            }
        }
    }

    /// Async localized-resource label-style button with a system image and stable log name.
    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
    @MainActor public static func log(
        _ titleResource: LocalizedStringResource,
        systemImage: String,
        logName: String,
        action: @escaping @Sendable () async -> Void,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column
    ) -> Button<SwiftUI.Label<Text, Image>> {
        Button(titleResource, systemImage: systemImage) {
            Task {
                await AutoLogInteraction.button(logName).log(
                    fileID: fileID,
                    line: line,
                    column: column
                ) { @Sendable in
                    await action()
                }
            }
        }
    }

    /// Async role-based label-style button with a system image and logged interaction.
    @MainActor public static func log(
        _ titleKey: StaticString,
        systemImage: String,
        role: ButtonRole?,
        action: @escaping @Sendable () async -> Void,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column
    ) -> Button<SwiftUI.Label<Text, Image>> {
        let logName = autoLogButtonName(titleKey)
        return Button(LocalizedStringKey(logName), systemImage: systemImage, role: role) {
            Task {
                await AutoLogInteraction.button(logName).log(
                    fileID: fileID,
                    line: line,
                    column: column
                ) { @Sendable in
                    await action()
                }
            }
        }
    }

    /// Async role-based dynamic-string label-style button with a system image.
    @_disfavoredOverload
    @MainActor public static func log<S>(
        _ title: S,
        systemImage: String,
        logName: String? = nil,
        role: ButtonRole?,
        action: @escaping @Sendable () async -> Void,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column
    ) -> Button<SwiftUI.Label<Text, Image>> where S: StringProtocol {
        Button(title, systemImage: systemImage, role: role) {
            Task {
                await AutoLogInteraction.button(autoLogButtonName(title, logName: logName)).log(
                    fileID: fileID,
                    line: line,
                    column: column
                ) { @Sendable in
                    await action()
                }
            }
        }
    }

    /// Async role-based localized label-style button with a system image and stable log name.
    @MainActor public static func log(
        _ titleKey: LocalizedStringKey,
        systemImage: String,
        logName: String,
        role: ButtonRole?,
        action: @escaping @Sendable () async -> Void,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column
    ) -> Button<SwiftUI.Label<Text, Image>> {
        Button(titleKey, systemImage: systemImage, role: role) {
            Task {
                await AutoLogInteraction.button(logName).log(
                    fileID: fileID,
                    line: line,
                    column: column
                ) { @Sendable in
                    await action()
                }
            }
        }
    }

    /// Async role-based localized-resource label-style button with a system image and stable log name.
    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
    @MainActor public static func log(
        _ titleResource: LocalizedStringResource,
        systemImage: String,
        logName: String,
        role: ButtonRole?,
        action: @escaping @Sendable () async -> Void,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column
    ) -> Button<SwiftUI.Label<Text, Image>> {
        Button(titleResource, systemImage: systemImage, role: role) {
            Task {
                await AutoLogInteraction.button(logName).log(
                    fileID: fileID,
                    line: line,
                    column: column
                ) { @Sendable in
                    await action()
                }
            }
        }
    }

    /// Creates a label-style button with an image resource and logged interaction.
    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
    @MainActor public static func log(
        _ titleKey: StaticString,
        image: ImageResource,
        action: @escaping @MainActor () -> Void,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column
    ) -> Button<SwiftUI.Label<Text, Image>> {
        let logName = autoLogButtonName(titleKey)
        return Button(LocalizedStringKey(logName), image: image) {
            AutoLogInteraction.button(logName).log(
                fileID: fileID,
                line: line,
                column: column
            ) {
                action()
            }
        }
    }

    /// Creates a dynamic-string label-style button with an image resource.
    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
    @_disfavoredOverload
    @MainActor public static func log<S>(
        _ title: S,
        image: ImageResource,
        logName: String? = nil,
        action: @escaping @MainActor () -> Void,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column
    ) -> Button<SwiftUI.Label<Text, Image>> where S: StringProtocol {
        Button(title, image: image) {
            AutoLogInteraction.button(autoLogButtonName(title, logName: logName)).log(
                fileID: fileID,
                line: line,
                column: column
            ) {
                action()
            }
        }
    }

    /// Creates a localized label-style button with an image resource and stable log name.
    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
    @MainActor public static func log(
        _ titleKey: LocalizedStringKey,
        image: ImageResource,
        logName: String,
        action: @escaping @MainActor () -> Void,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column
    ) -> Button<SwiftUI.Label<Text, Image>> {
        Button(titleKey, image: image) {
            AutoLogInteraction.button(logName).log(
                fileID: fileID,
                line: line,
                column: column
            ) {
                action()
            }
        }
    }

    /// Creates a localized-resource label-style button with an image resource and stable log name.
    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
    @MainActor public static func log(
        _ titleResource: LocalizedStringResource,
        image: ImageResource,
        logName: String,
        action: @escaping @MainActor () -> Void,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column
    ) -> Button<SwiftUI.Label<Text, Image>> {
        Button(titleResource, image: image) {
            AutoLogInteraction.button(logName).log(
                fileID: fileID,
                line: line,
                column: column
            ) {
                action()
            }
        }
    }

    /// Creates a role-based label-style button with an image resource and logged interaction.
    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
    @MainActor public static func log(
        _ titleKey: StaticString,
        image: ImageResource,
        role: ButtonRole?,
        action: @escaping @MainActor () -> Void,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column
    ) -> Button<SwiftUI.Label<Text, Image>> {
        let logName = autoLogButtonName(titleKey)
        return Button(LocalizedStringKey(logName), image: image, role: role) {
            AutoLogInteraction.button(logName).log(
                fileID: fileID,
                line: line,
                column: column
            ) {
                action()
            }
        }
    }

    /// Creates a role-based dynamic-string label-style button with an image resource.
    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
    @_disfavoredOverload
    @MainActor public static func log<S>(
        _ title: S,
        image: ImageResource,
        logName: String? = nil,
        role: ButtonRole?,
        action: @escaping @MainActor () -> Void,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column
    ) -> Button<SwiftUI.Label<Text, Image>> where S: StringProtocol {
        Button(title, image: image, role: role) {
            AutoLogInteraction.button(autoLogButtonName(title, logName: logName)).log(
                fileID: fileID,
                line: line,
                column: column
            ) {
                action()
            }
        }
    }

    /// Creates a role-based localized label-style button with an image resource and stable log name.
    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
    @MainActor public static func log(
        _ titleKey: LocalizedStringKey,
        image: ImageResource,
        logName: String,
        role: ButtonRole?,
        action: @escaping @MainActor () -> Void,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column
    ) -> Button<SwiftUI.Label<Text, Image>> {
        Button(titleKey, image: image, role: role) {
            AutoLogInteraction.button(logName).log(
                fileID: fileID,
                line: line,
                column: column
            ) {
                action()
            }
        }
    }

    /// Creates a role-based localized-resource label-style button with an image resource and stable log name.
    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
    @MainActor public static func log(
        _ titleResource: LocalizedStringResource,
        image: ImageResource,
        logName: String,
        role: ButtonRole?,
        action: @escaping @MainActor () -> Void,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column
    ) -> Button<SwiftUI.Label<Text, Image>> {
        Button(titleResource, image: image, role: role) {
            AutoLogInteraction.button(logName).log(
                fileID: fileID,
                line: line,
                column: column
            ) {
                action()
            }
        }
    }

    /// Async label-style button with an image resource and logged interaction.
    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
    @MainActor public static func log(
        _ titleKey: StaticString,
        image: ImageResource,
        action: @escaping @Sendable () async -> Void,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column
    ) -> Button<SwiftUI.Label<Text, Image>> {
        let logName = autoLogButtonName(titleKey)
        return Button(LocalizedStringKey(logName), image: image) {
            Task {
                await AutoLogInteraction.button(logName).log(
                    fileID: fileID,
                    line: line,
                    column: column
                ) { @Sendable in
                    await action()
                }
            }
        }
    }

    /// Async dynamic-string label-style button with an image resource.
    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
    @_disfavoredOverload
    @MainActor public static func log<S>(
        _ title: S,
        image: ImageResource,
        logName: String? = nil,
        action: @escaping @Sendable () async -> Void,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column
    ) -> Button<SwiftUI.Label<Text, Image>> where S: StringProtocol {
        Button(title, image: image) {
            Task {
                await AutoLogInteraction.button(autoLogButtonName(title, logName: logName)).log(
                    fileID: fileID,
                    line: line,
                    column: column
                ) { @Sendable in
                    await action()
                }
            }
        }
    }

    /// Async localized label-style button with an image resource and stable log name.
    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
    @MainActor public static func log(
        _ titleKey: LocalizedStringKey,
        image: ImageResource,
        logName: String,
        action: @escaping @Sendable () async -> Void,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column
    ) -> Button<SwiftUI.Label<Text, Image>> {
        Button(titleKey, image: image) {
            Task {
                await AutoLogInteraction.button(logName).log(
                    fileID: fileID,
                    line: line,
                    column: column
                ) { @Sendable in
                    await action()
                }
            }
        }
    }

    /// Async localized-resource label-style button with an image resource and stable log name.
    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
    @MainActor public static func log(
        _ titleResource: LocalizedStringResource,
        image: ImageResource,
        logName: String,
        action: @escaping @Sendable () async -> Void,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column
    ) -> Button<SwiftUI.Label<Text, Image>> {
        Button(titleResource, image: image) {
            Task {
                await AutoLogInteraction.button(logName).log(
                    fileID: fileID,
                    line: line,
                    column: column
                ) { @Sendable in
                    await action()
                }
            }
        }
    }

    /// Async role-based label-style button with an image resource and logged interaction.
    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
    @MainActor public static func log(
        _ titleKey: StaticString,
        image: ImageResource,
        role: ButtonRole?,
        action: @escaping @Sendable () async -> Void,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column
    ) -> Button<SwiftUI.Label<Text, Image>> {
        let logName = autoLogButtonName(titleKey)
        return Button(LocalizedStringKey(logName), image: image, role: role) {
            Task {
                await AutoLogInteraction.button(logName).log(
                    fileID: fileID,
                    line: line,
                    column: column
                ) { @Sendable in
                    await action()
                }
            }
        }
    }

    /// Async role-based dynamic-string label-style button with an image resource.
    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
    @_disfavoredOverload
    @MainActor public static func log<S>(
        _ title: S,
        image: ImageResource,
        logName: String? = nil,
        role: ButtonRole?,
        action: @escaping @Sendable () async -> Void,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column
    ) -> Button<SwiftUI.Label<Text, Image>> where S: StringProtocol {
        Button(title, image: image, role: role) {
            Task {
                await AutoLogInteraction.button(autoLogButtonName(title, logName: logName)).log(
                    fileID: fileID,
                    line: line,
                    column: column
                ) { @Sendable in
                    await action()
                }
            }
        }
    }

    /// Async role-based localized label-style button with an image resource and stable log name.
    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
    @MainActor public static func log(
        _ titleKey: LocalizedStringKey,
        image: ImageResource,
        logName: String,
        role: ButtonRole?,
        action: @escaping @Sendable () async -> Void,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column
    ) -> Button<SwiftUI.Label<Text, Image>> {
        Button(titleKey, image: image, role: role) {
            Task {
                await AutoLogInteraction.button(logName).log(
                    fileID: fileID,
                    line: line,
                    column: column
                ) { @Sendable in
                    await action()
                }
            }
        }
    }

    /// Async role-based localized-resource label-style button with an image resource and stable log name.
    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
    @MainActor public static func log(
        _ titleResource: LocalizedStringResource,
        image: ImageResource,
        logName: String,
        role: ButtonRole?,
        action: @escaping @Sendable () async -> Void,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column
    ) -> Button<SwiftUI.Label<Text, Image>> {
        Button(titleResource, image: image, role: role) {
            Task {
                await AutoLogInteraction.button(logName).log(
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

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 26.0, *)
extension Button where Label == DefaultButtonLabel {
    /// Mirrors `Button(role:action:)` while logging a stable interaction name.
    @MainActor public static func log(
        _ name: String,
        role: ButtonRole,
        action: @escaping @MainActor () -> Void,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column
    ) -> Button<DefaultButtonLabel> {
        Button(role: role) {
            AutoLogInteraction.button(name).log(
                fileID: fileID,
                line: line,
                column: column
            ) {
                action()
            }
        }
    }

    /// Async variant of ``log(_:role:action:fileID:line:column:)``.
    @MainActor public static func log(
        _ name: String,
        role: ButtonRole,
        action: @escaping @Sendable () async -> Void,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column
    ) -> Button<DefaultButtonLabel> {
        Button(role: role) {
            Task {
                await AutoLogInteraction.button(name).log(
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

extension AutoLogInteraction {
    /// Interaction names should be stable identifiers rather than localized UI
    /// labels. Pass the localization key's stable source name as a `String`.
    @available(*, unavailable, message: "Use a stable String interaction name instead of LocalizedStringKey display text.")
    public static func button(_ title: LocalizedStringKey) -> AutoLogInteraction {
        .button(nil)
    }
}

// MARK: - View lifecycle and callback modifiers

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
@MainActor
private struct AutoLogTaskOperation: Sendable {
    let source: any Sourceable
    let priority: TaskPriority
    let fileID: String
    let line: Int
    let column: Int
    let action: @Sendable () async -> Void

    func makeTask() -> Task<Void, Never> {
        Task(priority: priority) {
            await source.log(fileID: fileID, line: line, column: column) { @Sendable in
                await action()
            }
        }
    }
}

// Avoid delegating to SwiftUI .task here: watchOS Release clients can otherwise
// link against SwiftUI task opaque return descriptors that are not exported.
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
@MainActor
private struct AutoLogTaskModifier: ViewModifier {
    let operation: AutoLogTaskOperation

    @State private var currentTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .onAppear {
                startTask()
            }
            .onDisappear {
                cancelTask()
            }
    }

    private func startTask() {
        cancelTask()
        currentTask = operation.makeTask()
    }

    private func cancelTask() {
        currentTask?.cancel()
        currentTask = nil
    }
}

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
@MainActor
private struct AutoLogTaskIDModifier<ID: Equatable>: ViewModifier {
    let operation: AutoLogTaskOperation
    let value: ID

    @State private var currentTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .onAppear {
                startTask()
            }
            .onChange(of: value) { _, _ in
                startTask()
            }
            .onDisappear {
                cancelTask()
            }
    }

    private func startTask() {
        cancelTask()
        currentTask = operation.makeTask()
    }

    private func cancelTask() {
        currentTask?.cancel()
        currentTask = nil
    }
}

extension View {
    /// Runs `action` from `onAppear` with a system interaction source.
    ///
    /// Use this for view lifecycle work that should become a trace root for
    /// downstream `@AutoLog` calls.
    @MainActor public func onAppearLog(
        _ name: String,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column,
        perform action: @escaping @MainActor () -> Void
    ) -> some View {
        onAppearLog(
            AutoLogInteraction.system(name),
            fileID: fileID,
            line: line,
            column: column,
            perform: action
        )
    }

    /// Runs `action` from `onAppear` with a built-in interaction source.
    @MainActor public func onAppearLog(
        _ source: AutoLogInteraction,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column,
        perform action: @escaping @MainActor () -> Void
    ) -> some View {
        onAppearLog(
            source as any Sourceable,
            fileID: fileID,
            line: line,
            column: column,
            perform: action
        )
    }

    /// Runs `action` from `onAppear` with a custom interaction source.
    @MainActor public func onAppearLog(
        _ source: any Sourceable,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column,
        perform action: @escaping @MainActor () -> Void
    ) -> some View {
        onAppear {
            source.log(fileID: fileID, line: line, column: column) {
                action()
            }
        }
    }

    /// Runs SwiftUI `.task` work with a system interaction source.
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    @MainActor public func taskLog(
        _ name: String,
        priority: TaskPriority = .userInitiated,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column,
        _ action: @escaping @Sendable () async -> Void
    ) -> some View {
        taskLog(
            AutoLogInteraction.system(name),
            priority: priority,
            fileID: fileID,
            line: line,
            column: column,
            action
        )
    }

    /// Runs SwiftUI `.task` work with a built-in interaction source.
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    @MainActor public func taskLog(
        _ source: AutoLogInteraction,
        priority: TaskPriority = .userInitiated,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column,
        _ action: @escaping @Sendable () async -> Void
    ) -> some View {
        taskLog(
            source as any Sourceable,
            priority: priority,
            fileID: fileID,
            line: line,
            column: column,
            action
        )
    }

    /// Runs SwiftUI `.task` work with a custom interaction source.
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    @MainActor public func taskLog(
        _ source: any Sourceable,
        priority: TaskPriority = .userInitiated,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column,
        _ action: @escaping @Sendable () async -> Void
    ) -> some View {
        modifier(
            AutoLogTaskModifier(
                operation: AutoLogTaskOperation(
                    source: source,
                    priority: priority,
                    fileID: fileID,
                    line: line,
                    column: column,
                    action: action
                )
            )
        )
    }

    /// Runs SwiftUI `.task(id:)` work with a system interaction source.
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    @MainActor public func taskLog<ID: Equatable>(
        _ name: String,
        id value: ID,
        priority: TaskPriority = .userInitiated,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column,
        _ action: @escaping @Sendable () async -> Void
    ) -> some View {
        taskLog(
            AutoLogInteraction.system(name),
            id: value,
            priority: priority,
            fileID: fileID,
            line: line,
            column: column,
            action
        )
    }

    /// Runs SwiftUI `.task(id:)` work with a built-in interaction source.
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    @MainActor public func taskLog<ID: Equatable>(
        _ source: AutoLogInteraction,
        id value: ID,
        priority: TaskPriority = .userInitiated,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column,
        _ action: @escaping @Sendable () async -> Void
    ) -> some View {
        taskLog(
            source as any Sourceable,
            id: value,
            priority: priority,
            fileID: fileID,
            line: line,
            column: column,
            action
        )
    }

    /// Runs SwiftUI `.task(id:)` work with a custom interaction source.
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    @MainActor public func taskLog<ID: Equatable>(
        _ source: any Sourceable,
        id value: ID,
        priority: TaskPriority = .userInitiated,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column,
        _ action: @escaping @Sendable () async -> Void
    ) -> some View {
        modifier(
            AutoLogTaskIDModifier(
                operation: AutoLogTaskOperation(
                    source: source,
                    priority: priority,
                    fileID: fileID,
                    line: line,
                    column: column,
                    action: action
                ),
                value: value
            )
        )
    }

    /// Runs SwiftUI `.onChange(of:)` callbacks with a system interaction source.
    @MainActor public func onChangeLog<Value: Equatable>(
        _ name: String,
        of value: Value,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column,
        perform action: @escaping @MainActor (Value) -> Void
    ) -> some View {
        onChangeLog(
            AutoLogInteraction.system(name),
            of: value,
            fileID: fileID,
            line: line,
            column: column,
            perform: action
        )
    }

    /// Runs SwiftUI `.onChange(of:)` callbacks with a built-in interaction source.
    @MainActor public func onChangeLog<Value: Equatable>(
        _ source: AutoLogInteraction,
        of value: Value,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column,
        perform action: @escaping @MainActor (Value) -> Void
    ) -> some View {
        onChangeLog(
            source as any Sourceable,
            of: value,
            fileID: fileID,
            line: line,
            column: column,
            perform: action
        )
    }

    /// Runs SwiftUI `.onChange(of:)` callbacks with a custom interaction source.
    @MainActor public func onChangeLog<Value: Equatable>(
        _ source: any Sourceable,
        of value: Value,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column,
        perform action: @escaping @MainActor (Value) -> Void
    ) -> some View {
        onChange(of: value) { _, newValue in
            source.log(fileID: fileID, line: line, column: column) {
                action(newValue)
            }
        }
    }

    /// Runs SwiftUI `.onReceive` callbacks with a system interaction source.
    @MainActor public func onReceiveLog<P: Publisher>(
        _ name: String,
        _ publisher: P,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column,
        perform action: @escaping @MainActor (P.Output) -> Void
    ) -> some View where P.Failure == Never {
        onReceiveLog(
            AutoLogInteraction.system(name),
            publisher,
            fileID: fileID,
            line: line,
            column: column,
            perform: action
        )
    }

    /// Runs SwiftUI `.onReceive` callbacks with a built-in interaction source.
    @MainActor public func onReceiveLog<P: Publisher>(
        _ source: AutoLogInteraction,
        _ publisher: P,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column,
        perform action: @escaping @MainActor (P.Output) -> Void
    ) -> some View where P.Failure == Never {
        onReceiveLog(
            source as any Sourceable,
            publisher,
            fileID: fileID,
            line: line,
            column: column,
            perform: action
        )
    }

    /// Runs SwiftUI `.onReceive` callbacks with a custom interaction source.
    @MainActor public func onReceiveLog<P: Publisher>(
        _ source: any Sourceable,
        _ publisher: P,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column,
        perform action: @escaping @MainActor (P.Output) -> Void
    ) -> some View where P.Failure == Never {
        onReceive(publisher) { output in
            source.log(fileID: fileID, line: line, column: column) {
                action(output)
            }
        }
    }

    /// Runs SwiftUI `.refreshable` work with a system interaction source.
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    @MainActor public func refreshableLog(
        _ name: String,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column,
        action: @escaping @Sendable () async -> Void
    ) -> some View {
        refreshableLog(
            AutoLogInteraction.system(name),
            fileID: fileID,
            line: line,
            column: column,
            action: action
        )
    }

    /// Runs SwiftUI `.refreshable` work with a built-in interaction source.
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    @MainActor public func refreshableLog(
        _ source: AutoLogInteraction,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column,
        action: @escaping @Sendable () async -> Void
    ) -> some View {
        refreshableLog(
            source as any Sourceable,
            fileID: fileID,
            line: line,
            column: column,
            action: action
        )
    }

    /// Runs SwiftUI `.refreshable` work with a custom interaction source.
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    @MainActor public func refreshableLog(
        _ source: any Sourceable,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column,
        action: @escaping @Sendable () async -> Void
    ) -> some View {
        refreshable {
            await source.log(fileID: fileID, line: line, column: column) { @Sendable in
                await action()
            }
        }
    }

    /// Runs SwiftUI `.onSubmit` callbacks with a system interaction source.
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    @MainActor public func onSubmitLog(
        _ name: String,
        of triggers: SubmitTriggers = .text,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column,
        _ action: @escaping @MainActor () -> Void
    ) -> some View {
        onSubmitLog(
            AutoLogInteraction.system(name),
            of: triggers,
            fileID: fileID,
            line: line,
            column: column,
            action
        )
    }

    /// Runs SwiftUI `.onSubmit` callbacks with a built-in interaction source.
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    @MainActor public func onSubmitLog(
        _ source: AutoLogInteraction,
        of triggers: SubmitTriggers = .text,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column,
        _ action: @escaping @MainActor () -> Void
    ) -> some View {
        onSubmitLog(
            source as any Sourceable,
            of: triggers,
            fileID: fileID,
            line: line,
            column: column,
            action
        )
    }

    /// Runs SwiftUI `.onSubmit` callbacks with a custom interaction source.
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    @MainActor public func onSubmitLog(
        _ source: any Sourceable,
        of triggers: SubmitTriggers = .text,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column,
        _ action: @escaping @MainActor () -> Void
    ) -> some View {
        onSubmit(of: triggers) {
            source.log(fileID: fileID, line: line, column: column) {
                action()
            }
        }
    }
}

// MARK: - Binding.log

extension Binding {
    /// Returns a new binding that logs interactions when the value is set,
    /// propagating the source to all downstream `@AutoLog` function calls.
    ///
    /// Use the ``InteractionSource``-typed overload for dot-shorthand syntax:
    /// ```swift
    /// Toggle("Dark Mode", isOn: $vm.darkMode.log(.toggle("Dark Mode")))
    /// ```
    @MainActor public func log(
        _ source: AutoLogInteraction,
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
        _ source: AutoLogInteraction,
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
