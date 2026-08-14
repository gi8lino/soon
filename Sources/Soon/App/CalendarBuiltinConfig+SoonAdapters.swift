import EasyBarCalendarConfig
import EasyBarCalendarPresentation
import EasyBarShared

extension CalendarBuiltinConfig {
  var soonPresentationFilters: CalendarRequestFilters {
    CalendarRequestFilters(
      includedCalendarNames: filters.includedCalendarNames,
      excludedCalendarNames: filters.excludedCalendarNames,
      includedCalendarIDs: filters.includedCalendarIDs,
      excludedCalendarIDs: filters.excludedCalendarIDs,
      includedCalendarSourceIDs: filters.includedCalendarSourceIDs,
      excludedCalendarSourceIDs: filters.excludedCalendarSourceIDs
    )
  }

  var soonPresentationBirthdays: CalendarBirthdayRequestOptions {
    CalendarBirthdayRequestOptions(
      showBirthdays: birthdays.showBirthdays,
      showAge: birthdays.birthdaysShowAge
    )
  }

  var presentationUpcomingRequestOptions: CalendarUpcomingRequestOptions {
    CalendarUpcomingRequestOptions(
      dayCount: upcoming.events.days,
      emptyText: appointments.emptyText,
      allDayLabel: appointments.allDayLabel,
      birthdays: soonPresentationBirthdays,
      filters: soonPresentationFilters
    )
  }

  var presentationMonthRequestOptions: CalendarMonthRequestOptions {
    CalendarMonthRequestOptions(
      emptyText: appointments.emptyText,
      allDayLabel: appointments.allDayLabel,
      birthdays: soonPresentationBirthdays,
      filters: soonPresentationFilters
    )
  }

  var appointmentsCalendarUIStyle: CalendarAppointmentsStyle {
    CalendarAppointmentsStyle(
      secondaryTextColorHex: appointments.secondaryTextColorHex,
      emptyTextColorHex: appointments.emptyTextColorHex,
      eventTextColorHex: appointments.eventTextColorHex,
      travelTextColorHex: appointments.travelTextColorHex,
      locationIconColorHex: appointments.locationIconColorHex,
      travelIconColorHex: appointments.travelIconColorHex,
      alertIconColorHex: appointments.alertIconColorHex,
      showCalendarName: appointments.showCalendarName,
      showLocation: appointments.showLocation,
      showTravelTime: appointments.showTravelTime,
      showEndTime: appointments.showEndTime,
      showAlertIcon: appointments.showAlertIcon,
      showAllDayLabel: appointments.showAllDayLabel,
      allDayLabel: appointments.allDayLabel,
      showHolidayAllDayLabel: appointments.showHolidayAllDayLabel,
      locationIcon: appointments.locationIcon,
      alertIcon: appointments.alertIcon,
      travelIcon: appointments.travelIcon,
      itemIndent: appointments.itemIndent
    )
  }

  var birthdayCalendarUIStyle: CalendarBirthdayStyle {
    CalendarBirthdayStyle(
      birthdayIcon: birthdays.birthdayIcon,
      birthdayIconColorHex: birthdays.birthdayIconColorHex
    )
  }

  var calendarComposerUIConfig: CalendarComposerConfig {
    let style = composer.style
    let content = composer.content

    return CalendarComposerConfig(
      createTitle: content.createTitle,
      editTitle: content.editTitle,
      saveLabel: content.saveLabel,
      updateLabel: content.updateLabel,
      removeLabel: content.removeLabel,
      cancelLabel: content.cancelLabel,
      deleteConfirmationTitle: content.deleteConfirmationTitle,
      deleteConfirmationMessage: content.deleteConfirmationMessage,
      openCalendarLabel: content.openCalendarLabel,
      titleLabel: content.titleLabel,
      titlePlaceholder: content.titlePlaceholder,
      locationLabel: content.locationLabel,
      locationPlaceholder: content.locationPlaceholder,
      calendarLabel: content.calendarLabel,
      allDayLabel: content.allDayLabel,
      startLabel: content.startLabel,
      endLabel: content.endLabel,
      travelTimeLabel: content.travelTimeLabel,
      alertLabel: content.alertLabel,
      addAlertLabel: content.addAlertLabel,
      defaultCalendarName: content.defaultCalendarName,
      defaultAlert: content.defaultAlert,
      defaultTravelTime: content.defaultTravelTime,
      alertLabels: content.alertLabels,
      travelTimeLabels: content.travelTimeLabels,
      paddingX: style.paddingX,
      paddingY: style.paddingY,
      backgroundColorHex: style.backgroundColorHex,
      borderColorHex: style.borderColorHex,
      borderWidth: style.borderWidth,
      cornerRadius: style.cornerRadius,
      headerTextColorHex: style.headerTextColorHex,
      secondaryTextColorHex: appointments.secondaryTextColorHex
    )
  }

  var calendarMonthPopupUIConfig: CalendarMonthPopupConfig {
    let popup = month.popup
    let style = popup.style
    let calendar = popup.calendar
    let selection = popup.selection
    let agenda = popup.agenda
    let anchor = popup.anchor
    let todayButton = popup.todayButton

    return CalendarMonthPopupConfig(
      backgroundColorHex: style.backgroundColorHex,
      borderColorHex: style.borderColorHex,
      borderWidth: style.borderWidth,
      cornerRadius: style.cornerRadius,
      paddingX: style.paddingX,
      paddingY: style.paddingY,
      spacing: style.spacing,
      marginX: style.marginX,
      marginY: style.marginY,
      showWeekNumbers: calendar.showWeekNumbers,
      showEventIndicators: calendar.showEventIndicators,
      headerTextColorHex: calendar.headerTextColorHex,
      weekdayTextColorHex: calendar.weekdayTextColorHex,
      firstWeekday: calendar.firstWeekday,
      resolvedWeekdaySymbols: calendar.resolvedWeekdaySymbols,
      dayTextColorHex: calendar.dayTextColorHex,
      outsideMonthTextColorHex: calendar.outsideMonthTextColorHex,
      todayCellBackgroundColorHex: calendar.todayCellBackgroundColorHex,
      todayCellBorderColorHex: calendar.todayCellBorderColorHex,
      todayCellBorderWidth: calendar.todayCellBorderWidth,
      todayMarkerVariant: calendar.todayMarkerVariant,
      todayMarkerSize: calendar.todayMarkerSize,
      indicatorColorHex: calendar.indicatorColorHex,
      selectedTextColorHex: selection.selectedTextColorHex,
      selectedBackgroundColorHex: selection.selectedBackgroundColorHex,
      selectionDateFormat: selection.selectionDateFormat,
      selectionDateSeparator: selection.selectionDateSeparator,
      allowsRangeSelection: selection.allowsRangeSelection,
      resetSelectionOnThirdTap: selection.resetSelectionOnThirdTap,
      layout: agenda.layout,
      appointmentsScrollable: agenda.appointmentsScrollable,
      appointmentsMinHeight: agenda.appointmentsMinHeight,
      appointmentsMaxHeight: agenda.appointmentsMaxHeight,
      agendaTitle: agenda.agendaTitle,
      maxVisibleAppointments: agenda.maxVisibleAppointments,
      anchorDateFormat: anchor.dateFormat,
      anchorTextColorHex: anchor.textColorHex,
      anchorShowDateText: anchor.showDateText,
      todayButtonTitle: todayButton.title,
      todayButtonIcon: todayButton.icon,
      todayButtonPaddingX: todayButton.paddingX,
      todayButtonPaddingY: todayButton.paddingY,
      todayButtonMarginX: todayButton.marginX,
      todayButtonMarginY: todayButton.marginY
    )
  }

  var calendarUpcomingPopupUIConfig: CalendarUpcomingPopupConfig {
    CalendarUpcomingPopupConfig(
      days: upcoming.events.days,
      excludePastEvents: upcoming.events.excludePastEvents,
      backgroundColorHex: upcoming.popup.backgroundColorHex,
      borderColorHex: upcoming.popup.borderColorHex,
      borderWidth: upcoming.popup.borderWidth,
      cornerRadius: upcoming.popup.cornerRadius,
      paddingX: upcoming.popup.paddingX,
      paddingY: upcoming.popup.paddingY,
      spacing: upcoming.popup.spacing,
      marginX: upcoming.popup.marginX,
      marginY: upcoming.popup.marginY,
      firstWeekday: month.popup.calendar.firstWeekday,
      selectionDateFormat: month.popup.selection.selectionDateFormat,
      defaultIndicatorColorHex: month.popup.calendar.indicatorColorHex
    )
  }
}
