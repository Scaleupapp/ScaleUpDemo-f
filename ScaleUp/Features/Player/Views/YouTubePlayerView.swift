import SwiftUI
import WebKit

// MARK: - YouTube Player View

/// UIViewRepresentable wrapping WKWebView that loads YouTube's mobile watch page.
/// Injects a tracking script to monitor the <video> element and report playback
/// state back to Swift for progress tracking in the ScaleUp backend.
struct YouTubePlayerView: UIViewRepresentable {

    let videoId: String

    @Binding var isPlaying: Bool
    @Binding var currentTime: Double
    @Binding var duration: Double
    @Binding var isReady: Bool

    var onStateChange: ((YouTubePlayerState) -> Void)?
    var onTimeUpdate: ((Double, Double) -> Void)?
    var onVideoEnded: (() -> Void)?
    var onError: ((Int) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        // Register message handler for progress tracking bridge
        configuration.userContentController.add(context.coordinator, name: "scaleupTracker")

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = true
        webView.navigationDelegate = context.coordinator
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"

        context.coordinator.webView = webView

        let watchURL = "https://m.youtube.com/watch?v=\(videoId)"
        if let url = URL(string: watchURL) {
            webView.load(URLRequest(url: url))
        }

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if context.coordinator.currentVideoId != videoId {
            context.coordinator.currentVideoId = videoId
            let watchURL = "https://m.youtube.com/watch?v=\(videoId)"
            if let url = URL(string: watchURL) {
                webView.load(URLRequest(url: url))
            }
        }
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        coordinator.cleanup()
    }

    // MARK: - Tracking Script

    /// JavaScript injected after the YouTube page loads.
    /// Monitors the <video> element for playback state and reports back to Swift.
    static let trackingScript = """
    (function() {
        if (window._scaleupTrackerActive) return;
        window._scaleupTrackerActive = true;

        function findVideo() {
            return document.querySelector('video');
        }

        function post(msg) {
            try { window.webkit.messageHandlers.scaleupTracker.postMessage(JSON.stringify(msg)); }
            catch(e) {}
        }

        var lastState = '';
        var trackInterval = null;

        function startTracking(video) {
            if (trackInterval) clearInterval(trackInterval);

            video.addEventListener('play', function() {
                post({ event: 'stateChange', state: 'playing' });
            });
            video.addEventListener('pause', function() {
                post({ event: 'stateChange', state: 'paused' });
            });
            video.addEventListener('ended', function() {
                post({ event: 'ended', currentTime: video.currentTime, duration: video.duration });
            });

            // Report time every 2 seconds
            trackInterval = setInterval(function() {
                if (video && !video.paused) {
                    post({
                        event: 'timeUpdate',
                        currentTime: video.currentTime,
                        duration: video.duration
                    });
                }
            }, 2000);

            post({ event: 'ready', duration: video.duration || 0 });
        }

        // Poll for video element (YouTube loads it dynamically)
        var attempts = 0;
        var pollInterval = setInterval(function() {
            var video = findVideo();
            attempts++;
            if (video) {
                clearInterval(pollInterval);
                startTracking(video);
            } else if (attempts > 30) {
                clearInterval(pollInterval);
            }
        }, 500);
    })();
    """

    // MARK: - Coordinator

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {

        var parent: YouTubePlayerView
        weak var webView: WKWebView?
        var currentVideoId: String
        private var hasInjectedScript = false

        init(parent: YouTubePlayerView) {
            self.parent = parent
            self.currentVideoId = parent.videoId
            super.init()
        }

        // MARK: - WKScriptMessageHandler

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard message.name == "scaleupTracker",
                  let bodyString = message.body as? String,
                  let data = bodyString.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let event = json["event"] as? String
            else { return }

            DispatchQueue.main.async { [weak self] in
                self?.handleEvent(event, json: json)
            }
        }

        private func handleEvent(_ event: String, json: [String: Any]) {
            switch event {
            case "ready":
                parent.isReady = true
                if let dur = json["duration"] as? Double, dur > 0 {
                    parent.duration = dur
                }

            case "stateChange":
                if let state = json["state"] as? String {
                    switch state {
                    case "playing":
                        parent.isPlaying = true
                        parent.onStateChange?(.playing)
                    case "paused":
                        parent.isPlaying = false
                        parent.onStateChange?(.paused)
                    default:
                        break
                    }
                }

            case "timeUpdate":
                let ct = json["currentTime"] as? Double ?? 0
                let dur = json["duration"] as? Double ?? 0
                parent.currentTime = ct
                if dur > 0 { parent.duration = dur }
                parent.onTimeUpdate?(ct, dur)

            case "ended":
                let ct = json["currentTime"] as? Double ?? 0
                let dur = json["duration"] as? Double ?? 0
                parent.currentTime = ct
                if dur > 0 { parent.duration = dur }
                parent.isPlaying = false
                parent.onTimeUpdate?(ct, dur)
                parent.onVideoEnded?()

            default:
                break
            }
        }

        // MARK: - WKNavigationDelegate

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            if let url = navigationAction.request.url {
                let host = url.host ?? ""
                if host.contains("youtube.com")
                    || host.contains("youtube-nocookie.com")
                    || host.contains("ytimg.com")
                    || host.contains("googlevideo.com")
                    || host.contains("google.com")
                    || host.contains("googleapis.com")
                    || host.contains("gstatic.com")
                    || host.contains("ggpht.com")
                    || url.scheme == "about"
                    || url.scheme == "blob"
                    || navigationAction.navigationType == .other {
                    decisionHandler(.allow)
                    return
                }
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Inject tracking script after page loads
            injectTrackingScript()
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("‼️ YouTube navigation failed: \(error)")
            DispatchQueue.main.async { self.parent.onError?(0) }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("‼️ YouTube provisional navigation failed: \(error)")
            DispatchQueue.main.async { self.parent.onError?(0) }
        }

        // MARK: - Script Injection

        private func injectTrackingScript() {
            webView?.evaluateJavaScript(YouTubePlayerView.trackingScript) { _, error in
                if let error {
                    print("‼️ Tracking script injection error: \(error)")
                }
            }
        }

        // MARK: - Player Controls

        func play() {
            webView?.evaluateJavaScript("document.querySelector('video')?.play()")
        }

        func pause() {
            webView?.evaluateJavaScript("document.querySelector('video')?.pause()")
        }

        func seek(to seconds: Double) {
            webView?.evaluateJavaScript("var v = document.querySelector('video'); if(v) v.currentTime = \(seconds);")
        }

        // MARK: - Cleanup

        func cleanup() {
            webView?.configuration.userContentController.removeScriptMessageHandler(forName: "scaleupTracker")
            webView?.stopLoading()
            webView?.loadHTMLString("", baseURL: nil)
        }
    }
}

// MARK: - YouTube Player State

enum YouTubePlayerState: Int {
    case unstarted = -1
    case ended = 0
    case playing = 1
    case paused = 2
    case buffering = 3
    case unknown = -999
}
