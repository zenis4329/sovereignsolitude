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
            Color.white.opacity(0.05)
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity.animation(.easeOut(duration: 0.2)))
            } else {
                placeholder
                    .resizable()
                    .scaledToFit()
                    .padding(7)
                    .foregroundColor(.white.opacity(0.35))
                    .overlay(
                        ProgressView()
                            .tint(.cyan)
                            .scaleEffect(0.65)
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

// MARK: - MÀN HÌNH CHÍNH (BỐ CỤC GỐC MAKE LẠI SANG & GỌN)
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
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.02, green: 0.025, blue: 0.04)
                    .ignoresSafeArea()
                
                // BACKGROUND MỜ TẠO CHIỀU SÂU
                GeometryReader { geo in
                    SecureCatalogImage(urlString: authManager.publicBackgroundURL, placeholder: Image(systemName: "sparkles"))
                        .frame(width: geo.size.width, height: geo.size.height)
                        .opacity(0.45)
                        .overlay(
                            LinearGradient(
                                colors: [
                                    Color.black.opacity(0.35),
                                    Color(red: 0.02, green: 0.03, blue: 0.05).opacity(0.85),
                                    Color.black.opacity(0.96)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 22) {
                        // AVATAR + TÊN THƯƠNG HIỆU TRUNG TÂM
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.cyan.opacity(0.18))
                                    .frame(width: 108, height: 108)
                                    .blur(radius: 18)
                                
                                Circle()
                                    .stroke(
                                        AngularGradient(colors: [.cyan, .white, .blue, .cyan], center: .center),
                                        lineWidth: 2.5
                                    )
                                    .frame(width: 92, height: 92)
                                    .rotationEffect(.degrees(isRotating ? 360 : 0))
                                    .animation(.linear(duration: 4.5).repeatForever(autoreverses: false), value: isRotating)
                                    .drawingGroup()
                                
                                SecureCatalogImage(urlString: authManager.publicAvatarURL, placeholder: Image(systemName: "person.crop.circle.fill"))
                                    .frame(width: 82, height: 82)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
                            }
                            .padding(.top, 16)
                            
                            VStack(spacing: 6) {
                                Text(authManager.publicAppName.isEmpty ? "Sovereign Solitude" : authManager.publicAppName)
                                    .font(.system(size: 24, weight: .black, design: .rounded))
                                    .foregroundColor(.white)
                                    .shadow(color: .cyan.opacity(0.3), radius: 8)
                                
                                HStack(spacing: 8) {
                                    HStack(spacing: 5) {
                                        Circle()
                                            .fill(Color.green)
                                            .frame(width: 6.5, height: 6.5)
                                        Text("Sẵn sàng kích hoạt")
                                            .font(.system(size: 11.5, weight: .semibold))
                                            .foregroundColor(.white.opacity(0.8))
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.white.opacity(0.08))
                                    .clipShape(Capsule())
                                    
                                    if totalEnabledMods > 0 {
                                        Button {
                                            iPhoneHaptics.shared.playTickOff()
                                            withAnimation(.spring(response: 0.26, dampingFraction: 0.8)) {
                                                store.disableAllEnabledMods()
                                            }
                                        } label: {
                                            Text("Tắt hết (\(totalEnabledMods))")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundColor(.black)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 4)
                                                .background(Color.cyan)
                                                .clipShape(Capsule())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        
                        // DANH SÁCH GAME
                        VStack(spacing: 12) {
                            if store.catalog.orderedGames.isEmpty {
                                VStack(spacing: 10) {
                                    Image(systemName: "gamecontroller")
                                        .font(.system(size: 28))
                                        .foregroundColor(.white.opacity(0.35))
                                    Text("Chưa có trò chơi nào được cấu hình")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white.opacity(0.55))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 44)
                                .background(Color.white.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                                )
                                .padding(.horizontal, 16)
                            } else {
                                ForEach(store.catalog.orderedGames) { game in
                                    NavigationLink(destination: GameDetailView(gameID: game.id, isTabBarHidden: $isTabBarHidden)) {
                                        ClassicMakeoverGameCard(game: game)
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
                        .padding(.bottom, 100)
                    }
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

// MARK: - THẺ GAME MÀN HÌNH CHÍNH
private struct ClassicMakeoverGameCard: View {
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
                .frame(width: 58, height: 58)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            LinearGradient(colors: [.cyan, .white.opacity(0.25)], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1.3
                        )
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(game.name)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    Text("\(activeVisibleItemsCount) chức năng")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.55))
                    
                    if enabledModCount > 0 {
                        Text("• \(enabledModCount) đang bật")
                            .font(.system(size: 12.5, weight: .bold))
                            .foregroundColor(.cyan)
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.black)
                .frame(width: 34, height: 34)
                .background(
                    LinearGradient(colors: [Color(red: 0.25, green: 0.92, blue: 1.0), .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .clipShape(Circle())
                .shadow(color: .cyan.opacity(0.45), radius: 6)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.055))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.cyan.opacity(0.55), Color.white.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

// MARK: - HIỆU ỨNG NHÚN NHẸ
struct ClassicScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

// MARK: - MÀN HÌNH CHI TIẾT GAME (ĐÚNG BỐ CỤC BAN ĐẦU - MAKE LẠI SẮC NÉT & MƯỢT)
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
        authManager.isAuthorized
        && !authManager.isInteractionLocked
        && !store.catalog.resolvedMaintenanceEnabled
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
        GridItem(.flexible(), spacing: 11),
        GridItem(.flexible(), spacing: 11)
    ]

    var body: some View {
        ZStack {
            Color(red: 0.02, green: 0.025, blue: 0.04)
                .ignoresSafeArea()
            
            // NỀN MỜ ĐỒNG BỘ
            GeometryReader { geo in
                SecureCatalogImage(urlString: authManager.publicBackgroundURL, placeholder: Image(systemName: "photo"))
                    .frame(width: geo.size.width, height: geo.size.height)
                    .opacity(0.38)
                    .overlay(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.45),
                                Color(red: 0.02, green: 0.03, blue: 0.05).opacity(0.88),
                                Color.black.opacity(0.97)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .ignoresSafeArea()
            
            VStack(spacing: 12) {
                // 1. HEADER GỐC: NÚT BACK + TÊN GAME & TRẠNG THÁI + ICON GAME BÊN PHẢI
                HStack(spacing: 12) {
                    Button {
                        iPhoneHaptics.shared.playTap()
                        withAnimation(.easeInOut(duration: 0.2)) { isTabBarHidden = false }
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 38, height: 38)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                            .overlay(Circle().strokeBorder(Color.white.opacity(0.16), lineWidth: 1))
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(game?.name ?? "Free Fire Vn")
                            .font(.system(size: 19, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Text(activeCountInGame > 0 ? "Đang bật \(activeCountInGame) tính năng" : "Sẵn sàng kích hoạt")
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundColor(activeCountInGame > 0 ? .cyan : .white.opacity(0.55))
                    }
                    
                    Spacer()
                    
                    // Icon Game tròn góc phải như ảnh gốc
                    SecureCatalogImage(urlString: game?.iconURL ?? "", placeholder: Image(systemName: "gamecontroller.fill"))
                        .frame(width: 42, height: 42)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .strokeBorder(
                                    LinearGradient(colors: [.cyan, .white.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                    lineWidth: 1.4
                                )
                        )
                        .shadow(color: .cyan.opacity(0.25), radius: 6)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                
                // 2. THANH DANH MỤC PILL CUỘN NGANG CÓ SỐ ĐẾM (AIM LOCK 9 | MOD SKIN 5 | MOD KEO 0)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 9) {
                        ForEach(availableTabs) { tab in
                            let isSelected = selectedTabID == tab.id
                            let tabCount = (game?.items ?? []).filter { $0.hidden != true && $0.category.rawValue == tab.id }.count
                            
                            Button {
                                iPhoneHaptics.shared.playTap()
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                                    selectedTabID = tab.id
                                }
                            } label: {
                                HStack(spacing: 7) {
                                    Image(systemName: tab.icon)
                                        .font(.system(size: 12, weight: .bold))
                                    
                                    Text(tab.title.uppercased())
                                        .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                                    
                                    Text("\(tabCount)")
                                        .font(.system(size: 10.5, weight: .black, design: .rounded))
                                        .foregroundColor(isSelected ? .cyan : .white.opacity(0.85))
                                        .frame(width: 20, height: 20)
                                        .background(isSelected ? Color.black.opacity(0.82) : Color.white.opacity(0.14))
                                        .clipShape(Circle())
                                }
                                .foregroundColor(isSelected ? .black : .white.opacity(0.85))
                                .padding(.leading, 13)
                                .padding(.trailing, 8)
                                .padding(.vertical, 7.5)
                                .background(
                                    ZStack {
                                        if isSelected {
                                            Capsule()
                                                .fill(
                                                    LinearGradient(
                                                        colors: [Color(red: 0.22, green: 0.92, blue: 1.0), Color(red: 0.1, green: 0.78, blue: 0.96)],
                                                        startPoint: .leading,
                                                        endPoint: .trailing
                                                    )
                                                )
                                                .matchedGeometryEffect(id: "ACTIVE_CATEGORY_PILL", in: pillAnim)
                                                .shadow(color: .cyan.opacity(0.45), radius: 8)
                                        } else {
                                            Capsule()
                                                .fill(Color.white.opacity(0.06))
                                        }
                                    }
                                )
                                .overlay(
                                    Capsule()
                                        .strokeBorder(isSelected ? Color.white.opacity(0.45) : Color.white.opacity(0.12), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 2)
                }
                
                // 3. THANH TÌM KIẾM + NÚT "• ĐANG BẬT" NẰM CẠNH NHAU NHƯ ẢNH GỐC
                HStack(spacing: 9) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 13.5, weight: .medium))
                            .foregroundColor(.white.opacity(0.45))
                        
                        TextField("Tìm nhanh tính năng...", text: $searchText)
                            .font(.system(size: 13.5))
                            .foregroundColor(.white)
                            .tint(.cyan)
                        
                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.45))
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9.5)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                    )
                    
                    Button {
                        iPhoneHaptics.shared.playTap()
                        withAnimation(.spring(response: 0.26, dampingFraction: 0.78)) {
                            onlyActiveFilter.toggle()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(onlyActiveFilter ? Color.black : Color.cyan)
                                .frame(width: 6.5, height: 6.5)
                            Text("Đang bật")
                                .font(.system(size: 12.5, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(onlyActiveFilter ? .black : .white.opacity(0.9))
                        .padding(.horizontal, 13)
                        .padding(.vertical, 9.5)
                        .background(
                            onlyActiveFilter
                            ? AnyView(Color.cyan)
                            : AnyView(Color.white.opacity(0.07))
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .strokeBorder(onlyActiveFilter ? Color.white.opacity(0.5) : Color.cyan.opacity(0.35), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                
                // 4. LƯỚI 2 CỘT THẺ CHỨC NĂNG (GIỮ NGUYÊN BỐ CỤC BAN ĐẦU - MAKE SẮC NÉT)
                ScrollView(showsIndicators: false) {
                    if items.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "tray")
                                .font(.system(size: 28))
                                .foregroundColor(.white.opacity(0.3))
                            Text(onlyActiveFilter ? "Chưa có tính năng nào đang bật" : "Không có tính năng trong mục này")
                                .font(.system(size: 13.5, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 48)
                        .background(Color.white.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 6)
                    } else {
                        LazyVGrid(columns: columns, spacing: 11) {
                            ForEach(items) { item in
                                ClassicMakeoverModCard(item: item, fallbackAvatarURL: authManager.publicAvatarURL)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 2)
                        .padding(.bottom, 20)
                    }
                }
            }
            // 5. NÚT KHỞI ĐỘNG GAME NỔI GỌN Ở ĐÁY (KHÔNG CHE MẤT THẺ CUỐI)
            .safeAreaInset(edge: .bottom) {
                Button {
                    guard isSessionActive else { return }
                    iPhoneHaptics.shared.playLaunch()
                    let rawLaunch = (game?.launchURL ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    if let url = URL(string: rawLaunch), !rawLaunch.isEmpty {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 14, weight: .black))
                        Text("KHỞI ĐỘNG GAME")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .tracking(0.8)
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.25, green: 0.93, blue: 1.0), Color(red: 0.1, green: 0.8, blue: 0.98)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.45), lineWidth: 1)
                    )
                    .shadow(color: .cyan.opacity(0.42), radius: 12, y: 3)
                }
                .buttonStyle(ClassicScaleButtonStyle())
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 6)
                .background(
                    LinearGradient(
                        colors: [Color.black.opacity(0.0), Color.black.opacity(0.88), Color.black],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                )
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
}

// MARK: - THẺ CHỨC NĂNG 2 CỘT (ĐÚNG BỐ CỤC BAN ĐẦU - MAKE LẠI ĐẸP & MƯỢT)
private struct ClassicMakeoverModCard: View {
    let item: GameCatalogItem
    let fallbackAvatarURL: String
    @StateObject private var store = GameCatalogStore.shared
    @StateObject private var authManager = CustomAuthManager.shared
    @State private var showDetailSheet = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var sheenOffset: CGFloat = -160
    
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
        
        VStack(alignment: .leading, spacing: 10) {
            // HÀNG TRÊN: AVATAR TRÒN + NHÃN FREE/VIP + NÚT (i) GÓC PHẢI
            HStack(spacing: 7) {
                SecureCatalogImage(urlString: cardAvatarURL, placeholder: Image(systemName: "bolt.fill"))
                    .frame(width: 28, height: 28)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .strokeBorder(isOn ? Color.cyan : Color.white.opacity(0.25), lineWidth: 1)
                    )
                
                Text(badgeLabel)
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .foregroundColor(isHighlightedBadge ? .black : .white.opacity(0.85))
                    .padding(.horizontal, 7.5)
                    .padding(.vertical, 3)
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
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Color(red: 0.25, green: 0.92, blue: 1.0))
                }
                .buttonStyle(.plain)
            }
            
            // HÀNG GIỮA: TÊN CHỨC NĂNG + TRẠNG THÁI
            VStack(alignment: .leading, spacing: 2.5) {
                Text(item.name)
                    .font(.system(size: 13.5, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(busy ? "Đang nạp dữ liệu..." : (isOn ? "Đang kích hoạt" : subtitleDisplay))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(busy ? .yellow : (isOn ? .cyan : .white.opacity(0.5)))
                    .lineLimit(1)
            }
            
            // HÀNG DƯỚI: NÚT BẤM "KÍCH HOẠT" / "ĐANG BẬT" RIÊNG BIỆT NHƯ ẢNH GỐC
            Button {
                guard !busy, (hasLink || isOn) else { return }
                toggleFeature(currentlyOn: isOn)
            } label: {
                HStack(spacing: 5) {
                    if busy {
                        ProgressView()
                            .tint(isOn ? .black : .cyan)
                            .scaleEffect(0.72)
                        Text("ĐANG NẠP")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                    } else {
                        Image(systemName: "power")
                            .font(.system(size: 11, weight: .black))
                        Text(isOn ? "ĐANG BẬT" : "KÍCH HOẠT")
                            .font(.system(size: 11.5, weight: .black, design: .rounded))
                            .tracking(0.3)
                    }
                }
                .foregroundColor(isOn ? .black : Color(red: 0.25, green: 0.92, blue: 1.0))
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background(
                    Group {
                        if isOn {
                            LinearGradient(
                                colors: [Color(red: 0.25, green: 0.93, blue: 1.0), Color.white],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        } else {
                            Color.cyan.opacity(0.11)
                        }
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(
                            isOn ? Color.white.opacity(0.6) : Color.cyan.opacity(0.38),
                            lineWidth: 1
                        )
                )
                .shadow(color: isOn ? .cyan.opacity(0.45) : .clear, radius: 6)
            }
            .buttonStyle(ClassicScaleButtonStyle())
            .disabled(busy || (!hasLink && !isOn))
        }
        .padding(11)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: isOn
                                ? [Color.cyan.opacity(0.18), Color(white: 0.08)]
                                : [Color.white.opacity(0.065), Color.white.opacity(0.03)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // Tia sáng lướt nhẹ khi kích hoạt
                if isOn {
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
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    isOn
                    ? LinearGradient(colors: [.cyan, .white.opacity(0.55)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    : LinearGradient(colors: [Color.white.opacity(0.14), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: isOn ? 1.3 : 0.9
                )
        )
        .shadow(color: isOn ? .cyan.opacity(0.2) : .clear, radius: 8, y: 3)
        .opacity(hasLink ? 1 : 0.48)
        .animation(.spring(response: 0.25, dampingFraction: 0.76), value: isOn)
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
        .alert("Lỗi kích hoạt Mod", isPresented: $showErrorAlert) {
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
        
        // Tiếng "tích" + Taptic cứng chuẩn iPhone
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

// MARK: - POPUP CHI TIẾT MOD (ẢNH + HDSD + COPY + YOUTUBE)
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
                Color(red: 0.02, green: 0.025, blue: 0.04)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 18) {
                        if let imgURL = item.imageURL, !imgURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            SecureCatalogImage(urlString: imgURL, placeholder: Image(systemName: "photo"))
                                .frame(maxWidth: .infinity)
                                .frame(height: 235)
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .strokeBorder(Color.cyan.opacity(0.35), lineWidth: 1)
                                )
                        }
                        
                        if let guide = item.usageGuide, !guide.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "text.book.closed.fill")
                                        .foregroundColor(.cyan)
                                    Text("Hướng dẫn sử dụng")
                                        .font(.headline)
                                        .foregroundColor(.white)
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
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(copied ? Color.cyan : Color.cyan.opacity(0.15))
                                        .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                                
                                Text(guide)
                                    .font(.body)
                                    .foregroundColor(.white.opacity(0.9))
                                    .padding(14)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.white.opacity(0.06))
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
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
                                            Text("Mở Video Hướng Dẫn")
                                        }
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(LinearGradient(colors: [.red, .red.opacity(0.8)], startPoint: .leading, endPoint: .trailing))
                                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        
                        if (item.imageURL ?? "").isEmpty && (item.usageGuide ?? "").isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "doc.questionmark")
                                    .font(.system(size: 44))
                                    .foregroundColor(.white.opacity(0.3))
                                Text("Chưa có hướng dẫn cho tính năng này")
                                    .foregroundColor(.white.opacity(0.6))
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
                    Button("Đóng") {
                        iPhoneHaptics.shared.playTap()
                        dismiss()
                    }
                    .foregroundColor(.cyan)
                    .font(.headline.bold())
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
