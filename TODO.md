# Striker — Build TODO

Source of truth for coding agents. Complete phases in order; tasks within a phase can be parallelized unless noted.

---

## Phase 1: App Shell
Rewrite from SwiftUI to pure AppKit. Menubar icon, liquid glass floating panel, global hotkey.

- [ ] **1.1** Update `Package.swift` — narrow executable target path to `Sources/App`
- [ ] **1.2** Delete all SwiftUI files (`App.swift`, `ContentView.swift`, `BlurView.swift`, `EditorTextView.swift`). Create `main.swift` with `NSApplication.shared` + custom `AppDelegate` + `NSApp.run()`
- [ ] **1.3** Create `AppDelegate.swift` — sets `.accessory` activation policy, instantiates StatusBarController, FloatingPanel, HotkeyManager
- [ ] **1.4** Create `StatusBarController.swift` — `NSStatusItem` with icon, left-click toggles panel, right-click menu with Quit
- [ ] **1.5** Create `FloatingPanel.swift` — `NSPanel` subclass with `.nonactivatingPanel` + `.utilityWindow` style mask, `.floating` collection behavior, liquid glass background via `NSVisualEffectView` (`.hudWindow` material, `.behindWindow` blending, `.active` state), `canBecomeKey = true`, show/hide toggle, always-on-top toggle
- [ ] **1.6** Create `HotkeyManager.swift` — `NSEvent.addGlobalMonitorForEvents` + `addLocalMonitorForEvents` for ⌥N (keyCode 45, `.option` flag)

**Done when:** App launches with no Dock icon, menubar icon visible, click toggles a floating liquid glass panel, ⌥N works globally.

---

## Phase 2: File Management
Directory selection, sidebar file tree, file CRUD operations.

- [ ] **2.1** Create `DirectoryPicker.swift` — `NSOpenPanel` for choosing notes directory, store as security-scoped bookmark in UserDefaults, re-prompt if bookmark is stale
- [ ] **2.2** Create `SidebarItem.swift` — model struct (`url`, `name`, `isDirectory`, `depth`, `isExpanded`) + `loadDirectory()` returning flat sorted array (folders first, then files alphabetically)
- [ ] **2.3** Create `FileManager+Notes.swift` — extension with `createNote`, `deleteNote` (move to Trash via `NSWorkspace`), `renameNote`, `readNote`, `writeNote`
- [ ] **2.4** Create `MainViewController.swift` — `NSSplitView` with sidebar (left) + editor placeholder (right), set as panel's `contentViewController`
- [ ] **2.5** Create `SidebarController.swift` — `NSTableView` with indented rows via custom cell, click to open, folder expand/collapse, right-click context menu (New Note, New Folder, Rename, Delete)
- [ ] **2.6** Wire sidebar selection → editor loading, with dirty-file check before switching

**Done when:** Can pick a directory, see folder tree in sidebar, click to load file content, right-click to create/rename/delete notes and folders.

---

## Phase 3: Editor Foundation
Properly configured NSTextView with auto-save, undo, and keyboard shortcuts.

- [ ] **3.1** Create `EditorViewController.swift` — owns `NSScrollView` + `NSTextView`, `isRichText=true`, `allowsUndo=true`, disables auto-correction/spelling/substitution, monospace font (JetBrains Mono with system monospace fallback)
- [ ] **3.2** Create `AutoSaveController.swift` — 2.5s idle debounce timer (resets on each edit), saves on panel resign key (`didResignKey`) and app quit (`willTerminate`), dirty tracking flag
- [ ] **3.3** Create `StrikerTextView.swift` — `NSTextView` subclass, override `performKeyEquivalent` for Cmd+C/V/X/Z/Shift+Z/A/S/W/N since `.accessory` policy loses the default menu bar
- [ ] **3.4** Undo manager verification — confirm one-keystroke = one undo step with default NSTextView behavior, document any issues for Phase 4
- [ ] **3.5** Wire `AutoSaveController` + `StrikerTextView` into `MainViewController`, connect to sidebar file selection

**Done when:** Can type text, Cmd+Z undoes one character at a time, auto-save fires after 2.5s idle, switching files saves the previous one, Cmd+S force-saves.

---

## Phase 4: Markdown Engine
The core risk. Live formatting via cmark-gfm.

- [ ] **4.1** Vendor cmark-gfm headers — create `Sources/CMarkGFM/include/` with headers + `module.modulemap`, add C system target to `Package.swift`, link against system `libcmark-gfm.dylib`. Verify with a test call to `cmark_markdown_to_html()`. If system dylib is unavailable, fall back to compiling cmark-gfm sources as a C target.
- [ ] **4.2** Create `CMarkParser.swift` — Swift wrapper: parse string → AST, walk AST extracting `[(NodeType, NSRange)]` tuples, register GFM extensions (strikethrough, tables), free AST memory
- [ ] **4.3** Create `MarkdownStyle.swift` — attribute dictionaries per node type: H1–H4 (scaled font sizes), bold (`.bold` trait), italic (`.italic` trait), strikethrough (`.strikethroughStyle`), inline code (monospace + subtle background), code blocks (monospace, suppress inner formatting), links (blue + underline), blockquotes (gray + left indent), bullet/numbered lists (hanging indent). Use semantic colors for dark mode support.
- [ ] **4.4** Create `MarkdownTextStorage.swift` — `NSTextStorage` subclass: override `replaceCharacters`/`setAttributes`/`processEditing`, incremental re-parse (find edited paragraph boundaries, only re-style that range), suppress formatting inside fenced code blocks, save/restore `selectedRange` around attribute changes, disable undo registration during attribute application
- [ ] **4.5** Integrate into `EditorViewController` — replace default text storage with `MarkdownTextStorage` (custom `NSTextContainer` + `NSLayoutManager` chain), cursor preservation wiring, add raw markdown toggle (swap between styled storage and plain storage), full-document parse on file load

**Done when:** `# Hello` renders as large heading, `**bold**` renders bold, code blocks are monospace with no inner formatting, cursor stays in place while typing, undo works per-character, 1000-line file has no perceptible lag, raw mode shows plain markdown.

---

## Phase 5: UI Polish
Formatting toolbar, file watching, preferences, final touches.

- [ ] **5.1** Create `FormattingToolbar.swift` — floating borderless `NSPanel` positioned above text selection, buttons for H1–H4/Bold/Italic/Strikethrough/Code/Link, wraps/unwraps markdown syntax around selection, `.nonactivatingPanel` so clicks don't steal editor focus, screen-edge clamping for multi-monitor
- [ ] **5.2** Create `FileWatcher.swift` — FSEvents watching notes directory recursively, 100ms coalesce debounce, silent reload if file not dirty, conflict alert if dirty ("File changed externally. Reload or keep your version?")
- [ ] **5.3** Create `PreferencesWindowController.swift` — standard `NSWindow` with: change notes directory, always-on-top toggle, launch-at-login via `SMAppService` (macOS 13+)
- [ ] **5.4** Add raw/rich toggle UI — toolbar button or Cmd+Shift+R to switch between styled and plain monospace view
- [ ] **5.5** Final polish — `NSPanel` frame autosave (remembers position/size), restore last-open file on launch, graceful error handling for missing/moved notes directory, status bar icon highlight when panel is visible, retain cycle audit

**Done when:** Formatting toolbar appears on selection and inserts correct markdown, external file changes detected and handled, preferences window works, raw toggle works, app remembers state across launches.

---

## Details
Fix bugs, UX gaps, and polish items found during code review.

### Bugs
- [ ] **D.1** Fix `FileWatcher` thread-safety — `ignore(url:)` writes `ignoredPaths` from the main thread, but `handleIncoming()` reads/writes it on `callbackQueue`. Synchronize access with a lock or dispatch to the same queue.
- [ ] **D.2** Extend `FileWatcher` ignore window — currently 0.6s but autosave debounces at 2.5s. A save can trigger after the ignore window expires, causing a false "file changed externally" alert. Increase to ≥3s.
- [ ] **D.3** Remove force-unwraps in `FormattingToolbar.show(for:)` — `textView.layoutManager!` and `textView.textContainer!` can crash in edge cases. Use `guard let` instead.
- [ ] **D.4** Add `scrollRangeToVisible()` after cursor restore in `EditorViewController.reloadCurrentFileFromDisk()` — cursor is restored but view doesn't scroll to it.

### UX Gaps
- [ ] **D.5** Add empty state to sidebar — when the directory has no notes, show a placeholder message ("No notes yet") instead of a blank table.
- [ ] **D.6** Enable Cmd+F (find) — wire up `NSTextView`'s built-in find bar via `performFindPanelAction` in `StrikerTextView.performKeyEquivalent`.
- [ ] **D.7** Add dirty indicator — show a visual cue (e.g. dot in the status bar icon or sidebar filename) when the current file has unsaved changes.
- [ ] **D.8** Pre-select text in rename alert — call `tf.selectAll(nil)` in `SidebarController.promptRename()` so the user can type immediately.
- [ ] **D.9** Add H4 button to `FormattingToolbar` — spec says H1–H4, only H1–H3 are present.

### Nice-to-Haves
- [ ] **D.10** Cache `resourceValues` in `SidebarItem.loadDirectory()` — currently calls it multiple times per entry, causing redundant syscalls on large directories.
- [ ] **D.11** Handle deleted-file-while-editing — if the current file is deleted externally, notify the user instead of showing stale content silently.
- [ ] **D.12** Guide user on Accessibility permission — global hotkey (`NSEvent.addGlobalMonitorForEvents`) requires Accessibility access. Show a prompt or help text if it fails.

**Done when:** No force-unwraps in toolbar, file watcher is thread-safe with no false alerts, sidebar has empty state, Cmd+F works, rename pre-selects text, dirty indicator visible.

---

## Verification
After each phase: `swift build` to confirm compilation, then `swift run` to manually test the acceptance criteria.
