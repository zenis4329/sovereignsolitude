import SwiftUI
import CryptoKit
import AudioToolbox
import Darwin
import Foundation
import Security

// MARK: - LƯU TRỮ KEYCHAIN AN TOÀN
enum KeychainStorage {
    private static let service = Bundle.main.bundleIdentifier ?? "com.zenis.sovereignsolitude"
    
    static func save(_ value: String, forKey key: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
        
        guard !value.isEmpty else { return }
        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        SecItemAdd(attributes as CFDictionary, nil)
    }
    
    static func read(forKey key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }
    
    static func delete(forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - HỆ THỐNG BẢO MẬT & CHỐNG DEBUG
enum SecurityStatus {
    case safe
    case proxyDetected
    case crackDetected
}

struct AntiDebug {
    
    static func checkEnvironment() -> SecurityStatus {
        // 1. Kiểm tra Debugger, Jailbreak, Frida -> NO CRACK
        if isDebuggerAttached() || isJailbroken() || isFridaRunning() {
            return .crackDetected
        }
        
        // 2. Kiểm tra Proxy -> Chặn mạng
        if isProxyEnabled() {
            return .proxyDetected
        }
        
        return .safe
    }
    
    static func isProxyEnabled() -> Bool {
        guard let proxySettings = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [String: Any] else { return false }
        if let http = proxySettings["HTTPProxy"] as? String, !http.isEmpty { return true }
        if let https = proxySettings["HTTPSProxy"] as? String, !https.isEmpty { return true }
        if let socks = proxySettings["SOCKSProxy"] as? String, !socks.isEmpty { return true }
        return false
    }
    
    static func isDebuggerAttached() -> Bool {
        var info = kinfo_proc()
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        var size = MemoryLayout<kinfo_proc>.stride
        let sysctlResult = sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0)
        if sysctlResult != 0 { return false }
        return (info.kp_proc.p_flag & P_TRACED) != 0
    }
    
    static func isJailbroken() -> Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        let paths = [
            "/Applications/Cydia.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/bin/bash",
            "/usr/sbin/sshd",
            "/etc/apt",
            "/private/var/lib/apt/",
            "/usr/bin/ssh"
        ]
        for path in paths {
            if FileManager.default.fileExists(atPath: path) { return true }
        }
        let stringToWrite = "jailbreak_test"
        do {
            try stringToWrite.write(toFile: "/private/jailbreak.txt", atomically: true, encoding: .utf8)
            try FileManager.default.removeItem(atPath: "/private/jailbreak.txt")
            return true
        } catch {
            return false
        }
        #endif
    }
    
    static func isFridaRunning() -> Bool {
        let port = 27042
        let socketFD = socket(AF_INET, SOCK_STREAM, 0)
        if socketFD == -1 { return false }
        
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(port).bigEndian
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")
        
        let result = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(socketFD, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        close(socketFD)
        
        if result == 0 { return true }
        
        let fridaPaths = ["/usr/sbin/frida-server", "/usr/lib/frida/frida-agent.dylib"]
        for path in fridaPaths {
            if FileManager.default.fileExists(atPath: path) { return true }
        }
        
        return false
    }
}

// MARK: - MÀN HÌNH CHẶN BẢO MẬT
struct SecurityBlockView: View {
    let status: SecurityStatus
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 20) {
                if status == .proxyDetected {
                    Text("𝐒𝐨𝐯𝐞𝐫𝐞𝐢𝐠𝐧 𝐒𝐨𝐥𝐢𝐭𝐮𝐝𝐞 .........")
                        .font(.system(size: 26, weight: .black, design: .serif))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .shadow(color: .red.opacity(0.8), radius: 10)
                } else if status == .crackDetected {
                    Text("𝐒𝐨𝐯𝐞𝐫𝐞𝐢𝐠𝐧 𝐒𝐨𝐥𝐢𝐭𝐮𝐝𝐞 NO CRACK")
                        .font(.system(size: 26, weight: .black, design: .serif))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .shadow(color: .red.opacity(0.8), radius: 10)
                }
            }
            .padding(40)
            .background(Color(red: 0.1, green: 0.0, blue: 0.0).opacity(0.9))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.red.opacity(0.8), lineWidth: 2)
            )
            .padding(30)
        }
    }
}

// MARK: - MÃ HÓA TOKEN 30S
struct SecurityTokenGenerator {
    private static var secretSalt: String {
        let p1 = "SOLITUDE_"
        let p2 = "SECRET_SALT_"
        let p3 = "2026_!@#"
        return p1 + p2 + p3
    }
    
    static func generate30sToken(key: String, deviceId: String) -> String {
        let timeWindow = Int(Date().timeIntervalSince1970) / 30
        let rawData = "\(key):\(deviceId):\(timeWindow)"
        let symmetricKey = SymmetricKey(data: Data(secretSalt.utf8))
        let signature = HMAC<SHA256>.authenticationCode(for: Data(rawData.utf8), using: symmetricKey)
        return Data(signature).map { String(format: "%02x", $0) }.joined()
    }
}

@main
struct ThreeOneOSFiveApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var fileOperationCoordinator = FileOperationCoordinator()
    @StateObject private var gameCatalog = GameCatalogStore.shared
    @StateObject private var authManager = CustomAuthManager.shared
    
    @AppStorage(AppLanguage.storageKey) private var languageCode = AppLanguage.vietnamese.rawValue
    @AppStorage(AppThemePreferences.appearanceStorageKey) private var appearanceRaw = AppThemePreferences.defaultAppearance.rawValue
    @AppStorage(AppThemePreferences.accentStorageKey) private var accentRaw = AppThemePreferences.defaultAccent.rawValue
    
    @State private var showOnboarding = OnboardingStore.shouldShow()
    @State private var showNotice = false
    @State private var isInitialLoading = false
    @State private var protectedContentStarted = false
    @State private var noticeDismissedUntilNextEnter = false
    @State private var showAttribution = false
    @State private var isRefreshingCatalog = false
    @State private var catalogSyncTick = 0
    @Environment(\.scenePhase) private var scenePhase
    
    // TRẠNG THÁI BẢO MẬT
    @State private var securityStatus: SecurityStatus = .safe
    let securityTimer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    init() {
        URLProtocol.registerClass(SecurityURLProtocol.self)
        Self.configureTransparentContainers()
        setupLogCapture()
        log("app: Sovereign Solitude launching — iOS \(AppInfo.osVersion) (\(AppInfo.osBuild)) \(AppInfo.machineName)")
    }

    private static func configureTransparentContainers() {
        UITableView.appearance().backgroundColor = .clear
        UICollectionView.appearance().backgroundColor = .clear
        UIScrollView.appearance().backgroundColor = .clear

        let navigationAppearance = UINavigationBarAppearance()
        navigationAppearance.configureWithTransparentBackground()
        navigationAppearance.backgroundColor = .clear
        navigationAppearance.shadowColor = .clear
        UINavigationBar.appearance().standardAppearance = navigationAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navigationAppearance
        UINavigationBar.appearance().compactAppearance = navigationAppearance
        UINavigationBar.appearance().isTranslucent = true

        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithTransparentBackground()
        tabAppearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        tabAppearance.backgroundColor = UIColor.black.withAlphaComponent(0.18)
        tabAppearance.shadowColor = .clear
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().isTranslucent = true
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = tabAppearance
        }
    }

    private var language: AppLanguage { AppLanguage(rawValue: languageCode) ?? .vietnamese }
    private var preferredScheme: ColorScheme? { (AppAppearanceMode(rawValue: appearanceRaw) ?? .system).colorScheme }
    private var accentColor: Color { (AppAccentSpectrum(rawValue: accentRaw) ?? .azure).color }
    
    private var canInteractWithContent: Bool {
        authManager.isAuthorized
        && !authManager.isInteractionLocked
        && !showOnboarding
        && !showNotice
        && !gameCatalog.catalog.resolvedMaintenanceEnabled
    }

    private func refreshRemoteContent(presentNotice: Bool) {
        guard !isRefreshingCatalog else { return }
        isRefreshingCatalog = true
        Task { @MainActor in
            defer { isRefreshingCatalog = false }
            let connected = await GameCatalogStore.shared.refresh(prefetch: true)
            guard connected else { return }
            GameCatalogStore.shared.rememberCatalogItems()
            if GameCatalogStore.shared.catalog.resolvedMaintenanceEnabled {
                GameCatalogStore.shared.disableAllEnabledMods()
            }
            guard presentNotice else { return }
            evaluateNoticePresentation()
        }
    }

    private var mandatoryUpdate: MandatoryUpdateRequirement? {
        let catalog = gameCatalog.catalog
        guard catalog.forceUpdate == true else { return nil }
        let minimum = (catalog.minimumVersion ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !minimum.isEmpty, AppUpdateChecker.isNewer(minimum, than: AppUpdateChecker.currentVersion) else { return nil }
        let rawURL = (catalog.updateURL?.isEmpty == false ? catalog.updateURL : catalog.ipaDownloadURL) ?? ""
        guard let url = URL(string: rawURL), !rawURL.isEmpty else { return nil }
        let message = catalog.updateMessage?.trimmingCharacters(in: .whitespacesAndNewlines)
        return MandatoryUpdateRequirement(
            version: catalog.latestVersion?.isEmpty == false ? catalog.latestVersion! : minimum,
            message: message?.isEmpty == false ? message! : "Vui lòng cập nhật phiên bản mới nhất.",
            url: url
        )
    }

    private func startProtectedContentIfNeeded() {
        guard authManager.isAuthorized, !authManager.isInteractionLocked else { return }
        guard !protectedContentStarted else { return }
        protectedContentStarted = true
        GameCatalogStore.shared.rememberCatalogItems()
        if gameCatalog.catalog.resolvedMaintenanceEnabled {
            GameCatalogStore.shared.disableAllEnabledMods()
        }
        loadInitialContent()
        if !showOnboarding { appState.detectSupport() }
    }

    private func loadInitialContent() {
        Task {
            await MainActor.run {
                AmbientMediaController.shared.setPlaybackAllowed(false)
            }
            _ = await AmbientMediaController.shared.prepareForPlayback(
                catalog: GameCatalogStore.shared.catalog
            ) { _, _ in }
            await MainActor.run {
                if authManager.isAuthorized && !authManager.isInteractionLocked && !gameCatalog.catalog.resolvedMaintenanceEnabled {
                    AmbientMediaController.shared.setPlaybackAllowed(true)
                }
            }
            await GameCatalogStore.shared.prefetchPackages()
        }
    }

    private func evaluateNoticePresentation() {
        guard !showOnboarding, !NoticeStore.isSnoozed, !noticeDismissedUntilNextEnter else {
            showNotice = false
            return
        }
        let message = GameCatalogStore.shared.catalog.noticeMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        showNotice = !message.isEmpty
    }

    private func finishLanguageOnboarding() {
        OnboardingStore.markCompleted()
        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) { showOnboarding = false }
        appState.detectSupport()
        noticeDismissedUntilNextEnter = false
        refreshRemoteContent(presentNotice: true)
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                if securityStatus != .safe {
                    SecurityBlockView(status: securityStatus)
                        .zIndex(9999)
                } else {
                    if !authManager.isAuthorized {
                        AuthEntryView().zIndex(100)
                    } else {
                        ContentView()
                            .environmentObject(appState)
                            .environmentObject(fileOperationCoordinator)
                            .environmentObject(AmbientMediaController.shared)
                            .clearChromeForWallpaper()
                            .environment(\.appLanguage, language)
                            .environment(\.locale, language.locale)
                            .preferredColorScheme(preferredScheme)
                            .tint(accentColor)
                            .opacity(showOnboarding ? 0 : 1)
                            .disabled(!canInteractWithContent)
                            .allowsHitTesting(canInteractWithContent)
                            .onAppear { startProtectedContentIfNeeded() }

                        if authManager.isInteractionLocked {
                            Color.black.opacity(0.4)
                                .ignoresSafeArea()
                                .contentShape(Rectangle())
                                .onTapGesture { }
                                .zIndex(998)
                        }

                        if showOnboarding {
                            OnboardingView { finishLanguageOnboarding() }
                                .environment(\.appLanguage, language)
                                .environment(\.locale, language.locale)
                                .preferredColorScheme(preferredScheme)
                                .tint(accentColor)
                                .transition(.opacity.combined(with: .scale(scale: 0.98)))
                                .zIndex(2)
                        }

                        if showNotice && !showOnboarding {
                            NoticeBannerView(
                                onDismiss: {
                                    noticeDismissedUntilNextEnter = true
                                    withAnimation(.easeOut(duration: 0.2)) { showNotice = false }
                                },
                                onSnoozeOneHour: {
                                    NoticeStore.hideForOneHour()
                                    noticeDismissedUntilNextEnter = true
                                    withAnimation(.easeOut(duration: 0.2)) { showNotice = false }
                                }
                            )
                            .environment(\.appLanguage, language)
                            .environment(\.locale, language.locale)
                            .transition(.opacity)
                            .zIndex(3)
                        }

                        if !isInitialLoading && gameCatalog.catalog.resolvedMaintenanceEnabled {
                            BlockingStatusView(
                                title: gameCatalog.catalog.resolvedMaintenanceTitle,
                                message: gameCatalog.catalog.resolvedMaintenanceMessage,
                                symbol: "wrench.and.screwdriver.fill"
                            ).zIndex(11)
                        }

                        if !isInitialLoading, let update = mandatoryUpdate {
                            MandatoryUpdateView(requirement: update).zIndex(20)
                        }
                    }
                }
            }
            .preferredColorScheme(preferredScheme)
            .tint(accentColor)
            .displayIdentityAttribution(
                isPresented: $showAttribution,
                enabled: canInteractWithContent
            )
            .sheet(isPresented: $showAttribution) { DisplayAttributionSheet() }
            .onChange(of: authManager.isInteractionLocked) { locked in
                if locked {
                    showAttribution = false
                    AmbientMediaController.shared.setPlaybackAllowed(false)
                }
            }
            .onChange(of: authManager.isAuthorized) { authorized in
                if !authorized {
                    showAttribution = false
                    protectedContentStarted = false
                    catalogSyncTick = 0
                    AmbientMediaController.shared.setPlaybackAllowed(false)
                    GameCatalogStore.shared.disableAllEnabledMods()
                }
            }
            .onChange(of: gameCatalog.catalog.resolvedMaintenanceEnabled) { isMaintenance in
                if isMaintenance {
                    showAttribution = false
                    AmbientMediaController.shared.setPlaybackAllowed(false)
                    GameCatalogStore.shared.disableAllEnabledMods()
                } else if authManager.isAuthorized && !authManager.isInteractionLocked {
                    AmbientMediaController.shared.setPlaybackAllowed(true)
                }
            }
            .onChange(of: gameCatalog.catalog.noticeMessage) { _ in
                evaluateNoticePresentation()
            }
            .onReceive(securityTimer) { _ in
                // 1. Quét bảo mật mỗi 1 giây
                let newStatus = AntiDebug.checkEnvironment()
                if newStatus != securityStatus {
                    if newStatus != .safe {
                        authManager.lockInteractionsImmediately()
                        GameCatalogStore.shared.disableAllEnabledMods()
                    }
                    withAnimation {
                        securityStatus = newStatus
                    }
                }
                
                // 2. Kiểm tra hạn Key & đồng bộ bảo trì / gói Aim (chỉ chạy khi app đang mở trên màn hình)
                guard scenePhase == .active else { return }
                
                if authManager.isAuthorized {
                    authManager.performContinuousCheck()
                    
                    catalogSyncTick += 1
                    if catalogSyncTick >= 12 {
                        catalogSyncTick = 0
                        refreshRemoteContent(presentNotice: !showOnboarding)
                    }
                } else {
                    catalogSyncTick = 0
                }
            }
            .onChange(of: scenePhase) { newPhase in
                AmbientMediaController.shared.handleScenePhase(newPhase)
                if newPhase == .background || newPhase == .inactive {
                    if newPhase == .background { noticeDismissedUntilNextEnter = false }
                    return
                }
                guard newPhase == .active else { return }
                
                let currentSec = AntiDebug.checkEnvironment()
                securityStatus = currentSec
                if currentSec != .safe {
                    authManager.lockInteractionsImmediately()
                    GameCatalogStore.shared.disableAllEnabledMods()
                    return
                }
                
                guard authManager.isAuthorized else { return }
                
                authManager.verifyOnAppResume()
                
                catalogSyncTick = 0
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    refreshRemoteContent(presentNotice: !showOnboarding)
                }
                if !showOnboarding { appState.detectSupport() }
            }
        }
    }
}

// MARK: - CÁC VIEW PHỤ TRỢ

private struct BlockingStatusView: View {
    let title: String
    let message: String
    let symbol: String
    var body: some View {
        ZStack {
            AppTheme.canvas.ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: symbol).font(.system(size: 42, weight: .semibold)).foregroundStyle(AppTheme.accent)
                Text(title).font(.title2.weight(.black)).multilineTextAlignment(.center).foregroundColor(.white)
                Text(message).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }.padding(28).frame(maxWidth: 440)
        }
    }
}

private struct MandatoryUpdateRequirement {
    let version: String
    let message: String
    let url: URL
}

private struct MandatoryUpdateView: View {
    let requirement: MandatoryUpdateRequirement
    var body: some View {
        ZStack {
            AppTheme.canvas.ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "arrow.down.app.fill").font(.system(size: 48, weight: .semibold)).foregroundStyle(AppTheme.accent)
                Text("CẬP NHẬT BẮT BUỘC").font(.title2.weight(.black)).multilineTextAlignment(.center).foregroundColor(.white)
                Text("Sovereign Solitude [\(requirement.version)]").font(.headline.monospaced()).foregroundColor(.white)
                Text(requirement.message).foregroundStyle(.secondary).multilineTextAlignment(.center)
                Button("CẬP NHẬT NGAY") { UIApplication.shared.open(requirement.url) }
                    .buttonStyle(.borderedProminent).controlSize(.large).tint(AppTheme.accent)
            }.padding(28).frame(maxWidth: 440)
        }
    }
}

class AppState: ObservableObject {
    @Published var exploitStatus: ExploitStatus = .notStarted
    @Published var unsupportedMessage: String?
    @Published var kernelExploitRunning = false
    private var autoRunAttempted = false

    var kernelExploitApplicable: Bool {
        KernelExploit.isApplicable(major: AppInfo.versionTuple.major, minor: AppInfo.versionTuple.minor, patch: AppInfo.versionTuple.patch, build: AppInfo.osBuild)
    }
    var isSupported: Bool { unsupportedMessage == nil }

    func detectSupport() {
        let v = AppInfo.versionTuple
        let supported = ExploitSupportPolicy.isSupported(major: v.major, minor: v.minor, patch: v.patch, build: AppInfo.osBuild)
        unsupportedMessage = supported ? nil : "iOS \(AppInfo.osVersion) (\(AppInfo.osBuild))"
        if let unsupportedMessage { exploitStatus = .unsupported(unsupportedMessage); return }
        let applicable = KernelExploit.isApplicable(major: v.major, minor: v.minor, patch: v.patch, build: AppInfo.osBuild)
        guard applicable else { return }
        refreshKernelExploitStatus()
        maybeAutoRunKernelExploit()
    }

    private func maybeAutoRunKernelExploit() {
        guard !kernelExploitRunning, !exploitStatus.isSuccess, !exploitStatus.isFailed, !autoRunAttempted else { return }
        autoRunAttempted = true
        log("app: starting kernel exploit automatically")
        runKernelExploitIfNeeded()
    }

    private func refreshKernelExploitStatus() {
        guard !kernelExploitRunning else { return }
        if KernelExploit.requiresSandboxEscape {
            if KernelExploit.hasSandboxAccess() {
                if !exploitStatus.isSuccess { exploitStatus = .success(method: "kexploit") }
            } else if exploitStatus.isSuccess { exploitStatus = .notStarted }
        }
    }

    func runKernelExploitIfNeeded() {
        refreshKernelExploitStatus()
        guard !kernelExploitRunning, !exploitStatus.isSuccess, !exploitStatus.isFailed else { return }
        kernelExploitRunning = true
        exploitStatus = .notStarted
        DispatchQueue.global(qos: .userInitiated).async {
            let ok = KernelExploit.run()
            DispatchQueue.main.async {
                self.kernelExploitRunning = false
                if ok { self.exploitStatus = .success(method: "kexploit") }
                else { self.exploitStatus = .failed(method: "kexploit", code: -1) }
            }
        }
    }
}

// MARK: - DELEGATE SSL XÁC MINH CHỨNG CHỈ CHUẨN HỆ THỐNG
class VerifiedImageSessionDelegate: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if AntiDebug.isProxyEnabled() {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        var trustError: CFError?
        guard SecTrustEvaluateWithError(serverTrust, &trustError) else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        completionHandler(.useCredential, URLCredential(trust: serverTrust))
    }
}

// MARK: - BỘ TẢI ẢNH FULL MÀN HÌNH CHUẨN HD SẮC NÉT
struct SecureRemoteImage: View {
    var urlString: String
    let placeholder: Image
    @State private var image: UIImage?
    
    private static let imageDelegate = VerifiedImageSessionDelegate()
    private static let imageSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = 20
        return URLSession(configuration: config, delegate: imageDelegate, delegateQueue: nil)
    }()
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .transition(.opacity)
                } else {
                    placeholder
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                }
            }
            .animation(.easeInOut, value: image)
        }
        .onAppear {
            loadImage(from: urlString)
        }
        .onChange(of: urlString) { newUrl in
            loadImage(from: newUrl)
        }
    }
    
    private func loadImage(from urlString: String) {
        let cleanUrl = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanUrl.isEmpty, let url = URL(string: cleanUrl) else {
            if cleanUrl.isEmpty { DispatchQueue.main.async { self.image = nil } }
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        
        Self.imageSession.dataTask(with: request) { data, _, _ in
            if let data = data, let uiImage = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.image = uiImage
                }
            }
        }.resume()
    }
}

// MARK: - HIỆU ỨNG TUYẾT RƠI NEON TRẮNG
struct SnowParticle {
    var x: CGFloat
    var y: CGFloat
    var scale: CGFloat
    var speed: CGFloat
    var opacity: Double
}

struct SnowEffectView: View {
    @State private var particles: [SnowParticle] = []
    let timer = Timer.publish(every: 0.03, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<particles.count, id: \.self) { index in
                    Circle()
                        .fill(Color.white.opacity(particles[index].opacity))
                        .frame(width: 3.5 * particles[index].scale, height: 3.5 * particles[index].scale)
                        .position(x: particles[index].x * geo.size.width, y: particles[index].y * geo.size.height)
                        .shadow(color: .white, radius: 3)
                }
            }
            .onAppear { setupParticles() }
            .onReceive(timer) { _ in updateParticles() }
        }
        .allowsHitTesting(false)
    }

    private func setupParticles() {
        for _ in 0..<55 {
            particles.append(SnowParticle(
                x: CGFloat.random(in: 0...1),
                y: CGFloat.random(in: -0.2...1),
                scale: CGFloat.random(in: 0.6...1.4),
                speed: CGFloat.random(in: 0.002...0.005),
                opacity: Double.random(in: 0.4...0.85)
            ))
        }
    }

    private func updateParticles() {
        for i in 0..<particles.count {
            particles[i].y += particles[i].speed
            if particles[i].y > 1.1 {
                particles[i].y = -0.1
                particles[i].x = CGFloat.random(in: 0...1)
            }
        }
    }
}

// MARK: - GIAO DIỆN NHẬP KEY
struct AuthEntryView: View {
    @ObservedObject var authManager = CustomAuthManager.shared
    @State private var keyInput: String = ""
    @State private var isKeyVisible = false
    @State private var rotationAngle: Double = 0
    
    @State private var isSplashActive = true
    @State private var loadingProgress: CGFloat = 0.0
    @State private var splashTimer: Timer?
    @State private var autoLoginTriggered = false
    
    var body: some View {
        ZStack {
            SecureRemoteImage(urlString: authManager.publicBackgroundURL, placeholder: Image(systemName: "photo"))
                .ignoresSafeArea()
            
            SnowEffectView()
                .ignoresSafeArea()
            
            if isSplashActive {
                VStack(spacing: 28) {
                    ZStack {
                        Circle()
                            .stroke(
                                LinearGradient(colors: [Color(hex: "#00f2fe"), Color(hex: "#4facfe"), .white], startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 3.5
                            )
                            .frame(width: 135, height: 135)
                            .shadow(color: Color(hex: "#00f2fe"), radius: 18)
                        
                        SecureRemoteImage(urlString: authManager.publicAvatarURL, placeholder: Image(systemName: "person.crop.circle.fill"))
                            .frame(width: 124, height: 124)
                            .clipShape(Circle())
                    }
                    
                    Text(authManager.publicAppName.isEmpty ? "𝐒𝐨𝐯𝐞𝐫𝐞𝐢𝐠𝐧 𝐒𝐨𝐥𝐢𝐭𝐮𝐝𝐞" : authManager.publicAppName)
                        .font(.system(size: 30, weight: .black, design: .serif))
                        .foregroundColor(.white)
                        .shadow(color: .white.opacity(0.9), radius: 12)
                        .shadow(color: Color(hex: "#00f2fe").opacity(0.6), radius: 6)
                    
                    VStack(spacing: 12) {
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.2))
                                .frame(width: 240, height: 6.5)
                            
                            Capsule()
                                .fill(LinearGradient(colors: [Color(hex: "#00f2fe"), Color(hex: "#4facfe")], startPoint: .leading, endPoint: .trailing))
                                .frame(width: 240 * loadingProgress, height: 6.5)
                                .shadow(color: Color(hex: "#00f2fe"), radius: 8)
                        }
                        
                        Text(authManager.isLoading && loadingProgress >= 1.0 ? "Đang xác thực Key..." : "\(Int(loadingProgress * 100))%")
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .shadow(color: .white, radius: 6)
                    }
                }
                .transition(.opacity.animation(.easeInOut(duration: 0.4)))
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 22) {
                        Spacer().frame(height: 45)
                        
                        ZStack {
                            Circle()
                                .stroke(
                                    AngularGradient(
                                        gradient: Gradient(colors: [
                                            Color(hex: "#00f2fe"),
                                            Color(hex: "#4facfe"),
                                            Color(hex: "#00c6ff"),
                                            Color.white,
                                            Color(hex: "#00f2fe")
                                        ]),
                                        center: .center
                                    ),
                                    lineWidth: 4
                                )
                                .frame(width: 125, height: 125)
                                .shadow(color: Color(hex: "#00f2fe").opacity(0.95), radius: 16)
                                .shadow(color: Color(hex: "#0072ff").opacity(0.6), radius: 8)
                                .rotationEffect(.degrees(rotationAngle))
                                .animation(.linear(duration: 2.8).repeatForever(autoreverses: false), value: rotationAngle)
                                .onAppear { rotationAngle = 360 }
                            
                            SecureRemoteImage(urlString: authManager.publicAvatarURL, placeholder: Image(systemName: "person.crop.circle.fill"))
                                .frame(width: 112, height: 112)
                                .clipShape(Circle())
                        }
                        
                        VStack(spacing: 6) {
                            Text(authManager.publicAppName.isEmpty ? "𝐒𝐨𝐯𝐞𝐫𝐞𝐢𝐠𝐧 𝐒𝐨𝐥𝐢𝐭𝐮𝐝𝐞" : authManager.publicAppName)
                                .font(.system(size: 28, weight: .black, design: .serif))
                                .tracking(1.2)
                                .foregroundColor(.white)
                                .shadow(color: .white.opacity(0.9), radius: 10)
                                .shadow(color: Color(hex: "#00f2fe").opacity(0.5), radius: 5)
                            
                            HStack(spacing: 8) {
                                Rectangle().fill(Color(hex: "#00f2fe").opacity(0.7)).frame(width: 45, height: 1)
                                Image(systemName: "key.fill").font(.system(size: 11)).foregroundColor(Color(hex: "#00f2fe"))
                                Rectangle().fill(Color(hex: "#00f2fe").opacity(0.7)).frame(width: 45, height: 1)
                            }
                        }
                        
                        VStack(spacing: 16) {
                            HStack(spacing: 10) {
                                Image(systemName: "key.horizontal.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(Color(hex: "#00f2fe"))
                                    .frame(width: 44, height: 44)
                                    .background(Color.black.opacity(0.2))
                                    .cornerRadius(12)
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#00f2fe").opacity(0.5), lineWidth: 1))
                                
                                HStack {
                                    if isKeyVisible {
                                        TextField("", text: $keyInput, prompt: Text("Nhập Key...").foregroundColor(.white.opacity(0.6)))
                                            .font(.system(.body, design: .monospaced).weight(.bold))
                                            .foregroundColor(.white)
                                    } else {
                                        SecureField("", text: $keyInput, prompt: Text("Nhập Key...").foregroundColor(.white.opacity(0.6)))
                                            .font(.system(.body, design: .monospaced).weight(.bold))
                                            .foregroundColor(.white)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Color.black.opacity(0.2))
                                .cornerRadius(12)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.35), lineWidth: 1))
                                
                                Button(action: { isKeyVisible.toggle() }) {
                                    Image(systemName: isKeyVisible ? "eye.slash.fill" : "eye.fill")
                                        .foregroundColor(Color(hex: "#00f2fe"))
                                        .frame(width: 44, height: 44)
                                        .background(Color.black.opacity(0.2))
                                        .cornerRadius(12)
                                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#00f2fe").opacity(0.5), lineWidth: 1))
                                }
                            }
                            
                            Button(action: {
                                if let pasted = UIPasteboard.general.string {
                                    keyInput = pasted.trimmingCharacters(in: .whitespacesAndNewlines)
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                }
                            }) {
                                HStack {
                                    Image(systemName: "doc.on.clipboard.fill")
                                    Text("Dán Key")
                                }
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 42)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(12)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.3), lineWidth: 1))
                            }
                            
                            HStack {
                                Circle().fill(authManager.errorMessage != nil ? Color.red : Color(hex: "#00f2fe")).frame(width: 6, height: 6)
                                Text(authManager.errorMessage ?? "Trạng thái: Sẵn sàng xác thực...")
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .foregroundColor(authManager.errorMessage != nil ? Color(hex: "#ff6b6b") : .white)
                                    .shadow(color: .white.opacity(0.5), radius: 3)
                                Spacer()
                            }
                            
                            if authManager.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.2)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 52)
                                    .background(Color.black.opacity(0.3))
                                    .cornerRadius(14)
                            } else {
                                Button(action: {
                                    AudioServicesPlaySystemSound(1104)
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    authManager.authenticate(key: keyInput)
                                }) {
                                    HStack(spacing: 10) {
                                        Image(systemName: "lock.open.fill").font(.headline)
                                        Text("KÍCH HOẠT HỆ THỐNG").font(.headline.weight(.black)).tracking(1)
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 52)
                                    .background(
                                        LinearGradient(
                                            colors: [Color(hex: "#00f2fe").opacity(0.85), Color(hex: "#4facfe").opacity(0.85)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(14)
                                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.8), lineWidth: 1.2))
                                    .shadow(color: Color(hex: "#00f2fe").opacity(0.6), radius: 10, x: 0, y: 3)
                                }
                            }
                            
                            Button(action: {
                                if let url = URL(string: authManager.publicGetKeyURL), url.scheme == "http" || url.scheme == "https" {
                                    UIApplication.shared.open(url)
                                } else {
                                    authManager.errorMessage = "Link Get Key không hợp lệ!"
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "cart.fill")
                                    Text("LẤY KEY (GET KEY)").font(.headline.weight(.bold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(Color.black.opacity(0.2))
                                .cornerRadius(14)
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "#00f2fe").opacity(0.6), lineWidth: 1.2))
                            }
                        }
                        .padding(20)
                        .background(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)
                        .background(Color.black.opacity(0.08))
                        .cornerRadius(22)
                        .overlay(
                            RoundedRectangle(cornerRadius: 22)
                                .stroke(
                                    LinearGradient(
                                        colors: [Color(hex: "#00f2fe").opacity(0.8), Color.white.opacity(0.3), Color.clear],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.2
                                )
                        )
                        .padding(.horizontal, 20)
                        .shadow(color: .black.opacity(0.2), radius: 15, x: 0, y: 8)
                        
                        Spacer().frame(height: 30)
                    }
                    .frame(maxWidth: .infinity)
                }
                .transition(.opacity.animation(.easeInOut(duration: 0.4)))
            }
        }
        .onAppear {
            authManager.isInteractionLocked = false
            keyInput = authManager.savedKey
            authManager.fetchPublicConfig()
            
            if authManager.wasKickedOut || authManager.errorMessage != nil {
                isSplashActive = false
            } else {
                runSplashScreen()
            }
        }
        .onChange(of: authManager.isLoading) { loading in
            if !loading && loadingProgress >= 1.0 && !authManager.isAuthorized {
                withAnimation {
                    isSplashActive = false
                }
            }
        }
        .onDisappear {
            splashTimer?.invalidate()
            splashTimer = nil
        }
    }
    
    private func runSplashScreen() {
        splashTimer?.invalidate()
        let totalDuration = 1.2
        let steps = 100
        let timePerStep = totalDuration / Double(steps)
        
        let saved = authManager.savedKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !saved.isEmpty && !autoLoginTriggered {
            autoLoginTriggered = true
            authManager.authenticate(key: saved, isAutoLogin: true)
        }
        
        splashTimer = Timer.scheduledTimer(withTimeInterval: timePerStep, repeats: true) { timer in
            withAnimation(.linear(duration: timePerStep)) {
                loadingProgress = min(1.0, loadingProgress + 0.01)
            }
            if loadingProgress >= 1.0 {
                timer.invalidate()
                splashTimer = nil
                if !authManager.isLoading {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation {
                            isSplashActive = false
                        }
                    }
                }
            }
        }
    }
}

// MARK: - EXTENSION HỖ TRỢ MÀU HEX
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - CUSTOM AUTH MANAGER (CHỈ ĐÁ KHI HẾT KEY / BẢO TRÌ - KHÔNG ĐÁ OAN KHI THOÁT APP)
class CustomAuthManager: NSObject, ObservableObject, URLSessionDelegate {
    static let shared = CustomAuthManager()
    
    @Published var isAuthorized: Bool = false
    @Published var isInteractionLocked: Bool = false
    @Published var wasKickedOut: Bool = false
    @Published var errorMessage: String? = nil
    @Published var isLoading: Bool = false
    
    @AppStorage("saved_license_key") private var legacySavedKey: String = ""
    @AppStorage("license_expire_date") var expireDate: String = "N/A"
    @AppStorage("license_max_devices") var maxDevices: String = "1"
    
    var savedKey: String {
        get {
            if let keychainKey = KeychainStorage.read(forKey: "saved_license_key"), !keychainKey.isEmpty {
                return keychainKey
            }
            if !legacySavedKey.isEmpty {
                KeychainStorage.save(legacySavedKey, forKey: "saved_license_key")
                let migrated = legacySavedKey
                legacySavedKey = ""
                return migrated
            }
            return ""
        }
        set {
            KeychainStorage.save(newValue, forKey: "saved_license_key")
            legacySavedKey = ""
        }
    }
    
    @Published var publicAppName: String = "𝐒𝐨𝐯𝐞𝐫𝐞𝐢𝐠𝐧 𝐒𝐨𝐥𝐢𝐭𝐮𝐝𝐞"
    @Published var publicAvatarURL: String = ""
    @Published var publicBackgroundURL: String = ""
    @Published var publicGetKeyURL: String = ""
    
    private var isFetchingConfig = false
    private var isVerifyingHeartbeat = false
    private var isSyncingCatalogFromHeartbeat = false
    
    private var parsedExpirationDate: Date? = nil
    private var serverTimeOffset: TimeInterval = 0
    private var lastHeartbeatAttempt: Date = .distantPast
    private var lastSuccessfulServerCheck: Date? = nil
    private var consecutiveFailures: Int = 0
    private var monitorTimer: Timer?
    
    private let heartbeatInterval: TimeInterval = 12.0
    private let maxOfflineGracePeriod: TimeInterval = 300.0
    private let allowedHost = "zenisiosvn.io.vn"
    
    private var secretKey: String {
        let bytes: [UInt8] = [72, 111, 97, 110, 103, 113, 117, 121, 100, 122, 118, 108]
        return String(bytes: bytes, encoding: .utf8) ?? "Hoangquydzvl"
    }
    
    private var authURL: URL {
        let p1 = "https://zenisiosvn.io.vn/"
        let p2 = "sovereignsolitude/selleripa1/"
        let p3 = "ZenisAuth.php"
        return URL(string: p1 + p2 + p3)!
    }
    
    private var secureSession: URLSession!
    
    override init() {
        super.init()
        let config = URLSessionConfiguration.ephemeral
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = 15
        config.protocolClasses = [SecurityURLProtocol.self] + (config.protocolClasses ?? [])
        self.secureSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }
    
    func isProxyConfigured() -> Bool {
        return AntiDebug.isProxyEnabled()
    }
    
    // MARK: - KHÓA CHẠM & KÍCH KHỎI GIAO DIỆN TỨC THÌ
    
    func lockInteractionsImmediately() {
        if Thread.isMainThread {
            MainActor.assumeIsolated {
                self.isInteractionLocked = true
            }
        } else {
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self.isInteractionLocked = true
                }
            }
        }
    }
    
    func kickOutToLogin(reason: String) {
        let execute = {
            MainActor.assumeIsolated {
                self.isInteractionLocked = true
                self.stopContinuousMonitoring()
                GameCatalogStore.shared.disableAllEnabledMods()
                
                self.parsedExpirationDate = nil
                self.lastSuccessfulServerCheck = nil
                self.consecutiveFailures = 0
                self.wasKickedOut = true
                self.errorMessage = reason
                self.isLoading = false
                self.isAuthorized = false
                
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
        
        if Thread.isMainThread {
            execute()
        } else {
            DispatchQueue.main.async {
                execute()
            }
        }
    }
    
    // MARK: - GIÁM SÁT KEY & ĐỒNG BỘ SERVER
    
    private func startContinuousMonitoring() {
        stopContinuousMonitoring()
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.performContinuousCheck()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.monitorTimer = timer
    }
    
    private func stopContinuousMonitoring() {
        monitorTimer?.invalidate()
        monitorTimer = nil
    }
    
    func performContinuousCheck() {
        guard isAuthorized else { return }
        
        if isProxyConfigured() {
            kickOutToLogin(reason: "Phát hiện Proxy! Phiên truy cập đã bị khóa.")
            return
        }
        
        if checkLocalExpiration() {
            return
        }
        
        if Date().timeIntervalSince(lastHeartbeatAttempt) >= heartbeatInterval {
            heartbeatVerify(force: false)
        }
    }
    
    func verifyOnAppResume() {
        guard isAuthorized else { return }
        
        if isProxyConfigured() {
            kickOutToLogin(reason: "Phát hiện Proxy! Phiên truy cập đã bị khóa.")
            return
        }
        
        if checkLocalExpiration() {
            return
        }
        
        isInteractionLocked = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.heartbeatVerify(force: true)
        }
    }
    
    @discardableResult
    private func checkLocalExpiration() -> Bool {
        guard let expDate = parsedExpirationDate else { return false }
        let trustedNow = Date().addingTimeInterval(serverTimeOffset)
        if trustedNow >= expDate {
            kickOutToLogin(reason: "Key đã hết hạn! Vui lòng nhập Key mới.")
            return true
        }
        return false
    }
    
    private func heartbeatVerify(force: Bool = false) {
        if isVerifyingHeartbeat && !force { return }
        let activeKey = savedKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !activeKey.isEmpty else {
            kickOutToLogin(reason: "Không tìm thấy Key xác thực!")
            return
        }
        
        isVerifyingHeartbeat = true
        lastHeartbeatAttempt = Date()
        
        let timestamp = Int(Date().timeIntervalSince1970)
        let deviceId = AppDeviceIdentity.value
        let token30s = SecurityTokenGenerator.generate30sToken(key: activeKey, deviceId: deviceId)
        let payloadDict: [String: Any] = [
            "action": "auth",
            "key": activeKey,
            "device_id": deviceId,
            "timestamp": timestamp,
            "signature": token30s
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payloadDict),
              let jsonString = String(data: jsonData, encoding: .utf8),
              let encryptedBase64 = encryptAES(jsonString, key: secretKey) else {
            isVerifyingHeartbeat = false
            return
        }
        
        var request = URLRequest(url: authURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")
        request.setValue(token30s, forHTTPHeaderField: "X-Signature")
        
        let encodedBase64 = encryptedBase64.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
        request.httpBody = "data=\(encodedBase64)".data(using: .utf8)
        
        secureSession.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self.isVerifyingHeartbeat = false
                    guard self.isAuthorized else { return }
                    
                    if let httpResponse = response as? HTTPURLResponse {
                        self.syncServerClock(from: httpResponse, jsonDict: nil)
                    }
                    
                    if error != nil || (response as? HTTPURLResponse)?.statusCode != 200 {
                        self.consecutiveFailures += 1
                        if self.checkLocalExpiration() { return }
                        
                        if let lastSuccess = self.lastSuccessfulServerCheck,
                           Date().timeIntervalSince(lastSuccess) > self.maxOfflineGracePeriod,
                           self.consecutiveFailures >= 5 {
                            self.kickOutToLogin(reason: "Mất kết nối xác thực máy chủ quá lâu! Vui lòng kiểm tra mạng.")
                        }
                        return
                    }
                    
                    guard let httpResponse = response as? HTTPURLResponse,
                          let data = data, let responseString = String(data: data, encoding: .utf8),
                          let decryptedString = self.decryptAES(responseString, key: self.secretKey),
                          let resData = decryptedString.data(using: .utf8),
                          let resDict = try? JSONSerialization.jsonObject(with: resData) as? [String: Any] else {
                        self.consecutiveFailures += 1
                        if self.consecutiveFailures >= 5 {
                            self.kickOutToLogin(reason: "Xác thực phiên thất bại! Vui lòng đăng nhập lại.")
                        }
                        return
                    }
                    
                    self.consecutiveFailures = 0
                    self.syncServerClock(from: httpResponse, jsonDict: resDict)
                    
                    if let authInfo = resDict["auth_info"] as? [String: Any],
                       (authInfo["status"] as? String) == "success" {
                        let rawExpire = authInfo["expires_at"] as? String ?? "N/A"
                        self.expireDate = rawExpire
                        self.maxDevices = "\(authInfo["max_devices"] as? Int ?? 1)"
                        self.parsedExpirationDate = self.parseExpirationDate(from: rawExpire, authInfo: authInfo)
                        self.lastSuccessfulServerCheck = Date()
                        self.isInteractionLocked = false
                        
                        if let catalogData = try? JSONSerialization.data(withJSONObject: resDict),
                           let decodedCatalog = try? JSONDecoder().decode(GameCatalog.self, from: catalogData) {
                            GameCatalogStore.shared.catalog = decodedCatalog
                            GameCatalogStore.shared.rememberCatalogItems()
                            if decodedCatalog.resolvedMaintenanceEnabled {
                                GameCatalogStore.shared.disableAllEnabledMods()
                            }
                            if !self.isSyncingCatalogFromHeartbeat {
                                self.isSyncingCatalogFromHeartbeat = true
                                Task { @MainActor in
                                    defer { self.isSyncingCatalogFromHeartbeat = false }
                                    _ = await GameCatalogStore.shared.refresh(prefetch: true)
                                    GameCatalogStore.shared.rememberCatalogItems()
                                    if GameCatalogStore.shared.catalog.resolvedMaintenanceEnabled {
                                        GameCatalogStore.shared.disableAllEnabledMods()
                                    }
                                }
                            }
                        }
                        
                        _ = self.checkLocalExpiration()
                    } else {
                        let msg = resDict["message"] as? String ?? "Key đã hết hạn hoặc bị thu hồi!"
                        self.kickOutToLogin(reason: msg)
                    }
                }
            }
        }.resume()
    }
    
    // MARK: - API CÔNG KHAI & ĐĂNG NHẬP KEY
    
    func fetchPublicConfig() {
        guard !isFetchingConfig else { return }
        isFetchingConfig = true
        
        if isProxyConfigured() {
            isFetchingConfig = false
            return
        }
        
        let timestamp = Int(Date().timeIntervalSince1970)
        let deviceId = AppDeviceIdentity.value
        let token30s = SecurityTokenGenerator.generate30sToken(key: "public", deviceId: deviceId)
        let payloadDict: [String: Any] = [
            "action": "public",
            "key": "",
            "device_id": deviceId,
            "timestamp": timestamp,
            "signature": token30s
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payloadDict),
              let jsonString = String(data: jsonData, encoding: .utf8),
              let encryptedBase64 = encryptAES(jsonString, key: secretKey) else {
            isFetchingConfig = false
            return
        }
        
        var request = URLRequest(url: authURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")
        request.setValue(token30s, forHTTPHeaderField: "X-Signature")
        
        let encodedBase64 = encryptedBase64.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
        let bodyString = "data=\(encodedBase64)"
        request.httpBody = bodyString.data(using: .utf8)
        
        secureSession.dataTask(with: request) { [weak self] data, _, _ in
            defer { self?.isFetchingConfig = false }
            guard let data = data, let responseString = String(data: data, encoding: .utf8) else { return }
            
            if let decryptedString = self?.decryptAES(responseString, key: self?.secretKey ?? ""),
               let resData = decryptedString.data(using: .utf8),
               let resDict = try? JSONSerialization.jsonObject(with: resData) as? [String: Any] {
                
                DispatchQueue.main.async {
                    MainActor.assumeIsolated {
                        if let appName = resDict["app_name"] as? String, !appName.isEmpty {
                            self?.publicAppName = appName
                        }
                        if let avatar = resDict["avatar_url"] as? String, !avatar.isEmpty {
                            self?.publicAvatarURL = avatar
                        }
                        if let bg = resDict["background_url"] as? String, !bg.isEmpty {
                            self?.publicBackgroundURL = bg
                        }
                        if let getKey = resDict["get_key_url"] as? String, !getKey.isEmpty {
                            self?.publicGetKeyURL = getKey
                        }
                    }
                }
            }
        }.resume()
    }
    
    func authenticate(key: String, isAutoLogin: Bool = false) {
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            if !isAutoLogin {
                self.errorMessage = "Vui lòng nhập Key trước khi kích hoạt!"
            }
            return
        }
        
        if isProxyConfigured() {
            if !isAutoLogin {
                self.errorMessage = "Phát hiện Proxy. Vui lòng tắt để xác thực!"
            }
            return
        }
        
        isLoading = true
        if !isAutoLogin {
            errorMessage = nil
        }
        
        let timestamp = Int(Date().timeIntervalSince1970)
        let deviceId = AppDeviceIdentity.value
        let token30s = SecurityTokenGenerator.generate30sToken(key: trimmedKey, deviceId: deviceId)
        let payloadDict: [String: Any] = [
            "action": "auth",
            "key": trimmedKey,
            "device_id": deviceId,
            "timestamp": timestamp,
            "signature": token30s
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payloadDict),
              let jsonString = String(data: jsonData, encoding: .utf8),
              let encryptedBase64 = encryptAES(jsonString, key: secretKey) else {
            if !isAutoLogin {
                self.errorMessage = "Lỗi mã hóa dữ liệu"
            }
            self.isLoading = false
            return
        }
        
        var request = URLRequest(url: authURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")
        request.setValue(token30s, forHTTPHeaderField: "X-Signature")
        
        let encodedBase64 = encryptedBase64.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
        let bodyString = "data=\(encodedBase64)"
        request.httpBody = bodyString.data(using: .utf8)
        
        secureSession.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self.isLoading = false
                    
                    if let error = error {
                        if !isAutoLogin {
                            self.errorMessage = "Lỗi kết nối: \(error.localizedDescription)"
                        }
                        return
                    }
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        if !isAutoLogin {
                            self.errorMessage = "Phản hồi máy chủ không hợp lệ"
                        }
                        return
                    }
                    
                    if httpResponse.statusCode != 200 {
                        if !isAutoLogin {
                            self.errorMessage = "Server lỗi (HTTP \(httpResponse.statusCode))"
                        }
                        return
                    }
                    
                    guard let data = data, let responseString = String(data: data, encoding: .utf8) else {
                        if !isAutoLogin {
                            self.errorMessage = "Dữ liệu trả về rỗng"
                        }
                        return
                    }
                    
                    if let decryptedString = self.decryptAES(responseString, key: self.secretKey),
                       let resData = decryptedString.data(using: .utf8),
                       let resDict = try? JSONSerialization.jsonObject(with: resData) as? [String: Any] {
                        
                        self.syncServerClock(from: httpResponse, jsonDict: resDict)
                        
                        if let authInfo = resDict["auth_info"] as? [String: Any], (authInfo["status"] as? String) == "success" {
                            let rawExpire = authInfo["expires_at"] as? String ?? "N/A"
                            let expDate = self.parseExpirationDate(from: rawExpire, authInfo: authInfo)
                            let trustedNow = Date().addingTimeInterval(self.serverTimeOffset)
                            
                            if let expDate = expDate, trustedNow >= expDate {
                                self.errorMessage = "Key đã hết hạn!"
                                return
                            }
                            
                            self.savedKey = trimmedKey
                            self.expireDate = rawExpire
                            self.maxDevices = "\(authInfo["max_devices"] as? Int ?? 1)"
                            self.parsedExpirationDate = expDate
                            self.lastSuccessfulServerCheck = Date()
                            self.lastHeartbeatAttempt = Date()
                            self.consecutiveFailures = 0
                            self.wasKickedOut = false
                            self.isInteractionLocked = false
                            self.errorMessage = nil
                            self.isAuthorized = true
                            
                            if let catalogData = try? JSONSerialization.data(withJSONObject: resDict),
                               let decodedCatalog = try? JSONDecoder().decode(GameCatalog.self, from: catalogData) {
                                GameCatalogStore.shared.catalog = decodedCatalog
                                GameCatalogStore.shared.rememberCatalogItems()
                                if decodedCatalog.resolvedMaintenanceEnabled {
                                    GameCatalogStore.shared.disableAllEnabledMods()
                                }
                            }
                            
                            self.startContinuousMonitoring()
                        } else {
                            self.errorMessage = resDict["message"] as? String ?? "Key không hợp lệ hoặc đã hết hạn"
                        }
                    } else if !isAutoLogin {
                        self.errorMessage = "Giải mã thất bại! Dữ liệu bị can thiệp."
                    }
                }
            }
        }.resume()
    }
    
    // MARK: - ĐỒNG BỘ GIỜ SERVER & PARSE THỜI HẠN
    
    private func syncServerClock(from response: HTTPURLResponse, jsonDict: [String: Any]?) {
        if let json = jsonDict {
            if let ts = json["server_time"] as? TimeInterval, ts > 1_000_000_000 {
                serverTimeOffset = ts - Date().timeIntervalSince1970
                return
            }
            if let tsInt = json["timestamp"] as? Int, tsInt > 1_000_000_000 {
                serverTimeOffset = TimeInterval(tsInt) - Date().timeIntervalSince1970
                return
            }
        }
        
        if let dateHeader = response.value(forHTTPHeaderField: "Date") {
            let httpFormatter = DateFormatter()
            httpFormatter.locale = Locale(identifier: "en_US_POSIX")
            httpFormatter.timeZone = TimeZone(abbreviation: "GMT")
            httpFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
            if let serverDate = httpFormatter.date(from: dateHeader) {
                serverTimeOffset = serverDate.timeIntervalSince1970 - Date().timeIntervalSince1970
            }
        }
    }
    
    private func parseExpirationDate(from rawString: String, authInfo: [String: Any]) -> Date? {
        if let remaining = authInfo["remaining_seconds"] as? TimeInterval {
            return Date().addingTimeInterval(serverTimeOffset + remaining)
        }
        if let expTimestamp = authInfo["expires_timestamp"] as? TimeInterval, expTimestamp > 1_000_000_000 {
            return Date(timeIntervalSince1970: expTimestamp)
        }
        
        let trimmed = rawString.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        if trimmed.isEmpty || lower == "n/a" || lower.contains("vĩnh viễn") || lower.contains("lifetime") || lower == "never" {
            return nil
        }
        
        if let unixVal = Double(trimmed), unixVal > 1_000_000_000 {
            let seconds = unixVal > 10_000_000_000 ? unixVal / 1000.0 : unixVal
            return Date(timeIntervalSince1970: seconds)
        }
        
        let formats = [
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd'T'HH:mm:ss",
            "dd/MM/yyyy HH:mm:ss",
            "dd-MM-yyyy HH:mm:ss",
            "yyyy/MM/dd HH:mm:ss",
            "yyyy-MM-dd"
        ]
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh") ?? .current
        
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: trimmed) {
                return date
            }
        }
        
        return nil
    }
    
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if isProxyConfigured() {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              challenge.protectionSpace.host == allowedHost,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        var trustError: CFError?
        guard SecTrustEvaluateWithError(serverTrust, &trustError) else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        completionHandler(.useCredential, URLCredential(trust: serverTrust))
    }
    
    private func encryptAES(_ text: String, key: String) -> String? {
        guard let data = text.data(using: .utf8) else { return nil }
        let keyHash = SHA256.hash(data: Data(key.utf8))
        let symmetricKey = SymmetricKey(data: keyHash)
        guard let sealedBox = try? AES.GCM.seal(data, using: symmetricKey) else { return nil }
        
        var combinedData = Data()
        combinedData.append(Data(sealedBox.nonce))
        combinedData.append(sealedBox.ciphertext)
        combinedData.append(sealedBox.tag)
        return combinedData.base64EncodedString()
    }
    
    private func decryptAES(_ base64String: String, key: String) -> String? {
        let cleanedBase64 = base64String.trimmingCharacters(in: .whitespacesAndNewlines)
                                        .replacingOccurrences(of: " ", with: "+")
                                        .replacingOccurrences(of: "\r", with: "")
                                        .replacingOccurrences(of: "\n", with: "")
        guard let data = Data(base64Encoded: cleanedBase64), data.count >= 28 else { return nil }
        
        let keyHash = SHA256.hash(data: Data(key.utf8))
        let symmetricKey = SymmetricKey(data: keyHash)
        
        let nonceData = Data(data.prefix(12))
        let tagData = Data(data.suffix(16))
        let cipherData = Data(data.dropFirst(12).dropLast(16))
        
        guard let nonce = try? AES.GCM.Nonce(data: nonceData),
              let sealedBox = try? AES.GCM.SealedBox(nonce: nonce, ciphertext: cipherData, tag: tagData),
              let decryptedData = try? AES.GCM.open(sealedBox, using: symmetricKey) else {
            return nil
        }
        
        return String(data: decryptedData, encoding: .utf8)
    }
}

// MARK: - LỚP KHIÊN BẢO MẬT TOÀN CỤC
class SecureNetworkManager: NSObject, URLSessionDelegate {
    static let shared = SecureNetworkManager()
    
    func isProxyEnabled() -> Bool {
        return AntiDebug.isProxyEnabled()
    }
    
    func createSecureSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        config.timeoutIntervalForRequest = 30
        config.protocolClasses = [SecurityURLProtocol.self] + (config.protocolClasses ?? [])
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }
    
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if isProxyEnabled() {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        var trustError: CFError?
        guard SecTrustEvaluateWithError(serverTrust, &trustError) else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        completionHandler(.useCredential, URLCredential(trust: serverTrust))
    }
}

class SecurityURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool {
        return SecureNetworkManager.shared.isProxyEnabled()
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { return request }
    
    override func startLoading() {
        let error = NSError(domain: "Security", code: -999, userInfo: [NSLocalizedDescriptionKey: "Blocked by Security"])
        client?.urlProtocol(self, didFailWithError: error)
    }
    
    override func stopLoading() {}
}
