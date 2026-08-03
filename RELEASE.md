# Release Notes - v2.2.2

## New Features
- **Launch Prefix**: Added a configurable prefix for application launches.
- **Crash Isolation Default**: New launches use `systemd-run --user --scope` by default so apps started from the widget can survive a DMS crash.

## Improvements & Fixes
- **Unified Launch Path**: Grid, list, compact, and batch group launches now use the same launch helper.
- **Settings UI**: Added a Launch Behavior section where the prefix can be changed, cleared, or set to wrappers like `uwsm-app`.
