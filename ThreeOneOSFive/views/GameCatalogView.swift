import SwiftUI
import UIKit
import AudioToolbox

// MARK: - ÂM THANH "TÍCH" & TAPTIC ENGINE
final class iPhoneHaptics {
    static let shared = iPhoneHaptics()
    private let rigidGenerator = UIImpactFeedbackGenerator(style: .rigid)
    private let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private init() {
        rigidGenerator.prepare(); lightGenerator.prepare(); heavyGenerator.prepare()
    }
    func playTickOn()  { AudioServicesPlaySystemSound(1057); rigidGenerator.impactOccurred(intensity: 1.0); rigidGenerator.prepare() }
    func playTickOff() { AudioServicesPlaySystemSound(1104); lightGenerator.impactOccurred(intensity: 0.75); lightGenerator.prepare() }
    func playTap()     { AudioServicesPlaySystemSound(1104); lightGenerator.impactOccurred(intensity: 0.55); lightGenerator.prepare() }
    func playLaunch()  { AudioServicesPlaySystemSound(1057); heavyGenerator.impactOccurred(intensity: 1.0); heavyGenerator.prepare() }
}

// MARK: - CACHE ẢNH
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

// MARK: - NỀN HIỆN ĐẠI (NEON GLASS)
private struct ModernBackground: View {
    let urlString: String
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(red: 0.03, green: 0.035, blue: 0.06)
                SecureCatalogImage(urlString: urlString, placeholder: Image(systemName: "sparkles"))
                    .frame(width: geo.size.width, height: geo.size.height)
                    .opacity(0.32)
                    .overlay(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.42),
                                Color(red: 0.03, green: 0.04, blue: 0.07).opacity(0.9),
                                Color.black.opacity(0.98)
                            ],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                Circle().fill(Color.cyan.opacity(0.15))
                    .frame(width: 300, height: 300).blur(radius: 110)
                    .offset(x: -130, y: -280)
                Circle().fill(Color.blue.opacity(0.12))
                    .frame(width: 260, height: 260).blur(radius: 110)
                    .offset(x: 150, y: 420)
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - MINI STAT CARD
private struct StatMiniCard: View {
    let icon: String
    let value: String
    let label: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Image(systemName: icon).font(.system(size: 12, weight: .bold)).foregroundColor(tint)
                Spacer()
            }
            Text(value)
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.055)))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(tint.opacity(0.28), lineWidth: 1))
    }
}

// MARK: - MÀN HÌNH CHÍNH (REDESIGN)
struct GameCatalogView: View {
    @StateObject private var store = GameCatalogStore.shared
    @StateObject private var authManager = CustomAuthManager.shared
    @Binding var isTabBarHidden: Bool
    @State private var isRotating = false

    private var isSessionActive: Bool {
        authManager.isAuthorized
        && !authManager.isInteractionLocked
        && !store.catalog.resolvedMaintenanceEnabled
    }
    private var totalEnabledMods: Int {
        store.catalog.orderedGames.reduce(0) { partial, game in
            partial + game.items.filter { $0.hidden != true && store.isMultiItemOn(item: $0) }.count
        }
    }
    private var totalFeatures: Int {
        store.catalog.orderedGames.reduce(0) { partial, game in
            partial + game.items.filter { $0.hidden != true }.count
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ModernBackground(urlString: authManager.publicBackgroundURL)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        profileHeader
                        statsRow
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
            .onChange(of: authManager.isAuthorized) { authorized in
                if !authorized { isTabBarHidden = false; store.disableAllEnabledMods() }
            }
            .onChange(of: store.catalog.resolvedMaintenanceEnabled) { isMaintenance in
                if isMaintenance { isTabBarHidden = false; store.disableAllEnabledMods() }
            }
        }
    }

    // MARK: PROFILE HEADER
    private var profileHeader: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Color.cyan.opacity(0.22)).frame(width: 82, height: 82).blur(radius: 16)
                Circle()
                    .stroke(AngularGradient(colors: [.cyan, .white, .blue, .cyan], center: .center), lineWidth: 2.2)
                    .frame(width: 72, height: 72)
                    .rotationEffect(.degrees(isRotating ? 360 : 0))
                    .animation(.linear(duration: 4.5).repeatForever(autoreverses: false), value: isRotating)
                    .drawingGroup()
                SecureCatalogImage(urlString: authManager.publicAvatarURL, placeholder: Image(systemName: "person.crop.circle.fill"))
                    .frame(width: 62, height: 62).clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Circle().fill(Color.green).frame(width: 6, height: 6)
                    Text("Đã kết nối")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                }
                Text(authManager.publicAppName.isEmpty ? "Sovereign Solitude" : authManager.publicAppName)
                    .font(.system(size: 21, weight: .black, design: .rounded))
                    .foregroundColor(.white).lineLimit(1)
                Text("Chào mừng trở lại")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
            Spacer()

            if totalEnabledMods > 0 {
                Button {
                    iPhoneHaptics.shared.playTickOff()
                    withAnimation(.spring(response: 0.26, dampingFraction: 0.8)) {
                        store.disableAllEnabledMods()
                    }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: "power").font(.system(size: 15, weight: .bold))
                        Text("Tắt hết").font(.system(size: 9, weight: .bold))
                    }
                    .foregroundColor(.black)
                    .frame(width: 54, height: 54)
                    .background(LinearGradient(colors: [Color(red: 0.3, green: 0.95, blue: 1), .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .cyan.opacity(0.4), radius: 8)
                }
                .buttonStyle(ClassicScaleButtonStyle())
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.white.opacity(0.055)))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(
                    LinearGradient(colors: [Color.cyan.opacity(0.4), Color.white.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1
                )
        )
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    // MARK: STATS ROW
    private var statsRow: some View {
        HStack(spacing: 10) {
            StatMiniCard(icon: "gamecontroller.fill", value: "\(store.catalog.orderedGames.count)", label: "Trò chơi", tint: .cyan)
            StatMiniCard(icon: "bolt.fill", value: "\(totalFeatures)", label: "Chức năng", tint: .orange)
            StatMiniCard(icon: "checkmark.seal.fill", value: "\(totalEnabledMods)", label: "Đang bật", tint: .green)
        }
        .padding(.horizontal, 16)
    }

    // MARK: GAMES SECTION
    private var gamesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 12, weight: .bold)).foregroundColor(.cyan)
                Text("DANH SÁCH TRÒ CHƠI")
                    .font(.system(size: 11.5, weight: .black, design: .rounded))
                    .foregroundColor(.white.opacity(0.7)).tracking(0.8)
                Spacer()
                Text("\(store.catalog.orderedGames.count)")
                    .font(.system(size: 11, weight: .bold)).foregroundColor(.cyan)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.cyan.opacity(0.15)).clipShape(Capsule())
            }
            .padding(.horizontal, 20)

            if store.catalog.orderedGames.isEmpty {
                emptyGamesCard
            } else {
                VStack(spacing: 10) {
                    ForEach(store.catalog.orderedGames) { game in
                        NavigationLink(destination: GameDetailView(gameID: game.id, isTabBarHidden: $isTabBarHidden)) {
                            ModernGameCard(game: game)
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

    private var emptyGamesCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "gamecontroller").font(.system(size: 32, weight: .light)).foregroundColor(.white.opacity(0.35))
            Text("Chưa có trò chơi nào").font(.system(size: 14, weight: .semibold)).foregroundColor(.white.opacity(0.6))
            Text("Vui lòng quay lại sau").font(.system(size: 11.5)).foregroundColor(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity).padding(.vertical, 44)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.white.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
        .padding(.horizontal, 16)
    }
}

// MARK: - GAME CARD (REDESIGN)
private struct ModernGameCard: View {
    let game: GameCatalogGame
    @StateObject private var store = GameCatalogStore.shared

    private var activeVisibleItemsCount: Int { game.items.filter { $0.hidden != true }.count }
    private var enabledModCount: Int {
        game.items.filter { $0.hidden != true && store.isMultiItemOn(item: $0) }.count
    }
    private var progress: CGFloat {
        guard activeVisibleItemsCount > 0 else { return 0 }
        return CGFloat(enabledModCount) / CGFloat(activeVisibleItemsCount)
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                if enabledModCount > 0 {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.cyan.opacity(0.22)).frame(width: 60, height: 60).blur(radius: 10)
                }
                SecureCatalogImage(urlString: game.iconURL ?? "", placeholder: Image(systemName: "gamecontroller.fill"))
                    .frame(width: 58, height: 58)
                    .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 17, style: .continuous)
                            .strokeBorder(
                                enabledModCount > 0
                                ? LinearGradient(colors: [.cyan, .white.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                : LinearGradient(colors: [Color.white.opacity(0.2), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 1.4
                            )
                    )
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(game.name)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white).lineLimit(1)
                    if enabledModCount > 0 {
                        Text("\(enabledModCount)")
                            .font(.system(size: 9.5, weight: .black, design: .rounded))
                            .foregroundColor(.black)
                            .frame(width: 18, height: 18)
                            .background(Color.cyan).clipShape(Circle())
                    }
                }
                Text("\(activeVisibleItemsCount) chức năng")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.08))
                        Capsule()
                            .fill(LinearGradient(colors: [.cyan, Color(red: 0.3, green: 0.9, blue: 1)], startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * progress)
                    }
                }
                .frame(height: 4)
                .opacity(enabledModCount > 0 ? 1 : 0)
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .bold)).foregroundColor(.black)
                .frame(width: 32, height: 32)
                .background(LinearGradient(colors: [Color(red: 0.25, green: 0.92, blue: 1.0), .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                .clipShape(Circle()).shadow(color: .cyan.opacity(0.4), radius: 5)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.white.opacity(0.055)))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(
                    enabledModCount > 0
                    ? LinearGradient(colors: [Color.cyan.opacity(0.6), Color.white.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    : LinearGradient(colors: [Color.white.opacity(0.12), Color.white.opacity(0.04)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1
                )
        )
    }
}

// MARK: - HIỆU ỨNG NHÚN
struct ClassicScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

// MARK: - MÀN HÌNH CHI TIẾT (REDESIGN)
private struct GameDetailView: View {
    let gameID: String
    @Binding var isTabBarHidden: Bool
    @StateObject private var store = GameCatalogStore.shared
    @StateObject private var authManager = CustomAuthManager.shared
    @State private var selectedTabID = "aim"
    @State private var searchText = ""
    @State private var onlyActiveFilter = false
    @Namespace private var pillAnim
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
                return item.name.lowercased().contains(q)
                    || (item.subtitle ?? "").lowercased().contains(q)
            }
            .sorted { ($0.order ?? Int.max) < ($1.order ?? Int.max) }
    }

    private var activeCountInGame: Int {
        (game?.items ?? []).filter { $0.hidden != true && store.isMultiItemOn(item: $0) }.count
    }

    private var availableTabs: [GameCatalogTab] {
        let fallbackTabs: [GameCatalogTab] = catalog.resolvedTabs
        guard let game else { return fallbackTabs }
        let ownTabs = game.resolvedTabs(fallback: fallbackTabs)
        guard let selected = game.tabIDs else { return ownTabs }
        return ownTabs.filter { selected.contains($0.id) }
    }

    private let columns = [
        GridItem(.flexible(), spacing: 11),
        GridItem(.flexible(), spacing: 11)
    ]

    var body: some View {
        ZStack {
            ModernBackground(urlString: authManager.publicBackgroundURL)

            VStack(spacing: 12) {
                headerSection
                tabsSection
                searchFilterSection
                gridSection
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
        .onChange(of: authManager.isAuthorized) { authorized in
            if !authorized {
                store.disableAllEnabledMods()
                withAnimation { isTabBarHidden = false }
                dismiss()
            }
        }
        .onChange(of: store.catalog.resolvedMaintenanceEnabled) { isMaintenance in
            if isMaintenance {
                store.disableAllEnabledMods()
                withAnimation { isTabBarHidden = false }
                dismiss()
            }
        }
    }

    // MARK: HEADER
    private var headerSection: some View {
        HStack(spacing: 12) {
            Button {
                iPhoneHaptics.shared.playTap()
                withAnimation(.easeInOut(duration: 0.2)) { isTabBarHidden = false }
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                    .frame(width: 38, height: 38)
                    .background(Color.white.opacity(0.08)).clipShape(Circle())
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(game?.name ?? "Free Fire Vn")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white).lineLimit(1)
                HStack(spacing: 5) {
                    Circle().fill(activeCountInGame > 0 ? Color.cyan : Color.green).frame(width: 5, height: 5)
                    Text(activeCountInGame > 0 ? "Đang bật \(activeCountInGame) tính năng" : "Sẵn sàng kích hoạt")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(activeCountInGame > 0 ? .cyan : .white.opacity(0.55))
                }
            }
            Spacer()

            SecureCatalogImage(urlString: game?.iconURL ?? "", placeholder: Image(systemName: "gamecontroller.fill"))
                .frame(width: 42, height: 42)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(
                            LinearGradient(colors: [.cyan, .white.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1.3
                        )
                )
                .shadow(color: .cyan.opacity(0.25), radius: 6)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: TABS
    private var tabsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(availableTabs) { tab in
                    let isSelected = selectedTabID == tab.id
                    let tabCount = (game?.items ?? []).filter { $0.hidden != true && $0.category.rawValue == tab.id }.count

                    Button {
                        iPhoneHaptics.shared.playTap()
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                            selectedTabID = tab.id
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: tab.icon).font(.system(size: 11.5, weight: .bold))
                            Text(tab.title.uppercased())
                                .font(.system(size: 12, weight: .heavy, design: .rounded))
                            Text("\(tabCount)")
                                .font(.system(size: 10, weight: .black, design: .rounded))
                                .foregroundColor(isSelected ? .cyan : .white.opacity(0.8))
                                .frame(width: 19, height: 19)
                                .background(isSelected ? Color.black.opacity(0.8) : Color.white.opacity(0.12))
                                .clipShape(Circle())
                        }
                        .foregroundColor(isSelected ? .black : .white.opacity(0.85))
                        .padding(.leading, 12).padding(.trailing, 7).padding(.vertical, 7.5)
                        .background(
                            ZStack {
                                if isSelected {
                                    Capsule()
                                        .fill(LinearGradient(
                                            colors: [Color(red: 0.22, green: 0.92, blue: 1.0), Color(red: 0.1, green: 0.78, blue: 0.96)],
                                            startPoint: .leading, endPoint: .trailing))
                                        .matchedGeometryEffect(id: "ACTIVE_CATEGORY_PILL", in: pillAnim)
                                        .shadow(color: .cyan.opacity(0.4), radius: 7)
                                } else {
                                    Capsule().fill(Color.white.opacity(0.055))
                                }
                            }
                        )
                        .overlay(Capsule().strokeBorder(isSelected ? Color.white.opacity(0.4) : Color.white.opacity(0.1), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 2)
        }
    }

    // MARK: SEARCH + FILTER
    private var searchFilterSection: some View {
        HStack(spacing: 9) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").font(.system(size: 13.5, weight: .medium)).foregroundColor(.white.opacity(0.4))
                TextField("Tìm tính năng...", text: $searchText)
                    .font(.system(size: 13.5)).foregroundColor(.white).tint(.cyan)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14)).foregroundColor(.white.opacity(0.4))
                    }
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(Color.white.opacity(0.055))
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(Color.white.opacity(0.09), lineWidth: 1))

            Button {
                iPhoneHaptics.shared.playTap()
                withAnimation(.spring(response: 0.26, dampingFraction: 0.78)) { onlyActiveFilter.toggle() }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: onlyActiveFilter ? "checkmark.circle.fill" : "circle").font(.system(size: 11))
                    Text("Đang bật").font(.system(size: 12, weight: .bold, design: .rounded))
                }
                .foregroundColor(onlyActiveFilter ? .black : .white.opacity(0.85))
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(onlyActiveFilter ? AnyView(Color.cyan) : AnyView(Color.white.opacity(0.06)))
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .strokeBorder(onlyActiveFilter ? Color.white.opacity(0.4) : Color.cyan.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
    }

    // MARK: GRID
    private var gridSection: some View {
        ScrollView(showsIndicators: false) {
            if items.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "tray").font(.system(size: 30, weight: .light)).foregroundColor(.white.opacity(0.3))
                    Text(onlyActiveFilter ? "Chưa có tính năng nào đang bật" : "Không có tính năng trong mục này")
                        .font(.system(size: 13.5, weight: .medium)).foregroundColor(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity).padding(.vertical, 48)
                .background(Color.white.opacity(0.035))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.white.opacity(0.07), lineWidth: 1))
                .padding(.horizontal, 16).padding(.top, 6)
            } else {
                LazyVGrid(columns: columns, spacing: 11) {
                    ForEach(items) { item in
                        ModernModCard(item: item, fallbackAvatarURL: authManager.publicAvatarURL)
                    }
                }
                .padding(.horizontal, 16).padding(.top, 2).padding(.bottom, 20)
            }
        }
    }

    // MARK: LAUNCH
    private var launchButton: some View {
        Button {
            guard isSessionActive else { return }
            iPhoneHaptics.shared.playLaunch()
            let rawLaunch = (game?.launchURL ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if let url = URL(string: rawLaunch), !rawLaunch.isEmpty { UIApplication.shared.open(url) }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "play.fill").font(.system(size: 13, weight: .black))
                Text("KHỞI ĐỘNG GAME")
                    .font(.system(size: 14, weight: .black, design: .rounded)).tracking(0.8)
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity).frame(height: 48)
            .background(LinearGradient(
                colors: [Color(red: 0.25, green: 0.93, blue: 1.0), Color(red: 0.1, green: 0.8, blue: 0.98)],
                startPoint: .leading, endPoint: .trailing))
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).strokeBorder(Color.white.opacity(0.4), lineWidth: 1))
            .shadow(color: .cyan.opacity(0.4), radius: 10, y: 3)
        }
        .buttonStyle(ClassicScaleButtonStyle())
        .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 6)
        .background(
            LinearGradient(colors: [Color.black.opacity(0.0), Color.black.opacity(0.85), Color.black], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
    }
}

// MARK: - MOD CARD (REDESIGN)
private struct ModernModCard: View {
    let item: GameCatalogItem
    let fallbackAvatarURL: String
    @StateObject private var store = GameCatalogStore.shared
    @StateObject private var authManager = CustomAuthManager.shared
    @State private var showDetailSheet = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""

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
        if !custom.isEmpty { return custom }
        return isVip ? "VIP" : "FREE"
    }
    private var isHighlightedBadge: Bool {
        let custom = (item.badge ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return !custom.isEmpty || isVip
    }
    private var hasGuide: Bool {
        !(item.usageGuide ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        || !(item.imageURL ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    private var cardAvatarURL: String {
        let itemImg = (item.imageURL ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return itemImg.isEmpty ? fallbackAvatarURL : itemImg
    }
    private var subtitleDisplay: String {
        let cleanSub = (item.subtitle ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanSub.isEmpty ? "Sẵn sàng kích hoạt" : cleanSub
    }

    var body: some View {
        let hasLink = !item.resolvedFileURLs.isEmpty
        let isOn = store.isMultiItemOn(item: item)
        let busy = store.isMultiItemBusy(item: item)

        VStack(alignment: .leading, spacing: 9) {
            // TOP: icon + badge + info
            HStack(spacing: 8) {
                ZStack {
                    if isOn {
                        Circle().fill(Color.cyan.opacity(0.28)).frame(width: 34, height: 34).blur(radius: 6)
                    }
                    SecureCatalogImage(urlString: cardAvatarURL, placeholder: Image(systemName: "bolt.fill"))
                        .frame(width: 30, height: 30).clipShape(Circle())
                        .overlay(Circle().strokeBorder(isOn ? Color.cyan : Color.white.opacity(0.2), lineWidth: 1.2))
                }
                Text(badgeLabel)
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .foregroundColor(isHighlightedBadge ? .black : .white.opacity(0.85))
                    .padding(.horizontal, 7).padding(.vertical, 2.5)
                    .background(
                        isHighlightedBadge
                        ? AnyView(LinearGradient(colors: [.cyan, .white], startPoint: .leading, endPoint: .trailing))
                        : AnyView(Color.white.opacity(0.14))
                    )
                    .clipShape(Capsule())
                Spacer(minLength: 0)
                Button {
                    iPhoneHaptics.shared.playTap()
                    showDetailSheet = true
                } label: {
                    Image(systemName: "info.circle.fill").font(.system(size: 15)).foregroundColor(.cyan.opacity(0.9))
                }
                .buttonStyle(.plain)
            }

            // MIDDLE: name + status dot
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 13.5, weight: .bold, design: .rounded))
                    .foregroundColor(.white).lineLimit(1)
                HStack(spacing: 4) {
                    Circle()
                        .fill(busy ? Color.yellow : (isOn ? Color.cyan : Color.white.opacity(0.3)))
                        .frame(width: 5, height: 5)
                    Text(busy ? "Đang nạp..." : (isOn ? "Đang bật" : subtitleDisplay))
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundColor(busy ? .yellow : (isOn ? .cyan : .white.opacity(0.5)))
                        .lineLimit(1)
                }
            }

            // BUTTON
            Button {
                guard !busy, (hasLink || isOn) else { return }
                toggleFeature(currentlyOn: isOn)
            } label: {
                HStack(spacing: 5) {
                    if busy {
                        ProgressView().tint(isOn ? .black : .cyan).scaleEffect(0.7)
                        Text("ĐANG NẠP").font(.system(size: 11, weight: .black, design: .rounded))
                    } else {
                        Image(systemName: isOn ? "checkmark.circle.fill" : "power")
                            .font(.system(size: 11, weight: .black))
                        Text(isOn ? "ĐANG BẬT" : "KÍCH HOẠT")
                            .font(.system(size: 11.5, weight: .black, design: .rounded)).tracking(0.2)
                    }
                }
                .foregroundColor(isOn ? .black : Color(red: 0.25, green: 0.92, blue: 1.0))
                .frame(maxWidth: .infinity).frame(height: 32)
                .background(
                    Group {
                        if isOn {
                            LinearGradient(colors: [Color(red: 0.25, green: 0.93, blue: 1.0), .white], startPoint: .leading, endPoint: .trailing)
                        } else {
                            Color.cyan.opacity(0.12)
                        }
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(isOn ? Color.white.opacity(0.55) : Color.cyan.opacity(0.35), lineWidth: 1)
                )
                .shadow(color: isOn ? .cyan.opacity(0.4) : .clear, radius: 5)
            }
            .buttonStyle(ClassicScaleButtonStyle())
            .disabled(busy || (!hasLink && !isOn))
        }
        .padding(11)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: isOn
                            ? [Color.cyan.opacity(0.16), Color(white: 0.07)]
                            : [Color.white.opacity(0.06), Color.white.opacity(0.03)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    isOn
                    ? LinearGradient(colors: [.cyan, .white.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    : LinearGradient(colors: [Color.white.opacity(0.12), Color.white.opacity(0.04)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: isOn ? 1.2 : 0.9
                )
        )
        .shadow(color: isOn ? .cyan.opacity(0.18) : .clear, radius: 6, y: 2)
        .opacity(hasLink ? 1 : 0.5)
        .animation(.spring(response: 0.25, dampingFraction: 0.76), value: isOn)
        .onChange(of: isSessionActive) { active in
            if !active { showDetailSheet = false; showErrorAlert = false }
        }
        .sheet(isPresented: $showDetailSheet) { ModDetailSheet(item: item) }
        .alert("Lỗi kích hoạt Mod", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: { Text(errorMessage) }
    }

    private func toggleFeature(currentlyOn: Bool) {
        if currentlyOn {
            iPhoneHaptics.shared.playTickOff()
            Task { await store.setMultiEnabled(false, item: item) }
            return
        }
        guard isSessionActive else { return }
        iPhoneHaptics.shared.playTickOn()
        Task {
            await store.setMultiEnabled(true, item: item)
            if !authManager.isAuthorized || authManager.isInteractionLocked || store.catalog.resolvedMaintenanceEnabled {
                await store.setMultiEnabled(false, item: item)
                return
            }
            if let error = store.lastError {
                errorMessage = error; showErrorAlert = true
            } else if hasGuide {
                showDetailSheet = true
            }
        }
    }
}

// MARK: - POPUP CHI TIẾT MOD
struct ModDetailSheet: View {
    let item: GameCatalogItem
    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = GameCatalogStore.shared
    @StateObject private var authManager = CustomAuthManager.shared
    @State private var copied = false

    private var isYouTubeLink: Bool {
        let guide = (item.usageGuide ?? "").lowercased()
        return guide.contains("youtube.com") || guide.contains("youtu.be")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ModernBackground(urlString: authManager.publicBackgroundURL)
                ScrollView {
                    VStack(spacing: 18) {
                        if let imgURL = item.imageURL, !imgURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            SecureCatalogImage(urlString: imgURL, placeholder: Image(systemName: "photo"))
                                .frame(maxWidth: .infinity).frame(height: 235)
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.cyan.opacity(0.35), lineWidth: 1))
                        }
                        if let guide = item.usageGuide, !guide.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "text.book.closed.fill").foregroundColor(.cyan)
                                    Text("Hướng dẫn sử dụng").font(.headline).foregroundColor(.white)
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
                                    .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.white.opacity(0.06))
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
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
                                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                                        .background(LinearGradient(colors: [.red, .red.opacity(0.8)], startPoint: .leading, endPoint: .trailing))
                                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        if (item.imageURL ?? "").isEmpty && (item.usageGuide ?? "").isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "doc.questionmark").font(.system(size: 44)).foregroundColor(.white.opacity(0.3))
                                Text("Chưa có hướng dẫn cho tính năng này").foregroundColor(.white.opacity(0.6))
                            }
                            .padding(.top, 50)
                        }
                    }
                    .padding(20)
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
            .onChange(of: authManager.isAuthorized) { authorized in if !authorized { dismiss() } }
            .onChange(of: store.catalog.resolvedMaintenanceEnabled) { isMaintenance in if isMaintenance { dismiss() } }
        }
    }
}
