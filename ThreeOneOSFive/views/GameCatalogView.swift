import SwiftUI
import UIKit

// BỘ TẢI ẢNH (Thêm hiệu ứng Fade-in mượt mà)
struct SecureCatalogImage: View {
    let urlString: String
    let placeholder: Image
    @State private var image: UIImage?
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            Color.clear
            
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity.animation(.easeInOut(duration: 0.5)))
            } else {
                placeholder
                    .resizable()
                    .scaledToFit()
                    .padding(10)
                    .foregroundColor(.white.opacity(0.3))
                    .overlay(
                        ProgressView().tint(.cyan).opacity(isLoading ? 1 : 0)
                    )
            }
        }
        .clipped()
        .onAppear {
            guard !SecureNetworkManager.shared.isProxyEnabled() else { return }
            let cleanUrl = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let url = URL(string: cleanUrl) else {
                isLoading = false
                return
            }
            URLSession.shared.dataTask(with: url) { data, _, _ in
                DispatchQueue.main.async {
                    if let data = data, let uiImage = UIImage(data: data) {
                        withAnimation { self.image = uiImage }
                    }
                    self.isLoading = false
                }
            }.resume()
        }
    }
}

// MARK: - MÀN HÌNH CHÍNH (GAME CATALOG)
struct GameCatalogView: View {
    @StateObject private var store = GameCatalogStore.shared
    @StateObject private var authManager = CustomAuthManager.shared
    @Binding var isTabBarHidden: Bool
    
    // FIX LỖI XOAY: Dùng Bool thay vì thay đổi góc liên tục
    @State private var isRotating = false 
    
    var body: some View {
        NavigationStack {
            ZStack {
                // --- BACKGROUND ĐỘNG ---
                GeometryReader { geo in
                    SecureCatalogImage(urlString: authManager.publicBackgroundURL, placeholder: Image(systemName: "photo"))
                        .frame(width: geo.size.width, height: geo.size.height)
                        .overlay(
                            LinearGradient(
                                colors: [Color.black.opacity(0.2), Color.black.opacity(0.6), Color.black.opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .ignoresSafeArea()
                
                // Gọi hàm Tuyết rơi (Sẽ được fix ở Bước 2 trong App.swift)
                SnowfallView().ignoresSafeArea().allowsHitTesting(false)
                
                // --- NỘI DUNG CHÍNH ---
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        
                        // HEADER
                        VStack(spacing: 16) {
                            HStack {
                                Spacer()
                                HStack(spacing: 6) {
                                    Circle().fill(Color.green).frame(width: 8, height: 8)
                                        .shadow(color: .green, radius: 5)
                                    Text("ONLINE").font(.system(size: 11, weight: .black, design: .monospaced)).foregroundColor(.cyan)
                                }
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(.ultraThinMaterial)
                                .environment(\.colorScheme, .dark)
                                .overlay(Capsule().stroke(Color.cyan.opacity(0.6), lineWidth: 1))
                                .clipShape(Capsule())
                                .shadow(color: .cyan.opacity(0.4), radius: 8)
                            }
                            .padding(.top, 40).padding(.trailing, 20)
                            
                            // --- AVATAR XOAY (ĐÃ FIX LỖI GIẬT) ---
                            ZStack {
                                // Lớp sáng (Glow) phía sau
                                Circle()
                                    .fill(Color.cyan.opacity(0.15))
                                    .frame(width: 130, height: 130)
                                    .blur(radius: 15)
                                
                                // Viền xoay
                                Circle()
                                    .stroke(
                                        AngularGradient(
                                            gradient: Gradient(colors: [.cyan, .purple, .blue, .cyan]),
                                            center: .center
                                        ),
                                        lineWidth: 4
                                    )
                                    .frame(width: 124, height: 124)
                                    .rotationEffect(.degrees(isRotating ? 360 : 0))
                                    .animation(.linear(duration: 4).repeatForever(autoreverses: false), value: isRotating)
                                    .drawingGroup() // Fix lỗi giật/lệch khung
                                
                                // Ảnh Avatar bên trong
                                SecureCatalogImage(urlString: authManager.publicAvatarURL, placeholder: Image(systemName: "person.crop.circle.fill"))
                                    .frame(width: 110, height: 110)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                            }
                            .onAppear {
                                isRotating = true
                            }
                            
                            // Tên App
                            Text(authManager.publicAppName.isEmpty ? "𝐒𝐨𝐯𝐞𝐫𝐞𝐢𝐠𝐧 𝐒𝐨𝐥𝐢𝐭𝐮𝐝𝐞" : authManager.publicAppName)
                                .font(.system(size: 28, weight: .black, design: .serif))
                                .foregroundStyle(
                                    LinearGradient(colors: [.white, .cyan.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                                )
                                .shadow(color: .cyan.opacity(0.8), radius: 12)
                                .shadow(color: .white.opacity(0.3), radius: 4)
                        }
                        
                        // DANH SÁCH GAME
                        VStack(spacing: 16) {
                            ForEach(store.catalog.orderedGames) { game in
                                NavigationLink(destination: GameDetailView(gameID: game.id, isTabBarHidden: $isTabBarHidden)) {
                                    
                                    HStack(spacing: 16) {
                                        SecureCatalogImage(urlString: game.iconURL ?? "", placeholder: Image(systemName: "gamecontroller.fill"))
                                            .frame(width: 60, height: 60)
                                            .clipShape(Circle())
                                            .overlay(
                                                Circle().stroke(LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2)
                                            )
                                            .shadow(color: .cyan.opacity(0.6), radius: 6)
                                        
                                        Text(game.name)
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundColor(.white)
                                            .shadow(color: .black.opacity(0.8), radius: 2)
                                        
                                        Spacer()
                                        
                                        ZStack {
                                            Circle()
                                                .fill(LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                                                .frame(width: 40, height: 40)
                                                .shadow(color: .cyan.opacity(0.7), radius: 8)
                                            
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundColor(.white)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 16)
                                    // NÂNG CẤP GLASSMORPHISM
                                    .background(
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 24)
                                                .fill(.ultraThinMaterial)
                                            RoundedRectangle(cornerRadius: 24)
                                                .fill(LinearGradient(colors: [Color.white.opacity(0.1), Color.black.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                        }
                                    )
                                    .environment(\.colorScheme, .dark)
                                    .cornerRadius(24)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 24)
                                            .stroke(LinearGradient(colors: [.cyan.opacity(0.8), .white.opacity(0.1), .cyan.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
                                    )
                                    .shadow(color: .black.opacity(0.4), radius: 15, y: 8)
                                    .shadow(color: .cyan.opacity(0.15), radius: 5, x: 0, y: 0)
                                }
                                .buttonStyle(ScaleButtonStyle())
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

// MARK: - CUSTOM BUTTON STYLE
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - CHI TIẾT GAME (Giữ nguyên logic)
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
            GeometryReader { geo in
                SecureCatalogImage(urlString: authManager.publicBackgroundURL, placeholder: Image(systemName: "photo"))
                    .frame(width: geo.size.width, height: geo.size.height)
                    .overlay(Color.black.opacity(0.6))
            }
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                HStack {
                    Button(action: {
                        withAnimation { isTabBarHidden = false }
                        dismiss()
                    }) {
                        Image(systemName: "arrow.left")
                            .font(.headline.bold()).foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial)
                            .environment(\.colorScheme, .dark)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.cyan.opacity(0.6), lineWidth: 1))
                            .shadow(color: .cyan.opacity(0.4), radius: 6)
                    }
                    
                    Spacer()
                    
                    Text(game?.name ?? "Danh sách Mod")
                        .font(.title3.weight(.black))
                        .foregroundColor(.white)
                        .shadow(color: .cyan.opacity(0.8), radius: 8)
                    
                    Spacer()
                    Spacer().frame(width: 44) 
                }
                .padding(.horizontal, 20).padding(.top, 50).padding(.bottom, 10)
                
                Menu {
                    ForEach(availableTabs) { tab in
                        Button(action: { selectedTabID = tab.id }) {
                            Label(tab.title, systemImage: tab.icon)
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "folder.fill").foregroundColor(.cyan).font(.title3)
                            .shadow(color: .cyan, radius: 4)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("DANH MỤC MOD").font(.system(size: 10, weight: .bold)).foregroundColor(.white.opacity(0.7))
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
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.cyan.opacity(0.5), lineWidth: 1))
                    .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
                }
                .padding(.horizontal, 20).padding(.top, 10)
                
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
                    .cornerRadius(22)
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.4), lineWidth: 1.5))
                    .shadow(color: .cyan.opacity(0.8), radius: 20, y: 10)
                }
                .buttonStyle(ScaleButtonStyle())
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

// MARK: - HÀNG CHỨA TỪNG BẢN MOD
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
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(isOn ? Color.cyan.opacity(0.2) : Color.white.opacity(0.05))
                    .frame(width: 56, height: 56)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(isOn ? Color.cyan : Color.white.opacity(0.1), lineWidth: 1.5))
                    .shadow(color: isOn ? .cyan.opacity(0.6) : .clear, radius: 8)
                
                Image(systemName: isOn ? "shield.fill" : "shield")
                    .foregroundColor(isOn ? .cyan : .white.opacity(0.5))
                    .font(.title2)
                    .shadow(color: isOn ? .cyan : .clear, radius: 4)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(item.name).font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                    
                    Text(isVip ? "VIP" : "FREE")
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(isVip ? .black : .white.opacity(0.8))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(
                            isVip ? 
                            AnyView(LinearGradient(colors: [.cyan, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)) :
                            AnyView(Color.white.opacity(0.2))
                        )
                        .cornerRadius(6)
                        .shadow(color: isVip ? .cyan.opacity(0.6) : .clear, radius: 4)
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "info.square.fill").font(.system(size: 11))
                    Text(item.subtitle ?? "Tap để bật/tắt chức năng").font(.system(size: 12, weight: .medium))
                }.foregroundColor(.white.opacity(0.5))
            }
            
            Spacer()
            
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
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 20)
                    .fill(isOn ? Color.cyan.opacity(0.05) : Color.black.opacity(0.1))
            }
        )
        .environment(\.colorScheme, .dark)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(isOn ? Color.cyan.opacity(0.8) : Color.white.opacity(0.15), lineWidth: isOn ? 1.5 : 1)
        )
        .shadow(color: isOn ? .cyan.opacity(0.25) : .black.opacity(0.3), radius: 12, y: 5)
        .opacity(hasLink ? 1 : 0.6)
    }
}
