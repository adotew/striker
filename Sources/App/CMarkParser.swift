import Foundation
import CMarkGFM

// MARK: - Node types for styling

enum MarkdownNodeType {
    case heading(level: Int)     // # through ####
    case strong                  // **bold**
    case emphasis                // *italic*
    case strikethrough           // ~~strike~~
    case code                    // `inline code`
    case codeBlock               // fenced or indented code block
    case link(url: String)       // [text](url)
    case image(url: String)      // ![alt](url)
    case blockQuote              // > quote
    case list                    // - item / 1. item
    case listItem                // individual list item
    case thematicBreak           // ---
}

// MARK: - Parsed range

struct MarkdownRange {
    let type: MarkdownNodeType
    let range: NSRange            // UTF-16 range in the source string
}

// MARK: - Parser

enum CMarkParser {

    /// Parse a markdown string and return styled ranges.
    static func parse(_ string: String) -> [MarkdownRange] {
        cmark_gfm_core_extensions_ensure_registered()

        let parser = cmark_parser_new(CMARK_OPT_DEFAULT)!
        defer { cmark_parser_free(parser) }

        // Attach GFM extensions
        for ext in ["strikethrough", "table", "autolink", "tagfilter", "tasklist"] {
            if let syntax = cmark_find_syntax_extension(ext) {
                cmark_parser_attach_syntax_extension(parser, syntax)
            }
        }

        // Feed source
        let utf8 = Array(string.utf8)
        utf8.withUnsafeBufferPointer { buf in
            cmark_parser_feed(parser, buf.baseAddress, buf.count)
        }

        guard let doc = cmark_parser_finish(parser) else { return [] }
        defer { cmark_node_free(doc) }

        // Build line-offset table for converting line/col → UTF-16 offset
        let lineOffsets = buildLineOffsets(string)
        let nsString = string as NSString

        var results: [MarkdownRange] = []

        // Walk AST
        let iter = cmark_iter_new(doc)!
        defer { cmark_iter_free(iter) }

        // Cache the runtime extension node types
        let strikethroughType = CMARK_NODE_STRIKETHROUGH
        let tableType = CMARK_NODE_TABLE
        _ = tableType  // silence unused warning; reserved for future table styling

        while true {
            let evType = cmark_iter_next(iter)
            if evType == CMARK_EVENT_DONE { break }
            guard evType == CMARK_EVENT_ENTER else { continue }

            let node = cmark_iter_get_node(iter)!
            let nodeType = cmark_node_get_type(node)

            let startLine = Int(cmark_node_get_start_line(node))
            let startCol  = Int(cmark_node_get_start_column(node))
            let endLine   = Int(cmark_node_get_end_line(node))
            let endCol    = Int(cmark_node_get_end_column(node))

            // Skip nodes with no position info
            guard startLine > 0 && endLine > 0 else { continue }

            guard let range = utf16Range(
                startLine: startLine, startCol: startCol,
                endLine: endLine, endCol: endCol,
                lineOffsets: lineOffsets, stringLength: nsString.length
            ) else { continue }

            let mdType: MarkdownNodeType?

            switch nodeType {
            case CMARK_NODE_HEADING:
                let level = Int(cmark_node_get_heading_level(node))
                mdType = .heading(level: level)
            case CMARK_NODE_STRONG:
                mdType = .strong
            case CMARK_NODE_EMPH:
                mdType = .emphasis
            case CMARK_NODE_CODE:
                mdType = .code
            case CMARK_NODE_CODE_BLOCK:
                mdType = .codeBlock
            case CMARK_NODE_LINK:
                let url = cmark_node_get_url(node).flatMap { String(cString: $0) } ?? ""
                mdType = .link(url: url)
            case CMARK_NODE_IMAGE:
                let url = cmark_node_get_url(node).flatMap { String(cString: $0) } ?? ""
                mdType = .image(url: url)
            case CMARK_NODE_BLOCK_QUOTE:
                mdType = .blockQuote
            case CMARK_NODE_LIST:
                mdType = .list
            case CMARK_NODE_ITEM:
                mdType = .listItem
            case CMARK_NODE_THEMATIC_BREAK:
                mdType = .thematicBreak
            default:
                // Check runtime-registered GFM extension types
                if nodeType == strikethroughType {
                    mdType = .strikethrough
                } else {
                    mdType = nil
                }
            }

            if let mdType {
                results.append(MarkdownRange(type: mdType, range: range))
            }
        }

        return results
    }

    // MARK: - Line offset table

    /// Returns an array where index i is the UTF-16 offset of the start of line (i+1).
    /// lineOffsets[0] = offset of line 1 (always 0).
    private static func buildLineOffsets(_ string: String) -> [Int] {
        let nsString = string as NSString
        var offsets: [Int] = [0]
        var i = 0
        let length = nsString.length
        while i < length {
            let ch = nsString.character(at: i)
            i += 1
            if ch == 0x0A { // \n
                offsets.append(i)
            } else if ch == 0x0D { // \r
                if i < length && nsString.character(at: i) == 0x0A {
                    i += 1
                }
                offsets.append(i)
            }
        }
        return offsets
    }

    /// Convert cmark 1-based line/col to an NSRange (UTF-16).
    /// cmark columns are 1-based byte offsets within the line.
    private static func utf16Range(
        startLine: Int, startCol: Int,
        endLine: Int, endCol: Int,
        lineOffsets: [Int], stringLength: Int
    ) -> NSRange? {
        guard startLine >= 1, startLine <= lineOffsets.count,
              endLine >= 1, endLine <= lineOffsets.count else { return nil }

        let startOffset = lineOffsets[startLine - 1] + (startCol - 1)
        let endOffset   = lineOffsets[endLine - 1] + endCol

        guard startOffset >= 0, endOffset >= startOffset, endOffset <= stringLength else {
            // Clamp to valid range
            let s = max(0, min(startOffset, stringLength))
            let e = max(s, min(endOffset, stringLength))
            return NSRange(location: s, length: e - s)
        }

        return NSRange(location: startOffset, length: endOffset - startOffset)
    }
}
