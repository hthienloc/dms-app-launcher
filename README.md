# App Launcher

An application launcher widget for DankMaterialShell (DMS) to search and launch applications.

<img src="screenshot.png" width="400" alt="Screenshot">

## Install

**Required:** This plugin requires [dms-common](https://github.com/hthienloc/dms-common) to be installed.

```bash
# 1. Install shared components
git clone https://github.com/hthienloc/dms-common ~/.config/DankMaterialShell/plugins/dms-common

# 2. Install this plugin
dms plugins install appLauncher
```

Or manually:

```bash
git clone https://github.com/hthienloc/dms-app-launcher ~/.config/DankMaterialShell/plugins/dmsAppLauncher
```

## Features

- **App Discovery** - Scans standard system applications, user overrides, Flatpaks, and Snaps.
- **Header Controls** - Cycle grid sizes (Small, Medium, Large, Very Large) and toggle Edit Mode.
- **Fuzzy Search** - Live search matching application names and commands.
- **In-Widget App Scanner** - Add or remove application shortcuts with Wayland keyboard support.
- **Tactile Click Feedback** - Snappy spring scale-bounce and primary border highlight on hover.

## Usage

| Action | Result |
|--------|--------|
| Left Click App Icon | Launch application with click feedback |
| Left Click `+` Icon | Open in-widget scanner to add shortcuts |
| Left Click Edit Icon | Toggle Edit Mode (show close `x` buttons) |
| Left Click Grid Icon | Cycle app icon grid size (Small, Medium, Large, Very Large) |
| Left Click Close `x` | Remove application shortcut (in Edit Mode) |

## Requirements

- `python3` - Required for background system application scanning.

## License

GPL-3.0

## Roadmap / TODO

- [x] **Size Cycle Button:** Dynamic scaling button in the header toolbar.
- [x] **Flatpak & Snap Scanning:** Support Flatpak and Snap sandboxes.
- [x] **Tactile Animations:** Snappy scale-bounce feedback on click.
