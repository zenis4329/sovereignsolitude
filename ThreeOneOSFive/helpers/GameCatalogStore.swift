import Foundation
import Security

enum AppDeviceIdentity {
    private static let service = "com.apexipa.remote-access"
    private static let account = "fixed-device-id"

    static var value: String {
        let read: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        if SecItemCopyMatching(read as CFDictionary, &result) == errSecSuccess,
           let data = result as? Data,
           let existing = String(data: data, encoding: .utf8), !existing.isEmpty {
            return existing
        }
        let generated = UUID().uuidString.lowercased()
        let add: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: Data(generated.utf8)
        ]
        SecItemAdd(add as CFDictionary, nil)
        return generated
    }
}

struct GameItemCategory: RawRepresentable, Codable, Identifiable, Hashable {
    let rawValue: String
    init(rawValue: String) { self.rawValue = rawValue }
    
    static let aim = Self(rawValue: "aim")
    static let location = Self(rawValue: "location")
    static let mod = Self(rawValue: "mod")
    var id: String { rawValue }
    
    var title: String {
        switch rawValue {
        case "aim": return "AIM"
        case "location": return "Định vị"
        case "mod": return "Mod"
        default: return rawValue.uppercased()
        }
    }
    var icon: String {
        switch rawValue {
        case "aim": return "scope"
        case "location": return "location.north.circle.fill"
        case "mod": return "gearshape.fill"
        default: return "square.grid.2x2.fill"
        }
    }
    init(from decoder: Decoder) throws { rawValue = try decoder.singleValueContainer().decode(String.self) }
    func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(rawValue) }
}

struct GameCatalogItem: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var subtitle: String?
    var category: GameItemCategory
    var imageURL: String?
    var fileURL: String?
    var packagePassword: String?
    var enabled: Bool?
    var order: Int?
    var usageGuide: String? // <--- ĐÃ THÊM DÒNG NÀY

    var resolvedPackagePassword: String? {
        let primary = packagePassword?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !primary.isEmpty { return primary }
        return nil
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, subtitle, category, imageURL, fileURL, packagePassword, password, enabled, order, usageGuide
    }

    init(id: String, name: String, subtitle: String? = nil, category: GameItemCategory, imageURL: String? = nil, fileURL: String? = nil, packagePassword: String? = nil, enabled: Bool? = nil, order: Int? = nil, usageGuide: String? = nil) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.category = category
        self.imageURL = imageURL
        self.fileURL = fileURL
        self.packagePassword = packagePassword
        self.enabled = enabled
        self.order = order
        self.usageGuide = usageGuide // <--- ĐÃ THÊM
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        subtitle = try c.decodeIfPresent(String.self, forKey: .subtitle)
        category = try c.decode(GameItemCategory.self, forKey: .category)
        imageURL = try c.decodeIfPresent(String.self, forKey: .imageURL)
        fileURL = try c.decodeIfPresent(String.self, forKey: .fileURL)
        let modern = try c.decodeIfPresent(String.self, forKey: .packagePassword)
        let legacy = try c.decodeIfPresent(String.self, forKey: .password)
        packagePassword = (modern?.isEmpty == false ? modern : nil) ?? (legacy?.isEmpty == false ? legacy : nil)
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled)
        order = try c.decodeIfPresent(Int.self, forKey: .order)
        usageGuide = try c.decodeIfPresent(String.self, forKey: .usageGuide) // <--- ĐÃ THÊM
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encodeIfPresent(subtitle, forKey: .subtitle)
        try c.encode(category, forKey: .category)
        try c.encodeIfPresent(imageURL, forKey: .imageURL)
        try c.encodeIfPresent(fileURL, forKey: .fileURL)
        try c.encodeIfPresent(packagePassword, forKey: .packagePassword)
        try c.encodeIfPresent(enabled, forKey: .enabled)
        try c.encodeIfPresent(order, forKey: .order)
        try c.encodeIfPresent(usageGuide, forKey: .usageGuide) // <--- ĐÃ THÊM
    }
}

struct GameCatalogGame: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var bundleID: String
    var iconURL: String?
    var launchURL: String?
    var items: [GameCatalogItem]
    var order: Int? = nil
    var tabIDs: [String]? = nil
    var tabs: [GameCatalogTab]? = nil

    func resolvedTabs(fallback: [GameCatalogTab]) -> [GameCatalogTab] {
        let source = tabs ?? fallback
        return source.sorted { $0.order < $1.order }
    }
}

struct GameCatalogTab: Codable, Identifiable, Hashable {
    var id: String
    var title: String
    var icon: String
    var order: Int
}

struct RemoteProfileLink: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var role: String
    var url: String
    var icon: String
    var appIcon: String?
}

struct GameCatalog: Codable {
    var noticeTitle: String
    var noticeMessage: String
    var maintenanceEnabled: Bool?
    var maintenanceTitle: String?
    var maintenanceMessage: String?
    var brandTitle: String?
    var brandSubtitle: String?
    var brandAvatarURL: String?
    var cardOpacity: Double?
    var musicEnabled: Bool?
    var musicURL: String?
    var musicFromVideoURL: String?
    var musicUseBackgroundVideo: Bool? = nil
    var musicSource: String?
    var backgroundType: String?
    var backgroundImageURL: String?
    var backgroundVideoURL: String?
    var backgroundContentMode: String?
    var pageVisibility: [String: Bool]?
    var socialLinks: [RemoteProfileLink]?
    var credits: [RemoteProfileLink]?
    var tabs: [GameCatalogTab]?
    var latestVersion: String? = nil
    var minimumVersion: String? = nil
    var forceUpdate: Bool? = nil
    var updateURL: String? = nil
    var updateMessage: String? = nil
    var ipaDownloadURL: String? = nil
    var games: [GameCatalogGame]

    var resolvedMusicEnabled: Bool { musicEnabled ?? false }
    var resolvedMaintenanceEnabled: Bool { maintenanceEnabled ?? false }
    var resolvedMaintenanceTitle: String { maintenanceTitle?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? maintenanceTitle! : "MAINTENANCE" }
    var resolvedMaintenanceMessage: String { maintenanceMessage?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? maintenanceMessage! : "Hệ thống đang bảo trì. Vui lòng quay lại sau." }
    var resolvedCardOpacity: Double { min(max(cardOpacity ?? 0.92, 0.15), 1.0) }
    
    var resolvedBackgroundType: String {
        let t = (backgroundType ?? "none").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return ["none", "image", "video"].contains(t) ? t : "none"
    }
    
    var resolvedMusicSource: String {
        if let source = musicSource?.lowercased(), source == "audio" || source == "video" { return source }
        if musicUseBackgroundVideo == true { return "video" }
        let direct = musicURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let video = backgroundVideoURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return direct.isEmpty && !video.isEmpty ? "video" : "audio"
    }
    
    func isPageVisible(_ key: String) -> Bool { pageVisibility?[key] ?? true }
    var resolvedSocialLinks: [RemoteProfileLink] { socialLinks ?? [] }
    var resolvedCredits: [RemoteProfileLink] { credits ?? [] }
    
    var resolvedTabs: [GameCatalogTab] {
        (tabs?.isEmpty == false ? tabs! : Self.defaultTabs).sorted { $0.order < $1.order }
    }
    
    var resolvedBackgroundContentMode: String {
        (backgroundContentMode ?? "cover").lowercased() == "fit" ? "fit" : "cover"
    }
    
    var orderedGames: [GameCatalogGame] {
        games.sorted { ($0.order ?? Int.max) < ($1.order ?? Int.max) }
    }

    static let defaultTabs = [
        GameCatalogTab(id: "aim", title: "AIM", icon: "scope", order: 1),
        GameCatalogTab(id: "location", title: "Định vị", icon: "location.north.circle.fill", order: 2),
        GameCatalogTab(id: "mod", title: "MOD", icon: "gearshape.fill", order: 3)
    ]

    static let defaultSocialLinks = [
        RemoteProfileLink(id: "telegram-news", name: "Telegram", role: "Kênh thông báo", url: "https://t.me/apexproxyv1", icon: "fa-brands fa-telegram", appIcon: "paperplane.fill"),
        RemoteProfileLink(id: "telegram-chat", name: "Telegram", role: "Nhóm cộng đồng", url: "https://t.me/apexproxyv1chat", icon: "fa-solid fa-paper-plane", appIcon: "paperplane.fill"),
        RemoteProfileLink(id: "zalo-chat", name: "Zalo", role: "Nhóm cộng đồng", url: "https://zalo.me/g/gsl985njohn9jkco9sio", icon: "fa-solid fa-comment", appIcon: "message.fill")
    ]
    static let defaultCredits = [
        RemoteProfileLink(id: "huutien", name: "HuuTien", role: "Developer & Designer", url: "https://t.me/htios2590", icon: "fa-solid fa-user", appIcon: "person.crop.circle.fill"),
        RemoteProfileLink(id: "kari", name: "Kari", role: "FILE AIM, MOD, ĐỊNH VỊ", url: "https://t.me/kariios9", icon: "fa-solid fa-hammer", appIcon: "hammer.fill")
    ]

    var resolvedAmbientAudioURLString: String? {
        let music = musicURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let fromVideo = backgroundVideoURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return resolvedMusicSource == "video" ? (fromVideo.isEmpty ? nil : fromVideo) : (music.isEmpty ? nil : music)
    }

    static let fallback = GameCatalog(
        noticeTitle: "Thông báo", noticeMessage: "Chưa tải được cấu hình. Hãy kiểm tra kết nối máy chủ.",
        maintenanceEnabled: false, maintenanceTitle: "MAINTENANCE", maintenanceMessage: "Hệ thống đang bảo trì.",
        brandTitle: "HMT IPA PRX", brandSubtitle: "Quản lý thiết bị", brandAvatarURL: nil, cardOpacity: 0.92,
        musicEnabled: false, musicURL: nil, musicFromVideoURL: nil, musicSource: "audio",
        backgroundType: "none", backgroundImageURL: nil, backgroundVideoURL: nil, backgroundContentMode: "cover",
        pageVisibility: ["home": true, "games": true, "patches": true, "wallpaper": true, "files": true, "cleaner": true],
        socialLinks: [], credits: [], tabs: defaultTabs, games: []
    )
}

@MainActor
final class GameCatalogStore: ObservableObject {
    static let shared = GameCatalogStore()

    private let secureSession = SecureNetworkManager.shared.createSecureSession()

    @Published var catalog = GameCatalog.fallback
    @Published private(set) var isLoading = false
    @Published private(set) var isPrefetching = false
    @Published private(set) var busyItemIDs: Set<String> = []
    @Published private(set) var appliedItemIDs: Set<String> = []
    @Published private(set) var replacementRuleCounts: [String: Int] = [:]
    @Published private(set) var lastFetchedAt: Date?
    @Published var lastError: String?

    private init() {
        appliedItemIDs = GameCatalogItemService.loadAppliedItemIDs()
    }

    @discardableResult
    func refresh(prefetch: Bool = true) async -> Bool {
        // KHÔNG GỌI MẠNG. CONFIG ĐÃ ĐƯỢC TẢI TỪ ZENISAUTH.PHP
        isLoading = false
        lastError = nil
        lastFetchedAt = Date()
        
        if prefetch { 
            await prefetchPackages() 
        }
        return true
    }

    func prefetchPackages(progress: ((Int, Int) -> Void)? = nil) async {
        isPrefetching = true
        replacementRuleCounts = [:]
        defer { isPrefetching = false }
        replacementRuleCounts = await GameCatalogItemService.replacementRuleCounts(from: catalog, progress: progress)
    }

    func isOn(itemID: String) -> Bool { appliedItemIDs.contains(itemID) }
    func isBusy(itemID: String) -> Bool { busyItemIDs.contains(itemID) }
    func replacementRuleCount(itemID: String) -> Int? { replacementRuleCounts[itemID] }
    func isCatalogItemVisible(_ item: GameCatalogItem) -> Bool { replacementRuleCounts[item.id] != nil }
    func visibleItemCount(in game: GameCatalogGame) -> Int { game.items.filter(isCatalogItemVisible).count }

    func setEnabled(_ enabled: Bool, item: GameCatalogItem) async {
        guard !busyItemIDs.contains(item.id) else { return }
        busyItemIDs.insert(item.id)
        lastError = nil
        defer { busyItemIDs.remove(item.id) }

        do {
            if enabled {
                try await GameCatalogItemService.enable(item: item)
                appliedItemIDs.insert(item.id)
            } else {
                try await GameCatalogItemService.disable(item: item)
                appliedItemIDs.remove(item.id)
            }
            appliedItemIDs = GameCatalogItemService.loadAppliedItemIDs()
        } catch let error as PatchPackageError {
            lastError = error.localizedDescription
            appliedItemIDs = GameCatalogItemService.loadAppliedItemIDs()
        } catch {
            lastError = error.localizedDescription
            appliedItemIDs = GameCatalogItemService.loadAppliedItemIDs()
        }
    }
}
