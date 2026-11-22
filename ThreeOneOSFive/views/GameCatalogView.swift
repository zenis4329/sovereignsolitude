import SwiftUI
import UIKit
import AudioToolbox

// MARK: - ÂM THANH "TÍCH" & TAPTIC ENGINE CHUẨN IPHONE (0ms LATENCY)
final class iPhoneHaptics {
    static let shared = iPhoneHaptics()
    
    private let rigidGenerator = UIImpactFeedbackGenerator(style: .rigid)
    private let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
    
    private init() {
        rigidGenerator.prepare()
        lightGenerator.prepare()
        heavyGenerator.prepare()
    }
    
    /// Tiếng "tích" đanh gọn chuẩn iOS khi bật tính năng
    func playTickOn() {
        AudioServicesPlaySystemSound(1057) // Tink.caf gốc của iOS
        rigidGenerator.impactOccurred(intensity: 1.0)
        rigidGenerator.prepare()
    }
    
    /// Tiếng "tắc" nhẹ khi tắt tính năng
    func playTickOff() {
        AudioServicesPlaySystemSound(1104) // Tock.caf gốc của iOS
        lightGenerator.impactOccurred(intensity: 0.75)
        lightGenerator.prepare()
    }
    
    /// Tiếng chạm phím nhẹ khi chuyển tab / mở chi tiết
    func playTap() {
        AudioServicesPlaySystemSound(1104)
        lightGenerator.impactOccurred(intensity: 0.55)
        lightGenerator.prepare()
    }
    
    /// Phản hồi đầm chắc khi khởi động game
    func playLaunch() {
        AudioServicesPlaySystemSound(1057)
        heavyGenerator.impactOccurred(intensity: 1.0)
        heavyGenerator.prepare()
    }
}

// MARK: - CACHE ẢNH RAM SIÊU TỐC
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
            Color.white.opacity(0.04)
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity.animation(.easeOut(duration: 0.2)))
            } else {
                placeholder
                    .resizable()
                    .scaledToFit()
                    .padding(11)
                    .foregroundColor(.white.opacity(0.28))
                    .overlay(
                        ProgressView()
                            .tint(.white.opacity(0.7))
                            .scaleEffect(0.7)
                            .opacity(isLoading ? 1 : 0)
                    )
            }
        }
        .clipped()
        .onAppear { loadImage() }
        .onChange(of: urlString) { _ in
            image = nil
            isLoading = true
            loadImage()
        }
    }
    
    private func loadImage() {
        let cleanUrl = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanUrl.isEmpty else {
            isLoading = false
            return
        }
        if let cached = CatalogImageCache.shared.object(forKey: cleanUrl as NSString) {
            self.image = cached
            self.isLoading = false
            return
        }
        guard !SecureNetworkManager.shared.isProxyEnabled(), let url = URL(string: cleanUrl) else {
            isLoading = false
            return
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

// MARK: - MÀN HÌNH CHÍNH (OLED MINIMAL HUB)
struct GameCatalogView: View {
    @StateObject private var store = GameCatalogStore.shared
    @StateObject private var authManager = CustomAuthManager.shared
    @Binding var isTabBarHidden: Bool
    
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
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                // Nền mờ tối giản tạo chiều sâu tự nhiên
                GeometryReader { geo in
                    SecureCatalogImage(urlString: authManager.publicBackgroundURL, placeholder: Image(systemName: "sparkles"))
                        .frame(width: geo.size.width, height: geo.size.height)
                        .blur(radius: 28)
                        .opacity(0.22)
                        .overlay(
                            LinearGradient(
                                colors: [Color.black.opacity(0.3), Color.black.opacity(0.88), Color.black],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .ignoresSafeArea()
                
                // Điểm sáng nhẹ phía đỉnh màn hình
                RadialGradient(
                    colors: [Color.white.opacity(0.08), Color.clear],
                    center: .top,
                    startRadius: 10,
                    endRadius: 340
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 22) {
                        // HEADER GỌN CHUẨN IOS
                        HStack(spacing: 13) {
                            SecureCatalogImage(urlString: authManager.publicAvatarURL, placeholder: Image(systemName: "person.crop.circle.fill"))
                                .frame(width: 48, height: 48)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
                                )
                            
                            VStack(alignment: .leading, spacing: 3) {
                                Text(authManager.publicAppName.isEmpty ? "Sovereign Solitude" : authManager.publicAppName)
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 6, height: 6)
                                    Text(totalEnabledMods > 0 ? "Đang bật \(totalEnabledMods) tính năng" : "Sẵn sàng hoạt động")
                                        .font(.system(size: 12.5, weight: .medium))
                                        .foregroundColor(totalEnabledMods > 0 ? .white.opacity(0.9) : .white.opacity(0.5))
                                }
                            }
                            
                            Spacer()
                            
                            if totalEnabledMods > 0 {
                                Button {
                                    iPhoneHaptics.shared.playTickOff()
                                    withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                                        store.disableAllEnabledMods()
                                    }
                                } label: {
                                    Text("Tắt hết")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 7)
                                        .background(Color.white.opacity(0.12))
                                        .clipShape(Capsule())
                                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 0.8))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 14)
                        
                        // DANH SÁCH TRÒ CHƠI
                        VStack(alignment: .leading, spacing: 11) {
                            Text("Danh sách trò chơi")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.5))
                                .padding(.horizontal, 20)
                            
                            if store.catalog.orderedGames.isEmpty {
                                VStack(spacing: 10) {
                                    Image(systemName: "gamecontroller")
                                        .font(.system(size: 26))
                                        .foregroundColor(.white.opacity(0.3))
                                    Text("Chưa có trò chơi nào")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white.opacity(0.5))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 44)
                                .background(Color(white: 0.07))
                                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.8)
                                )
                                .padding(.horizontal, 16)
                            } else {
                                VStack(spacing: 10) {
                                    ForEach(store.catalog.orderedGames) { game in
                                        NavigationLink(destination: GameDetailView(gameID: game.id, isTabBarHidden: $isTabBarHidden)) {
                                            CleanGameRowCard(game: game)
                                        }
                                        .buttonStyle(NativeSpringPressStyle())
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
                        .padding(.bottom, 100)
                    }
                }
                .disabled(!isSessionActive)
                .allowsHitTesting(isSessionActive)
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                store.rememberCatalogItems()
                if !authManager.isAuthorized || store.catalog.resolvedMaintenanceEnabled {
                    store.disableAllEnabledMods()
                }
            }
            .onChange(of: store.catalog.games.count) { _ in
                store.rememberCatalogItems()
            }
            .onChange(of: authManager.isAuthorized) { authorized in
                if !authorized {
                    isTabBarHidden = false
                    store.disableAllEnabledMods()
                }
            }
            .onChange(of: store.catalog.resolvedMaintenanceEnabled) { isMaintenance in
                if isMaintenance {
                    isTabBarHidden = false
                    store.disableAllEnabledMods()
                }
            }
        }
    }
}

// MARK: - THẺ GAME GỌN ĐẸP CHUẨN APPLE
private struct CleanGameRowCard: View {
    let game: GameCatalogGame
    @StateObject private var store = GameCatalogStore.shared
    
    private var activeVisibleItemsCount: Int {
        game.items.filter { $0.hidden != true }.count
    }
    
    private var enabledModCount: Int {
        game.items
            .filter { $0.hidden != true }
            .filter { store.isMultiItemOn(item: $0) }
            .count
    }
    
    var body: some View {
        HStack(spacing: 14) {
            SecureCatalogImage(urlString: game.iconURL ?? "", placeholder: Image(systemName: "gamecontroller.fill"))
                .frame(width: 54, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.16), lineWidth: 0.8)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(game.name)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    Text("\(activeVisibleItemsCount) chức năng")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.5))
                    
                    if enabledModCount > 0 {
                        Text("• \(enabledModCount) đang bật")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundColor(.cyan)
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.45))
                .frame(width: 30, height: 30)
                .background(Color.white.opacity(0.07))
                .clipShape(Circle())
        }
        .padding(13)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(white: 0.075))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.22), Color.white.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
        )
    }
}

// MARK: - HIỆU ỨNG NHÚN LÒ XO TỰ NHIÊN
struct NativeSpringPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.965 : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.24, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

// MARK: - MÀN HÌNH CHI TIẾT GAME (CONTROL CENTER 2 CỘT SIÊU GỌN)
private struct GameDetailView: View {
    let gameID: String
    @Binding var isTabBarHidden: Bool
    @StateObject private var store = GameCatalogStore.shared
    @StateObject private var authManager = CustomAuthManager.shared
    @State private var selectedTabID = "aim"
    @State private var searchText = ""
    @State private var showSearch = false
    @State private var onlyActive = false
    @Namespace private var tabHighlight
    @Environment(\.dismiss) private var dismiss

    private var catalog: GameCatalog { store.catalog }
    private var game: GameCatalogGame? { catalog.games.first(where: { $0.id == gameID }) }
    
    private var isSessionActive: Bool {
        authManager.isAuthorized
        && !authManager.isInteractionLocked
        && !store.catalog.resolvedMaintenanceEnabled
    }
    
    private var items: [GameCatalogItem] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return (game?.items ?? [])
            .filter { $0.hidden != true && $0.category.rawValue == selectedTabID }
            .filter { item in
                if onlyActive && !store.isMultiItemOn(item: item) { return false }
                if q.isEmpty { return true }
                return item.name.lowercased().contains(q)
                    || (item.subtitle ?? "").lowercased().contains(q)
            }
            .sorted { ($0.order ?? Int.max) < ($1.order ?? Int.max) }
    }
    
    private var activeCountInGame: Int {
        (game?.items ?? [])
            .filter { $0.hidden != true && store.isMultiItemOn(item: $0) }
            .count
    }
    
    private var availableTabs: [GameCatalogTab] {
        let fallbackTabs: [GameCatalogTab] = catalog.resolvedTabs
        guard let game else { return fallbackTabs }
        let ownTabs = game.resolvedTabs(fallback: fallbackTabs)
        guard let selected = game.tabIDs else { return ownTabs }
        return ownTabs.filter { selected.contains($0.id) }
    }
    
    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // Nền mờ tối giản đồng bộ
            GeometryReader { geo in
                SecureCatalogImage(urlString: authManager.publicBackgroundURL, placeholder: Image(systemName: "photo"))
                    .frame(width: geo.size.width, height: geo.size.height)
                    .blur(radius: 30)
                    .opacity(0.2)
                    .overlay(
                        LinearGradient(
                            colors: [Color.black.opacity(0.35), Color.black.opacity(0.92), Color.black],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .ignoresSafeArea()
            
            VStack(spacing: 12) {
                // 1. TOP NAVIGATION BAR GỌN GÀNG
                HStack(spacing: 10) {
                    Button {
                        iPhoneHaptics.shared.playTap()
                        withAnimation(.easeInOut(duration: 0.2)) { isTabBarHidden = false }
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Color(white: 0.1))
                            .clipShape(Circle())
                            .overlay(Circle().strokeBorder(Color.white.opacity(0.14), lineWidth: 0.8))
                    }
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text(game?.name ?? "Tính năng")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Text(activeCountInGame > 0 ? "Đang bật \(activeCountInGame) tính năng" : "Chạm ô để bật hoặc tắt")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(activeCountInGame > 0 ? .cyan : .white.opacity(0.45))
                    }
                    
                    Spacer()
                    
                    // Nút Tắt hết (chỉ hiện khi có mục đang bật)
                    if activeCountInGame > 0 {
                        Button {
                            iPhoneHaptics.shared.playTickOff()
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                                store.disableAllEnabledMods()
                            }
                        } label: {
                            Text("Tắt hết")
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(Color.white.opacity(0.12))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Nút lọc nhanh mục đang bật
                    Button {
                        iPhoneHaptics.shared.playTap()
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                            onlyActive.toggle()
                        }
                    } label: {
                        Text("\(activeCountInGame)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(onlyActive ? .black : .white)
                            .frame(width: 34, height: 34)
                            .background(onlyActive ? Color.white : Color(white: 0.1))
                            .clipShape(Circle())
                            .overlay(Circle().strokeBorder(Color.white.opacity(0.14), lineWidth: 0.8))
                    }
                    .buttonStyle(.plain)
                    
                    // Nút tìm kiếm
                    Button {
                        iPhoneHaptics.shared.playTap()
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                            showSearch.toggle()
                            if !showSearch { searchText = "" }
                        }
                    } label: {
                        Image(systemName: showSearch ? "xmark" : "magnifyingglass")
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 34, height: 34)
                            .background(Color(white: 0.1))
                            .clipShape(Circle())
                            .overlay(Circle().strokeBorder(Color.white.opacity(0.14), lineWidth: 0.8))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                
                // THANH TÌM KIẾM THU GỌN
                if showSearch {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.45))
                        TextField("Tìm tính năng...", text: $searchText)
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                            .tint(.white)
                        if !searchText.isEmpty {
                            Button { searchText = "" } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.white.opacity(0.4))
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Color(white: 0.09))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8)
                    )
                    .padding(.horizontal, 16)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // 2. THANH DANH MỤC SEGMENTED PILL GỌN MẮT
                Group {
                    if availableTabs.count <= 3 {
                        HStack(spacing: 4) {
                            ForEach(availableTabs) { tab in
                                categoryTabPill(tab: tab, stretch: true)
                            }
                        }
                        .padding(4)
                        .background(Color(white: 0.08))
                        .clipShape(Capsule())
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.1), lineWidth: 0.8))
                        .padding(.horizontal, 16)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(availableTabs) { tab in
                                    categoryTabPill(tab: tab, stretch: false)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                }
                
                // 3. LƯỚI CONTROL CENTER 2 CỘT (HIỂN THỊ 8-10 Ô CÙNG LÚC)
                ScrollView(showsIndicators: false) {
                    if items.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "tray")
                                .font(.system(size: 26))
                                .foregroundColor(.white.opacity(0.3))
                            Text(onlyActive ? "Chưa có tính năng nào đang bật" : "Không có tính năng trong mục này")
                                .font(.system(size: 13.5, weight: .medium))
                                .foregroundColor(.white.opacity(0.45))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 48)
                        .background(Color(white: 0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.8)
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 6)
                    } else {
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(items) { item in
                                ControlCenterModTile(item: item)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 2)
                        .padding(.bottom, 24)
                    }
                }
            }
            // DOCK KHỞI ĐỘNG GAME NỔI GỌN DƯỚI ĐÁY
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 10) {
                    SecureCatalogImage(urlString: game?.iconURL ?? "", placeholder: Image(systemName: "gamecontroller.fill"))
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.2), lineWidth: 0.8))
                    
                    Button {
                        guard isSessionActive else { return }
                        iPhoneHaptics.shared.playLaunch()
                        let rawLaunch = (game?.launchURL ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                        if let url = URL(string: rawLaunch), !rawLaunch.isEmpty {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 13, weight: .bold))
                            Text("Khởi động Game")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.white)
                        .clipShape(Capsule())
                        .shadow(color: .white.opacity(0.22), radius: 10, y: 2)
                    }
                    .buttonStyle(NativeSpringPressStyle())
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.16), lineWidth: 0.8))
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
            }
        }
        .disabled(!isSessionActive)
        .allowsHitTesting(isSessionActive)
        .navigationBarHidden(true)
        .onAppear {
            store.rememberCatalogItems()
            if store.catalog.resolvedMaintenanceEnabled {
                store.disableAllEnabledMods()
                withAnimation { isTabBarHidden = false }
                dismiss()
                return
            }
            withAnimation { isTabBarHidden = true }
            if !availableTabs.contains(where: { $0.id == selectedTabID }) {
                selectedTabID = availableTabs.first?.id ?? "aim"
            }
        }
        .onDisappear {
            withAnimation { isTabBarHidden = false }
        }
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
    
    @ViewBuilder
    private func categoryTabPill(tab: GameCatalogTab, stretch: Bool) -> some View {
        let isSelected = selectedTabID == tab.id
        Button {
            iPhoneHaptics.shared.playTap()
            withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                selectedTabID = tab.id
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: tab.icon)
                    .font(.system(size: 11.5, weight: .semibold))
                Text(tab.title)
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundColor(isSelected ? .black : .white.opacity(0.68))
            .frame(maxWidth: stretch ? .infinity : nil)
            .padding(.horizontal, stretch ? 8 : 14)
            .padding(.vertical, 8.5)
            .background(
                ZStack {
                    if isSelected {
                        Capsule()
                            .fill(Color.white)
                            .matchedGeometryEffect(id: "ACTIVE_TAB_PILL", in: tabHighlight)
                            .shadow(color: .white.opacity(0.25), radius: 6)
                    } else if !stretch {
                        Capsule()
                            .fill(Color(white: 0.09))
                    }
                }
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - MODULE CONTROL CENTER 2 CỘT (GỌN, SANG, CHẠM BẬT/TẮT TIẾNG TÍCH IPHONE)
private struct ControlCenterModTile: View {
    let item: GameCatalogItem
    @StateObject private var store = GameCatalogStore.shared
    @StateObject private var authManager = CustomAuthManager.shared
    @State private var showDetailSheet = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var sheenOffset: CGFloat = -160
    @State private var isPressed = false
    
    private var isSessionActive: Bool {
        authManager.isAuthorized
        && !authManager.isInteractionLocked
        && !store.catalog.resolvedMaintenanceEnabled
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
    
    private var subtitleDisplay: String {
        let cleanSub = (item.subtitle ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanSub.isEmpty ? "Chạm để bật" : cleanSub
    }
    
    var body: some View {
        let hasLink = !item.resolvedFileURLs.isEmpty
        let isOn = store.isMultiItemOn(item: item)
        let busy = store.isMultiItemBusy(item: item)
        
        VStack(alignment: .leading, spacing: 8) {
            // HÀNG TRÊN: NÚT NGUỒN CONTROL CENTER + NHÃN + HDSD
            HStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(isOn ? Color.white : Color.white.opacity(0.09))
                        .frame(width: 28, height: 28)
                        .shadow(color: isOn ? .white.opacity(0.45) : .clear, radius: 6)
                    
                    if busy {
                        ProgressView()
                            .tint(isOn ? .black : .white)
                            .scaleEffect(0.68)
                    } else {
                        Image(systemName: isOn ? "checkmark" : "power")
                            .font(.system(size: 11.5, weight: .bold))
                            .foregroundColor(isOn ? .black : .white.opacity(0.75))
                    }
                }
                
                Text(badgeLabel)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(isHighlightedBadge ? .black : .white.opacity(0.75))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2.5)
                    .background(isHighlightedBadge ? Color.white : Color.white.opacity(0.12))
                    .clipShape(Capsule())
                
                Spacer(minLength: 0)
                
                if hasGuide {
                    Button {
                        iPhoneHaptics.shared.playTap()
                        showDetailSheet = true
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Spacer(minLength: 2)
            
            // HÀNG DƯỚI: TÊN CHỨC NĂNG & TRẠNG THÁI
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text(busy ? "Đang tải..." : (isOn ? "Đang bật" : subtitleDisplay))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(busy ? .yellow : (isOn ? .cyan : .white.opacity(0.42)))
                    .lineLimit(1)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 94, alignment: .leading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(isOn ? Color(white: 0.13) : Color(white: 0.07))
                
                if isOn {
                    LinearGradient(
                        colors: [Color.white.opacity(0.12), Color.cyan.opacity(0.08), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    
                    // Dải sáng lướt mượt qua mặt kính khi kích hoạt
                    LinearGradient(
                        colors: [.clear, Color.white.opacity(0.28), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: 65)
                    .rotationEffect(.degrees(20))
                    .offset(x: sheenOffset)
                    .allowsHitTesting(false)
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(
                    isOn
                    ? LinearGradient(colors: [Color.white.opacity(0.85), Color.cyan.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    : LinearGradient(colors: [Color.white.opacity(0.16), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: isOn ? 1.2 : 0.8
                )
        )
        .shadow(color: isOn ? .white.opacity(0.14) : .clear, radius: 10, y: 3)
        .scaleEffect(isPressed ? 0.96 : 1.0)
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 0.01, pressing: { pressing in
            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                isPressed = pressing
            }
        }, perform: {})
        .onTapGesture {
            guard !busy, (hasLink || isOn) else { return }
            toggleFeature(currentlyOn: isOn)
        }
        .opacity(hasLink ? 1 : 0.45)
        .animation(.spring(response: 0.26, dampingFraction: 0.76), value: isOn)
        .onChange(of: isOn) { active in
            if active {
                sheenOffset = -150
                withAnimation(.easeOut(duration: 0.45)) {
                    sheenOffset = 180
                }
            }
        }
        .onChange(of: isSessionActive) { active in
            if !active {
                showDetailSheet = false
                showErrorAlert = false
            }
        }
        .sheet(isPresented: $showDetailSheet) {
            ModDetailSheet(item: item)
        }
        .alert("Lỗi kích hoạt", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func toggleFeature(currentlyOn: Bool) {
        if currentlyOn {
            iPhoneHaptics.shared.playTickOff()
            Task { await store.setMultiEnabled(false, item: item) }
            return
        }
        
        guard isSessionActive else { return }
        
        // Tiếng "tích" & Taptic cứng chuẩn iPhone
        iPhoneHaptics.shared.playTickOn()
        
        Task {
            await store.setMultiEnabled(true, item: item)
            
            if !authManager.isAuthorized || authManager.isInteractionLocked || store.catalog.resolvedMaintenanceEnabled {
                await store.setMultiEnabled(false, item: item)
                return
            }
            
            if let error = store.lastError {
                errorMessage = error
                showErrorAlert = true
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
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 18) {
                        if let imgURL = item.imageURL, !imgURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            SecureCatalogImage(urlString: imgURL, placeholder: Image(systemName: "photo"))
                                .frame(maxWidth: .infinity)
                                .frame(height: 230)
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.8)
                                )
                        }
                        
                        if let guide = item.usageGuide, !guide.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Hướng dẫn sử dụng")
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                    Spacer()
                                    Button {
                                        iPhoneHaptics.shared.playTickOn()
                                        UIPasteboard.general.string = guide
                                        copied = true
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                            Text(copied ? "Đã chép" : "Sao chép")
                                        }
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(copied ? .black : .white)
                                        .padding(.horizontal, 11)
                                        .padding(.vertical, 6)
                                        .background(copied ? Color.white : Color.white.opacity(0.12))
                                        .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                                
                                Text(guide)
                                    .font(.system(size: 14.5))
                                    .foregroundColor(.white.opacity(0.88))
                                    .padding(14)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(white: 0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.8)
                                    )
                                
                                if isYouTubeLink {
                                    Button {
                                        iPhoneHaptics.shared.playTap()
                                        if let url = URL(string: guide.trimmingCharacters(in: .whitespacesAndNewlines)) {
                                            UIApplication.shared.open(url)
                                        }
                                    } label: {
                                        HStack(spacing: 8) {
                                            Image(systemName: "play.rectangle.fill")
                                            Text("Mở video hướng dẫn")
                                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                        }
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(Color.red)
                                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        
                        if (item.imageURL ?? "").isEmpty && (item.usageGuide ?? "").isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "doc.text")
                                    .font(.system(size: 40))
                                    .foregroundColor(.white.opacity(0.25))
                                Text("Chưa có hướng dẫn cho tính năng này")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.5))
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
                    Button("Xong") {
                        iPhoneHaptics.shared.playTap()
                        dismiss()
                    }
                    .foregroundColor(.white)
                    .font(.system(size: 15, weight: .semibold))
                }
            }
            .onChange(of: authManager.isAuthorized) { authorized in
                if !authorized { dismiss() }
            }
            .onChange(of: store.catalog.resolvedMaintenanceEnabled) { isMaintenance in
                if isMaintenance { dismiss() }
            }
        }
    }
}
