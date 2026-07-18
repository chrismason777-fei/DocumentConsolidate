// 2026-07-18 23:05 SGT

enum DocumentClassification {
    static func category(for fileExtension: String) -> DocumentCategory {
        switch fileExtension {
        case "pdf", "docx", "odt", "rtf": .document
        case "xlsx", "ods": .spreadsheet
        case "pptx", "odp": .presentation
        case "md", "txt": .text
        default: .other
        }
    }
}
