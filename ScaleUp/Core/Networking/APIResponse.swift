import Foundation

// MARK: - API Response Wrapper

/// Generic response wrapper matching the backend format:
/// `{ success: bool, message: string?, data: T?, error: { code, details }? }`
struct APIResponse<T: Decodable>: Decodable {
    let success: Bool
    let message: String?
    let data: T?
    let error: APIErrorDetail?
}

// MARK: - Void Response

/// Response wrapper for endpoints that return no data payload.
struct APIVoidResponse: Decodable {
    let success: Bool
    let message: String?
    let error: APIErrorDetail?
}

// MARK: - Error Detail

/// Error detail returned inside `APIResponse.error`.
struct APIErrorDetail: Decodable {
    let code: String?
    let details: String?
}

// MARK: - Paginated Data

/// Paginated wrapper matching the backend format:
/// `{ items: [T], pagination?: { total, page, limit, totalPages, hasNextPage, hasPrevPage } }`
struct PaginatedData<T: Decodable>: Decodable {
    let items: [T]
    let pagination: Pagination?
}

// MARK: - Flat Paginated Response

/// Response wrapper for endpoints that return `data` as a flat array with
/// `pagination` at the top level:
/// `{ success: bool, data: [T], pagination: { ... } }`
struct APIFlatPaginatedResponse<T: Decodable>: Decodable {
    let success: Bool
    let message: String?
    let data: [T]?
    let pagination: Pagination?
    let error: APIErrorDetail?
}

// MARK: - Comments Response Data

/// Wrapper for the comments endpoint which returns `{ comments: [...], pagination: {...} }`
/// instead of the standard `{ items: [...], pagination: {...} }` format.
struct CommentsResponseData: Decodable {
    let comments: [Comment]
    let pagination: Pagination?
}

// MARK: - Pagination Metadata

struct Pagination: Decodable {
    let total: Int?
    let page: Int?
    let limit: Int?
    let totalPages: Int?
    let hasNextPage: Bool?
    let hasPrevPage: Bool?

    /// Backward-compatible accessor.
    var hasMore: Bool { hasNextPage ?? false }
    var pages: Int { totalPages ?? 0 }
}
