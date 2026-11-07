import SwiftUI
import UIKit

/// First-launch only: choose language. Notices are handled separately by `NoticeBannerView`.
struct OnboardingView: View {
    // ĐÃ SỬA: Mặc định chọn sẵn Tiếng Việt
    @AppStorage(AppLanguage.storageKey) private var languageCode = AppLanguage.vietnamese.rawValue
    var onComplete: () -> Void

    private var language: AppLanguage { AppLanguage(rawValue: languageCode) ?? .vietnamese }

    var body: some View {
        ZStack {
            AppTheme.pageBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                languagePage
                controls
            }
        }
        .tint(AppTheme.accent)
        .animation(.spring(response: 0.38, dampingFraction: 0.84), value: languageCode)
    }

    private var languagePage: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 12)
            AppLogo(size: 72)
            VStack(spacing: 8) {
                Text(language.text("onboarding.language_title"))
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                Text(language.text("onboarding.language_subtitle"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            VStack(spacing: 10) {
                ForEach(AppLanguage.allCases) { option in
                    Button {
                        languageCode = option.rawValue
                    } label: {
                        HStack(spacing: 12) {
                            Text(option.displayName)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.primary)
                            Spacer()
                            if languageCode == option.rawValue {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(AppTheme.accent)
                                    .font(.title3)
                                    .transition(.scale.combined(with: .opacity))
                            } else {
                                Image(systemName: "circle")
                                    .foregroundStyle(.secondary.opacity(0.5))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color(uiColor: .secondarySystemBackground))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(languageCode == option.rawValue ? AppTheme.accent : Color.clear, lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            Spacer(minLength: 12)
        }
    }

    private var controls: some View {
        VStack(spacing: 12) {
            Text(language.text("onboarding.language_hint"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Button {
                OnboardingStore.markCompleted()
                onComplete()
            } label: {
                Text(language.text("common.finish"))
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.accent)
            .controlSize(.large)
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 16)
        .background(.bar)
    }
}

// MARK: - Notice (every open, can hide 1 hour)

enum NoticeStore {
    private static let snoozeUntilKey = "notice.snoozeUntil"

    static var snoozeUntil: Date? {
        get {
            let ts = UserDefaults.standard.double(forKey: snoozeUntilKey)
            guard ts > 0 else { return nil }
            return Date(timeIntervalSince1970: ts)
        }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue.timeIntervalSince1970, forKey: snoozeUntilKey)
            } else {
                UserDefaults.standard.removeObject(forKey: snoozeUntilKey)
            }
        }
    }

    static var isSnoozed: Bool {
        guard let until = snoozeUntil else { return false }
        return until > Date()
    }

    static func hideForOneHour() {
        snoozeUntil = Date().addingTimeInterval(60 * 60)
    }

    static func clearSnooze() {
        snoozeUntil = nil
    }
}

// LƯU Ý: Đã xóa struct NoticeBannerView cũ ở đây để tránh lỗi trùng lặp (redeclaration). 
// Giao diện mới đã được đặt trong ContentView.swift.

// MARK: - First-launch language gate
enum OnboardingStore {
    static let languageCompletedKey = "onboarding.languageCompleted"
    static let completedVersionKey = "onboarding.completedVersion"
    static let completedFingerprintKey = "onboarding.completedFingerprint"

    // ĐÃ SỬA: Ép App bỏ qua màn hình chọn ngôn ngữ (Luôn trả về false)
    static var shouldShowLanguagePicker: Bool {
        return false 
    }

    static func shouldShow() -> Bool {
        shouldShowLanguagePicker
    }

    static func markCompleted() {
        UserDefaults.standard.set(true, forKey: languageCompletedKey)
        UserDefaults.standard.set("language-only", forKey: completedVersionKey)
        UserDefaults.standard.set("language-only", forKey: completedFingerprintKey)
    }
}
