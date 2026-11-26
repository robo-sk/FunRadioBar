import SwiftUI

enum BroadcastMedia {
    private static let artworkHosts: Set<String> = [
        "www.funradio.sk", "www.radiovlna.sk", "radiogroup-cms.vercel.app",
        "ddvbk8xgdxx9n6sy.public.blob.vercel-storage.com", "www.expres.sk", "www.europa2.sk",
        "www.radiomelody.sk", "api.radiorock.sk", "i.ytimg.com", "c.actve.net", "m.actve.net",
        "api.somafm.com", "somafm.com"
    ]

    private static func allows(_ url: URL, hosts: Set<String>) -> Bool {
        url.scheme?.lowercased() == "https" && hosts.contains(url.host?.lowercased() ?? "")
            && url.user == nil && url.password == nil && (url.port == nil || url.port == 443)
    }

    static func allowsArtwork(_ url: URL) -> Bool { allows(url, hosts: artworkHosts) }

    static func youtube(_ candidate: URL?, artist: String, title: String) -> URL? {
        if let url = candidate, allows(url, hosts: ["youtube.com", "www.youtube.com", "m.youtube.com"]),
           url.path == "/watch",
           let id = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "v" })?.value,
           validVideoID(id) {
            return URL(string: "https://www.youtube.com/watch?v=\(id)")
        }
        if let url = candidate, allows(url, hosts: ["youtu.be"]), validVideoID(url.lastPathComponent) {
            return URL(string: "https://www.youtube.com/watch?v=\(url.lastPathComponent)")
        }
        var search = URLComponents(string: "https://www.youtube.com/results")
        search?.queryItems = [URLQueryItem(name: "search_query", value: "\(artist) \(title)")]
        return search?.url
    }

    private static func validVideoID(_ id: String) -> Bool {
        id.range(of: "^[a-zA-Z0-9_-]{11}$", options: .regularExpression) != nil
    }

    private final class Redirects: NSObject, URLSessionTaskDelegate {
        func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                        newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
            completionHandler(request.url.map(BroadcastMedia.allowsArtwork) == true ? request : nil)
        }
    }

    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.httpShouldSetCookies = false
        config.urlCredentialStorage = nil
        return URLSession(configuration: config, delegate: Redirects(), delegateQueue: nil)
    }()

    static func artwork(_ url: URL) async -> NSImage? {
        guard allowsArtwork(url), let (data, response) = try? await session.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return NSImage(data: data)
    }
}

struct BroadcastImage<Content: View>: View {
    let url: URL
    @ViewBuilder let content: (AsyncImagePhase) -> Content
    @State private var image: NSImage?

    var body: some View {
        content(image.map { .success(Image(nsImage: $0)) } ?? .empty)
            .task(id: url) {
                image = nil
                let loaded = await BroadcastMedia.artwork(url)
                if !Task.isCancelled { image = loaded }
            }
    }
}
