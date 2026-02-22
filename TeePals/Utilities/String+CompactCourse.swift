import Foundation

extension String {
    /// Shortens common golf course naming patterns for compact UI display.
    ///
    /// Only used client-side for rendering — the full name is always
    /// stored in Firestore for search and matching.
    ///
    /// Examples:
    /// - "Encinitas Ranch Golf Course" → "Encinitas Ranch GC"
    /// - "Riverwalk Golf & Country Club" → "Riverwalk G&CC"
    /// - "Torrey Pines Golf Course - South Course" → "Torrey Pines GC - South"
    func compactCourseName() -> String {
        var result = self

        // Longest phrases first to avoid partial replacements
        let replacements: [(target: String, abbreviation: String)] = [
            ("Golf & Country Club", "G&CC"),
            ("Golf and Country Club", "G&CC"),
            ("Country Club", "CC"),
            ("Golf Club", "GC"),
            ("Golf Course", "GC"),
            ("Golf Links", "GL"),
            ("Golf Resort", "Resort"),
        ]

        for rule in replacements {
            let pattern = "(?i)\\b\(NSRegularExpression.escapedPattern(for: rule.target))\\b"
            result = result.replacingOccurrences(
                of: pattern,
                with: rule.abbreviation,
                options: .regularExpression
            )
        }

        // Strip trailing standalone "Course" (e.g., "GC - South Course" → "GC - South")
        result = result.replacingOccurrences(
            of: "(?i)\\sCourse\\b",
            with: "",
            options: .regularExpression
        )

        return result
    }
}
