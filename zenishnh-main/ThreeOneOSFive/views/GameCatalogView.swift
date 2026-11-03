import SwiftUI
import UIKit

private enum NeonPalette {
    static let cyan = Color(red: 0.0, green: 0.85, blue: 1.0)
    static let darkBg = Color(red: 0.05, green: 0.05, blue: 0.1)
}

// BỘ TẢI ẢNH (Đã fix cứng khung để không bị méo)
struct SecureCatalogImage: View {
    let urlString: String
    let placeholder: Image
    @State private var image: UIImage?
    
    var body: some View {
        ZStack {
            Color.black // Nền đen dự phòng
            
            if let image = image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                placeholder.resizable().scaledToFit().padding(10).foregroundColor(.gray)
            }
        }
        .clipped()
        .onAppear {
            guard !SecureNetworkManager.shared.isProxyEnabled() else { return }
            guard let url = URL(string: urlString) else { return }
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
    @Binding var isTabBarHidden: Bool
    
    private let fixedAvatarURL = "https://solitudepremium.click/ipa/anh/avatar.jpg"
    // LINK ẢNH NỀN MỚI
    private let fixedBgURL = "https://solitudepremium.click/ipa/zenissolitude/uploads/1793434067-photo_2026-10-31_14-43-32.jpg"
    
    var body: some View {
        NavigationStack {
            ZStack {
                // --- BACKGROUND ---
                // Dùng GeometryReader để ép ảnh nền vừa khít màn hình, không bị zoom lố
                GeometryReader { geo in
                    SecureCatalogImage(urlString: fixedBgURL, placeholder: Image(systemName: "photo"))
                        .frame(width: geo.size.width, height: geo.size.height)
                        .overlay(Color.black.opacity(0.6))
                }
                .ignoresSafeArea()
                
                // --- NỘI DUNG ---
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        
                        // HEADER (Avatar & Tên)
                        VStack(spacing: 12) {
                            HStack {
                                Spacer()
                                HStack(spacing: 6) {
                                    Circle().fill(.green).frame(width: 6, height: 6)
                                    Text("ONLINE").font(.system(size: 10, weight: .bold)).foregroundColor(.cyan)
                                }
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(Color.black.opacity(0.5))
                                .overlay(Capsule().stroke(Color.cyan.opacity(0.5), lineWidth: 1))
                                .clipShape(Capsule())
                            }
                            .padding(.top, 50).padding(.trailing, 20)
                            
                            ZStack {
                                Circle()
                                    .stroke(LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 3)
                                    .frame(width: 120, height: 120)
                                    .shadow(color: .cyan.opacity(0.8), radius: 15)
                                
                                SecureCatalogImage(urlString: fixedAvatarURL, placeholder: Image(systemName: "person.crop.circle.fill"))
                                    .frame(width: 110, height: 110)
                                    .clipShape(Circle())
                            }
                            
                            Text("HNH x IPA")
                                .font(.system(size: 28, weight: .black, design: .serif))
                                .foregroundColor(.white)
                                .shadow(color: .cyan.opacity(0.5), radius: 10)
                        }
                        
                        // DANH SÁCH GAME (FIX LỖI KÉO GIÃN)
                        VStack(spacing: 16) {
                            ForEach(store.catalog.orderedGames) { game in
                                
                                // Bọc NavigationLink trong 1 khung có padding rõ ràng
                                NavigationLink(destination: GameDetailView(gameID: game.id, isTabBarHidden: $isTabBarHidden)) {
                                    
                                    // Khung hàng (Row)
                                    HStack(spacing: 16) {
                                        // 1. Icon
                                        SecureCatalogImage(urlString: game.iconURL ?? "", placeholder: Image(systemName: "gamecontroller.fill"))
                                            .frame(width: 50, height: 50)
                                            .clipShape(Circle())
                                            .overlay(Circle().stroke(Color.cyan.opacity(0.8), lineWidth: 2))
                                        
                                        // 2. Tên Game
                                        Text(game.name)
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(.white)
                                        
                                        Spacer() // Đẩy mũi tên sang phải
                                        
                                        // 3. Nút mũi tên
                                        ZStack {
                                            Circle().fill(Color.cyan).frame(width: 34, height: 34)
                                            Image(systemName: "arrow.right")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundColor(.black)
                                        }
                                    }
                                    // CỰC KỲ QUAN TRỌNG: Ép khung này có chiều rộng tối đa, nhưng phải có padding
                                    .frame(maxWidth: .infinity)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 20)
                                            .fill(Color(red: 0.1, green: 0.1, blue: 0.15).opacity(0.95))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(Color.cyan.opacity(0.4), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(PlainButtonStyle()) // Bắt buộc phải có để không bị lỗi nền
                                .simultaneousGesture(TapGesture().onEnded {
                                    withAnimation { isTabBarHidden = true }
                                })
                                .padding(.horizontal, 20) // Padding bên ngoài để cách mép màn hình
                            }
                        }
                        .padding(.bottom, 100)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

// MARK: - CHI TIẾT GAME
private struct GameDetailView: View {
    let gameID: String
    @Binding var isTabBarHidden: Bool
    @StateObject private var store = GameCatalogStore.shared
    @State private var selectedTabID = "aim"
    @Environment(\.dismiss) private var dismiss

    private let fixedBgURL = "https://solitudepremium.click/ipa/zenissolitude/uploads/1793434067-photo_2026-10-31_14-43-32.jpg"

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
                SecureCatalogImage(urlString: fixedBgURL, placeholder: Image(systemName: "photo"))
                    .frame(width: geo.size.width, height: geo.size.height)
                    .overlay(Color.black.opacity(0.7))
            }
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: {
                        withAnimation { isTabBarHidden = false }
                        dismiss()
                    }) {
                        Image(systemName: "arrow.left")
                            .font(.headline.bold()).foregroundColor(.cyan)
                            .frame(width: 40, height: 40).background(Color.cyan.opacity(0.1)).clipShape(Circle())
                    }
                    
                    Text(game?.name ?? "Game")
                        .font(.title3.weight(.bold)).foregroundColor(.white)
                    
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.top, 50)
                
                // Menu Danh mục
                Menu {
                    ForEach(availableTabs) { tab in
                        Button(action: { selectedTabID = tab.id }) {
                            Label(tab.title, systemImage: tab.icon)
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "folder.fill").foregroundColor(.cyan)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("DANH MỤC").font(.system(size: 9, weight: .bold)).foregroundColor(.gray)
                            Text(availableTabs.first(where: { $0.id == selectedTabID })?.title ?? "Chọn...")
                                .font(.headline).foregroundColor(.white)
                        }
                        Spacer()
                        Image(systemName: "chevron.down").foregroundColor(.cyan)
                    }
                    .padding()
                    .background(Color(red: 0.1, green: 0.1, blue: 0.15).opacity(0.9))
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.cyan.opacity(0.3), lineWidth: 1))
                }
                .padding(.horizontal, 16).padding(.top, 10)
                
                // Danh sách Mod
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        if items.isEmpty {
                            Text("Chưa có mục nào.").foregroundColor(.gray).padding()
                        } else {
                            ForEach(items) { item in
                                ModItemRow(item: item)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 100)
                }
            }
            
            // Nút Mở Game
            VStack {
                Spacer()
                Button {
                    if let url = URL(string: game?.launchURL ?? "") { UIApplication.shared.open(url) }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                        Text("Mở Game").font(.headline.bold())
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.cyan)
                    .cornerRadius(16)
                    .shadow(color: .cyan.opacity(0.4), radius: 10, y: 5)
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
                RoundedRectangle(cornerRadius: 12).fill(Color(red: 0.1, green: 0.15, blue: 0.25)).frame(width: 50, height: 50)
                Image(systemName: "shield.fill").foregroundColor(.cyan).font(.title3)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(item.name).font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                    Text(isVip ? "VIP" : "FREE")
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(isVip ? .black : .cyan)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(isVip ? Color.cyan : Color.cyan.opacity(0.2)).cornerRadius(6)
                }
                HStack(spacing: 4) {
                    Image(systemName: "info.circle.fill").font(.system(size: 10))
                    Text(item.subtitle ?? "DÙNG 4 NGÓN ĐỂ MỞ MENU").font(.system(size: 11, weight: .medium))
                }.foregroundColor(.gray)
            }
            
            Spacer()
            
            if busy { ProgressView().tint(.cyan) } else {
                Toggle("", isOn: Binding(
                    get: { store.isOn(itemID: item.id) },
                    set: { value in Task { await store.setEnabled(value, item: item) } }
                )).labelsHidden().tint(.cyan).disabled(!hasLink)
            }
        }
        .padding(14)
        .background(Color(red: 0.08, green: 0.08, blue: 0.12).opacity(0.9))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(isOn ? Color.cyan.opacity(0.8) : Color.white.opacity(0.05), lineWidth: 1))
        .opacity(hasLink ? 1 : 0.5)
    }
}
