import CoreGraphics
import EasyBarCalendarConfig

extension CalendarBuiltinConfig {
  /// Returns the actual surface size used by Soon for the active popup layout.
  var soonPopupSurfaceSize: CGSize {
    switch popupMode {
    case .month:
      let width: CGFloat

      switch month.popup.layout {
      case .calendarAppointmentsHorizontal, .appointmentsCalendarHorizontal:
        width = 560
      case .calendarAppointmentsVertical, .appointmentsCalendarVertical:
        width = 260
      }

      return CGSize(width: width, height: 560)

    case .upcoming:
      return CGSize(width: 360, height: 520)

    case .none:
      return CGSize(width: 280, height: 96)
    }
  }
}
