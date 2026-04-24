import XCTest
@testable import Striker

final class CMarkParserTests: XCTestCase {

    func testParsesInlineRangesWithExpectedContent() {
        let source = "This is **bold**, *italic*, ~~strike~~, and `code`."
        let ns = source as NSString
        let ranges = CMarkParser.parse(source)

        let strong = firstRange(in: ranges) { $0 == .strong }
        let emphasis = firstRange(in: ranges) { $0 == .emphasis }
        let strike = firstRange(in: ranges) { $0 == .strikethrough }
        let code = firstRange(in: ranges) { $0 == .code }

        XCTAssertNotNil(strong)
        XCTAssertNotNil(emphasis)
        XCTAssertNotNil(strike)
        XCTAssertNotNil(code)

        if let strong { XCTAssertTrue(ns.substring(with: strong.range).contains("bold")) }
        if let emphasis { XCTAssertTrue(ns.substring(with: emphasis.range).contains("italic")) }
        if let strike { XCTAssertTrue(ns.substring(with: strike.range).contains("strike")) }
        if let code { XCTAssertTrue(ns.substring(with: code.range).contains("code")) }
    }

    func testParsesBlockNodes() {
        let source = "# Title\n\n> quote\n\n- item\n\n---\n\n```swift\nlet x = 1\n```\n"
        let ranges = CMarkParser.parse(source)

        XCTAssertTrue(containsNodeType(in: ranges) { if case .heading(level: 1) = $0 { return true } else { return false } })
        XCTAssertTrue(containsNodeType(in: ranges) { if case .blockQuote = $0 { return true } else { return false } })
        XCTAssertTrue(containsNodeType(in: ranges) { if case .list = $0 { return true } else { return false } })
        XCTAssertTrue(containsNodeType(in: ranges) { if case .listItem = $0 { return true } else { return false } })
        XCTAssertTrue(containsNodeType(in: ranges) { if case .thematicBreak = $0 { return true } else { return false } })
        XCTAssertTrue(containsNodeType(in: ranges) { if case .codeBlock = $0 { return true } else { return false } })
    }

    func testParsesLinksAndImagesWithURLs() {
        let source = "[docs](https://example.com) and ![logo](/img/logo.png)"
        let ranges = CMarkParser.parse(source)

        XCTAssertTrue(containsNodeType(in: ranges) {
            if case .link(url: let url) = $0 { return url == "https://example.com" }
            return false
        })

        XCTAssertTrue(containsNodeType(in: ranges) {
            if case .image(url: let url) = $0 { return url == "/img/logo.png" }
            return false
        })
    }

    private func firstRange(in ranges: [MarkdownRange], _ predicate: (MarkdownNodeType) -> Bool) -> MarkdownRange? {
        ranges.first(where: { predicate($0.type) })
    }

    private func containsNodeType(in ranges: [MarkdownRange], _ predicate: (MarkdownNodeType) -> Bool) -> Bool {
        ranges.contains(where: { predicate($0.type) })
    }
}
