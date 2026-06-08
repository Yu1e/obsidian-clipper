# obsidian-clip

Windows tray utility that clips selected content from any application into a new Obsidian note via a global hotkey.

## What it does

- Captures selected text or image from the active window using the configured hotkey
- Retrieves the page URL from the browser address bar (Chrome, Firefox, Edge, Opera, Brave, Vivaldi)
- For Telegram: uses the window title as source
- Creates a `.md` file in the configured vault folder with YAML frontmatter: source URL, creation date, and any user-defined properties
- Optionally applies a [Templater](https://github.com/SilentVoid13/Templater) plugin template to the new note via [Advanced URI](https://github.com/Vinzent03/obsidian-advanced-uri)
- Shows a popup notification with a "Go to note" button (opens the note in Obsidian)
- Settings are configured through a GUI dialog (tray icon → Settings)

## Requirements

- Windows, PowerShell 5.1
- Obsidian
- Optional: Templater plugin + Advanced URI plugin (for template application)

## Setup

1. Place `obsidian_clip.ps1` and `start.vbs` in the same folder
2. Run `start.vbs` — a settings dialog opens on first launch
3. Fill in vault path, inbox folder, hotkey, and any other options; click Save
4. For autostart: put a shortcut to `start.vbs` in `shell:startup`

## Settings

| Field | Description |
|---|---|
| Vault path | Full path to the Obsidian vault folder |
| Inbox folder | Subfolder within the vault where notes are saved |
| Attachments folder | Subfolder for saved images |
| Date property | Frontmatter property name for the date (`date` by default) |
| Date format | .NET date format string, e.g. `yyyy-MM-dd` |
| Properties | Table of additional frontmatter properties (name + value) |
| Templater command | Command ID for auto-applying a Templater template |
| Hotkey | Modifier keys + F-key combination |

Settings are stored in `obsidian_clip.cfg` next to the script.

## Notes

Vibe-coded with Claude Sonnet 4.6.
