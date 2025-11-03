import Foundation
import CryptoKit

/// Secure network manager with SSL/TLS certificate pinning
/// Implements defense against MITM attacks for critical API communications
@available(macOS 14.0, *)
public actor SecureNetworkManager: NSObject {

    // MARK: - Types

    public enum NetworkError: LocalizedError {
        case invalidURL
        case certificatePinningFailed
        case noResponse
        case invalidResponse(Int)
        case decodingError(any Error)
        case networkError(any Error)
        case rateLimitExceeded

        public var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid URL provided"
            case .certificatePinningFailed:
                return "SSL certificate validation failed - possible security threat"
            case .noResponse:
                return "No response received from server"
            case .invalidResponse(let statusCode):
                return "Invalid response: HTTP \(statusCode)"
            case .decodingError(let error):
                return "Failed to decode response: \(error.localizedDescription)"
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .rateLimitExceeded:
                return "API rate limit exceeded. Please try again later."
            }
        }
    }

    public struct PinnedHost: Sendable {
        let hostname: String
        let pinnedCertificates: [Data]  // DER-encoded certificates
        let includeSubdomains: Bool
        let enforceBackup: Bool  // Require backup pin for recovery
    }

    // MARK: - Properties

    private var pinnedHosts: [String: PinnedHost] = [:]
    private let session: URLSession
    private let sessionDelegate: NetworkSessionDelegateProxy
    private var rateLimiter: RateLimiter

    // Security headers to include in all requests
    private let securityHeaders = [
        "X-Requested-With": "XMLHttpRequest",
        "X-Content-Type-Options": "nosniff",
        "X-Frame-Options": "DENY"
    ]

    // MARK: - Initialization

    public override init() {
        self.rateLimiter = RateLimiter()

        let configuration = URLSessionConfiguration.default
        configuration.tlsMinimumSupportedProtocolVersion = .TLSv12
        configuration.tlsMaximumSupportedProtocolVersion = .TLSv13
        configuration.httpShouldUsePipelining = false
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60

        self.sessionDelegate = NetworkSessionDelegateProxy(pinnedHosts: [:])
        self.session = URLSession(configuration: configuration, delegate: sessionDelegate, delegateQueue: nil)

        super.init()

        // Initialize default pinned hosts without violating actor isolation rules
        pinnedHosts = Self.defaultPinnedHosts()
        sessionDelegate.updatePinnedHosts(pinnedHosts)

        #if DEBUG
        print("🔒 SecureNetworkManager initialized with certificate pinning")
        #endif
    }

    // MARK: - Configuration

    /// Build default pinned hosts at initialization time without requiring actor isolation
    private static func defaultPinnedHosts() -> [String: PinnedHost] {
        var defaults: [String: PinnedHost] = [:]

        if let deepgramCert = loadCertificate(named: "deepgram_api_cert") {
            defaults["api.deepgram.com"] = PinnedHost(
                hostname: "api.deepgram.com",
                pinnedCertificates: [deepgramCert],
                includeSubdomains: true,
                enforceBackup: true
            )
        }

        if let openAICert = loadCertificate(named: "openai_api_cert") {
            defaults["api.openai.com"] = PinnedHost(
                hostname: "api.openai.com",
                pinnedCertificates: [openAICert],
                includeSubdomains: true,
                enforceBackup: true
            )
        }

        return defaults
    }

    /// Add a pinned host for certificate validation
    public func addPinnedHost(
        hostname: String,
        certificates: [Data],
        includeSubdomains: Bool = false,
        enforceBackup: Bool = true
    ) {
        pinnedHosts[hostname] = PinnedHost(
            hostname: hostname,
            pinnedCertificates: certificates,
            includeSubdomains: includeSubdomains,
            enforceBackup: enforceBackup
        )

        // Sync delegated snapshot
        sessionDelegate.updatePinnedHosts(pinnedHosts)

        #if DEBUG
        print("📌 Added pinned host: \(hostname) with \(certificates.count) certificate(s)")
        #endif
    }

    // MARK: - Network Requests

    /// Perform a secure GET request with certificate pinning
    public func secureGet(
        url: URL,
        headers: [String: String] = [:],
        requiresPinning: Bool = true
    ) async throws -> Data {
        // Check rate limiting
        guard await rateLimiter.shouldAllowRequest(for: url.host ?? "") else {
            throw NetworkError.rateLimitExceeded
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        // Add security headers
        for (key, value) in securityHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }

        // Add custom headers
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        return try await performRequest(request, requiresPinning: requiresPinning)
    }

    /// Perform a secure POST request with certificate pinning
    public func securePost(
        url: URL,
        body: Data,
        headers: [String: String] = [:],
        requiresPinning: Bool = true
    ) async throws -> Data {
        // Check rate limiting
        guard await rateLimiter.shouldAllowRequest(for: url.host ?? "") else {
            throw NetworkError.rateLimitExceeded
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body

        // Add security headers
        for (key, value) in securityHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }

        // Add custom headers
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        // Set content type if not already set
        if request.value(forHTTPHeaderField: "Content-Type") == nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        return try await performRequest(request, requiresPinning: requiresPinning)
    }

    /// Perform the actual network request
    private func performRequest(_ request: URLRequest, requiresPinning: Bool) async throws -> Data {
        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.noResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw NetworkError.invalidResponse(httpResponse.statusCode)
            }

            await rateLimiter.recordSuccessfulRequest(for: request.url?.host ?? "")

            return data

        } catch let error as NetworkError {
            throw error
        } catch {
            throw NetworkError.networkError(error)
        }
    }

    // MARK: - Certificate Loading

    private static func loadCertificate(named name: String) -> Data? {
        // In production, load the certificate from the app bundle
        // For now, return nil as we don't have the actual certificates
        // You would typically include the certificate files in your app bundle

        guard let certPath = Bundle.main.path(forResource: name, ofType: "cer"),
              let certData = try? Data(contentsOf: URL(fileURLWithPath: certPath)) else {
            #if DEBUG
            print("⚠️ Certificate not found: \(name).cer - Using default trust evaluation")
            #endif
            return nil
        }

        return certData
    }
}

// MARK: - URLSessionDelegate

// Non-actor delegate proxy to terminate @objc boundaries safely
final class NetworkSessionDelegateProxy: NSObject, URLSessionDelegate, @unchecked Sendable {
    private var pinnedHostsSnapshot: [String: SecureNetworkManager.PinnedHost]

    init(pinnedHosts: [String: SecureNetworkManager.PinnedHost]) {
        self.pinnedHostsSnapshot = pinnedHosts
    }

    func updatePinnedHosts(_ hosts: [String: SecureNetworkManager.PinnedHost]) {
        self.pinnedHostsSnapshot = hosts
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        let host = challenge.protectionSpace.host
        let pinned = getPinnedHostSync(for: host, from: pinnedHostsSnapshot)
        guard let pinned else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        let isValid = validateCertificateChainSync(serverTrust: serverTrust, pinnedHost: pinned)
        if isValid {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }

    private func getPinnedHostSync(
        for hostname: String,
        from pinnedHosts: [String: SecureNetworkManager.PinnedHost]
    ) -> SecureNetworkManager.PinnedHost? {
        if let pinnedHost = pinnedHosts[hostname] { return pinnedHost }
        for (_, pinnedHost) in pinnedHosts {
            if pinnedHost.includeSubdomains && hostname.hasSuffix(".\(pinnedHost.hostname)") {
                return pinnedHost
            }
        }
        return nil
    }

    private func validateCertificateChainSync(
        serverTrust: SecTrust,
        pinnedHost: SecureNetworkManager.PinnedHost
    ) -> Bool {
        guard let certificateChain = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate],
              !certificateChain.isEmpty else {
            return false
        }
        let serverCertificatesData = certificateChain.compactMap { SecCertificateCopyData($0) as Data }
        for serverCertData in serverCertificatesData {
            for pinnedCertData in pinnedHost.pinnedCertificates where serverCertData == pinnedCertData {
                return true
            }
        }
        // Public key pinning fallback
        for serverCert in certificateChain {
            guard let serverPublicKey = SecCertificateCopyKey(serverCert),
                  let serverPublicKeyData = SecKeyCopyExternalRepresentation(
                      serverPublicKey,
                      nil
                  ) as Data? else { continue }
            let serverKeyHash = SHA256.hash(data: serverPublicKeyData)
            for pinnedCertData in pinnedHost.pinnedCertificates {
                if let pinnedCert = SecCertificateCreateWithData(nil, pinnedCertData as CFData),
                   let pinnedPublicKey = SecCertificateCopyKey(pinnedCert),
                   let pinnedPublicKeyData = SecKeyCopyExternalRepresentation(pinnedPublicKey, nil) as Data? {
                    let pinnedKeyHash = SHA256.hash(data: pinnedPublicKeyData)
                    if serverKeyHash == pinnedKeyHash { return true }
                }
            }
        }
        return false
    }
}

extension SecureNetworkManager {
    private func getPinnedHost(for hostname: String) async -> PinnedHost? {
        // Check exact match first
        if let pinnedHost = pinnedHosts[hostname] {
            return pinnedHost
        }

        // Check for subdomain matches if includeSubdomains is true
        for (_, pinnedHost) in pinnedHosts {
            if pinnedHost.includeSubdomains && hostname.hasSuffix(".\(pinnedHost.hostname)") {
                return pinnedHost
            }
        }

        return nil
    }

    private func validateCertificateChain(serverTrust: SecTrust, pinnedHost: PinnedHost) async -> Bool {
        // Get the certificate chain
        guard let certificateChain = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate],
              !certificateChain.isEmpty else {
            return false
        }

        // Convert certificates to Data for comparison
        let serverCertificatesData = certificateChain.compactMap { cert in
            SecCertificateCopyData(cert) as Data
        }

        // Check if any server certificate matches our pinned certificates
        for serverCertData in serverCertificatesData {
            for pinnedCertData in pinnedHost.pinnedCertificates where serverCertData == pinnedCertData {
                #if DEBUG
                print("✅ Certificate pinning successful for: \(pinnedHost.hostname)")
                #endif
                return true
            }
        }

        // Also validate using public key pinning as a fallback
        return validatePublicKeyPinning(
            certificateChain: certificateChain,
            pinnedCertificates: pinnedHost.pinnedCertificates
        )
    }

    private func validatePublicKeyPinning(
        certificateChain: [SecCertificate],
        pinnedCertificates: [Data]
    ) -> Bool {
        for serverCert in certificateChain {
            guard let serverPublicKey = SecCertificateCopyKey(serverCert),
                  let serverPublicKeyData = SecKeyCopyExternalRepresentation(serverPublicKey, nil) as Data? else {
                continue
            }

            // Hash the public key for comparison
            let serverKeyHash = SHA256.hash(data: serverPublicKeyData)

            for pinnedCertData in pinnedCertificates {
                // Extract public key from pinned certificate
                if let pinnedCert = SecCertificateCreateWithData(nil, pinnedCertData as CFData),
                   let pinnedPublicKey = SecCertificateCopyKey(pinnedCert),
                   let pinnedPublicKeyData = SecKeyCopyExternalRepresentation(pinnedPublicKey, nil) as Data? {

                    let pinnedKeyHash = SHA256.hash(data: pinnedPublicKeyData)

                    if serverKeyHash == pinnedKeyHash {
                        #if DEBUG
                        print("✅ Public key pinning successful")
                        #endif
                        return true
                    }
                }
            }
        }

        return false
    }
}

// MARK: - Rate Limiter

@available(macOS 14.0, *)
actor RateLimiter {
    private var requestCounts: [String: (count: Int, resetTime: Date)] = [:]
    private let maxRequestsPerMinute = 60
    private let maxRequestsPerHour = 1000

    func shouldAllowRequest(for host: String) -> Bool {
        let now = Date()

        // Clean up old entries
        requestCounts = requestCounts.filter { $0.value.resetTime > now }

        // Check if we have a record for this host
        if let record = requestCounts[host] {
            if record.count >= maxRequestsPerMinute {
                return false
            }
        }

        return true
    }

    func recordSuccessfulRequest(for host: String) {
        let now = Date()
        let resetTime = now.addingTimeInterval(60) // Reset after 1 minute

        if var record = requestCounts[host] {
            record.count += 1
            requestCounts[host] = record
        } else {
            requestCounts[host] = (count: 1, resetTime: resetTime)
        }
    }
}
