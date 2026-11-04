import AVFoundation
import Combine
import Foundation
import ImageIO
import MediaPlayer
import SwiftUI
import UIKit

// MARK: - Transparent UIKit hosts (keeps remote wallpaper visible)

/// Clears opaque UIKit hosting backgrounds so remote wallpaper is visible under SwiftUI.
struct ClearHostingBackground: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        view.isOpaque = false
        view.backgroundColor = .clear
        DispatchQueue.main.async {
            var node: UIView? = view.superview
            while let current = node {
                if current is UIWindow { break }
                current.backgroundColor = .clear
                current.isOpaque = false
                node = current.superview
            }
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        uiView.backgroundColor = .clear
        uiView.isOpaque = false
    }
}

extension View {
    /// Makes NavigationStack / TabView hosts transparent so App-level wallpaper shows.
    func clearChromeForWallpaper() -> some View {
        self
            .background(ClearHostingBackground())
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarBackground(.hidden, for: .tabBar)
    }
}

/// Plays remote ambient music and drives full-app image/video wallpaper from website config.
@MainActor
final class AmbientMediaController: ObservableObject {
    static let shared = AmbientMediaController()

    static let userMusicEnabledKey = "ambient.music.userEnabled"

    @Published private(set) var backgroundType: String = "none"
    @Published private(set) var backgroundImageURL: URL?
    @Published private(set) var backgroundVideoURL: URL?
    @Published private(set) var backgroundContentMode: String = "cover"
    @Published private(set) var backgroundImage: UIImage?
    @Published private(set) var backgroundPlayer: AVQueuePlayer?
    @Published private(set) var isMusicPlaying = false
    @Published private(set) var mediaRevision: UInt = 0
    @Published var lastError: String?

    private var musicPlayer: AVPlayer?
    private var endObserver: NSObjectProtocol?
    private var catalogCancellable: AnyCancellable?
    private var lastAudioURL: URL?
    private var lastVideoURL: URL?
    private var preparedVideoSourceURL: URL?
    private var preparedVideoLocalURL: URL?
    private var lastLoadedImageURL: URL?
    private var imageLoadTask: Task<Void, Never>?
    private var videoLooper: AVPlayerLooper?
    private var videoStallObserver: NSObjectProtocol?
    private lazy var nowPlayingArtworkImage: UIImage? = Self.loadApplicationIcon()

    private var userEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: Self.userMusicEnabledKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: Self.userMusicEnabledKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: Self.userMusicEnabledKey) }
    }

    private init() {
        configureAudioSession()
        configureRemoteCommands()
        catalogCancellable = GameCatalogStore.shared.$catalog
            .receive(on: RunLoop.main)
            .sink { [weak self] catalog in
                self?.apply(catalog: catalog)
            }
        apply(catalog: GameCatalogStore.shared.catalog)
    }

    private var playbackAllowed = false
    private var backgroundVideoProvidesAudio = false

    /// Keeps every remote video/audio player stopped until the real startup work
    /// reaches 100% and the loading overlay has been removed.
    func setPlaybackAllowed(_ allowed: Bool) {
        guard playbackAllowed != allowed else { return }
        playbackAllowed = allowed
        if allowed {
            apply(catalog: GameCatalogStore.shared.catalog)
        } else {
            imageLoadTask?.cancel()
            backgroundVideoProvidesAudio = false
            stopBackgroundVideo()
            stopMusic(clearURL: true)
        }
    }

    var isUserMusicEnabled: Bool {
        get { userEnabled }
        set {
            userEnabled = newValue
            apply(catalog: GameCatalogStore.shared.catalog)
        }
    }

    /// True when admin chose image/video wallpaper (even before assets finish loading).
    var hasRemoteWallpaper: Bool {
        backgroundType == "image" || backgroundType == "video"
    }

    func apply(catalog: GameCatalog) {
        let nextType = catalog.resolvedBackgroundType
        let nextImage = Self.makeURL(catalog.backgroundImageURL, relativeToCatalog: true)
        let nextVideo = Self.makeURL(catalog.backgroundVideoURL, relativeToCatalog: true)
        let nextContentMode = catalog.resolvedBackgroundContentMode

        let typeChanged = backgroundType != nextType
        let imageChanged = backgroundImageURL != nextImage
        let videoChanged = backgroundVideoURL != nextVideo
        let contentModeChanged = backgroundContentMode != nextContentMode

        backgroundType = nextType
        backgroundImageURL = nextImage
        backgroundVideoURL = nextVideo
        backgroundContentMode = nextContentMode

        if typeChanged || imageChanged || videoChanged || contentModeChanged {
            mediaRevision &+= 1
        }

        guard playbackAllowed else {
            imageLoadTask?.cancel()
            stopBackgroundVideo()
            stopMusic(clearURL: true)
            return
        }

        if nextType != "image" || imageChanged {
            if nextType != "image" {
                backgroundImage = nil
                lastLoadedImageURL = nil
            }
        }

        if nextType == "image" {
            stopBackgroundVideo()
            if imageChanged || backgroundImage == nil {
                imageLoadTask?.cancel()
                imageLoadTask = Task { await loadBackgroundImage(force: imageChanged) }
            }
        } else if nextType == "video" {
            imageLoadTask?.cancel()
            let playbackURL = preparedVideoSourceURL == nextVideo ? preparedVideoLocalURL : nextVideo
            configureBackgroundVideo(url: playbackURL, force: videoChanged || typeChanged)
        } else {
            imageLoadTask?.cancel()
            backgroundImage = nil
            lastLoadedImageURL = nil
            stopBackgroundVideo()
        }

        // Ambient music (separate from muted wallpaper video).
        let serverWantsMusic = catalog.resolvedMusicEnabled
        let audioURL = Self.makeURL(catalog.resolvedAmbientAudioURLString, relativeToCatalog: true)
        let videoProvidesAudio = nextType == "video"
            && audioURL != nil
            && audioURL == nextVideo
        backgroundVideoProvidesAudio = serverWantsMusic && userEnabled && videoProvidesAudio

        backgroundPlayer?.isMuted = !(serverWantsMusic && userEnabled && videoProvidesAudio)

        guard serverWantsMusic, userEnabled, let audioURL else {
            stopMusic(clearURL: true)
            // If music comes from wallpaper video itself, mark playing when video is up.
            if serverWantsMusic, userEnabled, videoProvidesAudio, backgroundPlayer != nil {
                isMusicPlaying = true
            }
            return
        }

        // When audio is the wallpaper video track, don't start a second player.
        if videoProvidesAudio {
            stopMusic(clearURL: true)
            backgroundPlayer?.play()
            isMusicPlaying = backgroundPlayer != nil
            publishNowPlaying(for: backgroundPlayer, source: "Nhạc từ video nền")
            return
        }

        if lastAudioURL == audioURL, musicPlayer != nil {
            if musicPlayer?.timeControlStatus != .playing {
                musicPlayer?.play()
                isMusicPlaying = true
            }
            return
        }
        startMusic(url: audioURL)
    }

    func handleScenePhase(_ phase: ScenePhase) {
        guard playbackAllowed else { return }
        switch phase {
        case .active:
            apply(catalog: GameCatalogStore.shared.catalog)
            backgroundPlayer?.play()
            if let musicPlayer, musicPlayer.timeControlStatus != .playing, lastAudioURL != nil {
                musicPlayer.play()
                isMusicPlaying = true
                publishNowPlaying(for: musicPlayer, source: "Nhạc nền")
            }
        case .inactive, .background:
            // A wallpaper video must never keep rendering or playing its audio
            // after the app leaves the foreground. A separate audio track uses
            // musicPlayer and is intentionally allowed to continue in background.
            backgroundPlayer?.pause()
            if backgroundVideoProvidesAudio {
                isMusicPlaying = false
                updateNowPlayingPlaybackState(player: backgroundPlayer)
            }
        @unknown default:
            break
        }
    }

    /// Prefetch wallpaper image + prime video asset after catalog refresh (called from App).
    func prepareCurrentMedia() async {
        guard playbackAllowed else { return }
        await loadBackgroundImage(force: false)
        if let item = backgroundPlayer?.currentItem {
            _ = try? await item.asset.load(.isPlayable)
            backgroundPlayer?.play()
        }
        if let musicPlayer, lastAudioURL != nil, musicPlayer.timeControlStatus != .playing {
            musicPlayer.play()
            isMusicPlaying = true
        }
    }

    /// Downloads all selected media while playback remains locked. The loading
    /// screen reaches 100% only after this finishes.
    func prepareForPlayback(
        catalog: GameCatalog,
        progress: (Double, String) -> Void
    ) async -> Bool {
        apply(catalog: catalog)
        if backgroundType == "image", backgroundImageURL != nil {
            progress(0.82, "Đang tải ảnh nền")
            guard await loadBackgroundImage(force: false) else { return false }
        }
        progress(0.90, "Đang tải video nền")
        guard await prepareBackgroundVideoFile() else { return false }
        progress(0.98, "Đang hoàn tất media")
        return true
    }

    func stopMusic(clearURL: Bool = false) {
        musicPlayer?.pause()
        musicPlayer = nil
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        isMusicPlaying = false
        if clearURL { lastAudioURL = nil }
        if !backgroundVideoProvidesAudio {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            MPNowPlayingInfoCenter.default().playbackState = .stopped
        }
    }

    // MARK: - Private

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true, options: [])
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func startMusic(url: URL) {
        stopMusic(clearURL: false)
        lastAudioURL = url
        let item = AVPlayerItem(url: url)
        let p = AVPlayer(playerItem: item)
        p.actionAtItemEnd = .none
        p.isMuted = false
        p.volume = 0.85
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak p] _ in
            p?.seek(to: .zero)
            p?.play()
        }
        musicPlayer = p
        p.play()
        isMusicPlaying = true
        publishNowPlaying(for: p, source: "Nhạc nền")
    }

    private func configureRemoteCommands() {
        let commands = MPRemoteCommandCenter.shared()
        commands.playCommand.isEnabled = true
        commands.pauseCommand.isEnabled = true
        commands.togglePlayPauseCommand.isEnabled = true
        commands.nextTrackCommand.isEnabled = false
        commands.previousTrackCommand.isEnabled = false

        commands.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.resumeFromRemoteControl() }
            return .success
        }
        commands.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.pauseFromRemoteControl() }
            return .success
        }
        commands.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.isMusicPlaying ? self.pauseFromRemoteControl() : self.resumeFromRemoteControl()
            }
            return .success
        }
    }

    private func resumeFromRemoteControl() {
        guard playbackAllowed,
              GameCatalogStore.shared.catalog.resolvedMusicEnabled,
              userEnabled else { return }
        if backgroundVideoProvidesAudio {
            backgroundPlayer?.play()
            isMusicPlaying = backgroundPlayer != nil
            publishNowPlaying(for: backgroundPlayer, source: "Nhạc từ video nền")
        } else {
            musicPlayer?.play()
            isMusicPlaying = musicPlayer != nil
            publishNowPlaying(for: musicPlayer, source: "Nhạc nền")
        }
    }

    private func pauseFromRemoteControl() {
        if backgroundVideoProvidesAudio {
            backgroundPlayer?.pause()
            updateNowPlayingPlaybackState(player: backgroundPlayer)
        } else {
            musicPlayer?.pause()
            updateNowPlayingPlaybackState(player: musicPlayer)
        }
        isMusicPlaying = false
    }

    private func publishNowPlaying(for player: AVPlayer?, source: String) {
        guard let player else { return }
        let catalog = GameCatalogStore.shared.catalog
        let title = catalog.brandTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        let elapsed = player.currentTime().seconds
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: title?.isEmpty == false ? title! : "HMT IPA PRX",
            MPMediaItemPropertyArtist: source,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: max(elapsed.isFinite ? elapsed : 0, 0),
            MPNowPlayingInfoPropertyPlaybackRate: player.timeControlStatus == .playing ? 1.0 : 0.0
        ]
        let duration = player.currentItem?.duration.seconds ?? 0
        if duration.isFinite, duration > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }
        if let image = nowPlayingArtworkImage {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        MPNowPlayingInfoCenter.default().playbackState = player.timeControlStatus == .playing ? .playing : .paused
    }

    private func updateNowPlayingPlaybackState(player: AVPlayer?) {
        guard let player, var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        let elapsed = player.currentTime().seconds
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = max(elapsed.isFinite ? elapsed : 0, 0)
        info[MPNowPlayingInfoPropertyPlaybackRate] = player.timeControlStatus == .playing ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        MPNowPlayingInfoCenter.default().playbackState = player.timeControlStatus == .playing ? .playing : .paused
    }

    @discardableResult
    private func loadBackgroundImage(force: Bool) async -> Bool {
        guard let url = backgroundImageURL else {
            backgroundImage = nil
            lastLoadedImageURL = nil
            return true
        }
        if !force, lastLoadedImageURL == url, backgroundImage != nil { return true }

        var request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)
        request.setValue("image/*,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if Task.isCancelled { return false }
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                lastError = "Ảnh nền HTTP \(http.statusCode)"
                return false
            }
            let screenScale = UIScreen.main.scale
            let screenEdge = max(UIScreen.main.bounds.width, UIScreen.main.bounds.height) * screenScale
            let maxPixelSize = min(max(screenEdge, 1280), 2560)
            let decoded = await Task.detached(priority: .userInitiated) {
                Self.downsampledImage(data: data, maxPixelSize: maxPixelSize)
            }.value
            guard let decoded else {
                lastError = "Không decode được ảnh nền (\(data.count) bytes)"
                return false
            }
            backgroundImage = decoded
            lastLoadedImageURL = url
            lastError = nil
            mediaRevision &+= 1
            return true
        } catch {
            if Task.isCancelled { return false }
            lastError = error.localizedDescription
            return false
        }
    }

    nonisolated private static func downsampledImage(data: Data, maxPixelSize: CGFloat) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return UIImage(data: data)
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return UIImage(data: data)
        }
        return UIImage(cgImage: cgImage)
    }

    private static func loadApplicationIcon() -> UIImage? {
        let candidates = ["AppIcon", "AppIcon-1024", "AppIcon60x60", "AppIcon76x76"]
        for name in candidates {
            if let image = UIImage(named: name) { return image }
        }
        guard let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
              let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
              let files = primary["CFBundleIconFiles"] as? [String]
        else { return nil }
        for name in files.reversed() {
            if let image = UIImage(named: name) { return image }
        }
        return nil
    }

    private func prepareBackgroundVideoFile() async -> Bool {
        guard let sourceURL = backgroundVideoURL, backgroundType == "video" else {
            preparedVideoSourceURL = nil
            preparedVideoLocalURL = nil
            return true
        }
        if preparedVideoSourceURL == sourceURL,
           let localURL = preparedVideoLocalURL,
           FileManager.default.fileExists(atPath: localURL.path) {
            return true
        }
        do {
            let folder = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("AmbientMedia", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let ext = sourceURL.pathExtension.isEmpty ? "mp4" : sourceURL.pathExtension
            let destination = folder.appendingPathComponent(
                "background-\(Self.stableHash(sourceURL.absoluteString)).\(ext)"
            )
            if !FileManager.default.fileExists(atPath: destination.path) {
                var request = URLRequest(url: sourceURL, cachePolicy: .reloadRevalidatingCacheData)
                request.setValue("video/*,*/*;q=0.8", forHTTPHeaderField: "Accept")
                let (temporaryURL, response) = try await URLSession.shared.download(for: request)
                if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                    throw URLError(.badServerResponse)
                }
                try FileManager.default.moveItem(at: temporaryURL, to: destination)
            }
            preparedVideoSourceURL = sourceURL
            preparedVideoLocalURL = destination
            return true
        } catch {
            preparedVideoSourceURL = nil
            preparedVideoLocalURL = nil
            lastError = error.localizedDescription
            return false
        }
    }

    nonisolated private static func stableHash(_ value: String) -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return String(hash, radix: 16)
    }

    private func configureBackgroundVideo(url: URL?, force: Bool) {
        guard let url else {
            stopBackgroundVideo()
            return
        }
        if !force, lastVideoURL == url, backgroundPlayer != nil {
            backgroundPlayer?.play()
            return
        }

        stopBackgroundVideo()
        lastVideoURL = url

        let item = AVPlayerItem(url: url)
        // The startup flow downloads remote wallpaper videos into the local
        // cache first. A short forward buffer is still useful if this method is
        // ever called with a remote URL while the cache is being prepared.
        item.preferredForwardBufferDuration = 5
        let queue = AVQueuePlayer()
        queue.isMuted = true
        queue.actionAtItemEnd = .none
        queue.automaticallyWaitsToMinimizeStalling = true
        videoLooper = AVPlayerLooper(player: queue, templateItem: item)
        videoStallObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemPlaybackStalled,
            object: nil,
            queue: .main
        ) { [weak queue] notification in
            guard let queue,
                  notification.object as? AVPlayerItem === queue.currentItem else { return }
            // AVPlayer occasionally remains in .waiting after an interruption
            // or decoder hiccup. Calling play again is idempotent and lets it
            // resume as soon as enough data is available.
            queue.play()
        }
        backgroundPlayer = queue
        mediaRevision &+= 1
        queue.play()
    }

    private func stopBackgroundVideo() {
        backgroundPlayer?.pause()
        if let videoStallObserver {
            NotificationCenter.default.removeObserver(videoStallObserver)
            self.videoStallObserver = nil
        }
        backgroundPlayer = nil
        videoLooper = nil
        lastVideoURL = nil
    }

    /// Resolve absolute or site-relative media URLs against the protected catalog base.
    static func makeURL(_ raw: String?, relativeToCatalog: Bool = false) -> URL? {
        var s = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !s.isEmpty else { return nil }

        // Protocol-relative //cdn.example/a.jpg
        if s.hasPrefix("//") {
            s = "https:" + s
        }

        if let absolute = URL(string: s), let scheme = absolute.scheme?.lowercased(),
           scheme == "http" || scheme == "https" {
            return absolute
        }

        // Relative path: /APEX_IPA/uploads/x.jpg or uploads/x.jpg
        guard relativeToCatalog else { return nil }
        guard let catalog = catalogBaseURL() else { return nil }
        return URL(string: s, relativeTo: catalog)?.absoluteURL
    }

    private static func catalogBaseURL() -> URL? {
        guard let catalogURL = ProtectedConfiguration.catalogURL else { return nil }
        // Strip filename (config.php) → directory of the site endpoint.
        return catalogURL.deletingLastPathComponent()
    }
}

// MARK: - Full-app remote background

struct RemoteAppBackground: View {
    @ObservedObject private var media = AmbientMediaController.shared

    var body: some View {
        ZStack {
            // Only show solid canvas when there is NO remote wallpaper.
            // When wallpaper is set, keep a very dark fallback so letterboxing isn't pure black flash,
            // but never cover a successfully loaded image/video.
            if !media.hasRemoteWallpaper {
                AppTheme.canvas.ignoresSafeArea()
            } else {
                AppTheme.canvas.ignoresSafeArea()
            }
            // Force UIKit hosts behind this layer to stay transparent.
            ClearHostingBackground()
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)

            switch media.backgroundType {
            case "image":
                if let image = media.backgroundImage {
                    WallpaperImageLayer(image: image, contentMode: media.backgroundContentMode)
                        .id("bg-img-\(media.mediaRevision)")
                } else if let url = media.backgroundImageURL {
                    // View-owned fallback prevents a transient controller load
                    // failure from leaving the entire app on its black canvas.
                    RemoteBackgroundImage(url: url, contentMode: media.backgroundContentMode)
                }

            case "video":
                if let player = media.backgroundPlayer {
                    LoopingBackgroundVideo(player: player, contentMode: media.backgroundContentMode)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                        .ignoresSafeArea()
                } else if media.backgroundVideoURL != nil {
                    // Video mode is strict: an image URL may remain saved in
                    // admin, but it is never rendered as the active wallpaper.
                    ProgressView().tint(.white.opacity(0.7))
                }

            default:
                EmptyView()
            }

            // Soft scrim so text/cards stay readable — keep light so wallpaper still shows.
            if media.hasRemoteWallpaper {
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.28),
                        Color.black.opacity(0.12),
                        Color.black.opacity(0.32)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

private struct WallpaperImageLayer: View {
    let image: UIImage
    let contentMode: String

    var body: some View {
        ZStack {
            if contentMode == "fit" {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .blur(radius: 24)
                    .scaleEffect(1.08)
            }
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: contentMode == "fit" ? .fit : .fill)
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        .clipped()
        .ignoresSafeArea()
    }
}

private struct RemoteBackgroundImage: View {
    let url: URL
    let contentMode: String
    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        Group {
            if let image {
                WallpaperImageLayer(image: image, contentMode: contentMode)
            } else if failed {
                Color.clear
            } else {
                Color.clear
                    .overlay(ProgressView().tint(.white.opacity(0.7)))
            }
        }
        .task(id: url.absoluteString) {
            await load()
        }
    }

    private func load() async {
        failed = false
        image = nil
        var request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 45)
        request.setValue("image/*,*/*;q=0.8", forHTTPHeaderField: "Accept")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                failed = true
                return
            }
            guard let decoded = UIImage(data: data) else {
                failed = true
                return
            }
            image = decoded
        } catch {
            failed = true
        }
    }
}

/// Shared AVPlayer wallpaper (muted loop).
struct LoopingBackgroundVideo: UIViewRepresentable {
    let player: AVPlayer
    let contentMode: String

    func makeUIView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        view.configure(player: player, contentMode: contentMode)
        return view
    }

    func updateUIView(_ uiView: PlayerContainerView, context: Context) {
        uiView.configure(player: player, contentMode: contentMode)
    }

    final class PlayerContainerView: UIView {
        private let playerLayer = AVPlayerLayer()
        private weak var player: AVPlayer?

        override init(frame: CGRect) {
            super.init(frame: frame)
            isOpaque = false
            // Stay transparent while the first decoded frame is becoming
            // available so layer recreation can never flash an opaque color.
            backgroundColor = .clear
            isUserInteractionEnabled = false
            playerLayer.videoGravity = .resizeAspectFill
            layer.addSublayer(playerLayer)
        }

        required init?(coder: NSCoder) { fatalError("init(coder:)") }

        override func layoutSubviews() {
            super.layoutSubviews()
            playerLayer.frame = bounds
        }

        func configure(player: AVPlayer, contentMode: String) {
            playerLayer.videoGravity = contentMode == "fit" ? .resizeAspect : .resizeAspectFill
            if self.player === player {
                return
            }
            self.player = player
            playerLayer.player = player
        }
    }
}
