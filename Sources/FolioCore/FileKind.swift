import Foundation

/// Classification of a file for preview-routing purposes, derived from its extension.
public enum FileKind: Equatable, Sendable {
    case markdown
    case html
    case image
    case svg
    case pdf
    case csv
    case json
    case xml
    case text
    case other

    private static let markdownExts: Set<String> = ["md", "markdown", "mdown", "mkd"]
    private static let htmlExts: Set<String> = ["html", "htm", "xhtml"]
    private static let imageExts: Set<String> = ["png", "jpg", "jpeg", "gif", "webp", "bmp", "tiff", "tif", "heic", "ico"]
    private static let svgExts: Set<String> = ["svg"]
    private static let pdfExts: Set<String> = ["pdf"]
    private static let csvExts: Set<String> = ["csv", "tsv"]
    private static let jsonExts: Set<String> = ["json"]
    private static let xmlExts: Set<String> = ["xml", "plist"]
    private static let textExts: Set<String> = [
        "txt", "text", "log", "swift", "js", "jsx", "ts", "tsx", "css",
        "py", "rb", "go", "rs", "c", "h", "cpp", "hpp", "m", "java", "kt",
        "sh", "bash", "zsh", "yml", "yaml", "toml", "ini", "cfg", "conf",
        "sql", "rtf", "tex"
    ]

    /// Extension-less filenames that are conventionally plain text.
    private static let textFilenames: Set<String> = [
        "makefile", "gnumakefile", "dockerfile", "containerfile", "license", "licence",
        "readme", "changelog", "authors", "contributors", "contributing", "notice",
        "copying", "install", "news", "todo", "gemfile", "rakefile", "podfile",
        "brewfile", "procfile", "jenkinsfile", "vagrantfile", "cname", "codeowners"
    ]

    /// Classify the file at `url` by its (case-insensitive) path extension.
    public init(for url: URL) {
        let ext = url.pathExtension.lowercased()

        // No extension: dot-config files (.gitignore, .env, …) and known names (Makefile, LICENSE)
        // are plain text, so they preview as text rather than "no preview".
        if ext.isEmpty {
            let name = url.lastPathComponent.lowercased()
            let isDotConfig = name.hasPrefix(".") && !name.dropFirst().contains(".")
            if isDotConfig || Self.textFilenames.contains(name) {
                self = .text
                return
            }
        }

        switch ext {
        case _ where Self.markdownExts.contains(ext): self = .markdown
        case _ where Self.htmlExts.contains(ext): self = .html
        case _ where Self.svgExts.contains(ext): self = .svg
        case _ where Self.imageExts.contains(ext): self = .image
        case _ where Self.pdfExts.contains(ext): self = .pdf
        case _ where Self.csvExts.contains(ext): self = .csv
        case _ where Self.jsonExts.contains(ext): self = .json
        case _ where Self.xmlExts.contains(ext): self = .xml
        case _ where Self.textExts.contains(ext): self = .text
        default: self = .other
        }
    }

    /// Labels for the rendered/raw preview toggle, or `nil` if this kind has no toggle.
    public var previewToggle: (rendered: String, raw: String)? {
        switch self {
        case .markdown: return ("Formatted", "Raw")
        case .html: return ("Website", "Code")
        case .csv: return ("Table", "Raw")
        case .json: return ("Pretty", "Raw")
        case .xml: return ("Formatted", "Raw")
        case .svg: return ("Image", "Code")
        default: return nil
        }
    }

    /// True when full-text searching the file's contents makes sense. Excludes binary
    /// kinds (image, pdf, svg-as-binary, unknown) where reading bytes as UTF-8 would
    /// produce gibberish hits.
    public var isSearchable: Bool {
        switch self {
        case .markdown, .html, .csv, .json, .xml, .text: return true
        case .image, .svg, .pdf, .other: return false
        }
    }
}
