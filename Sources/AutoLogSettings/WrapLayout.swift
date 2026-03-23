import SwiftUI

/// A SwiftUI `Layout` that wraps its children into rows, like CSS `flex-wrap`.
struct WrapLayout: Layout {
  var hSpacing: CGFloat = 8
  var vSpacing: CGFloat = 8

  func sizeThatFits(
    proposal: ProposedViewSize,
    subviews: Subviews,
    cache: inout ()
  ) -> CGSize {
    let result = arrange(subviews: subviews, in: proposal.replacingUnspecifiedDimensions().width)
    return result.size
  }

  func placeSubviews(
    in bounds: CGRect,
    proposal: ProposedViewSize,
    subviews: Subviews,
    cache: inout ()
  ) {
    let result = arrange(subviews: subviews, in: bounds.width)
    for (frame, subview) in zip(result.frames, subviews) {
      subview.place(
        at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
        proposal: ProposedViewSize(frame.size)
      )
    }
  }

  // MARK: - Private

  private struct Arrangement {
    var frames: [CGRect]
    var size: CGSize
  }

  private func arrange(subviews: Subviews, in maxWidth: CGFloat) -> Arrangement {
    var frames: [CGRect] = []
    var x: CGFloat = 0
    var y: CGFloat = 0
    var rowHeight: CGFloat = 0
    var totalWidth: CGFloat = 0

    for subview in subviews {
      let size = subview.sizeThatFits(.unspecified)
      if x + size.width > maxWidth, x > 0 {
        x = 0
        y += rowHeight + vSpacing
        rowHeight = 0
      }
      frames.append(CGRect(origin: .init(x: x, y: y), size: size))
      rowHeight = max(rowHeight, size.height)
      x += size.width + hSpacing
      totalWidth = max(totalWidth, x - hSpacing)
    }

    return Arrangement(
      frames: frames,
      size: CGSize(width: totalWidth, height: y + rowHeight)
    )
  }
}
