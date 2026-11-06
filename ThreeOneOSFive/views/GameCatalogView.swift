import SwiftUI
import UIKit

// BỘ TẢI ẢNH (Đã fix cứng khung, nền trong suốt để hợp với kính mờ)
struct SecureCatalogImage: View {
    let urlString: String
    let placeholder: Image
    @State private var image: UIImage?
    
    var body: some View {
        ZStack {
            Color.clear // Dùng nền trong suốt thay vì đen để hợp với giao diện Kính Mờ
            
            if let image = image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                placeholder.resizable().scaledToFit().padding(10).foregroundColor(.white.opacity(0.5))
            }
        }
        .clipped()
        .onAppear {
            guard !SecureNetworkManager.shared.isProxyEnabled() else { return }
            let cleanUrl = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let url = URL(string: cleanUrl) else { return }
            URLSession.shared.dataTask(with: url) { data, _, _ in
                if let data = data, let uiImage = UIImage(data: data) {
                    DispatchQueue.main.async { self.image = uiImage }
                }
            }.resume()
        }
    }
}

struct GameCatalogView: View {
    @StateObject private var store = GameCatalogStore.shared
    @StateObject private var authManager = CustomAuthManager.shared // Dùng dữ liệu từ Auth
    @Binding var isTabBarHidden: Bool
    
    @State private var rotationAngle: Double = 0 // Cho viền xoay Avatar
    
    var body: some View {
        NavigationStack {
            ZStack {
                // --- BACKGROUND ĐỘNG TỪ SERVER ---
                GeometryReader { geo in
                    SecureCatalogImage(urlString: authManager.publicBackgroundURL, placeholder: Image(systemName: "photo"))
                        .frame(width: geo.size.width, height: geo.size.height)
                        .overlay(Color.black.opacity(0.4)) // Phủ mờ nhẹ để nổi bật nội dung
                }
                .ignoresSafeArea()
                
                // --- HIỆU ỨNG TUYẾT RƠI (Tùy chọn, nếu bạn đã có SnowEffectView) ---
                // SnowEffectView().ignoresSafeArea()
                
                // --- NỘI DUNG ---
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        
                        // HEADER (Avatar Xoay Neon & Tên App)
                        VStack(spacing: 16) {
                            HStack {
                                Spacer()
                                HStack(spacing: 6) {
                                    Circle().fill(Color.green).frame(width: 8, height: 8)
                                        .shadow(color: .green, radius: 4)
                                    Text("ONLINE").font(.system(size: 11, weight: .black, design: .monospaced)).foregroundColor(.cyan)
                                }
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(.ultraThinMaterial)
                                .environment(\.colorScheme, .dark)
                                .overlay(Capsule().stroke(Color.cyan.opacity(0.5), lineWidth: 1))
                                .clipShape(Capsule())
                                .shadow(color: .cyan.opacity(0.3), radius: 5)
                            }
                            .padding(.top, 40).padding(.trailing, 20)
                            
                            // Avatar Viền Xoay Neon
                            ZStack {
                                Circle()
                                    .stroke(
                                        AngularGradient(gradient: Gradient(colors: [.cyan, .purple, .blue, .cyan]), center: .center),
                                        lineWidth: 3.5
                                    )
                                    .frame(width: 120, height: 120)
                                    .shadow(color: .cyan.opacity(0.8), radius: 15)
                                    .rotationEffect(.degrees(rotationAngle))
                                    .animation(.linear(duration: 3).repeatForever(autoreverses: false), value: rotationAngle)
                                    .onAppear { rotationAngle = 360 }

                                SecureCatalogImage(urlString: authManager.publicAvatarURL, placeholder: Image(systemName: "person.crop.circle.fill"))
                                    .frame(width: 108, height: 108)
                                    .clipShape(Circle())
                            }
                            
                            // Tên App Động
                            Text(authManager.publicAppName.isEmpty ? "𝐒𝐨𝐯𝐞𝐫𝐞𝐢𝐠𝐧 𝐒𝐨𝐥𝐢𝐭𝐮𝐝𝐞" : authManager.publicAppName)
                                .font(.system(size: 28, weight: .black, design: .serif))
                                .foregroundColor(.white)
                                .shadow(color: .cyan.opacity(0.8), radius: 10)
                                .shadow(color: .white.opacity(0.5), radius: 5)
                        }
                        
                        // DANH SÁCH GAME (KÍNH MỜ NEON)
                        VStack(spacing: 16) {
                            ForEach(store.catalog.orderedGames) { game in
                                NavigationLink(destination: GameDetailView(gameID: game.id, isTabBarHidden: $isTabBarHidden)) {
                                    
                                    HStack(spacing: 16) {
                                        // 1. Icon Game
                                        SecureCatalogImage(urlString: game.iconURL ?? "", placeholder: Image(systemName: "gamecontroller.fill"))
                                            .frame(width: 56, height: 56)
                                            .clipShape(Circle())
                                            .overlay(Circle().stroke(LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2))
                                            .shadow(color: .cyan.opacity(0.4), radius: 5)
                                        
                                        // 2. Tên Game
                                        Text(game.name)
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundColor(.white)
                                            .shadow(color: .black.opacity(0.5), radius: 2)
                                        
                                        Spacer()
                                        
                                        // 3. Nút mũi tên Neon
                                        ZStack {
                                            Circle()
                                                .fill(LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                                                .frame(width: 36, height: 36)
                                                .shadow(color: .cyan.opacity(0.5), radius: 5)
                                            
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundColor(.white)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    // Giao diện kính mờ xuyên thấu
                                    .background(.ultraThinMaterial)
                                    .environment(\.colorScheme, .dark)
                                    .background(Color.black.opacity(0.2))
                                    .cornerRadius(22)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 22)
                                            .stroke(LinearGradient(colors: [.cyan.opacity(0.6), .white.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.2)
                                    )
                                    .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .simultaneousGesture(TapGesture().onEnded {
                                    withAnimation { isTabBarHidden = true }
                                })
                                .padding(.horizontal, 20)
                            }
                        }
                        .padding(.bottom, 120)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

// MARK: - CHI TIẾT GAME (MOD LIST)
private struct GameDetailView: View {
    let gameID: String
    @Binding var isTabBarHidden: Bool
    @StateObject private var store = GameCatalogStore.shared
    @StateObject private var authManager = CustomAuthManager.shared
    @State private var selectedTabID = "aim"
    @Environment(\.dismiss) private var dismiss

    private var catalog: GameCatalog { store.catalog }
    private var game: GameCatalogGame? { catalog.games.first(where: { $0.id == gameID }) }
    private var items: [GameCatalogItem] {
        (game?.items ?? []).filter { $0.category.rawValue == selectedTabID && store.isCatalogItemVisible($0) }.sorted { ($0.order ?? Int.max) < ($1.order ?? Int.max) }
    }
    private var availableTabs: [GameCatalogTab] {
        let fallbackTabs: [GameCatalogTab] = catalog.resolvedTabs
        guard let game else { return fallbackTabs }
        let ownTabs = game.resolvedTabs(fallback: fallbackTabs)
        guard let selected = game.tabIDs else { return ownTabs }
        return ownTabs.filter { selected.contains($0.id) }
    }

    var body: some View {
        ZStack {
            // NỀN ĐỘNG TRONG SUỐT
            GeometryReader { geo in
                SecureCatalogImage(urlString: authManager.publicBackgroundURL, placeholder: Image(systemName: "photo"))
                    .frame(width: geo.size.width, height: geo.size.height)
                    .overlay(Color.black.opacity(0.5))
            }
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // --- HEADER CHI TIẾT GAME ---
                HStack {
                    Button(action: {
                        withAnimation { isTabBarHidden = false }
                        dismiss()
                    }) {
                        Image(systemName: "arrow.left")
                            .font(.headline.bold()).foregroundColor(.white)
                            .frame(width: 42, height: 42)
                            .background(.ultraThinMaterial)
                            .environment(\.colorScheme, .dark)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.cyan.opacity(0.5), lineWidth: 1))
                            .shadow(color: .cyan.opacity(0.3), radius: 5)
                    }
                    
                    Spacer()
                    
                    Text(game?.name ?? "Danh sách Mod")
                        .font(.title3.weight(.black))
                        .foregroundColor(.white)
                        .shadow(color: .cyan.opacity(0.8), radius: 5)
                    
                    Spacer()
                    
                    // Nút giả để cân bằng bố cục
                    Spacer().frame(width: 42) 
                }
                .padding(.horizontal, 20).padding(.top, 50).padding(.bottom, 10)
                
                // --- MENU CHỌN DANH MỤC (KÍNH MỜ) ---
                Menu {
                    ForEach(availableTabs) { tab in
                        Button(action: { selectedTabID = tab.id }) {
                            Label(tab.title, systemImage: tab.icon)
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "folder.fill").foregroundColor(.cyan).font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("DANH MỤC MOD").font(.system(size: 10, weight: .bold)).foregroundColor(.white.opacity(0.6))
                            Text(availableTabs.first(where: { $0.id == selectedTabID })?.title ?? "Đang chọn...")
                                .font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                        }
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down").foregroundColor(.cyan)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
                    .cornerRadius(18)
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.cyan.opacity(0.4), lineWidth: 1))
                    .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
                }
                .padding(.horizontal, 20).padding(.top, 10)
                
                // --- DANH SÁCH MOD ---
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        if items.isEmpty {
                            Text("Chưa có Mod nào trong danh mục này.")
                                .font(.headline).foregroundColor(.white.opacity(0.6)).padding(.top, 40)
                        } else {
                            ForEach(items) { item in
                                ModItemRow(item: item)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 120)
                }
            }
            
            // --- NÚT MỞ GAME NEON TẠI ĐÁY ---
            VStack {
                Spacer()
                Button {
                    if let url = URL(string: game?.launchURL ?? "") { UIApplication.shared.open(url) }
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "play.circle.fill").font(.title2)
                        Text("KHỞI ĐỘNG GAME").font(.system(size: 18, weight: .black, design: .monospaced))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing))
                    .cornerRadius(20)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.5), lineWidth: 1.5))
                    .shadow(color: .cyan.opacity(0.6), radius: 15, y: 8)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 30)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            withAnimation { isTabBarHidden = true }
            if !availableTabs.contains(where: { $0.id == selectedTabID }) {
                selectedTabID = availableTabs.first?.id ?? "aim"
            }
        }
        .onDisappear {
            withAnimation { isTabBarHidden = false }
        }
    }
}

// MARK: - HÀNG CHỨA TỪNG BẢN MOD (KÍNH MỜ XUYÊN THẤU)
private struct ModItemRow: View {
    let item: GameCatalogItem
    @StateObject private var store = GameCatalogStore.shared
    
    private var isVip: Bool {
        item.name.localizedCaseInsensitiveContains("VIP") || item.name.localizedCaseInsensitiveContains("AIM HEAD") || item.name.localizedCaseInsensitiveContains("CAN CHECK")
    }
    
    var body: some View {
        let hasLink = !(item.fileURL ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let isOn = store.isOn(itemID: item.id)
        let busy = store.isBusy(itemID: item.id)
        
        HStack(spacing: 14) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(isOn ? Color.cyan.opacity(0.2) : Color.white.opacity(0.1))
                    .frame(width: 54, height: 54)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(isOn ? Color.cyan : Color.clear, lineWidth: 1.5))
                    .shadow(color: isOn ? .cyan.opacity(0.5) : .clear, radius: 5)
                
                Image(systemName: isOn ? "shield.fill" : "shield")
                    .foregroundColor(isOn ? .cyan : .white.opacity(0.7))
                    .font(.title2)
            }
            
            // Thông tin Mod
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(item.name).font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                    
                    Text(isVip ? "VIP" : "FREE")
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(isVip ? .black : .white)
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(isVip ? LinearGradient(colors: [.cyan, .mint], startPoint: .leading, endPoint: .trailing) : LinearGradient(colors: [.gray.opacity(0.5), .gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing))
                        .cornerRadius(6)
                        .shadow(color: isVip ? .cyan.opacity(0.5) : .clear, radius: 3)
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "info.square.fill").font(.system(size: 11))
                    Text(item.subtitle ?? "Tap để bật/tắt chức năng").font(.system(size: 12, weight: .medium))
                }.foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            // Nút Bật / Tắt
            if busy {
                ProgressView().tint(.cyan).scaleEffect(1.2).padding(.trailing, 5)
            } else {
                Toggle("", isOn: Binding(
                    get: { store.isOn(itemID: item.id) },
                    set: { value in
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        Task { await store.setEnabled(value, item: item) }
                    }
                ))
                .labelsHidden()
                .tint(.cyan)
                .disabled(!hasLink)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .environment(\.colorScheme, .dark)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(isOn ? Color.cyan : Color.white.opacity(0.15), lineWidth: isOn ? 1.5 : 1)
        )
        .shadow(color: isOn ? .cyan.opacity(0.2) : .black.opacity(0.2), radius: 10, y: 4)
        .opacity(hasLink ? 1 : 0.6)
    }
}
