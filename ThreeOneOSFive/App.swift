import SwiftUI
import UIKit
import CryptoKit
import AudioToolbox

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
    
    @State private var initialLoadingProgress = 0.0
    @State private var initialLoadingMessage = ""
    @State private var protectedContentStarted = false
    
    @State private var noticeDismissedUntilNextEnter = false
    @State private var showAttribution = false
    @Environment(\.scenePhase) private var scenePhase

    init() {
        URLProtocol.registerClass(SecurityURLProtocol.self)
        Self.configureTransparentContainers()
        setupLogCapture()
        log("app: HNH x IPA launching — iOS \(AppInfo.osVersion) (\(AppInfo.osBuild)) \(AppInfo.machineName)")
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

    private func refreshRemoteContent(presentNotice: Bool) {
        Task {
            let connected = await GameCatalogStore.shared.refresh(prefetch: true)
            guard connected else { return }
            guard presentNotice else { return }
            await MainActor.run { evaluateNoticePresentation() }
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
        guard !protectedContentStarted else { return }
        protectedContentStarted = true
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
                AmbientMediaController.shared.setPlaybackAllowed(true)
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
                        .allowsHitTesting(!showOnboarding && !showNotice && !gameCatalog.catalog.resolvedMaintenanceEnabled)
                        .onAppear { startProtectedContentIfNeeded() }

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
            .preferredColorScheme(preferredScheme)
            .tint(accentColor)
            .displayIdentityAttribution(isPresented: $showAttribution, enabled: authManager.isAuthorized && !showOnboarding && !showNotice)
            .sheet(isPresented: $showAttribution) { DisplayAttributionSheet() }
            .onChange(of: scenePhase) { newPhase in
                AmbientMediaController.shared.handleScenePhase(newPhase)
                if newPhase == .background || newPhase == .inactive {
                    if newPhase == .background { noticeDismissedUntilNextEnter = false }
                    return
                }
                guard newPhase == .active else { return }
                guard authManager.isAuthorized else { return }
                refreshRemoteContent(presentNotice: !showOnboarding)
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
                Text(title).font(.title2.weight(.black)).multilineTextAlignment(.center)
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
                Text("CẬP NHẬT BẮT BUỘC").font(.title2.weight(.black)).multilineTextAlignment(.center)
                Text("HNH x IPA [\(requirement.version)]").font(.headline.monospaced())
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

// MARK: - BỘ TẢI ẢNH BẢO MẬT (CHẶN PROXYMAN)
struct SecureRemoteImage: View {
    let urlString: String
    let placeholder: Image
    @State private var image: UIImage?
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            if let image = image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                placeholder.resizable().scaledToFit()
            }
        }
        .onAppear {
            loadImage()
        }
        .onChange(of: urlString) { _ in
            loadImage()
        }
    }
    
    private func loadImage() {
        if SecureNetworkManager.shared.isProxyEnabled() {
            isLoading = false
            return
        }
        
        guard let url = URL(string: urlString), !urlString.isEmpty else { isLoading = false; return }
        
        let session = SecureNetworkManager.shared.createSecureSession()
        session.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                if let data = data, let uiImage = UIImage(data: data) {
                    self.image = uiImage
                }
            }
        }.resume()
    }
}

// MARK: - GIAO DIỆN NHẬP KEY (ĐỌC TỪ CONFIG)
struct AuthEntryView: View {
    @ObservedObject var authManager = CustomAuthManager.shared
    @State private var keyInput: String = ""
    @State private var isKeyVisible = false
    @State private var rotationAngle: Double = 0
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // HÌNH NỀN (Đọc từ config)
                SecureRemoteImage(urlString: authManager.publicBackgroundURL, placeholder: Image(systemName: "photo"))
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .overlay(Color.black.opacity(0.6))
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 24) {
                        // --- AVATAR (Đọc từ config) ---
                        ZStack {
                            Circle()
                                .stroke(
                                    AngularGradient(gradient: Gradient(colors: [.cyan, .blue, .purple, .cyan]), center: .center),
                                    lineWidth: 3
                                )
                                .frame(width: 120, height: 120)
                                .shadow(color: .cyan.opacity(0.8), radius: 10)
                                .rotationEffect(.degrees(rotationAngle))
                                .animation(.linear(duration: 4).repeatForever(autoreverses: false), value: rotationAngle)
                                .onAppear { rotationAngle = 360 }
                            
                            SecureRemoteImage(urlString: authManager.publicAvatarURL, placeholder: Image(systemName: "person.crop.circle.fill"))
                                .frame(width: 110, height: 110)
                                .clipShape(Circle())
                        }
                        
                        // --- TÊN APP (Đọc từ config) ---
                        VStack(spacing: 8) {
                            Text(authManager.publicAppName)
                                .font(.system(size: 28, weight: .black, design: .monospaced))
                                .tracking(4)
                                .foregroundColor(.cyan)
                                .shadow(color: .cyan.opacity(0.8), radius: 10, x: 0, y: 0)
                                .multilineTextAlignment(.center)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                            
                            HStack(spacing: 8) {
                                Rectangle().fill(Color.cyan.opacity(0.5)).frame(width: 40, height: 1)
                                Image(systemName: "key.fill").font(.system(size: 10)).foregroundColor(.cyan)
                                Rectangle().fill(Color.cyan.opacity(0.5)).frame(width: 40, height: 1)
                            }
                        }
                        
                        // --- KHUNG NHẬP KEY ---
                        VStack(spacing: 16) {
                            // Ô Nhập Key
                            HStack(spacing: 10) {
                                // Icon Ổ khóa
                                Image(systemName: "key.horizontal.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.cyan)
                                    .frame(width: 44, height: 44)
                                    .background(Color.black.opacity(0.6))
                                    .cornerRadius(10)
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.cyan.opacity(0.5), lineWidth: 1))
                                
                                // Khung TextField
                                HStack {
                                    if isKeyVisible {
                                        TextField("Nhập Key...", text: $keyInput)
                                            .font(.system(.body, design: .monospaced).weight(.bold))
                                            .foregroundColor(.white)
                                    } else {
                                        SecureField("Nhập Key...", text: $keyInput)
                                            .font(.system(.body, design: .monospaced).weight(.bold))
                                            .foregroundColor(.white)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(10)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.cyan.opacity(0.5), lineWidth: 1))
                                .layoutPriority(1) // ÉP KHUNG KHÔNG ĐƯỢC PHÌNH TO
                                
                                // Nút con mắt
                                Button(action: { isKeyVisible.toggle() }) {
                                    Image(systemName: isKeyVisible ? "eye.slash.fill" : "eye.fill")
                                        .foregroundColor(.cyan)
                                        .frame(width: 44, height: 44)
                                        .background(Color.black.opacity(0.6))
                                        .cornerRadius(10)
                                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.cyan.opacity(0.5), lineWidth: 1))
                                }
                            }
                            
                            // Nút Dán
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
                                .foregroundColor(.cyan)
                                .frame(maxWidth: .infinity)
                                .frame(height: 40)
                                .background(Color.cyan.opacity(0.1))
                                .cornerRadius(10)
                            }
                            
                            // --- TRẠNG THÁI ---
                            HStack {
                                Circle().fill(authManager.errorMessage != nil ? Color.red : Color.cyan).frame(width: 6, height: 6)
                                Text(authManager.errorMessage ?? "Trạng thái: Chờ xác thực mã...")
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .foregroundColor(authManager.errorMessage != nil ? .red : .gray)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                Spacer()
                            }
                            
                            // --- NÚT KÍCH HOẠT ---
                            if authManager.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                    .scaleEffect(1.5)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 56)
                                    .background(Color.cyan)
                                    .cornerRadius(15)
                            } else {
                                Button(action: {
                                    AudioServicesPlaySystemSound(1104)
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    authManager.authenticate(key: keyInput)
                                }) {
                                    HStack(spacing: 10) {
                                        Image(systemName: "lock.open.fill")
                                            .font(.headline)
                                        Text("KÍCH HOẠT HỆ THỐNG")
                                            .font(.headline.weight(.black))
                                            .tracking(1)
                                    }
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 56)
                                    .background(Color.cyan)
                                    .cornerRadius(15)
                                    .shadow(color: .cyan.opacity(0.6), radius: 15, x: 0, y: 0)
                                }
                            }
                            
                            // --- NÚT LẤY KEY (GET KEY - Đọc từ config) ---
                            Button(action: {
                                if let url = URL(string: authManager.publicGetKeyURL) {
                                    UIApplication.shared.open(url)
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "cart.fill")
                                    Text("LẤY KEY (GET KEY)")
                                        .font(.headline.weight(.bold))
                                }
                                .foregroundColor(.cyan)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color.black.opacity(0.4))
                                .cornerRadius(15)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 15)
                                        .stroke(Color.cyan.opacity(0.6), lineWidth: 1.5)
                                )
                            }
                        }
                        .padding(20)
                        .background(RoundedRectangle(cornerRadius: 20).fill(Color(red: 0.05, green: 0.05, blue: 0.1).opacity(0.85)))
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(LinearGradient(colors: [.cyan.opacity(0.8), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5))
                        .padding(.horizontal, 20)
                        .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
                        
                        Spacer().frame(height: 40)
                    }
                    .frame(width: geo.size.width) // QUAN TRỌNG NHẤT ĐỂ FIX LỖI
                }
            }
        }
        .onAppear {
            keyInput = authManager.savedKey
            authManager.fetchPublicConfig() // GỌI HÀM TẢI CONFIG TỪ ZENISAUTH
        }
    }
}

// MARK: - CUSTOM AUTH MANAGER (CHẶN PROXY & LẤY CONFIG)
class CustomAuthManager: NSObject, ObservableObject, URLSessionDelegate {
    static let shared = CustomAuthManager()
    
    @Published var isAuthorized: Bool = false
    @Published var errorMessage: String? = nil
    @Published var isLoading: Bool = false
    @AppStorage("saved_license_key") var savedKey: String = ""
    @AppStorage("license_expire_date") var expireDate: String = "N/A"
    @AppStorage("license_max_devices") var maxDevices: String = "1"
    
    // --- BIẾN ĐỘNG LƯU CONFIG MÀN HÌNH LOGIN ---
    @Published var publicAppName: String = "HNH x IPA"
    @Published var publicAvatarURL: String = "https://zenisiosvn.io.vn/sovereignsolitude/ipa/uploads/avatar.jpg"
    @Published var publicBackgroundURL: String = "https://zenisiosvn.io.vn/sovereignsolitude/ipa/uploads/nen.jpg"
    @Published var publicGetKeyURL: String = "https://zenisiosvn.io.vn/sovereignsolitude/ipa/zeniskey/index.php"
    private var hasFetchedPublicConfig = false
    
    private let secretKey = "Hoangquydzvl" 
    
    // ĐÃ THAY ĐỔI LINK DOMAIN MỚI TẠI ĐÂY
    private let authURL = URL(string: "https://zenisiosvn.io.vn/sovereignsolitude/ipa/ZenisAuth.php")!
    
    private var secureSession: URLSession!
    
    override init() {
        super.init()
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = 30
        self.secureSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }
    
    func isProxyConfigured() -> Bool {
        guard let proxySettings = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [String: Any] else { return false }
        if let http = proxySettings["HTTPProxy"] as? String, !http.isEmpty { return true }
        if let https = proxySettings["HTTPSProxy"] as? String, !https.isEmpty { return true }
        if let socks = proxySettings["SOCKSProxy"] as? String, !socks.isEmpty { return true }
        return false
    }
    
    // HÀM LẤY CẤU HÌNH TỪ ZENISAUTH.PHP (ACTION = PUBLIC)
    func fetchPublicConfig() {
        guard !hasFetchedPublicConfig else { return } // Chỉ chạy 1 lần
        hasFetchedPublicConfig = true
        
        if isProxyConfigured() { return }
        
        let timestamp = Int(Date().timeIntervalSince1970)
        let payloadDict: [String: Any] = [
            "action": "public",
            "key": "",
            "device_id": AppDeviceIdentity.value,
            "timestamp": timestamp
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payloadDict),
              let jsonString = String(data: jsonData, encoding: .utf8),
              let encryptedBase64 = encryptAES(jsonString, key: secretKey) else {
            return
        }
        
        var request = URLRequest(url: authURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")
        
        let encodedBase64 = encryptedBase64.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
        let bodyString = "data=\(encodedBase64)"
        request.httpBody = bodyString.data(using: .utf8)
        
        secureSession.dataTask(with: request) { [weak self] data, response, error in
            guard let data = data, let responseString = String(data: data, encoding: .utf8) else { return }
            
            if let decryptedString = self?.decryptAES(responseString, key: self?.secretKey ?? ""),
               let resData = decryptedString.data(using: .utf8),
               let resDict = try? JSONSerialization.jsonObject(with: resData) as? [String: Any] {
                
                DispatchQueue.main.async {
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
        }.resume()
    }
    
    func authenticate(key: String) {
        if isProxyConfigured() {
            self.errorMessage = "ZENIS ..."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        let timestamp = Int(Date().timeIntervalSince1970)
        let payloadDict: [String: Any] = [
            "key": key,
            "device_id": AppDeviceIdentity.value,
            "timestamp": timestamp
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payloadDict),
              let jsonString = String(data: jsonData, encoding: .utf8),
              let encryptedBase64 = encryptAES(jsonString, key: secretKey) else {
            self.errorMessage = "Lỗi xử lý dữ liệu"
            self.isLoading = false
            return
        }
        
        var request = URLRequest(url: authURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")
        
        let encodedBase64 = encryptedBase64.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
        let bodyString = "data=\(encodedBase64)"
        request.httpBody = bodyString.data(using: .utf8)
        
        secureSession.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = "Lỗi bảo mật kết nối: \(error.localizedDescription)"
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                    self?.errorMessage = "Server lỗi (Mã HTTP: \(httpResponse.statusCode))"
                    return
                }
                
                guard let data = data, let responseString = String(data: data, encoding: .utf8) else {
                    self?.errorMessage = "Server trả về dữ liệu rỗng"
                    return
                }
                
                if responseString.contains("<") || responseString.contains("Fatal error") || responseString.contains("Warning") {
                    self?.errorMessage = "Lỗi PHP: \(responseString.prefix(50))..."
                    return
                }
                
                if let decryptedString = self?.decryptAES(responseString, key: self?.secretKey ?? ""),
                   let resData = decryptedString.data(using: .utf8),
                   let resDict = try? JSONSerialization.jsonObject(with: resData) as? [String: Any] {
                    
                    if let authInfo = resDict["auth_info"] as? [String: Any], (authInfo["status"] as? String) == "success" {
                        self?.isAuthorized = true
                        self?.savedKey = key
                        self?.expireDate = authInfo["expires_at"] as? String ?? "N/A"
                        self?.maxDevices = "\(authInfo["max_devices"] as? Int ?? 1)"
                        
                        if let catalogData = try? JSONSerialization.data(withJSONObject: resDict),
                           let decodedCatalog = try? JSONDecoder().decode(GameCatalog.self, from: catalogData) {
                            GameCatalogStore.shared.catalog = decodedCatalog
                        }
                    } else {
                        self?.errorMessage = resDict["message"] as? String ?? "Xác thực thất bại"
                    }
                } else {
                    self?.errorMessage = "Lỗi giải mã. Sai Secret Key hoặc dữ liệu bị can thiệp."
                }
            }
        }.resume()
    }
    
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        // ĐÃ THAY ĐỔI DOMAIN CHECK SSL
        if challenge.protectionSpace.host == "zenisiosvn.io.vn" {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
    
    private func encryptAES(_ text: String, key: String) -> String? {
        guard let data = text.data(using: .utf8) else { return nil }
        let keyHash = SHA256.hash(data: Data(key.utf8))
        let symmetricKey = SymmetricKey(data: keyHash)
        guard let sealedBox = try? AES.GCM.seal(data, using: symmetricKey) else { return nil }
        return sealedBox.combined?.base64EncodedString()
    }
    
    private func decryptAES(_ base64String: String, key: String) -> String? {
        guard let data = Data(base64Encoded: base64String) else { return nil }
        let keyHash = SHA256.hash(data: Data(key.utf8))
        let symmetricKey = SymmetricKey(data: keyHash)
        guard let sealedBox = try? AES.GCM.SealedBox(combined: data),
              let decryptedData = try? AES.GCM.open(sealedBox, using: symmetricKey) else { return nil }
        return String(data: decryptedData, encoding: .utf8)
    }
}

// MARK: - LỚP KHIÊN BẢO MẬT TOÀN CỤC
class SecureNetworkManager: NSObject, URLSessionDelegate {
    static let shared = SecureNetworkManager()
    
    func isProxyEnabled() -> Bool {
        guard let proxySettings = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [String: Any] else { return false }
        if let http = proxySettings["HTTPProxy"] as? String, !http.isEmpty { return true }
        if let https = proxySettings["HTTPSProxy"] as? String, !https.isEmpty { return true }
        if let socks = proxySettings["SOCKSProxy"] as? String, !socks.isEmpty { return true }
        return false
    }
    
    func createSecureSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        config.timeoutIntervalForRequest = 30
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }
    
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        // ĐÃ THAY ĐỔI DOMAIN CHECK SSL
        if challenge.protectionSpace.host == "zenisiosvn.io.vn" {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}

class SecurityURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool {
        return SecureNetworkManager.shared.isProxyEnabled()
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { return request }
    
    override func startLoading() {
        let error = NSError(domain: "Security", code: -999, userInfo: [NSLocalizedDescriptionKey: "ZENIS ..."])
        client?.urlProtocol(self, didFailWithError: error)
    }
    
    override func stopLoading() {}
}
