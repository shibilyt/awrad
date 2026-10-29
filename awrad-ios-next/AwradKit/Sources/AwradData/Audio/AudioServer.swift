import AwradDomain
import Foundation

/// A refusal of an audio operation that the client handles by its code
/// (contracts/api/paths/audio.yaml), with `storage_full`'s used and limit bytes.
struct AudioRefusal: Error, Equatable, Sendable {
    /// The problem codes handled here; anything else is a sync failure.
    static let codes: Set<String> = [
        "file_too_large", "unsupported_audio_type", "invalid_size", "storage_full", "asset_id_in_use",
        "upload_incomplete", "upload_mismatch", "not_found",
    ]

    let code: String
    var usage: AudioUsage?

    init(code: String, usage: AudioUsage? = nil) {
        self.code = code
        self.usage = usage
    }

    init(_ problem: ProblemWire) {
        code = problem.code
        usage = problem.usedBytes.flatMap { used in
            problem.limitBytes.map { AudioUsage(usedBytes: used, limitBytes: $0) }
        }
    }

    /// The upload rule this refusal is, if it is one.
    var uploadError: AudioUploadError? { AudioUploadError(rawValue: code) }
}

/// Why an audio operation didn't succeed.
enum AudioServerFailure: Error, Equatable, Sendable {
    /// As the change queue's requests fail: offline, rate limited, another account, signed out.
    case sync(SyncFailure)
    case refused(AudioRefusal)
}

/// The four audio operations, for one account: the upload engine's and the player's seam to the
/// API (ADR 0004). Every request names the account (`X-Awrad-Account`).
protocol AudioServer: Sendable {
    func createUpload(_ request: AudioUploadRequestWire, account: AwradID) async throws(AudioServerFailure)
        -> AudioCreateResponseWire
    func completeUpload(_ assetID: AwradID, account: AwradID) async throws(AudioServerFailure)
        -> AudioAssetResultWire
    func downloadLink(_ assetID: AwradID, account: AwradID) async throws(AudioServerFailure) -> AudioDownloadWire
    func usage(account: AwradID) async throws(AudioServerFailure) -> AudioUsageWire
}

/// `AudioServer` over the Awrad API with this device's session.
struct APIAudioServer: AudioServer {
    let session: AuthSession

    func createUpload(_ request: AudioUploadRequestWire, account: AwradID) async throws(AudioServerFailure)
        -> AudioCreateResponseWire
    {
        try await outcome(await session.createAudioUpload(request, account: account))
    }

    func completeUpload(_ assetID: AwradID, account: AwradID) async throws(AudioServerFailure)
        -> AudioAssetResultWire
    {
        try await outcome(await session.completeAudioUpload(assetID, account: account))
    }

    func downloadLink(_ assetID: AwradID, account: AwradID) async throws(AudioServerFailure) -> AudioDownloadWire {
        try await outcome(await session.audioDownload(assetID, account: account))
    }

    func usage(account: AwradID) async throws(AudioServerFailure) -> AudioUsageWire {
        try await outcome(await session.audioUsage(account: account))
    }

    private func outcome<Wire>(_ result: Result<Result<Wire, AudioRefusal>, AccountError>)
        async throws(AudioServerFailure) -> Wire
    {
        switch result {
        case .success(.success(let wire)): return wire
        case .success(.failure(let refusal)): throw .refused(refusal)
        case .failure(let error): throw .sync(await SyncFailure(error, session: session))
        }
    }
}

// The audio requests with this device's session: the bearer token (refreshed as needed, through
// `authorized`) and the profile's account in `X-Awrad-Account`. A refusal the engine handles comes
// back as a value, so `authorized` only sees the failures every request shares.
extension AuthSession {
    typealias AudioResult<Wire> = Result<Result<Wire, AudioRefusal>, AccountError>

    func createAudioUpload(_ body: AudioUploadRequestWire, account: AwradID) async -> AudioResult<
        AudioCreateResponseWire
    > {
        await audioCall(account) { token, headers throws(APIFailure) in
            try await client.send(
                .createAudioUpload, body: body, accessToken: token, headers: headers,
                expecting: AudioCreateResponseWire.self)
        }
    }

    func completeAudioUpload(_ assetID: AwradID, account: AwradID) async -> AudioResult<AudioAssetResultWire> {
        await audioCall(account) { token, headers throws(APIFailure) in
            try await client.send(
                .completeAudioUpload, body: NoBody?.none, accessToken: token,
                pathParameters: ["asset_id": assetID.description], headers: headers,
                expecting: AudioAssetResultWire.self)
        }
    }

    func audioDownload(_ assetID: AwradID, account: AwradID) async -> AudioResult<AudioDownloadWire> {
        await audioCall(account) { token, headers throws(APIFailure) in
            try await client.send(
                .getAudioDownload, body: NoBody?.none, accessToken: token,
                pathParameters: ["asset_id": assetID.description], headers: headers,
                expecting: AudioDownloadWire.self)
        }
    }

    func audioUsage(account: AwradID) async -> AudioResult<AudioUsageWire> {
        await audioCall(account) { token, headers throws(APIFailure) in
            try await client.send(
                .getAudioUsage, body: NoBody?.none, accessToken: token, headers: headers,
                expecting: AudioUsageWire.self)
        }
    }

    private func audioCall<Wire: Sendable>(
        _ account: AwradID,
        _ call: (_ token: String, _ headers: [String: String]) async throws(APIFailure) -> Wire
    ) async -> AudioResult<Wire> {
        let headers = ["X-Awrad-Account": account.description]
        do throws(AccountError) {
            return .success(
                try await authorized { token throws(APIFailure) -> Result<Wire, AudioRefusal> in
                    do throws(APIFailure) {
                        return .success(try await call(token, headers))
                    } catch {
                        guard case .problem(let problem, _) = error, AudioRefusal.codes.contains(problem.code) else {
                            throw error
                        }
                        return .failure(AudioRefusal(problem))
                    }
                })
        } catch {
            return .failure(error)
        }
    }
}
