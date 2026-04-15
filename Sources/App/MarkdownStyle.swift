import AppKit

/// Provides NSAttributedString attributes for each markdown node type.
enum MarkdownStyle {

    // MARK: - Base font

    static let baseFontSize: CGFloat = 13
    static var baseFont: NSFont {
        NSFont(name: "JetBrainsMono-Regular", size: baseFontSize)
            ?? NSFont.monospacedSystemFont(ofSize: baseFontSize, weight: .regular)
    }

    // MARK: - Default attributes (applied to entire string before styling)

    static var baseAttributes: [NSAttributedString.Key: Any] {
        [
            .font: baseFont,
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: defaultParagraphStyle,
        ]
    }

    private static var defaultParagraphStyle: NSParagraphStyle {
        let ps = NSMutableParagraphStyle()
        ps.lineSpacing = 4
        return ps
    }

    // MARK: - Per-node attributes

    static func attributes(for nodeType: MarkdownNodeType) -> [NSAttributedString.Key: Any] {
        switch nodeType {
        case .heading(let level):
            return headingAttributes(level: level)
        case .strong:
            return boldAttributes
        case .emphasis:
            return italicAttributes
        case .strikethrough:
            return strikethroughAttributes
        case .code:
            return inlineCodeAttributes
        case .codeBlock:
            return codeBlockAttributes
        case .link:
            return linkAttributes
        case .image:
            return linkAttributes  // style images like links
        case .blockQuote:
            return blockQuoteAttributes
        case .list, .listItem:
            return listAttributes
        case .thematicBreak:
            return [:]  // no special attributes
        }
    }

    // MARK: - Heading

    private static func headingAttributes(level: Int) -> [NSAttributedString.Key: Any] {
        let size: CGFloat
        switch level {
        case 1:  size = 26
        case 2:  size = 22
        case 3:  size = 18
        case 4:  size = 15
        default: size = baseFontSize
        }
        let font = NSFont(name: "JetBrainsMono-Bold", size: size)
            ?? NSFont.monospacedSystemFont(ofSize: size, weight: .bold)
        return [
            .font: font,
            .foregroundColor: NSColor.labelColor,
        ]
    }

    // MARK: - Bold

    private static var boldAttributes: [NSAttributedString.Key: Any] {
        let font = NSFont(name: "JetBrainsMono-Bold", size: baseFontSize)
            ?? NSFont.monospacedSystemFont(ofSize: baseFontSize, weight: .bold)
        return [.font: font]
    }

    // MARK: - Italic

    private static var italicAttributes: [NSAttributedString.Key: Any] {
        let font = NSFont(name: "JetBrainsMono-Italic", size: baseFontSize)
            ?? {
                let descriptor = baseFont.fontDescriptor.withSymbolicTraits(.italic)
                return NSFont(descriptor: descriptor, size: baseFontSize)
                    ?? NSFont.monospacedSystemFont(ofSize: baseFontSize, weight: .regular)
            }()
        return [.font: font]
    }

    // MARK: - Strikethrough

    private static var strikethroughAttributes: [NSAttributedString.Key: Any] {
        [
            .strikethroughStyle: NSUnderlineStyle.single.rawValue,
            .foregroundColor: NSColor.secondaryLabelColor,
        ]
    }

    // MARK: - Inline code

    private static var inlineCodeAttributes: [NSAttributedString.Key: Any] {
        [
            .font: NSFont.monospacedSystemFont(ofSize: baseFontSize, weight: .regular),
            .backgroundColor: NSColor.quaternaryLabelColor,
        ]
    }

    // MARK: - Code block

    private static var codeBlockAttributes: [NSAttributedString.Key: Any] {
        [
            .font: NSFont.monospacedSystemFont(ofSize: baseFontSize, weight: .regular),
            .backgroundColor: NSColor.quaternaryLabelColor,
            .foregroundColor: NSColor.secondaryLabelColor,
        ]
    }

    // MARK: - Link

    private static var linkAttributes: [NSAttributedString.Key: Any] {
        [
            .foregroundColor: NSColor.linkColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
        ]
    }

    // MARK: - Block quote

    private static var blockQuoteAttributes: [NSAttributedString.Key: Any] {
        let ps = NSMutableParagraphStyle()
        ps.headIndent = 20
        ps.firstLineHeadIndent = 20
        ps.lineSpacing = 4
        return [
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: ps,
        ]
    }

    // MARK: - List

    private static var listAttributes: [NSAttributedString.Key: Any] {
        let ps = NSMutableParagraphStyle()
        ps.headIndent = 24
        ps.firstLineHeadIndent = 8
        ps.lineSpacing = 4
        return [.paragraphStyle: ps]
    }

    // MARK: - Hidden syntax

    /// Attributes that make markdown syntax delimiters invisible.
    /// Uses a near-zero font size + transparent color so characters
    /// take up negligible space and are not drawn.
    static var hiddenSyntaxAttributes: [NSAttributedString.Key: Any] {
        [
            .font: NSFont.monospacedSystemFont(ofSize: 0.01, weight: .regular),
            .foregroundColor: NSColor.clear,
        ]
    }

    // MARK: - Syntax delimiter ranges

    /// Returns sub-ranges within `range` that are markdown syntax delimiters
    /// and should be hidden in rich-text mode.
    static func syntaxRanges(for mdRange: MarkdownRange, in source: NSString) -> [NSRange] {
        let r = mdRange.range
        guard r.length > 0, NSMaxRange(r) <= source.length else { return [] }

        let text = source.substring(with: r)

        switch mdRange.type {
        case .heading(let level):
            // "## heading text" → hide "## " (level hashes + space)
            let prefixLen = level + 1  // hashes + space
            guard prefixLen < r.length else { return [] }
            return [NSRange(location: r.location, length: prefixLen)]

        case .strong:
            // "**bold**" or "__bold__"
            return wrapperRanges(text: text, range: r, prefixes: ["**", "__"])

        case .emphasis:
            // "*italic*" or "_italic_"
            return wrapperRanges(text: text, range: r, prefixes: ["*", "_"])

        case .strikethrough:
            // "~~strike~~"
            return wrapperRanges(text: text, range: r, prefixes: ["~~"])

        case .code:
            // "`code`" or "``code``"
            return backtickWrapperRanges(text: text, range: r)

        case .codeBlock:
            // Fenced: first line is "```lang\n", last line is "```\n"
            return codeFenceRanges(text: text, range: r)

        case .link(let url):
            // "[text](url)"
            return linkSyntaxRanges(text: text, range: r, url: url, isImage: false)

        case .image(let url):
            // "![alt](url)"
            return linkSyntaxRanges(text: text, range: r, url: url, isImage: true)

        case .blockQuote:
            // "> " at the start of each line
            return blockQuotePrefixRanges(text: text, range: r)

        case .list, .listItem, .thematicBreak:
            return []
        }
    }

    // MARK: - Helpers

    /// For symmetric wrappers like **bold**, find prefix/suffix delimiter ranges.
    private static func wrapperRanges(text: String, range: NSRange, prefixes: [String]) -> [NSRange] {
        for prefix in prefixes {
            let pLen = prefix.count
            if text.hasPrefix(prefix) && text.hasSuffix(prefix) && text.count >= pLen * 2 {
                return [
                    NSRange(location: range.location, length: pLen),
                    NSRange(location: NSMaxRange(range) - pLen, length: pLen),
                ]
            }
        }
        return []
    }

    /// For backtick-wrapped code: `` `code` `` or ``` ``code`` ```
    private static func backtickWrapperRanges(text: String, range: NSRange) -> [NSRange] {
        var count = 0
        for ch in text { if ch == "`" { count += 1 } else { break } }
        guard count > 0, text.count >= count * 2 else { return [] }
        // Verify trailing backticks
        var trailing = 0
        for ch in text.reversed() { if ch == "`" { trailing += 1 } else { break } }
        let ticks = min(count, trailing)
        guard ticks > 0 else { return [] }
        return [
            NSRange(location: range.location, length: ticks),
            NSRange(location: NSMaxRange(range) - ticks, length: ticks),
        ]
    }

    /// For fenced code blocks: hide the opening and closing fence lines.
    private static func codeFenceRanges(text: String, range: NSRange) -> [NSRange] {
        let lines = text.components(separatedBy: "\n")
        guard lines.count >= 2 else { return [] }

        let firstLine = lines[0]
        // Check if it's a fenced block (starts with ``` or ~~~)
        let trimmed = firstLine.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") else { return [] }

        // Opening fence line (including the newline)
        let openLen = (firstLine as NSString).length + 1  // +1 for \n
        var result = [NSRange(location: range.location, length: min(openLen, range.length))]

        // Closing fence: find last non-empty line
        let lastLine = lines.last ?? ""
        let lastTrimmed = lastLine.trimmingCharacters(in: .whitespaces)
        if lastTrimmed.hasPrefix("```") || lastTrimmed.hasPrefix("~~~") || lastTrimmed.isEmpty {
            // Calculate the closing fence range
            // Include the \n before the closing fence too
            let lastLineLen = (lastLine as NSString).length
            if lastLineLen > 0 {
                let closeStart = NSMaxRange(range) - lastLineLen
                if closeStart > range.location {
                    // Also hide the newline before closing fence
                    let nlStart = max(range.location, closeStart - 1)
                    result.append(NSRange(location: nlStart, length: NSMaxRange(range) - nlStart))
                }
            }
        }

        return result
    }

    /// For [text](url) and ![alt](url) — hide `[`, `](url)`, and the `!` prefix for images.
    private static func linkSyntaxRanges(text: String, range: NSRange, url: String, isImage: Bool) -> [NSRange] {
        var results: [NSRange] = []

        // For images, hide the leading "!"
        let contentStart: Int
        if isImage && text.hasPrefix("!") {
            results.append(NSRange(location: range.location, length: 1))
            contentStart = range.location + 1
        } else {
            contentStart = range.location
        }

        // Hide the opening "["
        if (isImage ? text.dropFirst() : text[...]).hasPrefix("[") {
            results.append(NSRange(location: contentStart, length: 1))
        }

        // Hide "](url)" at the end
        let suffix = "](\(url))"
        let nsText = text as NSString
        let suffixNS = suffix as NSString
        if nsText.length >= suffixNS.length {
            let suffixStart = range.location + nsText.length - suffixNS.length
            if suffixStart > range.location {
                results.append(NSRange(location: suffixStart, length: suffixNS.length))
            }
        }

        return results
    }

    /// For block quotes: hide "> " at the start of each line.
    private static func blockQuotePrefixRanges(text: String, range: NSRange) -> [NSRange] {
        var results: [NSRange] = []
        var offset = 0
        for line in text.components(separatedBy: "\n") {
            let nsLine = line as NSString
            if line.hasPrefix("> ") {
                results.append(NSRange(location: range.location + offset, length: 2))
            } else if line.hasPrefix(">") {
                results.append(NSRange(location: range.location + offset, length: 1))
            }
            offset += nsLine.length + 1  // +1 for \n
        }
        return results
    }
}
