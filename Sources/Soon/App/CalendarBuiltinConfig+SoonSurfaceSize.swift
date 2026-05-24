import CoreGraphics
import EasyBarCalendarConfig

extension CalendarBuiltinConfig {
  /// Returns the actual surface size used by Soon for the active popup layout.
  var soonPopupSurfaceSize: CGSize {
    switch popupMode {
    case .month:
      let contentWidth: CGFloat

      switch month.popup.layout {
      case .calendarAppointmentsHorizontal, .appointmentsCalendarHorizontal:
        contentWidth = 560
      case .calendarAppointmentsVertical, .appointmentsCalendarVertical:
        contentWidth = 320
      }

      return CGSize(
        width: decorateHorizontal(contentWidth, paddingX: month.popup.paddingX, marginX: month.popup.marginX),
        height: decorateVertical(560, paddingY: month.popup.paddingY, marginY: month.popup.marginY)
      )

    case .upcoming:
      return CGSize(
        width: decorateHorizontal(
          360,
          paddingX: upcoming.popup.paddingX,
          marginX: upcoming.popup.marginX
        ),
        height: decorateVertical(
          520,
          paddingY: upcoming.popup.paddingY,
          marginY: upcoming.popup.marginY
        )
      )

    case .none:
      return CGSize(width: 280, height: 96)
    }
  }

  /// Expands one content width to include popup padding and outer margins.
  private func decorateHorizontal(_ contentWidth: CGFloat, paddingX: Double, marginX: Double) -> CGFloat {
    contentWidth + (CGFloat(paddingX) * 2) + (CGFloat(marginX) * 2)
  }

  /// Expands one content height to include popup padding and outer margins.
  private func decorateVertical(_ contentHeight: CGFloat, paddingY: Double, marginY: Double) -> CGFloat {
    contentHeight + (CGFloat(paddingY) * 2) + (CGFloat(marginY) * 2)
  }
}
