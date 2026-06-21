import Foundation

/// Minimal RFC-4180-style parser for CSV/TSV: handles quoted fields, escaped quotes (`""`),
/// embedded delimiters/newlines inside quotes, and CRLF line endings.
public enum DelimitedText {
    public static func parse(_ text: String, delimiter: Character) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        let chars = Array(text)
        var i = 0

        func endField() { row.append(field); field = "" }
        func endRow() { endField(); rows.append(row); row = [] }

        while i < chars.count {
            let c = chars[i]
            if inQuotes {
                if c == "\"" {
                    if i + 1 < chars.count && chars[i + 1] == "\"" { field.append("\""); i += 2; continue }
                    inQuotes = false; i += 1; continue
                }
                field.append(c); i += 1; continue
            }
            switch c {
            case "\"":
                inQuotes = true; i += 1
            case delimiter:
                endField(); i += 1
            case "\r\n", "\n", "\r": // Swift treats CRLF as one Character grapheme
                endRow(); i += 1
            default:
                field.append(c); i += 1
            }
        }
        // Flush the final field/row unless the input ended exactly on a row break.
        if !field.isEmpty || !row.isEmpty { endRow() }
        return rows
    }
}
