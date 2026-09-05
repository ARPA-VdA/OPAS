# UI Documentation

Overview of OPAS DL Neo's main sections.

## Dashboard

Overview of the station: system alarms (disk almost full, instruments not responding,
Python service unreachable) when present, a shortcut to your favorite view if you've set
one, driver status, and recent logs.

## Instruments

List of configured instruments. Opening an instrument's detail view shows the "Parametri"
(Parameters) and "Diagnostici" (Diagnostics) cards with current values, including the
pre-formula raw value when available (depends on the Python service build in use).

## Drivers

Status of the drivers talking to the physical instruments, with access to their logs.

## Configurations

Management of the service's configuration files (instruments, modules, channels, formulas).

## Graphs

Historical view of readings, by channel and time range.

## Views

Custom dashboards: pick the channels you care about across multiple instruments and save
them as a view, shown as cards or as a table. A view can be marked as favorite (star icon)
to show up as a shortcut on the Dashboard.

## Settings

Path to the Opas DL service, station-wide log level, and the maximum number of decimals
shown for raw values. The app's own settings (service path and decimals) can be exported to
a file and re-imported, e.g. for a backup or to carry them over to another installation.

## Documentation

This section: gathers the Python service's own documentation ("Servizio Python") and the
UI's documentation (this page).

## System

Information about the app version, Python service status, and CPU/RAM/disk usage.
