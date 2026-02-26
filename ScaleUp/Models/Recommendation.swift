import Foundation

// MARK: - RecommendedContent

/// Wrapper around Content for recommendations.
/// The backend returns content objects with an extra `_recommendationScore` field,
/// which is mapped directly on the `Content` model via its `recommendationScore` property.
/// This typealias exists for semantic clarity when working with recommendation endpoints.
typealias RecommendedContent = Content
