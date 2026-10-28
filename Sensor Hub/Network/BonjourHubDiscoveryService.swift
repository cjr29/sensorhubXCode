//
//  HubDiscoveryServiceBonjour.swift
//  Sensor Hub
//
//  Created by Chris Riddick on 8/13/26.
//
// Used to search local network for Sensor Hub devices responding on port 5000
// using Bonjour discovery, assuming that Sensor Hubs are advertising
// using name "sensorhubXXXXXXXXXXXX.local" on port 5000
// at _sensorhub._tcp.
//
// Found addresses are validated by sending the following REST query:
// http://sensorhubXXXXXXXXXXXX.local:5000/sensors
// If validated, it is added to the HubDTO array, and when search is complete,
// All HubDTO are upserted into the [Hub] in SwiftData
//
// This IP scan is a backup service if we cannot use Bonjour mDNS discovery.
/** EXAMPLE bonjour record:
   wlan0 IPv4 sensorhub2ccf67e4ad4a                         _sensorhub._tcp      local
   hostname = [sensorhub2ccf67e4ad4a.local]
   address = [192.168.68.120]
   port = [5000]
   txt = ["device=Sensor Hub"]
 */

import Foundation
import SwiftData
import Network
import Darwin

func refreshHubsBonjour(container: ModelContainer, timeout: TimeInterval) async -> [HubDTO] {
    var newDTOs: [HubDTO] = []
    
    let finder = HubFinderBonjour()
    
    let hubStore = HubStore(container: container)
    
    do {
        let existing = try await hubStore.existingURLs()
        
        newDTOs = await finder.discoverNewHubDTOs(
            timeout: 10,
            maxConcurrency: 8,
            excluding: existing
        )
        try await hubStore.insertNewHubs(newDTOs)
    } catch {
        print("Hub insert failed:", error)
    }
    return newDTOs
}

private extension NSRegularExpression {
    func firstMatchString(in s: String) -> String? {
        let range = NSRange(s.startIndex..<s.endIndex, in: s)
        guard let m = firstMatch(in: s, range: range) else { return nil }
        return Range(m.range(at: 0), in: s).map { String(s[$0]) }
    }
}

final class BonjourHubDiscoveryService {
    private let session = URLSession.shared
    private let port: UInt16 = 5000
    private let hubStationRegex = try! NSRegularExpression(pattern: #"^sensorhub([0-9A-Fa-f]{12})$"#)
 
    struct HubDiscoveryResult: Sendable {
        // DTOs only
        let hubs: [HubDTO]
        let sensors: [SensorDTO]
    }

    func isValidStation(_ station: String) -> Bool {
        let range = NSRange(station.startIndex..<station.endIndex, in: station)
        return hubStationRegex.firstMatch(in: station, range: range) != nil
    }

    private func stationFromBonjourName(_ name: String) -> String? {
        if let m = hubStationRegex.firstMatchString(in: name) {
            return m
        }
        return nil
    }

    private func stationFromBonjourHostname(_ hostName: String) -> String? {
        let lower = hostName.lowercased()
        let withoutSuffix: String
        if lower.hasSuffix(".local") {
            withoutSuffix = String(lower.dropLast(".local".count))
        } else if lower.hasSuffix(".") {
            withoutSuffix = String(lower.dropLast())
        } else {
            withoutSuffix = lower
        }
        return stationFromBonjourName(withoutSuffix)
    }

    // Use to get any sensors controlled by this Hub
    func tryFetchSensors(host: String, timeout: TimeInterval) async -> HubDiscoveryResult? {
        guard let url = URL(string: "http://\(host):\(port)/sensors") else { return nil }

        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.timeoutInterval = timeout
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            try Task.checkCancellation()
            let (data, response) = try await session.data(for: req)
            try Task.checkCancellation()

            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode) else {
                return nil
            }

            let sensors = try JSONDecoder().decode([SensorDTO].self, from: data)

            // Build DTOs only
            var hubsByStation: [String: HubDTO] = [:]
            for dto in sensors {
                let station = dto.STATION
                guard isValidStation(station) else { continue }

                if hubsByStation[station] == nil {
                    hubsByStation[station] = HubDTO(
                        station: station,
                        urlString: "http://\(station).local:5000",
                        name: station
                    )
                }
            }

            let hubs = Array(hubsByStation.values)
            return hubs.isEmpty ? nil : HubDiscoveryResult(hubs: hubs, sensors: sensors)
        } catch is CancellationError {
            return nil
        } catch {
            return nil
        }
    }

    func validateBonjourService(
        _ service: NetService,
        timeout: TimeInterval
    ) async -> HubDiscoveryResult? {

        let stationCandidate: String?

        let name = service.name
        if !name.isEmpty {
            stationCandidate = stationFromBonjourName(name)
        } else {
            if let hn = service.hostName, !hn.isEmpty {
                stationCandidate = stationFromBonjourHostname(hn)
            } else {
                stationCandidate = nil
            }
        }

        guard let station = stationCandidate, isValidStation(station) else {
            return nil
        }

        let hn = "\(station).local"
        return await tryFetchSensors(host: hn, timeout: timeout)
    }

    static func ipv4String(from address: Data) -> String? {
        var storage = sockaddr_storage()
        return address.withUnsafeBytes { rawBuf in
            guard rawBuf.count >= MemoryLayout<sockaddr_storage>.size else { return nil }
            memcpy(&storage, rawBuf.baseAddress!, MemoryLayout<sockaddr_storage>.size)

            if storage.ss_family == sa_family_t(AF_INET) {
                var sin = sockaddr_in()
                memcpy(&sin, &storage, MemoryLayout<sockaddr_in>.size)
                var buf = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                if inet_ntop(AF_INET, &sin.sin_addr, &buf, socklen_t(buf.count)) != nil {
                    return String(cString: buf)
                }
            }
            return nil
        }
    }
}
    
struct HubDiscoveryBonjourConfig {
    let serviceType: String = "_sensorhub._tcp."
    let domain: String = "local."
    let restPort: UInt16 = 5000
}

final class HubFinderBonjour {
    private let discoveryService = BonjourHubDiscoveryService()

    func discoverNewHubDTOs(
        timeout: TimeInterval,
        maxConcurrency: Int = 8,
        excluding existingStations: Set<String>
    ) async -> [HubDTO] {
        let browser = NetServiceBrowser()
        browser.includesPeerToPeer = true

        final class Accumulator {
            var services: [NetService] = []
        }

        let accumulator = Accumulator()
        let lock = NSLock()

        let delegate = BrowserDelegate { [weak accumulator] service in
            guard let accumulator else { return }

            let combined = [
                service.name,
                service.hostName ?? ""
            ]
            .joined(separator: " ")

            guard combined.localizedCaseInsensitiveContains("sensorhub") else {
                return
            }

            lock.lock()
            accumulator.services.append(service)
            lock.unlock()
        }

        browser.delegate = delegate

        let runLoop = RunLoop.main
        browser.schedule(in: runLoop, forMode: .default)

        defer {
            browser.stop()
            browser.delegate = nil
            browser.remove(from: runLoop, forMode: .default)
        }

        browser.searchForServices(
            ofType: "_sensorhub._tcp",
            inDomain: "local."
        )

        let start = Date()

        while Date().timeIntervalSince(start) < timeout {
            try? await Task.sleep(
                nanoseconds: 150_000_000
            )

            if Task.isCancelled {
                break
            }
        }

        let services: [NetService] = {
            lock.lock()
            defer { lock.unlock() }
            return accumulator.services
        }()

        guard !services.isEmpty else {
            return []
        }

        var discovered: [HubDTO] = []
        discovered.reserveCapacity(services.count)

        await withTaskGroup(of: [HubDTO]?.self) { group in
            let workerCount = min(
                max(1, maxConcurrency),
                services.count
            )

            for worker in 0..<workerCount {
                group.addTask { [self] in
                    guard !Task.isCancelled else {
                        return nil
                    }

                    var local: [HubDTO] = []
                    var index = worker

                    while index < services.count {
                        guard !Task.isCancelled else {
                            break
                        }

                        let service = services[index]

                        if let result = await self.discoveryService
                            .validateBonjourService(
                                service,
                                timeout: timeout
                            ) {
                            local.append(contentsOf: result.hubs)
                        }

                        index += workerCount
                    }

                    return local.isEmpty ? nil : local
                }
            }

            for await result in group {
                if let result {
                    discovered.append(contentsOf: result)
                }
            }
        }

        // Preserve discovery order, reject existing stations,
        // and reject duplicates from the current discovery pass.
        var selectedStations = existingStations
        var result: [HubDTO] = []
        result.reserveCapacity(discovered.count)

        for dto in discovered {
            guard selectedStations.insert(dto.station).inserted else {
                continue
            }

            result.append(dto)
        }

        return result
    }
}


private final class BrowserDelegate: NSObject, NetServiceBrowserDelegate {
    private let onFound: (NetService) -> Void
    init(_ onFound: @escaping (NetService) -> Void) { self.onFound = onFound }
    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        onFound(service)
    }
}
