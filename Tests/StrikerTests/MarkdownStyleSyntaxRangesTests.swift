import XCTest
import Foundation
@testable import Striker

final class MarkdownStyleSyntaxRangesTests: XCTestCase {

    func testStrongSyntaxRanges() {
        let source = "**bold**" as NSString
        let md = MarkdownRange(type: .strong, range: NSRange(location: 0, length: source.length))

        let ranges = MarkdownStyle.syntaxRanges(for: md, in: source)
        XCTAssertEqual(ranges, [NSRange(location: 0, length: 2), NSRange(location: 6, length: 2)])
    }

    func testHeadingSyntaxRanges() {
        let source = "### Heading" as NSString
        let md = MarkdownRange(type: .heading(level: 3), range: NSRange(location: 0, length: source.length))

        let ranges = MarkdownStyle.syntaxRanges(for: md, in: source)
        XCTAssertEqual(ranges, [NSRange(location: 0, length: 4)]) // "### "
    }

    func testLinkSyntaxRanges() {
        let source = "[text](https://example.com)" as NSString
        let md = MarkdownRange(type: .link(url: "https://example.com"), range: NSRange(location: 0, length: source.length))

        let ranges = MarkdownStyle.syntaxRanges(for: md, in: source)
        XCTAssertEqual(ranges, [NSRange(location: 0, length: 1), NSRange(location: 5, length: 22)])
    }

    func testImageSyntaxRanges() {
        let source = "![alt](/img.png)" as NSString
        let md = MarkdownRange(type: .image(url: "/img.png"), range: NSRange(location: 0, length: source.length))

        let ranges = MarkdownStyle.syntaxRanges(for: md, in: source)
        XCTAssertEqual(ranges, [NSRange(location: 0, length: 1), NSRange(location: 1, length: 1), NSRange(location: 5, length: 11)])
    }

    func testBlockQuoteSyntaxRangesAcrossLines() {
        let source = "> quote\n>next" as NSString
        let md = MarkdownRange(type: .blockQuote, range: NSRange(location: 0, length: source.length))

        let ranges = MarkdownStyle.syntaxRanges(for: md, in: source)
        XCTAssertEqual(ranges, [NSRange(location: 0, length: 2), NSRange(location: 8, length: 1)])
    }

    func testCodeFenceSyntaxRanges() {
        let fenced = "```swift\nlet x = 1\n```"
        let source = fenced as NSString
        let md = MarkdownRange(type: .codeBlock, range: NSRange(location: 0, length: source.length))

        let ranges = MarkdownStyle.syntaxRanges(for: md, in: source)
        XCTAssertEqual(ranges.count, 2)

        XCTAssertEqual((source.substring(with: ranges[0])), "```swift\n")
        XCTAssertEqual((source.substring(with: ranges[1])), "\n```")
    }
}
