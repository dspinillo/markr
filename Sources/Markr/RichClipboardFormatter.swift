import AppKit
import Foundation

struct RichCopyPayload {
    let plainText: String
    let htmlData: Data?
    let rtfData: Data?
}

enum RichClipboardFormatter {
    /// Reads the current pasteboard after a native Copy event and enriches plainText with bullets from HTML if present
    static func captureFromPasteboard(_ pb: NSPasteboard, fallbackText: String) -> RichCopyPayload {
        let htmlData = pb.data(forType: .html)
        let rtfData = pb.data(forType: .rtf)
        let rawPlain = pb.string(forType: .string) ?? fallbackText

        let htmlString = htmlData.flatMap { String(data: $0, encoding: .utf8) }
        let formattedPlain = formatPlainText(rawPlain: rawPlain, htmlString: htmlString)

        // Update the plain text representation on the pasteboard while preserving HTML and RTF!
        if formattedPlain != rawPlain {
            pb.clearContents()
            let item = NSPasteboardItem()
            item.setString(formattedPlain, forType: .string)
            if let htmlData = htmlData {
                item.setData(htmlData, forType: .html)
            }
            if let rtfData = rtfData {
                item.setData(rtfData, forType: .rtf)
            }
            pb.writeObjects([item])
        }

        return RichCopyPayload(
            plainText: formattedPlain,
            htmlData: htmlData,
            rtfData: rtfData
        )
    }

    /// Writes a stored ClipItem back to the pasteboard preserving HTML, RTF, and formatted plain text
    static func writeToPasteboard(_ pb: NSPasteboard, text: String, htmlData: Data?, rtfData: Data?) {
        pb.clearContents()
        let item = NSPasteboardItem()
        item.setString(text, forType: .string)
        if let htmlData = htmlData {
            item.setData(htmlData, forType: .html)
        }
        if let rtfData = rtfData {
            item.setData(rtfData, forType: .rtf)
        }
        pb.writeObjects([item])
    }

    static func formatPlainText(rawPlain: String, htmlString: String?) -> String {
        var text = rawPlain
            .replacingOccurrences(of: "\u{FFFC}", with: "")
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        guard let html = htmlString, !html.isEmpty else {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // If plain text came without line breaks despite block tags in HTML, reconstruct line breaks from HTML block tags
        if !text.contains("\n") && containsBlockTags(html) {
            if let reconstructed = reconstructStructuredTextFromHTML(html), !reconstructed.isEmpty {
                return reconstructed
            }
        }

        // Extract <li> item texts from HTML so we can ensure bullet prefixes "• " exist in plainText
        let liTexts = extractListItemTexts(from: html)
        if !liTexts.isEmpty {
            var lines = text.components(separatedBy: "\n")
            for i in 0..<lines.count {
                let trimmed = lines[i].trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { continue }
                if trimmed.hasPrefix("•") || trimmed.hasPrefix("-") || trimmed.hasPrefix("*") {
                    continue
                }
                let normalizedLine = normalizeWhitespace(trimmed)
                if liTexts.contains(where: { normalizedLine.hasPrefix($0) || $0.hasPrefix(normalizedLine) }) {
                    lines[i] = "• " + trimmed
                }
            }
            text = lines.joined(separator: "\n")
        }

        // Extract bold phrases (<strong> / <b>) from HTML and wrap them with *...* for WhatsApp/Slack plain text
        let boldPhrases = extractBoldPhrases(from: html)
        for phrase in boldPhrases {
            if !text.contains("*\(phrase)*"), text.contains(phrase) {
                text = text.replacingOccurrences(of: phrase, with: "*\(phrase)*")
            }
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - HTML Structure Helpers

    private static func containsBlockTags(_ html: String) -> Bool {
        let lower = html.lowercased()
        let tags = ["<p", "<li", "<div", "<h1", "<h2", "<h3", "<h4", "<br", "<tr"]
        return tags.contains { lower.contains($0) }
    }

    private static func extractListItemTexts(from html: String) -> [String] {
        guard let regex = try? NSRegularExpression(
            pattern: "<li[^>]*>(.*?)</li>",
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else {
            return []
        }

        let nsHTML = html as NSString
        let matches = regex.matches(in: html, range: NSRange(location: 0, length: nsHTML.length))
        var results: [String] = []

        for match in matches {
            guard match.numberOfRanges > 1 else { continue }
            let innerHTML = nsHTML.substring(with: match.range(at: 1))
            let stripped = stripHTMLTags(innerHTML)
            let normalized = normalizeWhitespace(stripped)
            if normalized.count >= 3 {
                // Take the first 28 chars as prefix signature to match reliably even with math nodes
                let prefix = String(normalized.prefix(28))
                results.append(prefix)
            }
        }
        return results
    }

    private static func extractBoldPhrases(from html: String) -> [String] {
        guard let regex = try? NSRegularExpression(
            pattern: "<(?:strong|b|h[1-4])(?:\\s[^>]*)?>(.*?)</(?:strong|b|h[1-4])>",
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else {
            return []
        }

        let nsHTML = html as NSString
        let matches = regex.matches(in: html, range: NSRange(location: 0, length: nsHTML.length))
        var seen = Set<String>()
        var results: [String] = []

        for match in matches {
            guard match.numberOfRanges > 1 else { continue }
            let innerHTML = nsHTML.substring(with: match.range(at: 1))
            let stripped = normalizeWhitespace(stripHTMLTags(innerHTML))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard stripped.count >= 2, !stripped.contains("\n"), !seen.contains(stripped) else {
                continue
            }
            seen.insert(stripped)
            results.append(stripped)
        }
        // Sort longest first so longer bold phrases are replaced before shorter substrings
        return results.sorted { $0.count > $1.count }
    }

    private static func reconstructStructuredTextFromHTML(_ html: String) -> String? {
        var working = html
        // Remove hidden MathML/annotation duplicates inside KaTeX
        if let mathmlRegex = try? NSRegularExpression(
            pattern: "<span[^>]*class=\"[^\"]*katex-mathml[^\"]*\"[^>]*>.*?</span>",
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) {
            working = mathmlRegex.stringByReplacingMatches(
                in: working,
                range: NSRange(location: 0, length: (working as NSString).length),
                withTemplate: ""
            )
        }

        // Replace block boundaries, bold tags, and list items with explicit newlines, *bold*, and bullets
        let replacements: [(String, String)] = [
            ("<br\\s*/?>", "\n"),
            ("<(?:strong|b)(?:\\s[^>]*)?>", "*"),
            ("</(?:strong|b)>", "*"),
            ("<h[1-6](?:\\s[^>]*)?>", "\n*"),
            ("</h[1-6]>", "*\n\n"),
            ("<li[^>]*>", "\n• "),
            ("</li>", "\n"),
            ("</p>", "\n\n"),
            ("</div>", "\n")
        ]

        for (pattern, template) in replacements {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                working = regex.stringByReplacingMatches(
                    in: working,
                    range: NSRange(location: 0, length: (working as NSString).length),
                    withTemplate: template
                )
            }
        }

        let plain = stripHTMLTags(working)
            .replacingOccurrences(of: "\u{00A0}", with: " ")
        let lines = plain
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }

        var cleanedLines: [String] = []
        var previousWasEmpty = false
        for line in lines {
            if line.isEmpty {
                if !previousWasEmpty && !cleanedLines.isEmpty {
                    cleanedLines.append("")
                    previousWasEmpty = true
                }
            } else {
                cleanedLines.append(line)
                previousWasEmpty = false
            }
        }

        return cleanedLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func stripHTMLTags(_ html: String) -> String {
        var result = html
        if let tagRegex = try? NSRegularExpression(pattern: "<[^>]+>", options: []) {
            result = tagRegex.stringByReplacingMatches(
                in: result,
                range: NSRange(location: 0, length: (result as NSString).length),
                withTemplate: ""
            )
        }
        return decodeHTMLEntities(result)
    }

    private static func decodeHTMLEntities(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&minus;", with: "−")
            .replacingOccurrences(of: "&divide;", with: "÷")
            .replacingOccurrences(of: "&times;", with: "×")
    }

    private static func normalizeWhitespace(_ str: String) -> String {
        str
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
