import AppKit
import Foundation

struct RichCopyPayload {
    let plainText: String
    let htmlData: Data?
    let rtfData: Data?
}

enum RichClipboardFormatter {
    /// Reads the current pasteboard after a native Copy event and cleans both plainText and HTML
    static func captureFromPasteboard(_ pb: NSPasteboard, fallbackText: String) -> RichCopyPayload {
        let rawHTMLData = pb.data(forType: .html)
        let rtfData = pb.data(forType: .rtf)
        let rawPlain = pb.string(forType: .string) ?? fallbackText

        let rawHTMLString = rawHTMLData.flatMap { String(data: $0, encoding: .utf8) }
        let sanitizedHTMLString = rawHTMLString.map { sanitizeRichHTML($0) }
        let sanitizedHTMLData = sanitizedHTMLString?.data(using: .utf8) ?? rawHTMLData

        let formattedPlain = formatPlainText(rawPlain: rawPlain, htmlString: rawHTMLString)

        // Update the pasteboard with the clean plain text and sanitized HTML!
        if formattedPlain != rawPlain || sanitizedHTMLString != rawHTMLString {
            pb.clearContents()
            let item = NSPasteboardItem()
            item.setString(formattedPlain, forType: .string)
            if let sanitizedHTMLData = sanitizedHTMLData {
                item.setData(sanitizedHTMLData, forType: .html)
            }
            if let rtfData = rtfData {
                item.setData(rtfData, forType: .rtf)
            }
            pb.writeObjects([item])
        }

        return RichCopyPayload(
            plainText: formattedPlain,
            htmlData: sanitizedHTMLData,
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
            return cleanInlineLatexMath(text).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // If the HTML contains KaTeX / MathML or lacked newlines despite block tags,
        // reconstruct directly from the clean HTML so hidden <math> duplicates and broken tokens are eliminated!
        if containsMathMarkup(html) || (!text.contains("\n") && containsBlockTags(html)) {
            if let reconstructed = reconstructStructuredTextFromHTML(html), !reconstructed.isEmpty {
                return cleanInlineLatexMath(reconstructed)
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

        return cleanInlineLatexMath(text).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Inline LaTeX Cleanup ($...$)

    /// Converts inline LaTeX math blocks like `$1.417 \div 2 = \text{R\$ } 708,50$` into clean readable Unicode text
    static func cleanInlineLatexMath(_ input: String) -> String {
        guard input.contains("\\") && input.contains("$") else {
            return input
        }
        // Temporarily replace escaped `\$` with a placeholder so the outer `$ ... $` delimiter match doesn't stop early on `R\$`
        let escapedDollarPlaceholder = "\u{E000}"
        let prepared = input.replacingOccurrences(of: "\\$", with: escapedDollarPlaceholder)

        guard let regex = try? NSRegularExpression(
            pattern: "\\$([^$\\n]+)\\$",
            options: []
        ) else {
            return input
        }

        let nsPrepared = prepared as NSString
        let matches = regex.matches(in: prepared, range: NSRange(location: 0, length: nsPrepared.length))
        guard !matches.isEmpty else { return input }

        var result = prepared
        for match in matches.reversed() {
            guard match.numberOfRanges > 1 else { continue }
            let innerRange = match.range(at: 1)
            let inner = nsPrepared.substring(with: innerRange)
            // Only treat `$...$` as LaTeX math if it contains a LaTeX backslash command or our escaped `\$` placeholder
            guard inner.contains("\\") || inner.contains(escapedDollarPlaceholder) else { continue }

            let cleanedInner = convertLatexFragmentToReadable(inner)
            if let swiftRange = Range(match.range, in: result) {
                result.replaceSubrange(swiftRange, with: cleanedInner)
            }
        }
        return result.replacingOccurrences(of: escapedDollarPlaceholder, with: "$")
    }

    private static func convertLatexFragmentToReadable(_ latex: String) -> String {
        var s = latex
            .replacingOccurrences(of: "\\$", with: "\u{E000}") // temporary placeholder for literal $

        // Unwrap \text{...}, \textbf{...}, \mathrm{...}
        if let textMacroRegex = try? NSRegularExpression(
            pattern: "\\\\(?:text|textbf|textit|mathrm|mathbf)\\{([^}]*)\\}",
            options: []
        ) {
            s = textMacroRegex.stringByReplacingMatches(
                in: s,
                range: NSRange(location: 0, length: (s as NSString).length),
                withTemplate: "$1"
            )
        }

        let symbolMap: [(String, String)] = [
            ("\\div", "÷"),
            ("\\times", "×"),
            ("\\cdot", "·"),
            ("\\pm", "±"),
            ("\\approx", "≈"),
            ("\\neq", "≠"),
            ("\\leq", "≤"),
            ("\\geq", "≥"),
            ("\\left", ""),
            ("\\right", ""),
            ("\\,", " "),
            ("\\;", " "),
            ("\\!", "")
        ]

        for (cmd, sym) in symbolMap {
            s = s.replacingOccurrences(of: cmd, with: sym)
        }

        s = s.replacingOccurrences(of: "\u{E000}", with: "$")
        // Collapse multiple spaces
        s = s.components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return s
    }

    // MARK: - HTML Sanitization & Reconstruction

    /// Removes hidden MathML/LaTeX annotations from HTML so rich-paste targets don't get duplicate math either
    static func sanitizeRichHTML(_ html: String) -> String {
        var working = html
        let patternsToRemove = [
            "<math\\b[^>]*>.*?</math>",
            "<annotation\\b[^>]*>.*?</annotation>",
            "\\sdata-math=\"[^\"]*\""
        ]
        for pattern in patternsToRemove {
            if let regex = try? NSRegularExpression(
                pattern: pattern,
                options: [.caseInsensitive, .dotMatchesLineSeparators]
            ) {
                working = regex.stringByReplacingMatches(
                    in: working,
                    range: NSRange(location: 0, length: (working as NSString).length),
                    withTemplate: ""
                )
            }
        }
        return cleanInlineLatexMath(working)
    }

    private static func containsMathMarkup(_ html: String) -> Bool {
        let lower = html.lowercased()
        return lower.contains("katex") || lower.contains("<math") || lower.contains("mathjax") || lower.contains("data-math=")
    }

    private static func containsBlockTags(_ html: String) -> Bool {
        let lower = html.lowercased()
        let tags = ["<p", "<li", "<div", "<h1", "<h2", "<h3", "<h4", "<br", "<tr"]
        return tags.contains { lower.contains($0) }
    }

    private static func extractListItemTexts(from html: String) -> [String] {
        let cleanHTML = sanitizeRichHTML(html)
        guard let regex = try? NSRegularExpression(
            pattern: "<li[^>]*>(.*?)</li>",
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else {
            return []
        }

        let nsHTML = cleanHTML as NSString
        let matches = regex.matches(in: cleanHTML, range: NSRange(location: 0, length: nsHTML.length))
        var results: [String] = []

        for match in matches {
            guard match.numberOfRanges > 1 else { continue }
            let innerHTML = nsHTML.substring(with: match.range(at: 1))
            let stripped = stripHTMLTags(innerHTML)
            let normalized = normalizeWhitespace(stripped)
            if normalized.count >= 3 {
                let prefix = String(normalized.prefix(28))
                results.append(prefix)
            }
        }
        return results
    }

    private static func extractBoldPhrases(from html: String) -> [String] {
        let cleanHTML = sanitizeRichHTML(html)
        guard let regex = try? NSRegularExpression(
            pattern: "<(?:strong|b|h[1-4])(?:\\s[^>]*)?>(.*?)</(?:strong|b|h[1-4])>",
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else {
            return []
        }

        let nsHTML = cleanHTML as NSString
        let matches = regex.matches(in: cleanHTML, range: NSRange(location: 0, length: nsHTML.length))
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
        return results.sorted { $0.count > $1.count }
    }

    static func reconstructStructuredTextFromHTML(_ html: String) -> String? {
        var working = sanitizeRichHTML(html)

        // Normalize visual spaces inside KaTeX/HTML math before stripping tags:
        // <span class="mbin">÷</span> -> " ÷ ", <span class="mrel">=</span> -> " = "
        let mathSpacingReplacements: [(String, String)] = [
            ("<span[^>]*class=\"[^\"]*\\bmbin\\b[^\"]*\"[^>]*>(.*?)</span>", " $1 "),
            ("<span[^>]*class=\"[^\"]*\\bmrel\\b[^\"]*\"[^>]*>(.*?)</span>", " $1 "),
            ("<li[^>]*>\\s*<p[^>]*>", "\n• "),
            ("</p>\\s*</li>", "\n")
        ]

        for (pattern, template) in mathSpacingReplacements {
            if let regex = try? NSRegularExpression(
                pattern: pattern,
                options: [.caseInsensitive, .dotMatchesLineSeparators]
            ) {
                working = regex.stringByReplacingMatches(
                    in: working,
                    range: NSRange(location: 0, length: (working as NSString).length),
                    withTemplate: template
                )
            }
        }

        // Replace block boundaries, bold tags, and list items with explicit newlines, *bold*, and bullets
        let replacements: [(String, String)] = [
            ("<br\\s*/?>", "\n"),
            ("<(?:strong|b)(?:\\s[^>]*)?>", "*"),
            ("</(?:strong|b)>", "*"),
            ("<h[1-6](?:\\s[^>]*)?>", "\n*"),
            ("</h[1-6]>", "*\n\n"),
            ("<ul[^>]*>", "\n"),
            ("</ul>", "\n\n"),
            ("<ol[^>]*>", "\n"),
            ("</ol>", "\n\n"),
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

        let rawLines = plain.components(separatedBy: "\n")
        var cleanedLines: [String] = []
        var previousWasEmpty = false

        for rawLine in rawLines {
            // Collapse multiple spaces within the same line while keeping single spaces clean
            let collapsed = rawLine
                .components(separatedBy: .whitespaces)
                .filter { !$0.isEmpty }
                .joined(separator: " ")
                .replacingOccurrences(of: " ,", with: ",")
                .replacingOccurrences(of: " .", with: ".")
                .replacingOccurrences(of: " )", with: ")")
                .replacingOccurrences(of: "( ", with: "(")
                .trimmingCharacters(in: .whitespaces)

            if collapsed.isEmpty {
                if !previousWasEmpty && !cleanedLines.isEmpty {
                    cleanedLines.append("")
                    previousWasEmpty = true
                }
            } else {
                cleanedLines.append(collapsed)
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
