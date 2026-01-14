import Foundation

/// Username validation utilities
struct UsernameValidator {
    
    /// Validation result
    struct ValidationResult {
        let isValid: Bool
        let errorMessage: String
        
        static let valid = ValidationResult(isValid: true, errorMessage: "")
    }
    
    /// Validate username according to rules:
    /// - 3-20 characters after trimming
    /// - Only letters, numbers, and single spaces (no consecutive spaces)
    /// - Strip leading/trailing whitespace
    /// - No special characters
    static func validate(_ username: String) -> ValidationResult {
        // Strip whitespace
        let trimmed = username.trimmingCharacters(in: .whitespaces)
        
        // Check if empty
        if trimmed.isEmpty {
            return ValidationResult(isValid: false, errorMessage: "Username cannot be empty")
        }
        
        // Check length (3-20 characters)
        if trimmed.count < 3 {
            return ValidationResult(isValid: false, errorMessage: "Username must be at least 3 characters")
        }
        
        if trimmed.count > 20 {
            return ValidationResult(isValid: false, errorMessage: "Username must be no more than 20 characters")
        }
        
        // Check for consecutive spaces
        if trimmed.contains("  ") {
            return ValidationResult(isValid: false, errorMessage: "Cannot have consecutive spaces")
        }
        
        // Check for valid characters (letters, numbers, single spaces)
        // Pattern: start with alphanumeric, can have single spaces between words, end with alphanumeric
        let pattern = "^[a-zA-Z0-9]+( [a-zA-Z0-9]+)*$"
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(trimmed.startIndex..., in: trimmed)
        
        if regex?.firstMatch(in: trimmed, range: range) == nil {
            return ValidationResult(isValid: false, errorMessage: "Only letters, numbers, and single spaces allowed")
        }
        
        return .valid
    }
    
    /// Sanitize username by removing leading/trailing whitespace and replacing consecutive spaces
    static func sanitize(_ username: String) -> String {
        // Strip leading/trailing whitespace
        let trimmed = username.trimmingCharacters(in: .whitespaces)
        
        // Replace consecutive spaces with single space
        let components = trimmed.components(separatedBy: .whitespaces)
        let filtered = components.filter { !$0.isEmpty }
        return filtered.joined(separator: " ")
    }
    
    /// Get validation hints for the UI
    static func getValidationHints(for username: String) -> [ValidationHint] {
        let trimmed = username.trimmingCharacters(in: .whitespaces)
        
        return [
            ValidationHint(
                text: "3-20 characters",
                isValid: trimmed.count >= 3 && trimmed.count <= 20
            ),
            ValidationHint(
                text: "Letters and numbers only",
                isValid: trimmed.allSatisfy { $0.isLetter || $0.isNumber || $0 == " " }
            ),
            ValidationHint(
                text: "No consecutive spaces",
                isValid: !trimmed.contains("  ")
            )
        ]
    }
}

/// Validation hint for UI display
struct ValidationHint: Identifiable {
    let id: String  // Stable ID based on text, not random UUID
    let text: String
    let isValid: Bool
    
    init(text: String, isValid: Bool) {
        self.id = text  // Use text as stable identifier
        self.text = text
        self.isValid = isValid
    }
}

