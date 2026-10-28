//
//  ConnectoToWPA2Hotspot.swift
//  Sensor Hub
//
//  Created by Chris Riddick on 8/18/26.
//

import Foundation
import Network
import NetworkExtension
import Darwin

enum HotspotJoinError: LocalizedError {
    case applyFailed(String)
    case timedOut
    case noWiFiInterface
    case noIPv4Address

    var errorDescription: String? {
        switch self {
        case .applyFailed(let msg): return "Failed to apply hotspot config: \(msg)"
        case .timedOut: return "Timed out waiting for Wi‑Fi connectivity."
        case .noWiFiInterface: return "No Wi‑Fi interface detected."
        case .noIPv4Address: return "No IPv4 address available on the Wi‑Fi interface."
        }
    }
}

func connectToWPA2Hotspot(ssid: String, passphrase: String, timeout: TimeInterval = 20) async throws {
    let config = NEHotspotConfiguration(ssid: ssid, passphrase: passphrase, isWEP: false)
    config.joinOnce = true

    try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
        NEHotspotConfigurationManager.shared.apply(config) { error in
            if let error {
                cont.resume(throwing: HotspotJoinError.applyFailed(error.localizedDescription))
            } else {
                cont.resume(returning: ())
            }
        }
    }

    let ok = await waitForWiFiConnectivity(timeout: timeout)
    if !ok { throw HotspotJoinError.timedOut }
}

private actor ContinuationGate {
    private var finished = false

    private let monitor: NWPathMonitor
    private let continuation: CheckedContinuation<Bool, Never>

    init(
        monitor: NWPathMonitor,
        continuation: CheckedContinuation<Bool, Never>
    ) {
        self.monitor = monitor
        self.continuation = continuation
    }

    func finish(_ value: Bool) {
        guard !finished else {
            return
        }

        finished = true
        monitor.cancel()
        continuation.resume(returning: value)
    }
}

/**
 finished is protected by NSLock.
 gate is a reference type that can safely be captured by @Sendable closures.
 Both completion paths call the same thread-safe finish.
 monitor.cancel() prevents further monitoring after completion.
 The continuation is resumed exactly once.
 */
private func waitForWiFiConnectivity(
    timeout: TimeInterval
) async -> Bool {
    let monitor = NWPathMonitor()
    let queue = DispatchQueue(label: "WiFiConnectivityMonitor")

    return await withCheckedContinuation { continuation in
        let gate = ContinuationGate(
            monitor: monitor,
            continuation: continuation
        )

        monitor.pathUpdateHandler = { path in
            guard path.status == .satisfied else {
                return
            }

            let hasWiFi = path.availableInterfaces.contains {
                $0.type == .wifi
            }

            if hasWiFi {
                Task {
                    await gate.finish(true)
                }
            }
        }

        monitor.start(queue: queue)

        queue.asyncAfter(deadline: .now() + timeout) {
            Task {
                await gate.finish(false)
            }
        }
    }
}

func currentWiFiIPv4Address() throws -> String {
    var addrs: UnsafeMutablePointer<ifaddrs>? = nil
    defer { if addrs != nil { freeifaddrs(addrs) } }

    guard getifaddrs(&addrs) == 0, let first = addrs else {
        throw HotspotJoinError.noWiFiInterface
    }

    var found: String? = nil
    var ptr = first

    while true {
        let ifa = ptr.pointee
        defer { ptr = ptr.advanced(by: 1) }
        if ifa.ifa_name == nil { break }

        // Skip down interfaces
        let flags = Int32(ifa.ifa_flags)
        if (flags & IFF_UP) == 0 { continue }

        // We only want IPv4: sa_family == AF_INET
        if let addr = ifa.ifa_addr, addr.pointee.sa_family == UInt8(AF_INET) {
            // Convert sockaddr_in to string
            var sa = addr.pointee
            let sockaddrIn = withUnsafePointer(to: &sa) { ptrSock -> sockaddr_in in
                return ptrSock.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
            }

            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            var saCopy = sockaddrIn

            let saLen = socklen_t(saCopy.sin_len) // copy length out to avoid overlapping access
            let result = withUnsafePointer(to: &saCopy) { p in
                p.withMemoryRebound(to: sockaddr.self, capacity: 1) { saPtr in
                    getnameinfo(
                        saPtr,
                        saLen,
                        &hostname,
                        socklen_t(hostname.count),
                        nil,
                        0,
                        NI_NUMERICHOST
                    )
                }
            }
            
            if result == 0, let ifName = String(validatingUTF8: ifa.ifa_name) {
                // Commonly Wi‑Fi is en0; but on some devices/contexts it can vary.
                // Keep it simple: prefer en0.
                if ifName == "en0" {
                    found = String(cString: hostname)
                    break
                }
                // Fallback if en0 isn't present (rare): take the first IPv4 on a "wifi-like" interface name.
                if found == nil && (ifName == "en1" || ifName.hasPrefix("en")) {
                    found = String(cString: hostname)
                }
            }
        }

        // move to next in list
        if ptr.pointee.ifa_next == nil { break }
        // ptr advanced by defer above; loop relies on pointer end condition below
    }

    guard let ipv4 = found, !ipv4.isEmpty else {
        throw HotspotJoinError.noIPv4Address
    }
    return ipv4
}

func connectAndFetchHotspotIPv4(ssid: String, passphrase: String) async throws -> String {
    try await connectToWPA2Hotspot(ssid: ssid, passphrase: passphrase)
    // Sometimes the interface IP assignment lags slightly after link-up.
    // If you see occasional failures, add a short retry loop.
    let currentIP = try currentWiFiIPv4Address()
    let routerIP = replaceLastIPv4Segment(currentIP)
    return (routerIP ?? currentIP)
}

func disconnectFromHotspot(ssid: String) async {
    // Removing the config is the closest you can get to “disconnect”.
    NEHotspotConfigurationManager.shared.removeConfiguration(forSSID: ssid)
}

// Return the assumed Router address for the Hotspot given an input IP
func replaceLastIPv4Segment(_ address: String) -> String? {
    var segments = address.split(separator: ".", omittingEmptySubsequences: false)

    guard segments.count == 4,
          segments.allSatisfy({ segment in
              guard let value = Int(segment), (0...255).contains(value) else {
                  return false
              }
              return true
          })
    else {
        return nil
    }

    segments[3] = "1"
    return segments.joined(separator: ".")
}

/**
 The following functions provide a means to command the Hotspot to reconnect to a specific SSID
 */
struct ConnectSSIDRequest: Encodable {
    let ssid: String
    let password: String

    enum CodingKeys: String, CodingKey {
        case ssid = "SSID"
        case password
    }
}

struct SensorHubClient {

    func tellHubToConnectToWiFi(
        host: String,
        ssid: String,
        password: String
    ) async throws {
        let requestBody = ConnectSSIDRequest(
            ssid: ssid,
            password: password
        )

        let endpoint = URL(string: "http://" + host + ":5000/connect-ssid")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(
            "application/json",
            forHTTPHeaderField: "Content-Type"
        )
        request.httpBody = try JSONEncoder().encode(requestBody)

        let (_, response) = try await URLSession.shared.data(
            for: request
        )

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw NSError(
                domain: "SensorHub",
                code: httpResponse.statusCode,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "SensorHub returned HTTP \(httpResponse.statusCode)"
                ]
            )
        }
    }
}
