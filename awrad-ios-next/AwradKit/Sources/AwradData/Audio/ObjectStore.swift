import Foundation

/// Why a transfer to or from storage didn't finish.
enum ObjectStoreFailure: Error, Equatable, Sendable {
    /// No response: offline, timed out, or storage couldn't be reached.
    case transport
    /// Storage answered with this status (an expired link, a checksum R2 refused).
    case status(Int)
}

/// Private storage, reached only through signed links (root ADR-2026-10-29): the bytes go straight
/// between the phone and R2, never through the API. The links are opaque and never stored.
protocol ObjectStore: Sendable {
    /// `PUT`s the file, unchanged, to a signed link with exactly `headers`.
    func put(_ file: URL, to url: URL, headers: [String: String]) async throws(ObjectStoreFailure)
    /// `GET`s a signed link into a temporary file, which the caller moves into place.
    func download(_ url: URL) async throws(ObjectStoreFailure) -> URL
}

/// `ObjectStore` over its own ephemeral `URLSession`: no cookies, no cache, and never the API's
/// bearer token.
struct URLSessionObjectStore: ObjectStore {
    private let session: URLSession

    init(timeout: TimeInterval = 120) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        configuration.timeoutIntervalForRequest = timeout
        session = URLSession(configuration: configuration)
    }

    func put(_ file: URL, to url: URL, headers: [String: String]) async throws(ObjectStoreFailure) {
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        for (name, value) in headers { request.setValue(value, forHTTPHeaderField: name) }
        let response: URLResponse
        do {
            (_, response) = try await session.upload(for: request, fromFile: file)
        } catch {
            throw .transport
        }
        try Self.check(response)
    }

    func download(_ url: URL) async throws(ObjectStoreFailure) -> URL {
        let file: URL
        let response: URLResponse
        do {
            (file, response) = try await session.download(for: URLRequest(url: url))
        } catch {
            throw .transport
        }
        do {
            try Self.check(response)
        } catch {
            try? FileManager.default.removeItem(at: file)
            throw error
        }
        return file
    }

    private static func check(_ response: URLResponse) throws(ObjectStoreFailure) {
        guard let http = response as? HTTPURLResponse else { throw .transport }
        guard (200..<300).contains(http.statusCode) else { throw .status(http.statusCode) }
    }
}
