import Foundation

enum StationAvailability: String, Codable {
    case unknown
    case checking
    case available
    case unavailable
}

enum StationDiscovery {
    private static let catalogURL = URL(string: "https://www.funradio.sk/api/zive/")!
    private static let mountPattern = #/^([a-z0-9][a-z0-9_-]*?)[-_]?(32|48|56|64|80|96|112|128|160|192|224|256|320)\.mp3$/#
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 4
        configuration.timeoutIntervalForResource = 7
        return URLSession(configuration: configuration)
    }()

    static func fetchStations() async throws -> [RadioStation] {
        let (data, response) = try await session.data(from: catalogURL)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try stations(from: data)
    }

    static func stations(from data: Data) throws -> [RadioStation] {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              root["ok"] as? Bool == true else { throw URLError(.badServerResponse) }

        var catalog: [RadioStation] = []
        for (key, network) in [("fun", RadioNetwork.funRadio), ("vlna", .vlna)] {
            guard let section = root[key] as? [String: Any],
                  let mounts = section["mounts"] as? [String: [String: Any]] else {
                throw URLError(.badServerResponse)
            }
            catalog += try stations(in: network, mounts: Array(mounts.keys))
        }
        return catalog
    }

    private static func stations(in network: RadioNetwork, mounts: [String]) throws -> [RadioStation] {
        let builtIns = RadioStation.allStations.filter { $0.network == network }
        var knownBySlug: [String: RadioStation] = [:]
        for station in builtIns {
            for quality in StreamQuality.allCases {
                let mount = station.streamURL(for: quality).lastPathComponent
                if let (slug, _) = parseMount(mount, network: network) {
                    knownBySlug[slug] = station
                }
            }
        }

        var variantsByKey: [String: [Int: String]] = [:]
        for mount in mounts.sorted() {
            guard let (slug, bitrate) = parseMount(mount, network: network) else { continue }
            let key = knownBySlug[slug]?.id ?? slug
            variantsByKey[key, default: [:]][bitrate] = mount
        }
        guard mounts.isEmpty || !variantsByKey.isEmpty else { throw URLError(.badServerResponse) }

        let builtInIDs = builtIns.map(\.id)
        let newKeys = Set(variantsByKey.keys).subtracting(builtInIDs).sorted()
        return (builtInIDs + newKeys).compactMap { key in
            guard let variants = variantsByKey[key],
                  let highest = variants.keys.max(), let high = variants[highest],
                  let lowest = variants.keys.min(), let low = variants[lowest] else { return nil }

            let known = builtIns.first { $0.id == key }
            let id = known?.id ?? (network == .vlna ? "vlna_" + key : key)
            guard known != nil || !RadioStation.allStations.contains(where: { $0.id == id }) else { return nil }
            let base = network == .funRadio ? "https://stream.funradio.sk:8000/" : "https://stream.radiovlna.sk/"
            let knownURLs = [known?.standardURL, known?.hdURL, known?.ecoURL].compactMap { $0 }
            func url(for mount: String) -> String {
                // Some Vlna streams use a different port for high and low quality.
                knownURLs.first { $0.hasSuffix("/" + mount) } ?? base + mount
            }
            let christmas = key == "xmas" || key == "vianoce"
            let prefix = network == .funRadio ? "Fun" : "Vlna"
            let name: String
            if let known {
                name = known.name
            } else if christmas {
                name = "\(prefix) Vianoce"
            } else if key == "cba" {
                name = "CBA"
            } else {
                let title = key.replacingOccurrences(of: "-", with: " ").replacingOccurrences(of: "_", with: " ")
                name = "\(prefix) \(title.capitalized)"
            }

            let standard = variants[128] ?? high
            return RadioStation(
                id: id,
                sepiaKey: known?.sepiaKey ?? (network == .vlna && key == "xmas" ? "vlnaxmas" : key),
                icecastMount: standard,
                name: name,
                subtitle: known?.subtitle ?? (network == .funRadio ? "Fun Rádio" : "Rádio Vlna"),
                network: network,
                symbolName: known?.symbolName ?? (christmas ? "snowflake" : "dot.radiowaves.left.and.right"),
                primaryColorHex: known?.primaryColorHex ?? 0xFF2D78,
                secondaryColorHex: known?.secondaryColorHex ?? 0x7928CA,
                standardURL: url(for: standard),
                hdURL: url(for: high),
                ecoURL: url(for: variants[64] ?? low)
            )
        }
    }

    static func check(_ station: RadioStation, quality: StreamQuality) async -> StationAvailability {
        await check(station.streamURL(for: quality))
    }

    static func check(_ url: URL) async -> StationAvailability {
        do {
            let request = URLRequest(url: url, timeoutInterval: 4)
            let (bytes, response) = try await session.bytes(for: request)
            defer { bytes.task.cancel() }
            guard let response = response as? HTTPURLResponse else { return .unavailable }
            let mimeType = response.mimeType?.lowercased() ?? ""
            guard (200...299).contains(response.statusCode),
                  mimeType.hasPrefix("audio/") || mimeType == "application/ogg" else { return .unavailable }
            var iterator = bytes.makeAsyncIterator()
            return try await iterator.next() == nil ? .unavailable : .available
        } catch {
            return .unavailable
        }
    }

    private static func parseMount(_ mount: String, network: RadioNetwork) -> (slug: String, bitrate: Int)? {
        if network == .vlna {
            guard let match = mount.wholeMatch(of: #/^([a-z0-9][a-z0-9_-]*)-(hi|lo)\.mp3$/#) else { return nil }
            return (String(match.1), match.2 == "hi" ? 128 : 64)
        }
        guard let match = mount.wholeMatch(of: mountPattern), let bitrate = Int(match.2) else { return nil }
        return (String(match.1), bitrate)
    }
}
