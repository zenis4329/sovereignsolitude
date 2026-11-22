import SwiftUI
import UIKit
import AudioToolbox

// MARK: - HAPTICS
final class iPhoneHaptics {
    static let shared = iPhoneHaptics()
    private let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private let light = UIImpactFeedbackGenerator(style: .light)
    private let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private init() { rigid.prepare(); light.prepare(); heavy.prepare() }
    func playTickOn()  { AudioServicesPlaySystemSound(1057); rigid.impactOccurred(intensity: 1.0); rigid.prepare() }
    func playTickOff() { AudioServicesPlaySystemSound(1104); light.impactOccurred(intensity: 0.75); light.prepare() }
    func playTap()     { AudioServicesPlaySystemSound(1104); light.impactOccurred(intensity: 0.55); light.prepare() }
    func playLaunch()  { AudioServicesPlaySystemSound(1057); heavy.impactOccurred(intensity: 1.0); heavy.prepare() }
}

// MARK: - IMAGE CACHE
final class CatalogImageCache {
    static let shared = NSCache<NSString, UIImage>()
}

struct SecureCatalogImage: View {
    let urlString: String
    let placeholder: Image
    @State private var image: UIImage?
    @State private var isLoading = true

    var body: some View {
        ZStack {
            Color.white.opacity(0.05)
            if let image = image {
                Image(uiImage: image).resizable().scaledToFill()
                    .transition(.opacity.animation(.easeOut(duration: 0.2)))
            } else {
                placeholder.resizable().scaledToFit().padding(7)
                    .foregroundColor(.white.opacity(0.35))
                    .overlay(ProgressView().tint(.cyan).scaleEffect(0.65).opacity(isLoading ? 1 : 0))
            }
        }
        .clipped()
        .onAppear { loadImage() }
        .onChange(of: urlString) { _ in image = nil; isLoading = true; loadImage() }
    }

    private func loadImage() {
        let cleanUrl = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanUrl.isEmpty else { isLoading = false; return }
        if let cached = CatalogImageCache.shared.object(forKey: cleanUrl as NSString) {
            self.image = cached; self.isLoading = false; return
        }
        guard !SecureNetworkManager.shared.isProxyEnabled(), let url = URL(string: cleanUrl) else {
            isLoading = false; return
        }
        SecureNetworkManager.shared.createSecureSession().dataTask(with: url) { data, _, _ in
            DispatchQueue.main.async {
                if let data = data, let uiImage = UIImage(data: data) {
                    CatalogImageCache.shared.setObject(uiImage, forKey: cleanUrl as NSString)
                    withAnimation { self.image = uiImage }
                }
                self.isLoading = false
            }
        }.resume()
    }
}

// MARK: - BACKGROUND
private struct ModernBackground: View {
    let urlString: String
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(red: 0.04, green: 0.045, blue: 0.07)
                SecureCatalogImage(urlString: urlString, placeholder: Image(systemName: "sparkles"))
                    .frame(width: geo.size.width, height: geo.size.height)
                    .opacity(0.28)
                LinearGradient(
                    colors: [Color.black.opacity(0.55), Color(red: 0.04, green: 0.045, blue: 0.07).opacity(0.92), Color.black],
                    startPoint: .top, endPoint: .bottom
                )
                Circle().fill(Color.cyan.opacity(0.14))
                    .frame(width: 280, height: 280).blur(radius: 120)
                    .offset(x: -150, y: -260)
                Circle().fill(Color.purple.opacity(0.10))
                    .frame(width: 240, height: 240).blur(radius: 120)
                    .offset(x: 160, y: 380)
            }
        }.ignoresSafeArea()
    }
}

// MARK: - BUTTON STYLE
struct ClassicScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

// ==========================================================
// MARK: - MÀN HÌNH CHÍNH
// ==========================================================
struct GameCatalogView: View {
    @StateObject private var store = GameCatalogStore.shared
    @StateObject private var authManager = CustomAuthManager.shared
    @Binding var isTabBarHidden: Bool
    @State private var isRotating = false

    private var isSessionActive: Bool {
        authManager.isAuthorized && !authManager.isInteractionLocked && !store.catalog.resolvedMaintenanceEnabled
    }
    private var totalEnabled: Int {
        store.catalog.orderedGames.reduce(0) { $0 + $1.items.filter { $0.hidden != true && store.isMultiItemOn(item: $0) }.count }
    }
    private var totalFeatures: Int {
        store.catalog.orderedGames.reduce(0) { $0 + $1.items.filter { $0.hidden != true }.count }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ModernBackground(urlString: authManager.publicBackgroundURL)
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        profileCard
                        gamesSection
                    }
                    .padding(.bottom, 100)
                }
                .disabled(!isSessionActive)
                .allowsHitTesting(isSessionActive)
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                isRotating = true
                store.rememberCatalogItems()
                if !authManager.isAuthorized || store.catalog.resolvedMaintenanceEnabled {
                    store.disableAllEnabledMods()
                }
            }
            .onChange(of: store.catalog.games.count) { _ in store.rememberCatalogItems() }
            .onChange(of: authManager.isAuthorized) { a in if !a { isTabBarHidden = false; store.disableAllEnabledMods() } }
            .onChange(of: store.catalog.resolvedMaintenanceEnabled) { m in if m { isTabBarHidden = false; store.disableAllEnabledMods() } }
        }
    }

    // MARK: PROFILE CARD (gọn, gộp stats)
    private var profileCard: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.cyan.opacity(0.22)).frame(width: 68, height: 68).blur(radius: 14)
                Circle()
                    .stroke(AngularGradient(colors: [.cyan, .white, .blue, .cyan], center: .center), lineWidth: 2)
                    .frame(width: 58, height: 58)
                    .rotationEffect(.degrees(isRotating ? 360 : 0))
                    .animation(.linear(duration: 4.5).repeatForever(autoreverses: false), value: isRotating)
                    .drawingGroup()
                SecureCatalogImage(urlString: authManager.publicAvatarURL, placeholder: Image(systemName: "person.crop.circle.fill"))
                    .frame(width: 50, height: 50).clipShape(Circle())
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(authManager.publicAppName.isEmpty ? "Sovereign Solitude" : authManager.publicAppName)
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundColor(.white).lineLimit(1)
                HStack(spacing: 6) {
                    HStack(spacing: 4) {
                        Circle().fill(Color.green).frame(width: 5, height: 5)
                        Text("Online").font(.system(size: 10, weight: .semibold)).foregroundColor(.white.opacity(0.55))
                    }
                    Text("•").foregroundColor(.white.opacity(0.3))
                    Text("\(store.catalog.orderedGames.count) game · \(totalFeatures) mod")
                        .font(.system(size: 10.5, weight: .medium)).foregroundColor(.white.opacity(0.55))
                }
                if totalEnabled > 0 {
                    Text("Đang bật \(totalEnabled) mod")
                        .font(.system(size: 10.5, weight: .bold)).foregroundColor(.cyan)
                }
            }
            Spacer(minLength: 4)

            if totalEnabled > 0 {
                Button {
                    iPhoneHaptics.shared.playTickOff()
                    withAnimation(.spring(response: 0.26, dampingFraction: 0.8)) { store.disableAllEnabledMods() }
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: "power").font(.system(size: 13, weight: .black))
                        Text("Tắt").font(.system(size: 9, weight: .black))
                    }
                    .foregroundColor(.black)
                    .frame(width: 44, height: 44)
                    .background(LinearGradient(colors: [Color(red: 0.3, green: 0.95, blue: 1), .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .shadow(color: .cyan.opacity(0.4), radius: 7)
                }
                .buttonStyle(ClassicScaleButtonStyle())
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.white.opacity(0.055)))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(
                    LinearGradient(colors: [Color.cyan.opacity(0.35), Color.white.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1
                )
        )
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }

    // MARK: GAMES SECTION
    private var gamesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "square.grid.2x2.fill").font(.system(size: 10, weight: .black)).foregroundColor(.cyan)
                Text("TRÒ CHƠI").font(.system(size: 10.5, weight: .black, design: .rounded)).foregroundColor(.white.opacity(0.55)).tracking(1)
                Spacer()
                Text("\(store.catalog.orderedGames.count)")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(.black)
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(Color.cyan).clipShape(Capsule())
            }
            .padding(.horizontal, 20)

            if store.catalog.orderedGames.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "gamecontroller").font(.system(size: 28, weight: .light)).foregroundColor(.white.opacity(0.3))
                    Text("Chưa có trò chơi nào").font(.system(size: 13, weight: .semibold)).foregroundColor(.white.opacity(0.55))
                }
                .frame(maxWidth: .infinity).padding(.vertical, 40)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.04)))
                .padding(.horizontal, 16)
            } else {
                VStack(spacing: 8) {
                    ForEach(store.catalog.orderedGames) { game in
                        NavigationLink(destination: GameDetailView(gameID: game.id, isTabBarHidden: $isTabBarHidden)) {
                            ModernGameRow(game: game)
                        }
                        .buttonStyle(ClassicScaleButtonStyle())
                        .disabled(!isSessionActive)
                        .simultaneousGesture(TapGesture().onEnded {
                            guard isSessionActive else { return }
                            iPhoneHaptics.shared.playTap()
                            withAnimation(.easeInOut(duration: 0.2)) { isTabBarHidden = true }
                        })
                        .padding(.horizontal, 16)
                    }
                }
            }
        }
    }
}

// MARK: - GAME ROW
private struct ModernGameRow: View {
    let game: GameCatalogGame
    @StateObject private var store = GameCatalogStore.shared

    private var total: Int { game.items.filter { $0.hidden != true }.count }
    private var active: Int { game.items.filter { $0.hidden != true && store.isMultiItemOn(item: $0) }.count }
    private var progress: CGFloat { total > 0 ? CGFloat(active) / CGFloat(total) : 0 }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                if active > 0 {
                    RoundedRectangle(cornerRadius: 14).fill(Color.cyan.opacity(0.25))
                        .frame(width: 52, height: 52).blur(radius: 8)
                }
                SecureCatalogImage(urlString: game.iconURL ?? "", placeholder: Image(systemName: "gamecontroller.fill"))
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(
                                active > 0 ? LinearGradient(colors: [.cyan, .white.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                            : LinearGradient(colors: [Color.white.opacity(0.15), Color.white.opacity(0.04)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 1.2
                            )
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(game.name).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundColor(.white).lineLimit(1)
                    if active > 0 {
                        Text("\(active)")
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .foregroundColor(.black)
                            .frame(width: 16, height: 16)
                            .background(Color.cyan).clipShape(Circle())
                    }
                }
                Text("\(total) mod\(active > 0 ? " · \(active) bật" : "")")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(active > 0 ? .cyan.opacity(0.85) : .white.opacity(0.45))
                if active > 0 {
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.08))
                            Capsule().fill(LinearGradient(colors: [.cyan, Color(red: 0.3, green: 0.9, blue: 1)], startPoint: .leading, endPoint: .trailing))
                                .frame(width: g.size.width * progress)
                        }
                    }.frame(height: 3)
                }
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .black)).foregroundColor(.black)
                .frame(width: 28, height: 28)
                .background(LinearGradient(colors: [Color(red: 0.25, green: 0.92, blue: 1), .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                .clipShape(Circle())
        }
        .padding(11)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.045)))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    active > 0 ? Color.cyan.opacity(0.45) : Color.white.opacity(0.08),
                    lineWidth: active > 0 ? 1.1 : 0.8
                )
        )
    }
}

// ==========================================================
// MARK: - MÀN HÌNH CHI TIẾT (REDESIGN HOÀN TOÀN)
// ==========================================================
private struct GameDetailView: View {
    let gameID: String
    @Binding var isTabBarHidden: Bool
    @StateObject private var store = GameCatalogStore.shared
    @StateObject private var authManager = CustomAuthManager.shared
    @State private var selectedTabID = "aim"
    @State private var searchText = ""
    @State private var onlyActiveFilter = false
    @Environment(\.dismiss) private var dismiss

    private var catalog: GameCatalog { store.catalog }
    private var game: GameCatalogGame? { catalog.games.first(where: { $0.id == gameID }) }
    private var isSessionActive: Bool {
        authManager.isAuthorized && !authManager.isInteractionLocked && !store.catalog.resolvedMaintenanceEnabled
    }

    private var items: [GameCatalogItem] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return (game?.items ?? [])
            .filter { $0.hidden != true && $0.category.rawValue == selectedTabID }
            .filter { item in
                if onlyActiveFilter && !store.isMultiItemOn(item: item) { return false }
                if q.isEmpty { return true }
                return item.name.lowercased().contains(q) || (item.subtitle ?? "").lowercased().contains(q)
            }
            .sorted { ($0.order ?? Int.max) < ($1.order ?? Int.max) }
    }

    private var activeCountInGame: Int {
        (game?.items ?? []).filter { $0.hidden != true && store.isMultiItemOn(item: $0) }.count
    }

    private var availableTabs: [GameCatalogTab] {
        let fallback: [GameCatalogTab] = catalog.resolvedTabs
        guard let game else { return fallback }
        let own = game.resolvedTabs(fallback: fallback)
        guard let selected = game.tabIDs else { return own }
        return own.filter { selected.contains($0.id) }
    }

    private var currentTab: GameCatalogTab? { availableTabs.first(where: { $0.id == selectedTabID }) ?? availableTabs.first }
    private var currentCount: Int {
        (game?.items ?? []).filter { $0.hidden != true && $0.category.rawValue == selectedTabID }.count
    }

    var body: some View {
        ZStack {
            ModernBackground(urlString: authManager.publicBackgroundURL)

            VStack(spacing: 10) {
                headerSection
                categoryBar
                modList
            }
            .safeAreaInset(edge: .bottom) { launchButton }
        }
        .disabled(!isSessionActive)
        .allowsHitTesting(isSessionActive)
        .navigationBarHidden(true)
        .onAppear {
            store.rememberCatalogItems()
            if store.catalog.resolvedMaintenanceEnabled {
                store.disableAllEnabledMods()
                withAnimation { isTabBarHidden = false }
                dismiss(); return
            }
            withAnimation { isTabBarHidden = true }
            if !availableTabs.contains(where: { $0.id == selectedTabID }) {
                selectedTabID = availableTabs.first?.id ?? "aim"
            }
        }
        .onDisappear { withAnimation { isTabBarHidden = false } }
        .onChange(of: authManager.isAuthorized) { a in
            if !a { store.disableAllEnabledMods(); withAnimation { isTabBarHidden = false }; dismiss() }
        }
        .onChange(of: store.catalog.resolvedMaintenanceEnabled) { m in
            if m { store.disableAllEnabledMods(); withAnimation { isTabBarHidden = false }; dismiss() }
        }
    }

    // MARK: HEADER
    private var headerSection: some View {
        HStack(spacing: 11) {
            Button {
                iPhoneHaptics.shared.playTap()
                withAnimation(.easeInOut(duration: 0.2)) { isTabBarHidden = false }
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.08)).clipShape(Circle())
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(game?.name ?? "Game")
                    .font(.system(size: 16.5, weight: .bold, design: .rounded))
                    .foregroundColor(.white).lineLimit(1)
                HStack(spacing: 4) {
                    Circle().fill(activeCountInGame > 0 ? Color.cyan : Color.green).frame(width: 5, height: 5)
                    Text(activeCountInGame > 0 ? "\(activeCountInGame) đang bật" : "Sẵn sàng")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(activeCountInGame > 0 ? .cyan : .white.opacity(0.55))
                }
            }
            Spacer()
            SecureCatalogImage(urlString: game?.iconURL ?? "", placeholder: Image(systemName: "gamecontroller.fill"))
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(
                            LinearGradient(colors: [.cyan, .white.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1.2
                        )
                )
        }
        .padding(.horizontal, 16).padding(.top, 6)
    }

    // MARK: CATEGORY BAR (MENU DROPDOWN + SEARCH + FILTER)
    private var categoryBar: some View {
        HStack(spacing: 8) {
            // Menu dropdown danh mục
            Menu {
                ForEach(availableTabs) { tab in
                    let count = (game?.items ?? []).filter { $0.hidden != true && $0.category.rawValue == tab.id }.count
                    Button {
                        iPhoneHaptics.shared.playTap()
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                            selectedTabID = tab.id
                        }
                    } label: {
                        Label {
                            Text("\(tab.title) (\(count))")
                        } icon: {
                            Image(systemName: tab.icon)
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: currentTab?.icon ?? "square.grid.2x2.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text(currentTab?.title.uppercased() ?? "DANH MỤC")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .lineLimit(1)
                    Text("\(currentCount)")
                        .font(.system(size: 9.5, weight: .black, design: .rounded))
                        .foregroundColor(.black)
                        .frame(minWidth: 18, minHeight: 18)
                        .background(Color.white.opacity(0.95))
                        .clipShape(Capsule())
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .black))
                }
                .foregroundColor(.black)
                .padding(.horizontal, 11).padding(.vertical, 9)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.25, green: 0.92, blue: 1.0), Color.cyan],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                .shadow(color: .cyan.opacity(0.35), radius: 6)
            }

            // Search field
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .medium)).foregroundColor(.white.opacity(0.4))
                TextField("Tìm mod...", text: $searchText)
                    .font(.system(size: 12.5)).foregroundColor(.white).tint(.cyan)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12)).foregroundColor(.white.opacity(0.4))
                    }
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 9)
            .background(Color.white.opacity(0.055))
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
            .layoutPriority(-1)

            // Filter button
            Button {
                iPhoneHaptics.shared.playTap()
                withAnimation(.spring(response: 0.26, dampingFraction: 0.78)) { onlyActiveFilter.toggle() }
            } label: {
                Image(systemName: onlyActiveFilter ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(onlyActiveFilter ? .black : .white.opacity(0.55))
                    .frame(width: 36, height: 36)
                    .background(onlyActiveFilter ? Color.cyan : Color.white.opacity(0.055))
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(onlyActiveFilter ? Color.white.opacity(0.5) : Color.white.opacity(0.08), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
    }

    // MARK: MOD LIST (1 CỘT, TOGGLE NATIVE)
    private var modList: some View {
        ScrollView(showsIndicators: false) {
            if items.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "tray").font(.system(size: 28, weight: .light)).foregroundColor(.white.opacity(0.3))
                    Text(onlyActiveFilter ? "Chưa có mod nào đang bật" : "Không có mod trong mục này")
                        .font(.system(size: 13, weight: .medium)).foregroundColor(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity).padding(.vertical, 44)
                .background(Color.white.opacity(0.035))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 16).padding(.top, 6)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(items) { item in
                        ModernModRow(item: item, fallbackAvatarURL: authManager.publicAvatarURL)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4).padding(.bottom, 20)
            }
        }
    }

    // MARK: LAUNCH
    private var launchButton: some View {
        Button {
            guard isSessionActive else { return }
            iPhoneHaptics.shared.playLaunch()
            let raw = (game?.launchURL ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if let url = URL(string: raw), !raw.isEmpty { UIApplication.shared.open(url) }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "play.fill").font(.system(size: 13, weight: .black))
                Text("KHỞI ĐỘNG GAME")
                    .font(.system(size: 14, weight: .black, design: .rounded)).tracking(0.8)
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity).frame(height: 48)
            .background(
                LinearGradient(colors: [Color(red: 0.25, green: 0.93, blue: 1.0), Color(red: 0.1, green: 0.8, blue: 0.98)],
                               startPoint: .leading, endPoint: .trailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).strokeBorder(Color.white.opacity(0.4), lineWidth: 1))
            .shadow(color: .cyan.opacity(0.42), radius: 10, y: 3)
        }
        .buttonStyle(ClassicScaleButtonStyle())
        .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 6)
        .background(
            LinearGradient(colors: [Color.black.opacity(0.0), Color.black.opacity(0.85), Color.black], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
    }
}

// ==========================================================
// MARK: - MOD ROW (1 CỘT, TOGGLE)
// ==========================================================
private struct ModernModRow: View {
    let item: GameCatalogItem
    let fallbackAvatarURL: String
    @StateObject private var store = GameCatalogStore.shared
    @StateObject private var authManager = CustomAuthManager.shared
    @State private var showDetailSheet = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var localToggle: Bool = false

    private var isSessionActive: Bool {
        authManager.isAuthorized && !authManager.isInteractionLocked && !store.catalog.resolvedMaintenanceEnabled
    }
    private var isVip: Bool {
        item.name.localizedCaseInsensitiveContains("VIP")
        || item.name.localizedCaseInsensitiveContains("AIM HEAD")
        || item.name.localizedCaseInsensitiveContains("CAN CHECK")
    }
    private var badgeLabel: String {
        let custom = (item.badge ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return custom.isEmpty ? (isVip ? "VIP" : "") : custom
    }
    private var hasBadge: Bool { !badgeLabel.isEmpty }
    private var hasGuide: Bool {
        !(item.usageGuide ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        || !(item.imageURL ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    private var cardAvatarURL: String {
        let img = (item.imageURL ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return img.isEmpty ? fallbackAvatarURL : img
    }
    private var subtitleDisplay: String {
        let s = (item.subtitle ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return s.isEmpty ? "Sẵn sàng kích hoạt" : s
    }

    var body: some View {
        let hasLink = !item.resolvedFileURLs.isEmpty
        let isOn = store.isMultiItemOn(item: item)
        let busy = store.isMultiItemBusy(item: item)

        HStack(spacing: 11) {
            // Icon
            ZStack {
                if isOn {
                    RoundedRectangle(cornerRadius: 11).fill(Color.cyan.opacity(0.28))
                        .frame(width: 42, height: 42).blur(radius: 7)
                }
                SecureCatalogImage(urlString: cardAvatarURL, placeholder: Image(systemName: "bolt.fill"))
                    .frame(width: 38, height: 38)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(isOn ? Color.cyan : Color.white.opacity(0.15), lineWidth: isOn ? 1.3 : 1)
                    )
            }

            // Info
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(item.name)
                        .font(.system(size: 13.5, weight: .bold, design: .rounded))
                        .foregroundColor(.white).lineLimit(1)
                    if hasBadge {
                        Text(badgeLabel)
                            .font(.system(size: 8, weight: .black, design: .rounded))
                            .foregroundColor(.black)
                            .padding(.horizontal, 5).padding(.vertical, 1.5)
                            .background(LinearGradient(colors: [.cyan, .white], startPoint: .leading, endPoint: .trailing))
                            .clipShape(Capsule())
                    }
                }
                HStack(spacing: 4) {
                    Circle()
                        .fill(busy ? Color.yellow : (isOn ? Color.cyan : Color.white.opacity(0.25)))
                        .frame(width: 5, height: 5)
                    Text(busy ? "Đang nạp..." : (isOn ? "Đang bật" : subtitleDisplay))
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundColor(busy ? .yellow : (isOn ? .cyan : .white.opacity(0.45)))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 4)

            // Info
            Button {
                iPhoneHaptics.shared.playTap()
                showDetailSheet = true
            } label: {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 17))
                    .foregroundColor(.white.opacity(0.35))
            }
            .buttonStyle(.plain)

            // Toggle / Loading
            if busy {
                ProgressView().tint(.cyan).scaleEffect(0.72)
                    .frame(width: 40, height: 26)
            } else {
                Toggle("", isOn: $localToggle)
                    .labelsHidden()
                    .tint(.cyan)
                    .scaleEffect(0.82)
                    .disabled(!hasLink && !isOn)
                    .onAppear { localToggle = isOn }
                    .onChange(of: isOn) { v in localToggle = v }
                    .onChange(of: localToggle) { v in
                        if v == isOn { return }
                        handleToggle(v)
                    }
            }
        }
        .padding(.horizontal, 11).padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isOn ? Color.cyan.opacity(0.06) : Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    isOn ? Color.cyan.opacity(0.4) : Color.white.opacity(0.07),
                    lineWidth: isOn ? 1.2 : 0.8
                )
        )
        .opacity(hasLink ? 1 : 0.5)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isOn)
        .onChange(of: isSessionActive) { a in
            if !a { showDetailSheet = false; showErrorAlert = false }
        }
        .sheet(isPresented: $showDetailSheet) { ModDetailSheet(item: item) }
        .alert("Lỗi kích hoạt Mod", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: { Text(errorMessage) }
    }

    private func handleToggle(_ newVal: Bool) {
        guard !store.isMultiItemBusy(item: item) else { localToggle = store.isMultiItemOn(item: item); return }
        if newVal {
            guard isSessionActive else { localToggle = false; return }
            iPhoneHaptics.shared.playTickOn()
            Task {
                await store.setMultiEnabled(true, item: item)
                if !authManager.isAuthorized || authManager.isInteractionLocked || store.catalog.resolvedMaintenanceEnabled {
                    await store.setMultiEnabled(false, item: item); return
                }
                if let error = store.lastError {
                    await MainActor.run { errorMessage = error; showErrorAlert = true }
                } else if hasGuide {
                    await MainActor.run { showDetailSheet = true }
                }
            }
        } else {
            iPhoneHaptics.shared.playTickOff()
            Task { await store.setMultiEnabled(false, item: item) }
        }
    }
}

// MARK: - MOD DETAIL SHEET
struct ModDetailSheet: View {
    let item: GameCatalogItem
    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = GameCatalogStore.shared
    @StateObject private var authManager = CustomAuthManager.shared
    @State private var copied = false

    private var isYouTubeLink: Bool {
        let g = (item.usageGuide ?? "").lowercased()
        return g.contains("youtube.com") || g.contains("youtu.be")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ModernBackground(urlString: authManager.publicBackgroundURL)
                ScrollView {
                    VStack(spacing: 16) {
                        if let imgURL = item.imageURL, !imgURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            SecureCatalogImage(urlString: imgURL, placeholder: Image(systemName: "photo"))
                                .frame(maxWidth: .infinity).frame(height: 220)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.cyan.opacity(0.35), lineWidth: 1))
                        }
                        if let guide = item.usageGuide, !guide.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "text.book.closed.fill").foregroundColor(.cyan)
                                    Text("Hướng dẫn").font(.headline).foregroundColor(.white)
                                    Spacer()
                                    Button {
                                        iPhoneHaptics.shared.playTickOn()
                                        UIPasteboard.general.string = guide
                                        copied = true
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: copied ? "checkmark.circle.fill" : "doc.on.doc")
                                            Text(copied ? "Đã Copy" : "Copy")
                                        }
                                        .font(.caption.bold())
                                        .foregroundColor(copied ? .black : .cyan)
                                        .padding(.horizontal, 10).padding(.vertical, 6)
                                        .background(copied ? Color.cyan : Color.cyan.opacity(0.15))
                                        .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                                Text(guide)
                                    .font(.body).foregroundColor(.white.opacity(0.9))
                                    .padding(13).frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.white.opacity(0.06))
                                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
                                if isYouTubeLink {
                                    Button {
                                        iPhoneHaptics.shared.playTap()
                                        if let url = URL(string: guide.trimmingCharacters(in: .whitespacesAndNewlines)) {
                                            UIApplication.shared.open(url)
                                        }
                                    } label: {
                                        HStack(spacing: 8) {
                                            Image(systemName: "play.rectangle.fill")
                                            Text("Mở Video Hướng Dẫn")
                                        }
                                        .font(.headline).foregroundColor(.white)
                                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                                        .background(LinearGradient(colors: [.red, .red.opacity(0.8)], startPoint: .leading, endPoint: .trailing))
                                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        if (item.imageURL ?? "").isEmpty && (item.usageGuide ?? "").isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "doc.questionmark").font(.system(size: 44)).foregroundColor(.white.opacity(0.3))
                                Text("Chưa có hướng dẫn").foregroundColor(.white.opacity(0.6))
                            }
                            .padding(.top, 50)
                        }
                    }
                    .padding(18)
                }
            }
            .navigationTitle(item.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng") { iPhoneHaptics.shared.playTap(); dismiss() }
                        .foregroundColor(.cyan).font(.headline.bold())
                }
            }
            .onChange(of: authManager.isAuthorized) { a in if !a { dismiss() } }
            .onChange(of: store.catalog.resolvedMaintenanceEnabled) { m in if m { dismiss() } }
        }
    }
}
