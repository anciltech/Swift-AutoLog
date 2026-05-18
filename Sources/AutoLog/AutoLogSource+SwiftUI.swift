#if canImport(SwiftUI)
import SwiftUI

// MARK: - Button.log

private func autoLogButtonName<S: StringProtocol>(
    _ title: S,
    logName: String?
) -> String {
    logName ?? String(title)
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
