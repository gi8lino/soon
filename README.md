# Soon

Soon is a small macOS menu bar calendar app.

It lives in the official macOS menu bar and gives you quick access to a month calendar or upcoming appointments.

- Left click opens the calendar popup
- Right click opens the app menu
- Calendar access is handled through macOS Calendar permission
- Calendar changes are observed directly while the app is running
- The menu bar label and calendar popup are configurable

## Install

Install from Homebrew:

```bash
brew tap gi8lino/tap
brew install gi8lino/tap/soon
```

Run Soon:

```bash
open "$(brew --prefix)/opt/soon/libexec/Soon.app"
```

If macOS blocks the app with a quarantine warning:

```bash
xattr -dr com.apple.quarantine "$(brew --prefix)/opt/soon/libexec/Soon.app"
open "$(brew --prefix)/opt/soon/libexec/Soon.app"
```

To upgrade:

```bash
brew update
brew upgrade soon
```

To uninstall:

```bash
brew uninstall soon
```

## Permissions

Soon needs Calendar access.

On first launch, macOS should ask for Calendar permission. Soon needs this permission to read events and to create, edit, or delete appointments.

To reset permission and trigger the prompt again:

```bash
tccutil reset Calendar io.github.gi8lino.soon
open "$(brew --prefix)/opt/soon/libexec/Soon.app"
```

Then allow Calendar access in:

```text
System Settings → Privacy & Security → Calendars
```

Without Calendar access:

- the app still opens
- the menu bar item still appears
- calendar events are unavailable
- the popup shows a permission warning

## Configuration

Default config path:

```text
~/.config/soon/config.toml
```

The repository includes `config.default.toml` with the current default values.

Runtime defaults:

```text
lock dir: /tmp/soon
log dir: ~/.local/state/soon
log level: info
calendar popup mode: month
menu bar label: calendar icon only
file logging: false
```

Supported environment variables:

- `SOON_CONFIG_PATH`
- `SOON_LOG_LEVEL`

`SOON_CONFIG_PATH` selects the config file. `SOON_LOG_LEVEL` is a temporary diagnostic override for verbosity only. Logging enablement and the log directory are configured in `config.toml`.

Example config:

```toml
[logging]
enabled = false # Enables file logging to the directory below.
level = "info" # Minimum log level: trace | debug | info | warn | error.
directory = "~/.local/state/soon" # Directory used for Soon log files.

[app]
lock_dir = "/tmp/soon" # Directory used for the single-instance app lock file.

[menu_bar]
spacing = 4 # Spacing in points between visible menu bar items.

[menu_bar.icon]
enabled = true # Shows the menu bar icon when true.
kind = "sf_symbol" # Icon type: "sf_symbol" for SF Symbols or "text" for a text glyph.
value = "calendar" # SF Symbol name or text glyph to render as the icon.

[menu_bar.date]
enabled = false # Shows the formatted date text in the menu bar when true.
format = "EEE d" # Date format string used for the menu bar label.

[calendar]
popup_mode = "month" # Popup mode: "month", "upcoming", or "none".
```

Example environment overrides:

```bash
SOON_CONFIG_PATH=~/.config/soon/config.toml open "$(brew --prefix)/opt/soon/libexec/Soon.app"
SOON_LOG_LEVEL=debug open "$(brew --prefix)/opt/soon/libexec/Soon.app"
SOON_LOG_LEVEL=trace open "$(brew --prefix)/opt/soon/libexec/Soon.app"
```

## Menu bar label

By default, Soon shows only a calendar icon.

Show a date next to the icon:

```toml
[menu_bar.date]
enabled = true # Shows the formatted date text in the menu bar when true.
format = "EEE d" # Date format string used for the menu bar label.
```

Use a different SF Symbol:

```toml
[menu_bar.icon]
enabled = true # Shows the menu bar icon when true.
kind = "sf_symbol" # Icon type: "sf_symbol" for SF Symbols or "text" for a text glyph.
value = "calendar.badge.clock" # SF Symbol name or text glyph to render as the icon.
```

Use a text icon:

```toml
[menu_bar.icon]
enabled = true # Shows the menu bar icon when true.
kind = "text" # Icon type: "sf_symbol" for SF Symbols or "text" for a text glyph.
value = "󰃭" # SF Symbol name or text glyph to render as the icon.
```

Disable the icon and show only a date:

```toml
[menu_bar.icon]
enabled = false # Hides the menu bar icon when false.

[menu_bar.date]
enabled = true # Shows the formatted date text in the menu bar when true.
format = "EEE d" # Date format string used for the menu bar label.
```

## Calendar mode

Soon supports two popup modes:

- `month`
- `upcoming`

Month mode:

```toml
[calendar]
popup_mode = "month" # Popup mode: "month", "upcoming", or "none".
```

Upcoming mode:

```toml
[calendar]
popup_mode = "upcoming" # Popup mode: "month", "upcoming", or "none".

[calendar.upcoming.events]
days = 7 # Number of days to include in upcoming mode.
exclude_past_events = true # Hides events that already started when true.
```

Disable the calendar popup:

```toml
[calendar]
popup_mode = "none" # Popup mode: "month", "upcoming", or "none".
```

## Calendar config

Common appointment options:

```toml
[calendar.filters]
included_calendar_names = [] # Optional allowlist of visible Calendar.app names. Empty means all calendars are eligible.
excluded_calendar_names = [] # Optional denylist of visible Calendar.app names applied after the allowlist.
included_calendar_ids = [] # Optional advanced allowlist of exact calendar identifiers.
excluded_calendar_ids = [] # Optional advanced denylist of exact calendar identifiers.
included_calendar_source_ids = [] # Optional advanced allowlist of exact calendar source identifiers.
excluded_calendar_source_ids = [] # Optional advanced denylist of exact calendar source identifiers.

[calendar.appointments]
empty_text = "No appointments" # Placeholder text shown when no appointments are visible.
show_calendar_name = false # Shows each event's calendar name in appointment rows.
show_location = true # Shows event locations in appointment rows when present.
show_travel_time = true # Shows travel time details when available.
show_end_time = true # Shows event end times alongside start times.
show_alert_icon = false # Shows an alert indicator for events with reminders.
show_all_day_label = true # Shows a label for all-day events.
show_holiday_all_day_label = false # Shows the all-day label for holiday calendars too.
all_day_label = "All day" # Label text used for all-day events.
```

Birthday options:

```toml
[calendar.birthdays]
show_birthdays = true # Includes birthdays from Calendar.app in event lists.
birthdays_show_age = true # Shows the computed age for birthday entries when available.
birthday_icon = "" # Icon shown next to birthday entries.
```

Upcoming options:

```toml
[calendar.upcoming.events]
days = 3 # Number of days to include in upcoming mode.
exclude_past_events = false # Hides events that already started when true.

[calendar.upcoming.popup]
background_color = "#111111" # Popup background color.
border_color = "#444444" # Popup border color.
border_width = 1 # Popup border width in points.
corner_radius = 10 # Popup corner radius in points.
padding_x = 10 # Horizontal inner padding in points.
padding_y = 8 # Vertical inner padding in points.
spacing = 8 # Vertical spacing between popup sections in points.
margin_x = 8 # Horizontal screen-edge margin in points.
margin_y = 8 # Vertical screen-edge margin in points.
```

Month popup style:

```toml
[calendar.month.popup.style]
background_color = "#111111" # Month popup background color.
border_color = "#444444" # Month popup border color.
border_width = 1 # Month popup border width in points.
corner_radius = 10 # Month popup corner radius in points.
padding_x = 10 # Horizontal inner padding in points.
padding_y = 8 # Vertical inner padding in points.
spacing = 8 # Spacing between month popup sections in points.
margin_x = 8 # Horizontal screen-edge margin in points.
margin_y = 8 # Vertical screen-edge margin in points.
```

Month calendar style:

```toml
[calendar.month.popup.calendar]
show_week_numbers = true # Shows ISO week numbers in the month grid.
show_event_indicators = true # Shows dots or markers for days with events.
header_text_color = "#ffffff" # Text color for the month header.
weekday_text_color = "#91d7e3" # Text color for weekday labels.
weekday_format = "dd" # Date format string used for weekday labels.
day_text_color = "#d0d0d0" # Text color for days in the current month.
outside_month_text_color = "#6e738d" # Text color for days outside the current month.
today_cell_background_color = "#00000000" # Background color for today's day cell.
today_cell_border_color = "#ff0000" # Border color for today's day cell.
today_cell_border_width = 1.4 # Border width for today's day cell in points.
indicator_color = "#8bd5ca" # Color used for event indicators in the month grid.
```

Month selection style:

```toml
[calendar.month.popup.selection]
selected_text_color = "#0b1020" # Text color for selected dates.
selected_background_color = "#89b4fa" # Background color for selected dates.
selection_date_format = "yyyy-MM-dd" # Format used in the selected-date summary.
selection_date_separator = " - " # Separator used for date-range summaries.
allows_range_selection = true # Allows selecting a start and end date range.
reset_selection_on_third_tap = true # Clears the current range on a third tap.
```

Month agenda style:

```toml
[calendar.month.popup.agenda]
layout = "calendar_appointments_vertical" # Agenda layout style shown beside or below the month view.
appointments_scrollable = true # Makes the appointments list scroll when content exceeds the height cap.
appointments_min_height = 140 # Minimum agenda height in points.
appointments_max_height = 240 # Maximum agenda height in points before scrolling.
agenda_title = "Appointments" # Section title shown above the agenda list.
max_visible_appointments = 8 # Maximum number of appointments shown before truncation or scrolling.
```

Month selected-date header:

```toml
[calendar.month.popup.anchor]
date_format = "EEE d MMM" # Format used for the selected-date header text.
text_color = "#ffffff" # Text color for the selected-date header.
show_date_text = true # Shows the selected-date header when true.
```

Today button:

```toml
[calendar.month.popup.today_button]
title = "Today" # Button label used to jump back to today's date.
icon = "" # Optional icon shown beside the Today button label.
border_color = "#3F2F6B" # Border color for the Today button.
border_width = 1.5 # Border width for the Today button in points.
```

Composer labels:

```toml
[calendar.composer]
create_title = "New Appointment" # Window title used when creating a new appointment.
edit_title = "Edit Appointment" # Window title used when editing an existing appointment.
save_label = "Save" # Primary action label for creating an appointment.
update_label = "Update" # Primary action label for updating an appointment.
remove_label = "Remove" # Destructive action label for deleting an appointment.
cancel_label = "Cancel" # Secondary action label for dismissing the composer.
delete_confirmation_title = "Remove appointment?" # Title shown in the delete confirmation prompt.
delete_confirmation_message = "This action cannot be undone." # Message shown in the delete confirmation prompt.
```

## Usage

Start Soon:

```bash
open "$(brew --prefix)/opt/soon/libexec/Soon.app"
```

Menu bar interactions:

```text
left click
  open or close the calendar popup

right click
  open app menu
```

The app menu contains:

- Refresh
- Open Calendar Settings
- Open Calendar App
- Quit Soon

Calendar popup actions:

- click `+` to create an appointment
- use the action menu on an event to edit it
- copy event details from the action menu
- join a meeting or open an event URL when the event contains one
- open Calendar.app from the action menu
- use Refresh to request a fresh calendar snapshot
- use Today to jump back to the current day in month mode

## How updates work

Soon reads Calendar data directly inside the app process.

While Soon is running, it observes Calendar changes and refreshes its current snapshot when events change. There is no separate calendar agent and no socket connection between the app and the calendar service.

Manual refresh is still useful when:

- the user clicks Refresh
- the visible month changes
- an event is created, updated, or deleted
- Calendar permission changes

## Troubleshooting

Quick checks:

```bash
pgrep -fl Soon
ls -la /tmp/soon
```

Check logs when file logging is enabled:

```bash
tail -n 200 ~/.local/state/soon/soon.out
```

Run with debug logging once:

```bash
SOON_LOG_LEVEL=debug open "$(brew --prefix)/opt/soon/libexec/Soon.app"
```

Reset Calendar permission:

```bash
tccutil reset Calendar io.github.gi8lino.soon
open "$(brew --prefix)/opt/soon/libexec/Soon.app"
```

Remove quarantine if macOS blocks the Homebrew-installed app:

```bash
xattr -dr com.apple.quarantine "$(brew --prefix)/opt/soon/libexec/Soon.app"
open "$(brew --prefix)/opt/soon/libexec/Soon.app"
```

Common cases:

- If the menu bar icon does not appear, check whether another Soon instance is already running.
- If the popup opens but shows no events, Calendar permission is usually missing or denied.
- If config changes do not apply, quit and reopen Soon.
- If logging is enabled but no logs appear, check `[logging].directory` or `~/.local/state/soon`.

Clean restart:

```bash
pkill -x Soon || true
rm -rf /tmp/soon
open "$(brew --prefix)/opt/soon/libexec/Soon.app"
```

## Development

Build debug:

```bash
swift build
```

Build release:

```bash
swift build -c release
```

Bundle the app locally:

```bash
make bundle
```

Run the local bundled app:

```bash
make run
```

Open the local bundled app manually:

```bash
open dist/Soon.app
```

## Screenshots

### Calendar

<img src="./assets/month.png" alt="Calendar screenshot" width="320" />

### Upcoming

<img src="./assets/upcoming.png" alt="Upcoming screenshot" width="320" />

## License

This project is licensed under the Apache 2.0 License. See the `LICENSE` file for details.


