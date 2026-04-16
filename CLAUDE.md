# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

```bash
swift build          # compile
swift run Striker    # launch the app
```

No external dependencies. Two targets: `CMarkGFM` (vendored C library) and `Striker` (executable, `Sources/App/`). Requires macOS 13+, Swift 5.9+.

## Architecture

Striker is a **menubar-only** macOS markdown notes app built in pure AppKit (no SwiftUI). It runs as `NSApp.setActivationPolicy(.accessory)` — no Dock icon, no default menu bar.

### Component hierarchy

```
AppDelegate
├── FloatingPanel (NSPanel, liquid glass)
│   └── MainViewController (NSSplitViewController)
│       ├── SidebarController (NSTableView file tree)
│       └── EditorViewController (NSScrollView + StrikerTextView)
├── StatusBarController (NSStatusItem)
├── HotkeyManager (⌥N global hotkey)
└── PreferencesWindowController
```

### Text system chain

The editor uses a custom NSTextStorage subclass, not default NSTextView storage:

```
MarkdownTextStorage → NSLayoutManager → NSTextContainer → StrikerTextView
```

`MarkdownTextStorage.processEditing()` calls `CMarkParser` (Swift wrapper around vendored cmark-gfm C library) to parse markdown into an AST, then `MarkdownStyle` maps AST nodes to attributed string attributes. Syntax delimiters are hidden via near-zero font size + transparent color.

### Key patterns

- **No default menu bar**: Since `.accessory` policy removes the app menu, `StrikerTextView` overrides `performKeyEquivalent` to manually route all Cmd+key shortcuts.
- **NotificationCenter messaging**: Components communicate via notifications (`.strikerHidePanel`, `.strikerNewNote`, `.strikerDidSaveFile`, `.strikerToggleSidebar`), defined in `EditorViewController.swift`.
- **Flat sidebar array**: Uses NSTableView with manual depth-based indentation instead of NSOutlineView. `SidebarItem.loadDirectory()` returns a flat array. Multiple root folders are supported with collapsible headers.
- **Security-scoped bookmarks**: Directory access persisted via bookmark data arrays in UserDefaults (`DirectoryPicker.swift`).
- **Auto-save**: 2.5s idle debounce via `AutoSaveController`. Also saves on window resign key and app quit.
- **File watching**: `FileWatcher` uses FSEvents with 100ms debounce. Own writes are ignored via a time-windowed ignore list to prevent false conflict alerts.

## Key files

| File | Role |
|---|---|
| `MarkdownTextStorage.swift` | NSTextStorage subclass — the core risk area. Handles re-parsing, attribute application, undo suppression during styling |
| `CMarkParser.swift` | Swift ↔ cmark-gfm bridge. Parses markdown string → `[MarkdownRange]` tuples |
| `MarkdownStyle.swift` | Attribute dictionaries per node type + delimiter hiding logic |
| `StrikerTextView.swift` | NSTextView subclass routing keyboard shortcuts |
| `SidebarController.swift` | File tree + context menus + cell view (all in one file) |
| `FileManager+Notes.swift` | CRUD operations for notes/folders on disk |

## Constraints

- **Pure AppKit** — no SwiftUI, no web views, no external Swift packages.
- **cmark-gfm is vendored** as a C target in `Sources/CMarkGFM/` (not a system library).
- NSTextStorage mutations must disable undo registration (`textView.undoManager?.disableUndoRegistration()`) to keep one-keystroke-per-undo-step behavior.
