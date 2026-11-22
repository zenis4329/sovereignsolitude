import SwiftUI
import UIKit
import AudioToolbox
import Combine

// ==========================================================
// MARK: - 🔊 HAPTICS + ÂM THANH
// ==========================================================
final class iPhoneHaptics {
    static let shared = iPhoneHaptics()
    private let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private let light = UIImpactFeedbackGenerator(style: .light)
    private let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private let soft  = UIImpactFeedbackGenerator(style: .soft)
    private init() { rigid.prepare(); light.prepare(); heavy.prepare(); soft.prepare() }

    func playTickOn() {
        AudioServicesPlaySystemSound(1520)
        rigid.impactOccurred(intensity: 1.0); rigid.prepare()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.055) {
            self.soft.impactOccurred(intensity: 0.65); self.soft.prepare()
        }
    }
    func playTickOff() { AudioServicesPlaySystemSound(1104); light.impactOccurred(intensity: 0.7); light.prepare() }
    func playTap()     { AudioServicesPlaySystemSound(1103); light.impactOccurred(intensity: 0.5); light.prepare() }
    func playLaunch() {
        AudioServicesPlaySystemSound(1306)
        heavy.impactOccurred(intensity: 1.0); heavy.prepare()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) {
            self.rigid.impactOccurred(intensity: 0.85); self.rigid.prepare()
        }
    }
}

// ==========================================================
// MARK: - IMAGE CACHE
// ==========================================================
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
                    .transition(.opacity.animation(.easeOut(duration: 0.25)))
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

// ==========================================================
// MARK: - 🌌 BACKGROUND EFFECTS
// ==========================================================
struct AuroraWaves: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let colors: [Color] = [
                    Color(red: 0.2, green: 0.85, blue: 1.0),
                    Color(red: 0.6, green: 0.3, blue: 1.0),
                    Color(red: 0.2, green: 0.55, blue: 1.0)
                ]
                for i in 0..<3 {
                    var path = Path()
                    let phase = Double(i) * 2.2
                    let amplitude = size.height * 0.09
                    let yBase = size.height * (0.35 + Double(i) * 0.18)
                    path.move(to: CGPoint(x: 0, y: yBase))
                    for x in stride(from: 0, through: size.width, by: 6) {
                        let y = yBase + sin((Double(x) / 120) + t * 0.55 + phase) * amplitude
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                    path.addLine(to: CGPoint(x: size.width, y: size.height))
                    path.addLine(to: CGPoint(x: 0, y: size.height))
                    path.closeSubpath()
                    ctx.fill(path, with: .color(colors[i].opacity(0.08)))
                }
            }
        }
        .blur(radius: 40).allowsHitTesting(false)
    }
}

struct ShootingStars: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                for i in 0..<4 {
                    let period = 4.5 + Double(i) * 1.8
                    let offset = Double(i) * 1.4
                    let progress = (t + offset).truncatingRemainder(dividingBy: period) / period
                    if progress < 0.12 {
                        let localProgress = progress / 0.12
                        let startX = size.width * (0.05 + Double(i) * 0.28)
                        let startY = size.height * (0.05 + Double(i % 2) * 0.15)
                        let length: CGFloat = 140
                        let x = startX + localProgress * 500
                        let y = startY + localProgress * 380
                        let alpha = 1 - localProgress
                        var path = Path()
                        path.move(to: CGPoint(x: x - length, y: y - length * 0.76))
                        path.addLine(to: CGPoint(x: x, y: y))
                        ctx.stroke(path, with: .linearGradient(Gradient(colors: [.clear, Color.cyan.opacity(alpha), Color.white.opacity(alpha)]), startPoint: CGPoint(x: x - length, y: y - length * 0.76), endPoint: CGPoint(x: x, y: y)), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
                        let head = CGRect(x: x - 2.5, y: y - 2.5, width: 5, height: 5)
                        ctx.fill(Ellipse().path(in: head), with: .color(.white.opacity(alpha)))
                    }
                }
            }
        }.allowsHitTesting(false)
    }
}

struct TwinkleStars: View {
    var count: Int = 42
    struct Star: Identifiable {
        let id = UUID()
        let xRatio: CGFloat; let yRatio: CGFloat; let size: CGFloat; let phase: Double; let speed: Double
    }
    @State private var stars: [Star] = []
    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                Canvas { ctx, size in
                    for s in stars {
                        let alpha = 0.15 + 0.65 * (0.5 + 0.5 * sin(t * s.speed + s.phase))
                        let rect = CGRect(x: s.xRatio * size.width, y: s.yRatio * size.height, width: s.size, height: s.size)
                        ctx.fill(Ellipse().path(in: rect), with: .color(.white.opacity(alpha)))
                    }
                }
            }
            .onAppear {
                stars = (0..<count).map { _ in Star(xRatio: .random(in: 0...1), yRatio: .random(in: 0...1), size: .random(in: 1...2.6), phase: .random(in: 0...6.28), speed: .random(in: 1.2...3.2)) }
            }
        }.allowsHitTesting(false)
    }
}

struct FallingParticles: View {
    var count: Int = 32
    struct P: Identifiable {
        let id = UUID()
        let xRatio: CGFloat; let startOffset: Double; let speed: Double; let size: CGFloat; let opacity: Double; let sway: Double; let color: Color
    }
    @State private var particles: [P] = []
    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                Canvas { ctx, size in
                    for p in particles {
                        let travel = (p.startOffset + t * p.speed).truncatingRemainder(dividingBy: Double(size.height) + 40) - 20
                        let sway = sin(t * 0.55 + p.sway) * 7
                        let rect = CGRect(x: p.xRatio * size.width + CGFloat(sway), y: CGFloat(travel), width: p.size, height: p.size)
                        ctx.fill(Ellipse().path(in: rect), with: .color(p.color.opacity(p.opacity)))
                    }
                }
            }
            .onAppear {
                particles = (0..<count).map { _ in P(xRatio: .random(in: 0...1), startOffset: .random(in: 0...Double(geo.size.height)), speed: .random(in: 10...28), size: .random(in: 1.2...3.8), opacity: .random(in: 0.28...0.78), sway: .random(in: 0...6.28), color: [Color.cyan, Color.white, Color(red: 0.5, green: 0.88, blue: 1.0)].randomElement() ?? .cyan) }
            }
        }.allowsHitTesting(false)
    }
}

struct PulsingOrb: View {
    let color: Color; let size: CGFloat; let xOffset: CGFloat; let yOffset: CGFloat; let duration: Double
    @State private var pulse = false
    var body: some View {
        Circle().fill(color.opacity(0.16)).frame(width: size, height: size).blur(radius: 110)
            .scaleEffect(pulse ? 1.18 : 0.9).opacity(pulse ? 0.95 : 0.55)
            .offset(x: xOffset, y: yOffset)
            .animation(.easeInOut(duration: duration).repeatForever(autoreverses: true), value: pulse)
            .onAppear { pulse = true }.allowsHitTesting(false)
    }
}

struct ModernBackground: View {
    let urlString: String
    var particleCount: Int = 32
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(red: 0.035, green: 0.04, blue: 0.065)
                SecureCatalogImage(urlString: urlString, placeholder: Image(systemName: "sparkles"))
                    .frame(width: geo.size.width, height: geo.size.height).opacity(0.26)
                LinearGradient(colors: [Color.black.opacity(0.55), Color(red: 0.035, green: 0.04, blue: 0.065).opacity(0.92), Color.black.opacity(0.98)], startPoint: .top, endPoint: .bottom)
                AuroraWaves().opacity(0.85)
                PulsingOrb(color: .cyan,   size: 300, xOffset: -150, yOffset: -260, duration: 4.5)
                PulsingOrb(color: .purple, size: 260, xOffset:  170, yOffset:  400, duration: 5.5)
                PulsingOrb(color: .blue,   size: 200, xOffset:  190, yOffset: -140, duration: 6.0)
                TwinkleStars(count: 42).opacity(0.85)
                FallingParticles(count: particleCount).opacity(0.9)
                ShootingStars().opacity(0.9)
            }
        }.ignoresSafeArea()
    }
}

// ==========================================================
// MARK: - 🌟 SPARKLE BURST (ĐÃ THÊM LẠI)
// ==========================================================
struct SparkleBurst: View {
    let trigger: Bool
    var body: some View {
        ZStack {
            ForEach(0..<8) { i in
                let angle = Double(i) * .pi / 4
                Circle()
                    .fill(Color.cyan)
                    .frame(width: 5, height: 5)
                    .offset(
                        x: trigger ? CGFloat(cos(angle)) * 34 : 0,
                        y: trigger ? CGFloat(sin(angle)) * 34 : 0
                    )
                    .opacity(trigger ? 0 : 1)
                    .scaleEffect(trigger ? 1.8 : 0.3)
            }
        }
        .allowsHitTesting(false)
    }
}

// ==========================================================
// MARK: - 🌟 AVATAR ORBITS
// ==========================================================
struct AvatarOrbits: View {
    let ringSize: CGFloat; let dotCount: Int; let dotSize: CGFloat; let speed: Double; let color: Color; var reverse: Bool = false
    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let center = CGPoint(x: size.width/2, y: size.height/2)
                let radius = size.width/2 - dotSize
                for i in 0..<dotCount {
                    let direction = reverse ? -1.0 : 1.0
                    let angle = t * speed * direction + Double(i) * (.pi * 2 / Double(dotCount))
                    let x = center.x + CGFloat(cos(angle)) * radius
                    let y = center.y + CGFloat(sin(angle)) * radius
                    let rect = CGRect(x: x - dotSize/2, y: y - dotSize/2, width: dotSize, height: dotSize)
                    let glowRect = rect.insetBy(dx: -1.5, dy: -1.5)
                    ctx.fill(Ellipse().path(in: glowRect), with: .color(color.opacity(0.35)))
                    ctx.fill(Ellipse().path(in: rect), with: .color(color))
                }
            }
        }.frame(width: ringSize, height: ringSize).allowsHitTesting(false)
    }
}

struct ClassicScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed ? 0.965 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

// ==========================================================
// MARK: - STATUS CARD HELPER
// ==========================================================
struct StatusCard: View {
    let icon: String; let title: String; let value: String; let color: Color
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 16, weight: .semibold)).foregroundColor(color)
            Text(value).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundColor(.white)
            Text(title).font(.system(size: 9.5, weight: .medium)).foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity).padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(color.opacity(0.25), lineWidth: 1))
    }
}

// ==========================================================
// MARK: - MÀN HÌNH CHÍNH
// ==========================================================
struct GameCatalogView: View {
    @StateObject private var store = GameCatalogStore.shared
    @StateObject private var authManager = CustomAuthManager.shared
    @Binding var isTabBarHidden: Bool
    @State private var glowPulse = false
    @State private var ringRotate: Double = 0
    @State private var haloScale: CGFloat = 1.0

    private var isSessionActive: Bool {
        authManager.isAuthorized && !authManager.isInteractionLocked && !store.catalog.resolvedMaintenanceEnabled
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ModernBackground(urlString: authManager.publicBackgroundURL, particleCount: 36)
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        profileCard
                        featuredGameCard
                        systemStatusSection
                        antiBanBanner
                    }
                    .padding(.bottom, 100)
                }
                .disabled(!isSessionActive)
                .allowsHitTesting(isSessionActive)
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                glowPulse = true
                store.rememberCatalogItems()
                withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) { ringRotate = 360 }
                withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) { haloScale = 1.15 }
                if !authManager.isAuthorized || store.catalog.resolvedMaintenanceEnabled { store.disableAllEnabledMods() }
            }
            .onChange(of: store.catalog.games.count) { _ in store.rememberCatalogItems() }
            .onChange(of: authManager.isAuthorized) { a in if !a { isTabBarHidden = false; store.disableAllEnabledMods() } }
            .onChange(of: store.catalog.resolvedMaintenanceEnabled) { m in if m { isTabBarHidden = false; store.disableAllEnabledMods() } }
        }
    }

    // MARK: PROFILE CARD (CÓ ANTIBAN ONLINE)
    private var profileCard: some View {
        HStack(spacing: 14) {
            avatarView

            VStack(alignment: .leading, spacing: 4) {
                Text(authManager.publicAppName.isEmpty ? "Sovereign Solitude" : authManager.publicAppName)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundColor(.white).lineLimit(1)
                    .shadow(color: .cyan.opacity(0.4), radius: 6)
                
                HStack(spacing: 6) {
                    HStack(spacing: 4) {
                        Circle().fill(Color.green).frame(width: 5, height: 5).shadow(color: .green, radius: 3)
                        Text("Online").font(.system(size: 9.5, weight: .bold)).foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.white.opacity(0.1)).clipShape(Capsule())
                    
                    HStack(spacing: 4) {
                        Image(systemName: "shield.checkered").font(.system(size: 9, weight: .bold))
                        Text("ANTIBAN").font(.system(size: 9.5, weight: .black, design: .rounded))
                    }
                    .foregroundColor(.green)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.green.opacity(0.15)).clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(Color.green.opacity(0.4), lineWidth: 0.8))
                }
            }

            Spacer(minLength: 4)

            if totalEnabledAll > 0 {
                Button {
                    iPhoneHaptics.shared.playTickOff()
                    withAnimation(.spring(response: 0.26, dampingFraction: 0.8)) { store.disableAllEnabledMods() }
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: "power").font(.system(size: 13, weight: .black))
                        Text("Tắt hết").font(.system(size: 8.5, weight: .black))
                    }
                    .foregroundColor(.black).frame(width: 46, height: 46)
                    .background(LinearGradient(colors: [Color(red: 0.3, green: 0.95, blue: 1), .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .shadow(color: .cyan.opacity(0.5), radius: 8)
                }.buttonStyle(ClassicScaleButtonStyle())
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.white.opacity(0.055)))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(LinearGradient(colors: [Color.cyan.opacity(0.5), Color.purple.opacity(0.25), Color.white.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.2))
        .shadow(color: .cyan.opacity(0.18), radius: 18, y: 4)
        .padding(.horizontal, 16).padding(.top, 10)
    }

    private var avatarView: some View {
        ZStack {
            Circle().fill(Color.cyan.opacity(0.35)).frame(width: 82, height: 82).blur(radius: 24).scaleEffect(haloScale).opacity(glowPulse ? 0.95 : 0.5)
            AvatarOrbits(ringSize: 86, dotCount: 8, dotSize: 3.5, speed: 0.65, color: .cyan)
            AvatarOrbits(ringSize: 78, dotCount: 5, dotSize: 2.8, speed: 0.9, color: Color(red: 0.6, green: 0.5, blue: 1.0), reverse: true)
            Circle().stroke(AngularGradient(colors: [.cyan, .white, .blue, .purple, .cyan], center: .center), style: StrokeStyle(lineWidth: 2.4, dash: [4, 6])).frame(width: 64, height: 64).rotationEffect(.degrees(ringRotate))
            Circle().stroke(Color.white.opacity(0.25), lineWidth: 1).frame(width: 56, height: 56)
            SecureCatalogImage(urlString: authManager.publicAvatarURL, placeholder: Image(systemName: "person.crop.circle.fill"))
                .frame(width: 54, height: 54).clipShape(Circle()).overlay(Circle().strokeBorder(Color.white.opacity(0.3), lineWidth: 1)).shadow(color: .cyan.opacity(0.6), radius: 8)
        }.frame(width: 90, height: 90)
    }

    // MARK: FEATURED GAME CARD (KHÔNG HIỆN SỐ MOD)
    private var featuredGameCard: some View {
        Group {
            if let game = store.catalog.orderedGames.first {
                NavigationLink(destination: GameDetailView(gameID: game.id, isTabBarHidden: $isTabBarHidden)) {
                    VStack(spacing: 12) {
                        HStack {
                            SecureCatalogImage(urlString: game.iconURL ?? "", placeholder: Image(systemName: "gamecontroller.fill"))
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(LinearGradient(colors: [.cyan, .white.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5))
                                .shadow(color: .cyan.opacity(0.4), radius: 8)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(game.name)
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                Text("Hệ thống Mod & Bypass")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.cyan.opacity(0.8))
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .black)).foregroundColor(.black)
                                .frame(width: 32, height: 32)
                                .background(LinearGradient(colors: [Color(red: 0.25, green: 0.92, blue: 1), .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .clipShape(Circle()).shadow(color: .cyan.opacity(0.5), radius: 6)
                        }
                        
                        Divider().background(Color.white.opacity(0.1))
                        
                        HStack {
                            Label("Truy cập nhanh", systemImage: "bolt.fill").font(.system(size: 11, weight: .bold)).foregroundColor(.white.opacity(0.6))
                            Spacer()
                            Text("VÀO MENU CHỨC NĂNG").font(.system(size: 12, weight: .black, design: .rounded)).foregroundColor(.cyan)
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(LinearGradient(colors: [Color.white.opacity(0.08), Color.white.opacity(0.03)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(LinearGradient(colors: [.cyan.opacity(0.6), .purple.opacity(0.4), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.2)
                    )
                    .shadow(color: .cyan.opacity(0.15), radius: 15, y: 5)
                }
                .buttonStyle(ClassicScaleButtonStyle())
                .padding(.horizontal, 16)
            } else {
                Text("Chưa có trò chơi nào").foregroundColor(.white.opacity(0.5)).padding()
            }
        }
    }

    // MARK: SYSTEM STATUS (LẤP ĐẦY KHOẢNG TRỐNG)
    private var systemStatusSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TRẠNG THÁI HỆ THỐNG")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundColor(.white.opacity(0.5)).tracking(1.2)
                .padding(.horizontal, 20)
            
            HStack(spacing: 10) {
                StatusCard(icon: "shield.lefthalf.filled", title: "Bypass", value: "An Toàn", color: .green)
                StatusCard(icon: "lock.shield.fill", title: "Anti-Ban", value: "Online", color: .cyan)
                StatusCard(icon: "antenna.radiowaves.left.and.right", title: "Server", value: "VN", color: .purple)
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 6)
    }

    // MARK: ANTIBAN BANNER
    private var antiBanBanner: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 32))
                .foregroundColor(.green)
                .shadow(color: .green.opacity(0.6), radius: 10)
            
            Text("HỆ THỐNG ANTIBAN ONLINE")
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundColor(.white)
            
            Text("Mọi tính năng đều được mã hoá và bảo vệ.\nAn toàn tuyệt đối khi tham gia trận đấu.")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.green.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.green.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    private var totalEnabledAll: Int {
        store.catalog.orderedGames.reduce(0) { $0 + $1.items.filter { $0.hidden != true && store.isMultiItemOn(item: $0) }.count }
    }
}

// ==========================================================
// MARK: - MÀN HÌNH CHI TIẾT
// ==========================================================
private struct GameDetailView: View {
    let gameID: String
    @Binding var isTabBarHidden: Bool
    @StateObject private var store = GameCatalogStore.shared
    @StateObject private var authManager = CustomAuthManager.shared
    @State private var selectedTabID = "aim"
    @State private var onlyActiveFilter = false
    @Environment(\.dismiss) private var dismiss

    private var catalog: GameCatalog { store.catalog }
    private var game: GameCatalogGame? { catalog.games.first(where: { $0.id == gameID }) }
    private var isSessionActive: Bool { authManager.isAuthorized && !authManager.isInteractionLocked && !store.catalog.resolvedMaintenanceEnabled }

    private var items: [GameCatalogItem] {
        (game?.items ?? [])
            .filter { $0.hidden != true && $0.category.rawValue == selectedTabID }
            .filter { item in !onlyActiveFilter || store.isMultiItemOn(item: item) }
            .sorted { ($0.order ?? Int.max) < ($1.order ?? Int.max) }
    }
    private var activeCountInGame: Int { (game?.items ?? []).filter { $0.hidden != true && store.isMultiItemOn(item: $0) }.count }
    private var totalActiveAllGames: Int { store.catalog.orderedGames.reduce(0) { $0 + $1.items.filter { $0.hidden != true && store.isMultiItemOn(item: $0) }.count } }
    
    private var availableTabs: [GameCatalogTab] {
        let fallback: [GameCatalogTab] = catalog.resolvedTabs
        guard let game else { return fallback }
        let own = game.resolvedTabs(fallback: fallback)
        guard let selected = game.tabIDs else { return own }
        return own.filter { selected.contains($0.id) }
    }
    private var currentTab: GameCatalogTab? { availableTabs.first(where: { $0.id == selectedTabID }) ?? availableTabs.first }
    private var currentCount: Int { (game?.items ?? []).filter { $0.hidden != true && $0.category.rawValue == selectedTabID }.count }

    var body: some View {
        ZStack {
            ModernBackground(urlString: authManager.publicBackgroundURL, particleCount: 22)
            VStack(spacing: 12) {
                headerSection
                categoryBar
                modList
            }
            .safeAreaInset(edge: .bottom) { launchButton }
        }
        .disabled(!isSessionActive).allowsHitTesting(isSessionActive).navigationBarHidden(true)
        .onAppear {
            store.rememberCatalogItems()
            if store.catalog.resolvedMaintenanceEnabled {
                store.disableAllEnabledMods(); withAnimation { isTabBarHidden = false }; dismiss(); return
            }
            withAnimation { isTabBarHidden = true }
            if !availableTabs.contains(where: { $0.id == selectedTabID }) { selectedTabID = availableTabs.first?.id ?? "aim" }
        }
        .onDisappear { withAnimation { isTabBarHidden = false } }
        .onChange(of: authManager.isAuthorized) { a in if !a { store.disableAllEnabledMods(); withAnimation { isTabBarHidden = false }; dismiss() } }
        .onChange(of: store.catalog.resolvedMaintenanceEnabled) { m in if m { store.disableAllEnabledMods(); withAnimation { isTabBarHidden = false }; dismiss() } }
    }

    private var headerSection: some View {
        HStack(spacing: 10) {
            Button {
                iPhoneHaptics.shared.playTap(); withAnimation(.easeInOut(duration: 0.2)) { isTabBarHidden = false }; dismiss()
            } label: {
                Image(systemName: "chevron.left").font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                    .frame(width: 36, height: 36).background(Circle().fill(Color.white.opacity(0.08))).overlay(Circle().strokeBorder(Color.white.opacity(0.14), lineWidth: 1)).shadow(color: .black.opacity(0.3), radius: 4)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(game?.name ?? "Game").font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(.white).lineLimit(1).shadow(color: .cyan.opacity(0.25), radius: 4)
                HStack(spacing: 4) {
                    Circle().fill(activeCountInGame > 0 ? Color.cyan : Color.green).frame(width: 5, height: 5).shadow(color: (activeCountInGame > 0 ? Color.cyan : Color.green).opacity(0.8), radius: 3)
                    Text(activeCountInGame > 0 ? "\(activeCountInGame) mod đang bật" : "Sẵn sàng").font(.system(size: 11, weight: .semibold)).foregroundColor(activeCountInGame > 0 ? .cyan : .white.opacity(0.55))
                }
            }
            Spacer(minLength: 4)
            if totalActiveAllGames > 0 {
                Button {
                    iPhoneHaptics.shared.playTickOff(); withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) { store.disableAllEnabledMods() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "power").font(.system(size: 11, weight: .black))
                        Text("Tắt all").font(.system(size: 10.5, weight: .black, design: .rounded))
                        Text("\(totalActiveAllGames)").font(.system(size: 9, weight: .black, design: .rounded)).foregroundColor(.white).frame(minWidth: 16, minHeight: 16).background(Color.black.opacity(0.35)).clipShape(Circle())
                    }.foregroundColor(.black).padding(.horizontal, 9).padding(.vertical, 7)
                    .background(LinearGradient(colors: [Color(red: 1.0, green: 0.35, blue: 0.3), Color(red: 0.95, green: 0.2, blue: 0.2)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous)).overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.white.opacity(0.35), lineWidth: 1)).shadow(color: .red.opacity(0.5), radius: 6)
                }.buttonStyle(ClassicScaleButtonStyle())
            }
            SecureCatalogImage(urlString: game?.iconURL ?? "", placeholder: Image(systemName: "gamecontroller.fill")).frame(width: 38, height: 38).clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous)).overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(LinearGradient(colors: [.cyan, .white.opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.2)).shadow(color: .cyan.opacity(0.35), radius: 6)
        }.padding(.horizontal, 16).padding(.top, 6)
    }

    private var categoryBar: some View {
        HStack(spacing: 9) {
            Menu {
                ForEach(availableTabs) { tab in
                    let count = (game?.items ?? []).filter { $0.hidden != true && $0.category.rawValue == tab.id }.count
                    Button {
                        iPhoneHaptics.shared.playTap(); withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { selectedTabID = tab.id }
                    } label: { Label("\(tab.title) (\(count))", systemImage: tab.icon) }
                }
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: currentTab?.icon ?? "square.grid.2x2.fill").font(.system(size: 13, weight: .bold))
                    Text(currentTab?.title.uppercased() ?? "DANH MỤC").font(.system(size: 12.5, weight: .heavy, design: .rounded)).lineLimit(1)
                    Text("\(currentCount)").font(.system(size: 9.5, weight: .black, design: .rounded)).foregroundColor(.black).frame(minWidth: 18, minHeight: 18).background(Color.white).clipShape(Capsule())
                    Image(systemName: "chevron.down").font(.system(size: 9, weight: .black))
                }.foregroundColor(.black).padding(.horizontal, 12).padding(.vertical, 10)
                .background(LinearGradient(colors: [Color(red: 0.25, green: 0.92, blue: 1.0), Color.cyan], startPoint: .leading, endPoint: .trailing))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous)).shadow(color: .cyan.opacity(0.5), radius: 8)
            }.frame(maxWidth: .infinity)

            Button {
                iPhoneHaptics.shared.playTap(); withAnimation(.spring(response: 0.26, dampingFraction: 0.78)) { onlyActiveFilter.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: onlyActiveFilter ? "checkmark.circle.fill" : "circle.dashed").font(.system(size: 12, weight: .bold))
                    Text("Đang bật").font(.system(size: 12, weight: .bold, design: .rounded))
                }.foregroundColor(onlyActiveFilter ? .black : .white.opacity(0.75)).padding(.horizontal, 12).padding(.vertical, 10)
                .background(Group {
                    if onlyActiveFilter { LinearGradient(colors: [Color.cyan, Color(red: 0.4, green: 0.95, blue: 1)], startPoint: .topLeading, endPoint: .bottomTrailing) }
                    else { Color.white.opacity(0.055) }
                }).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous)).overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(onlyActiveFilter ? Color.white.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1)).shadow(color: onlyActiveFilter ? .cyan.opacity(0.45) : .clear, radius: 7)
            }.buttonStyle(.plain)
        }.padding(.horizontal, 16)
    }

    private var modList: some View {
        ScrollView(showsIndicators: false) {
            if items.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "tray").font(.system(size: 28, weight: .ultraLight)).foregroundColor(.white.opacity(0.3))
                    Text(onlyActiveFilter ? "Chưa có mod nào đang bật" : "Không có mod trong mục này").font(.system(size: 13, weight: .medium)).foregroundColor(.white.opacity(0.5))
                }.frame(maxWidth: .infinity).padding(.vertical, 44).background(Color.white.opacity(0.035)).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous)).padding(.horizontal, 16).padding(.top, 6)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(items) { item in ModernModRow(item: item, fallbackAvatarURL: authManager.publicAvatarURL) }
                }.padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 20)
            }
        }
    }

    private var launchButton: some View {
        Button {
            guard isSessionActive else { return }
            iPhoneHaptics.shared.playLaunch()
            let raw = (game?.launchURL ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if let url = URL(string: raw), !raw.isEmpty { UIApplication.shared.open(url) }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "play.fill").font(.system(size: 13, weight: .black))
                Text("KHỞI ĐỘNG GAME").font(.system(size: 14, weight: .black, design: .rounded)).tracking(0.9)
            }.foregroundColor(.black).frame(maxWidth: .infinity).frame(height: 48)
            .background(LinearGradient(colors: [Color(red: 0.25, green: 0.93, blue: 1.0), Color(red: 0.1, green: 0.8, blue: 0.98)], startPoint: .leading, endPoint: .trailing))
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous)).overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).strokeBorder(Color.white.opacity(0.45), lineWidth: 1)).shadow(color: .cyan.opacity(0.5), radius: 12, y: 4)
        }.buttonStyle(ClassicScaleButtonStyle()).padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 6)
        .background(LinearGradient(colors: [Color.black.opacity(0.0), Color.black.opacity(0.88), Color.black], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
    }
}

// ==========================================================
// MARK: - MOD ROW
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
    @State private var burst = false
    @State private var iconScale: CGFloat = 1.0

    private var isSessionActive: Bool { authManager.isAuthorized && !authManager.isInteractionLocked && !store.catalog.resolvedMaintenanceEnabled }
    private var isVip: Bool { item.name.localizedCaseInsensitiveContains("VIP") || item.name.localizedCaseInsensitiveContains("AIM HEAD") || item.name.localizedCaseInsensitiveContains("CAN CHECK") }
    private var badgeLabel: String {
        let custom = (item.badge ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return custom.isEmpty ? (isVip ? "VIP" : "") : custom
    }
    private var hasBadge: Bool { !badgeLabel.isEmpty }
    private var hasGuide: Bool { !(item.usageGuide ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !(item.imageURL ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
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
            ZStack {
                if isOn { RoundedRectangle(cornerRadius: 12).fill(Color.cyan.opacity(0.3)).frame(width: 44, height: 44).blur(radius: 9) }
                SparkleBurst(trigger: burst).frame(width: 44, height: 44)
                SecureCatalogImage(urlString: cardAvatarURL, placeholder: Image(systemName: "bolt.fill"))
                    .frame(width: 40, height: 40).clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(isOn ? LinearGradient(colors: [.cyan, .white.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing) : LinearGradient(colors: [Color.white.opacity(0.18), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: isOn ? 1.4 : 1))
                    .shadow(color: isOn ? .cyan.opacity(0.6) : .clear, radius: 6).scaleEffect(iconScale)
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(item.name).font(.system(size: 13.5, weight: .bold, design: .rounded)).foregroundColor(.white).lineLimit(1)
                    if hasBadge {
                        Text(badgeLabel).font(.system(size: 8, weight: .black, design: .rounded)).foregroundColor(.black).padding(.horizontal, 5).padding(.vertical, 1.5).background(LinearGradient(colors: [.cyan, .white], startPoint: .leading, endPoint: .trailing)).clipShape(Capsule())
                    }
                }
                HStack(spacing: 4) {
                    Circle().fill(busy ? Color.yellow : (isOn ? Color.cyan : Color.white.opacity(0.25))).frame(width: 5, height: 5).shadow(color: isOn ? .cyan.opacity(0.9) : .clear, radius: 3)
                    Text(busy ? "Đang nạp..." : (isOn ? "Đang bật" : subtitleDisplay)).font(.system(size: 10.5, weight: .medium)).foregroundColor(busy ? .yellow : (isOn ? .cyan : .white.opacity(0.45))).lineLimit(1)
                }
            }
            Spacer(minLength: 4)
            Button { iPhoneHaptics.shared.playTap(); showDetailSheet = true } label: {
                Image(systemName: "info.circle.fill").font(.system(size: 17)).foregroundColor(.white.opacity(0.35))
            }.buttonStyle(.plain)
            
            if busy {
                ProgressView().tint(.cyan).scaleEffect(0.72).frame(width: 42, height: 26)
            } else {
                Toggle("", isOn: $localToggle).labelsHidden().tint(.cyan).scaleEffect(0.82).disabled(!hasLink && !isOn)
                    .onAppear { localToggle = isOn }.onChange(of: isOn) { v in localToggle = v }.onChange(of: localToggle) { v in if v != isOn { handleToggle(v) } }
            }
        }.padding(.horizontal, 11).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(isOn ? LinearGradient(colors: [Color.cyan.opacity(0.13), Color.cyan.opacity(0.04)], startPoint: .leading, endPoint: .trailing) : LinearGradient(colors: [Color.white.opacity(0.05), Color.white.opacity(0.025)], startPoint: .top, endPoint: .bottom)))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(isOn ? LinearGradient(colors: [.cyan, Color.cyan.opacity(0.5), Color.white.opacity(0.25)], startPoint: .topLeading, endPoint: .bottomTrailing) : LinearGradient(colors: [Color.white.opacity(0.09), Color.white.opacity(0.03)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: isOn ? 1.3 : 0.9))
        .shadow(color: isOn ? .cyan.opacity(0.2) : .clear, radius: 8, y: 2).opacity(hasLink ? 1 : 0.5).animation(.spring(response: 0.28, dampingFraction: 0.78), value: isOn)
        .onChange(of: isSessionActive) { a in if !a { showDetailSheet = false; showErrorAlert = false } }
        .sheet(isPresented: $showDetailSheet) { ModDetailSheet(item: item) }
        .alert("Lỗi kích hoạt Mod", isPresented: $showErrorAlert) { Button("OK", role: .cancel) { } } message: { Text(errorMessage) }
    }

    private func handleToggle(_ newVal: Bool) {
        guard !store.isMultiItemBusy(item: item) else { localToggle = store.isMultiItemOn(item: item); return }
        if newVal {
            guard isSessionActive else { localToggle = false; return }
            iPhoneHaptics.shared.playTickOn()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) { iconScale = 1.15 }
            withAnimation(.easeOut(duration: 0.5)) { burst = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { iconScale = 1.0 } }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { var tx = Transaction(); tx.disablesAnimations = true; withTransaction(tx) { burst = false } }
            Task {
                await store.setMultiEnabled(true, item: item)
                if !authManager.isAuthorized || authManager.isInteractionLocked || store.catalog.resolvedMaintenanceEnabled { await store.setMultiEnabled(false, item: item); return }
                if let error = store.lastError { await MainActor.run { errorMessage = error; showErrorAlert = true } }
                else if hasGuide { await MainActor.run { showDetailSheet = true } }
            }
        } else {
            iPhoneHaptics.shared.playTickOff()
            Task { await store.setMultiEnabled(false, item: item) }
        }
    }
}

// ==========================================================
// MARK: - MOD DETAIL SHEET
// ==========================================================
struct ModDetailSheet: View {
    let item: GameCatalogItem
    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = GameCatalogStore.shared
    @StateObject private var authManager = CustomAuthManager.shared
    @State private var copied = false

    private var isYouTubeLink: Bool { let g = (item.usageGuide ?? "").lowercased(); return g.contains("youtube.com") || g.contains("youtu.be") }

    var body: some View {
        NavigationStack {
            ZStack {
                ModernBackground(urlString: authManager.publicBackgroundURL, particleCount: 18)
                ScrollView {
                    VStack(spacing: 16) {
                        if let imgURL = item.imageURL, !imgURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            SecureCatalogImage(urlString: imgURL, placeholder: Image(systemName: "photo")).frame(maxWidth: .infinity).frame(height: 220).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous)).overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.cyan.opacity(0.4), lineWidth: 1)).shadow(color: .cyan.opacity(0.25), radius: 12)
                        }
                        if let guide = item.usageGuide, !guide.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "text.book.closed.fill").foregroundColor(.cyan)
                                    Text("Hướng dẫn").font(.headline).foregroundColor(.white)
                                    Spacer()
                                    Button {
                                        iPhoneHaptics.shared.playTickOn(); UIPasteboard.general.string = guide; copied = true
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                                    } label: {
                                        HStack(spacing: 4) { Image(systemName: copied ? "checkmark.circle.fill" : "doc.on.doc"); Text(copied ? "Đã Copy" : "Copy") }
                                            .font(.caption.bold()).foregroundColor(copied ? .black : .cyan).padding(.horizontal, 10).padding(.vertical, 6).background(copied ? Color.cyan : Color.cyan.opacity(0.15)).clipShape(Capsule())
                                    }.buttonStyle(.plain)
                                }
                                Text(guide).font(.body).foregroundColor(.white.opacity(0.9)).padding(13).frame(maxWidth: .infinity, alignment: .leading).background(Color.white.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous)).overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
                                if isYouTubeLink {
                                    Button {
                                        iPhoneHaptics.shared.playTap()
                                        if let url = URL(string: guide.trimmingCharacters(in: .whitespacesAndNewlines)) { UIApplication.shared.open(url) }
                                    } label: {
                                        HStack(spacing: 8) { Image(systemName: "play.rectangle.fill"); Text("Mở Video Hướng Dẫn") }
                                            .font(.headline).foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 13).background(LinearGradient(colors: [.red, .red.opacity(0.8)], startPoint: .leading, endPoint: .trailing)).clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                                    }.buttonStyle(.plain)
                                }
                            }
                        }
                        if (item.imageURL ?? "").isEmpty && (item.usageGuide ?? "").isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "doc.questionmark").font(.system(size: 44)).foregroundColor(.white.opacity(0.3))
                                Text("Chưa có hướng dẫn").foregroundColor(.white.opacity(0.6))
                            }.padding(.top, 50)
                        }
                    }.padding(18)
                }
            }
            .navigationTitle(item.name).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Đóng") { iPhoneHaptics.shared.playTap(); dismiss() }.foregroundColor(.cyan).font(.headline.bold()) } }
            .onChange(of: authManager.isAuthorized) { a in if !a { dismiss() } }
            .onChange(of: store.catalog.resolvedMaintenanceEnabled) { m in if m { dismiss() } }
        }
    }
}
