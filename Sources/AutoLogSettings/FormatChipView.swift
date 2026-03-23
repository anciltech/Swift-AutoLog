import SwiftUI
import AutoLog

// MARK: - Chip appearance

enum ChipRole {
  case active   // In the format strip — accent fill
  case palette  // In the palette — secondary fill
}

/// A pill-shaped chip representing one ``LogFormat/Element``.
struct FormatChipView: View {
  let element: LogFormat.Element
  let role: ChipRole
  /// When `true` a small × button appears (active chips only).
  var showRemove: Bool = false
  var onRemove: (() -> Void)? = nil

  var body: some View {
    HStack(spacing: 5) {
      Text(element.previewFragment)
        .font(.system(.caption, design: element.isSpacer ? .monospaced : .rounded))
        .fontWeight(.semibold)

      if element.isSpacer {
        // No extra label for spacers — the preview fragment is the whole chip
      } else {
        Text(element.displayName)
          .font(.system(.caption, design: .rounded))
          .fontWeight(.medium)
          .lineLimit(1)
      }

      if showRemove {
        Button {
          onRemove?()
        } label: {
          Image(systemName: "xmark")
            .font(.system(size: 8, weight: .bold))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
      }
    }
    .padding(.horizontal, element.isSpacer ? 10 : 10)
    .padding(.vertical, 5)
    .background(background)
    .foregroundStyle(foreground)
    .clipShape(RoundedRectangle(cornerRadius: 7))
    .overlay(
      RoundedRectangle(cornerRadius: 7)
        .strokeBorder(border, lineWidth: 1)
    )
    .help(element.elementDescription)
  }

  // MARK: - Colours

  private var background: Color {
    switch role {
    case .active  where element.isSpacer: return Color.orange.opacity(0.18)
    case .active:                         return Color.accentColor.opacity(0.15)
    case .palette where element.isSpacer: return Color.orange.opacity(0.07)
    case .palette:                        return Color.secondary.opacity(0.10)
    }
  }

  private var foreground: Color {
    switch role {
    case .active  where element.isSpacer: return Color.orange
    case .active:                         return Color.accentColor
    case .palette where element.isSpacer: return Color.orange.opacity(0.7)
    case .palette:                        return Color.secondary
    }
  }

  private var border: Color {
    switch role {
    case .active  where element.isSpacer: return Color.orange.opacity(0.4)
    case .active:                         return Color.accentColor.opacity(0.3)
    case .palette:                        return Color.secondary.opacity(0.2)
    }
  }
}

// MARK: - Insertion indicator

/// The thin blue vertical bar shown between chips during a drag.
struct InsertionIndicatorView: View {
  var body: some View {
    RoundedRectangle(cornerRadius: 2)
      .fill(Color.accentColor)
      .frame(width: 3)
      .padding(.vertical, 2)
  }
}
