import SwiftUI
import AutoLog
import UniformTypeIdentifiers

// MARK: - Payload helpers

/// Encodes which zone and index a dragged chip came from.
///
/// Active chips encode as `"A:<index>:<rawValue>"`.
/// Palette chips encode as `"P:<rawValue>"`.
private func encodeActive(index: Int, element: LogFormat.Element) -> String {
  "A:\(index):\(element.rawValue)"
}

private func encodePalette(element: LogFormat.Element) -> String {
  "P:\(element.rawValue)"
}

private struct DragPayload {
  enum Origin { case active(index: Int); case palette }
  let origin: Origin
  let element: LogFormat.Element

  init?(_ string: String) {
    let parts = string.split(separator: ":", maxSplits: 2).map(String.init)
    switch parts.first {
    case "A" where parts.count == 3:
      guard let idx = Int(parts[1]),
            let el  = LogFormat.Element(rawValue: parts[2]) else { return nil }
      origin  = .active(index: idx)
      element = el
    case "P" where parts.count == 2:
      guard let el = LogFormat.Element(rawValue: parts[1]) else { return nil }
      origin  = .palette
      element = el
    default:
      return nil
    }
  }
}

// MARK: - FormatEditorView

/// Left-hand panel: two-zone chip drag-and-drop format editor.
struct FormatEditorView: View {
  @Bindable var viewModel: SettingsViewModel

  /// Index in `activeElements` where the next drop will insert, or `nil`.
  @State private var insertionIndex: Int? = nil
  /// Whether the palette is currently highlighted as a drop target.
  @State private var paletteIsTargeted = false
  /// Index of the hovered active chip (shows × button).
  @State private var hoveredActiveIndex: Int? = nil

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      header
      Divider()

      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          activeSection
          paletteSection
          arrowStyleSection
          statusStyleSection
        }
        .padding(16)
      }

      Divider()
      footer
    }
    .frame(minWidth: 400)
  }

  // MARK: - Header / footer

  private var header: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text("Format Builder")
        .font(.headline)
      Text("Drag chips to build your log line · drag to palette to remove")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .padding([.horizontal, .top], 16)
    .padding(.bottom, 10)
  }

  private var footer: some View {
    HStack(spacing: 12) {
      Button("Reset to Default") { viewModel.resetToDefault() }
        .buttonStyle(.bordered)
      Spacer()
      Button {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(viewModel.codeSnippet, forType: .string)
      } label: {
        Label("Copy Code", systemImage: "doc.on.doc")
      }
      .buttonStyle(.borderedProminent)
    }
    .padding(16)
  }

  // MARK: - Active strip section

  private var activeSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label("Active Format", systemImage: "arrow.left.arrow.right")
        .font(.subheadline.weight(.semibold))

      activeStrip
    }
  }

  @ViewBuilder
  private var activeStrip: some View {
    let isEmpty = viewModel.activeElements.isEmpty

    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 6) {
        // Empty-state hint + drop target
        if isEmpty {
          Text("Drop elements here")
            .font(.caption)
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 12)
        }

        // Chips + insertion indicators
        ForEach(viewModel.activeElements.indices, id: \.self) { i in
          // Insertion indicator before chip i
          if insertionIndex == i {
            InsertionIndicatorView()
          }

          activeChip(at: i)
        }

        // Insertion indicator at end (after all chips)
        if insertionIndex == viewModel.activeElements.count {
          InsertionIndicatorView()
        }

        // Invisible spacer so the strip always has a drop zone even when chips fill it
        Color.clear.frame(width: 24, height: 36)
          .contentShape(Rectangle())
          .onDrop(of: [.plainText], isTargeted: Binding(
            get: { insertionIndex == viewModel.activeElements.count && !isEmpty },
            set: { _ in }
          )) { providers in
            handleDrop(providers: providers, at: viewModel.activeElements.count)
          }
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 10)
    }
    .frame(minHeight: 56)
    .background(isEmpty ? Color.accentColor.opacity(0.04) : Color.secondary.opacity(0.06))
    .clipShape(RoundedRectangle(cornerRadius: 10))
    .overlay(
      RoundedRectangle(cornerRadius: 10)
        .strokeBorder(
          isEmpty ? Color.accentColor.opacity(0.25) : Color.clear,
          style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
        )
    )
    // The strip background receives drops (inserts at end) when not over a chip
    .onDrop(of: [.plainText], isTargeted: Binding(
      get: { insertionIndex == viewModel.activeElements.count },
      set: { active in
        if !active, insertionIndex == viewModel.activeElements.count {
          insertionIndex = nil
        }
      }
    )) { providers in
      handleDrop(providers: providers, at: viewModel.activeElements.count)
    }
  }

  @ViewBuilder
  private func activeChip(at i: Int) -> some View {
    let element = viewModel.activeElements[i]

    FormatChipView(
      element: element,
      role: .active,
      showRemove: hoveredActiveIndex == i,
      onRemove: { viewModel.deactivate(at: i) }
    )
    .onHover { hoveredActiveIndex = $0 ? i : nil }
    // Make it draggable
    .onDrag {
      NSItemProvider(object: encodeActive(index: i, element: element) as NSString)
    }
    // Accept drops from both palette and other active chips
    .onDrop(
      of: [.plainText],
      isTargeted: Binding(
        get: { insertionIndex == i },
        set: { active in
          insertionIndex = active ? i : (insertionIndex == i ? nil : insertionIndex)
        }
      )
    ) { providers in
      handleDrop(providers: providers, at: i)
    }
  }

  // MARK: - Palette section

  private var paletteSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label("Available Elements", systemImage: "square.grid.2x2")
        .font(.subheadline.weight(.semibold))

      paletteGrid
    }
  }

  private var paletteGrid: some View {
    Group {
      if viewModel.inactiveElements.isEmpty {
        Text("All elements are active")
          .font(.caption)
          .foregroundStyle(.tertiary)
          .padding(12)
      } else {
        WrapLayout(hSpacing: 8, vSpacing: 8) {
          ForEach(viewModel.inactiveElements) { element in
            FormatChipView(element: element, role: .palette)
              .onDrag {
                NSItemProvider(object: encodePalette(element: element) as NSString)
              }
          }
        }
        .padding(12)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(paletteIsTargeted ? Color.red.opacity(0.06) : Color.secondary.opacity(0.04))
    .clipShape(RoundedRectangle(cornerRadius: 10))
    .overlay(
      RoundedRectangle(cornerRadius: 10)
        .strokeBorder(
          paletteIsTargeted ? Color.red.opacity(0.4) : Color.secondary.opacity(0.15),
          lineWidth: 1
        )
    )
    // Palette accepts drops from active strip → deactivates the chip
    .onDrop(of: [.plainText], isTargeted: $paletteIsTargeted) { providers in
      handleDropOnPalette(providers: providers)
    }
  }

  // MARK: - Arrow style section

  private var arrowStyleSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      Label("Arrow Style", systemImage: "arrow.right")
        .font(.subheadline.weight(.semibold))

      HStack(spacing: 16) {
        arrowField(label: "Start", value: Binding(
          get: { viewModel.arrowStyle.start },
          set: { viewModel.updateArrowStyle(
            LogFormat.ArrowStyle(start: $0,
                                 repeater: viewModel.arrowStyle.repeater,
                                 end:      viewModel.arrowStyle.end))
          }
        ))

        arrowField(label: "Repeat", value: Binding(
          get: { viewModel.arrowStyle.repeater },
          set: { viewModel.updateArrowStyle(
            LogFormat.ArrowStyle(start:    viewModel.arrowStyle.start,
                                 repeater: $0,
                                 end:      viewModel.arrowStyle.end))
          }
        ))

        arrowField(label: "End", value: Binding(
          get: { viewModel.arrowStyle.end },
          set: { viewModel.updateArrowStyle(
            LogFormat.ArrowStyle(start:    viewModel.arrowStyle.start,
                                 repeater: viewModel.arrowStyle.repeater,
                                 end:      $0))
          }
        ))
      }

      // Live depth preview
      HStack(spacing: 12) {
        ForEach(1...4, id: \.self) { depth in
          VStack(spacing: 2) {
            Text(viewModel.arrowStyle.arrow(for: depth))
              .font(.system(.body, design: .monospaced))
              .foregroundStyle(.primary)
            Text("depth \(depth)")
              .font(.caption2)
              .foregroundStyle(.tertiary)
          }
        }
        Spacer()
      }
      .padding(10)
      .background(Color.secondary.opacity(0.06))
      .clipShape(RoundedRectangle(cornerRadius: 8))
    }
  }

  // MARK: - Status style section

  private var statusStyleRows: [(label: String, preview: String,
                                  get: KeyPath<LogFormat.StatusStyle, String>,
                                  set: WritableKeyPath<LogFormat.StatusStyle, String>)] {
    [
      ("Start",   "🔵", \.start,   \.start),
      ("Success", "🟢", \.success, \.success),
      ("Failure", "🔴", \.failure, \.failure),
      ("Warning", "🟡", \.warning, \.warning),
      ("Update",  "🟣", \.update,  \.update),
    ]
  }

  private var statusStyleSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      Label("Status", systemImage: "circle.fill")
        .font(.subheadline.weight(.semibold))

      HStack(spacing: 16) {
        ForEach(statusStyleRows, id: \.label) { row in
          statusField(
            label:   row.label,
            preview: row.preview,
            value: Binding(
              get: { viewModel.statusStyle[keyPath: row.get] },
              set: {
                var s = viewModel.statusStyle
                s[keyPath: row.set] = $0
                viewModel.updateStatusStyle(s)
              }
            )
          )
        }
      }
    }
  }

  private func statusField(label: String, preview: String, value: Binding<String>) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack(spacing: 4) {
        Text(preview)
          .font(.caption)
        Text(label)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      TextField("", text: value)
        .textFieldStyle(.roundedBorder)
        .font(.system(.body, design: .monospaced))
        .frame(width: 52)
    }
  }

  private func arrowField(label: String, value: Binding<String>) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(label)
        .font(.caption)
        .foregroundStyle(.secondary)
      TextField("", text: value)
        .textFieldStyle(.roundedBorder)
        .font(.system(.body, design: .monospaced))
        .frame(width: 60)
    }
  }

  // MARK: - Drop handlers

  private func handleDrop(providers: [NSItemProvider], at index: Int) -> Bool {
    insertionIndex = nil
    guard let provider = providers.first else { return false }

    provider.loadObject(ofClass: NSString.self) { item, _ in
      guard let string = item as? String,
            let payload = DragPayload(string) else { return }

      DispatchQueue.main.async {
        switch payload.origin {
        case .active(let fromIndex):
          viewModel.moveInActive(from: fromIndex, to: index)
        case .palette:
          viewModel.activate(payload.element, at: index)
        }
      }
    }
    return true
  }

  private func handleDropOnPalette(providers: [NSItemProvider]) -> Bool {
    guard let provider = providers.first else { return false }

    provider.loadObject(ofClass: NSString.self) { item, _ in
      guard let string = item as? String,
            let payload = DragPayload(string),
            case .active(let fromIndex) = payload.origin else { return }

      DispatchQueue.main.async {
        viewModel.deactivate(at: fromIndex)
      }
    }
    return true
  }
}
