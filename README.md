# Striker

A native macOS menubar markdown note-taking app with a Notion-like live rich text editing experience over real `.md` files on disk.

## Core Experience
- **Lives in the menubar** — no Dock icon, no Cmd+Tab clutter
- **Summoned from anywhere** via ⌥N global hotkey
- **Floating NSPanel** — always-on-top by default, toggleable
- **Real filesystem mapping** — sidebar folders = directories on disk
- **User picks notes directory** on first launch (stored in UserDefaults), changeable later via preferences
- **Auto-save** with 2–3s idle debounce (timer resets on each keystroke, fires after inactivity) — also saves on blur/close
- **File watching** — detect external changes to `.md` files via FSEvents and reload, so edits from other apps or sync services are reflected

## Editor
- NSTextView with custom NSTextStorage subclass for live formatting
- Use system `cmark` (libcmark, ships with macOS) via a thin Swift wrapper to parse markdown into an AST, then map AST nodes to NSAttributedString ranges — avoids hand-rolled regex edge cases while staying dependency-free
- Incremental re-parsing: only re-style the edited paragraph/block, not the entire document, for performance on large files
- Carefully save/restore selected range around attributed string mutations to prevent cursor jumps
- Ensure NSTextStorage mutations integrate cleanly with NSUndoManager (one keystroke = one undo step)
- Suppress live formatting inside fenced code blocks (requires block-level parse awareness)
- Rich text rendering of markdown as you type (headings grow, bold bolds, etc.)
- Floating formatting toolbar appears on text selection (H1–H4, Bold, Italic, Strikethrough, Code, Link) — handle multi-monitor positioning and screen edge clamping
- Toggle between rich text view and raw markdown source
- Handle keyboard shortcuts (Cmd+C/V/Z/A) explicitly since `.accessory` activation policy removes the default app menu bar

## Supported Markdown
- Headings H1–H4
- **Bold**, *Italic*, ~~Strikethrough~~
- `Inline code` and code blocks
- [Links](url)
- Bullet lists, numbered lists
- Blockquotes

## Sidebar
- NSTableView with indentation levels (simpler and less buggy than NSOutlineView for a folder tree)
- Click to open, right-click for new/delete/rename
- Mirrors the chosen directory on disk

## Technical Constraints
- **Pure Swift/AppKit** — zero external dependencies (system libraries like cmark are allowed)
- **AppKit, not SwiftUI** for the core (NSPanel, NSStatusItem, NSTextView, NSTableView)
- **No web views** — fully native rendering
- `NSApp.setActivationPolicy(.accessory)` for menubar-only behavior

## Known Risks & Future Considerations
- **NSTextStorage live formatting is the core risk** — get this working well on a single note before building sidebar/file management
- **iCloud/Dropbox conflict resolution** — at minimum detect conflicts and don't silently overwrite
- **Image support** — users will paste screenshots; need to decide where images are stored and how to render `![](path)` inline
