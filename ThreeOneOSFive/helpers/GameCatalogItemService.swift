import Foundation

enum GameCatalogItemService {
    private static let packagesFolderName = "CatalogPackages"
    private static let stateFileName = "catalog-item-state.json"
    private static let appliedKey = "appliedPackageIDs"

    static func loadAppliedItemIDs() -> Set<String> {
        guard let url = try? stateURL(),
              let data = try? Data(contentsOf: url),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let ids = object[appliedKey] as? [String]
        else { return [] }
        return Set(ids)
    }

    static func isApplied(itemID: String) -> Bool {
        loadAppliedItemIDs().contains(itemID)
    }

    private static func setApplied(_ applied: Bool, itemID: String) throws {
        var ids = loadAppliedItemIDs()
        if applied { ids.insert(itemID) } else { ids.remove(itemID) }
        let payload: [String: Any] = [appliedKey: Array(ids).sorted()]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
        let url = try stateURL()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }

    // TỰ ĐỘNG CHUYỂN ĐỔI LINK: ?file= THÀNH /
    private static func formatSecureURL(_ rawURL: String?) -> URL? {
        guard let raw = rawURL?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        let fixedRaw = raw.replacingOccurrences(of: "?file=", with: "/")
        return URL(string: fixedRaw)
    }

    static func prefetchAll(from catalog: GameCatalog) async {
        let urls: [(String, URL)] = catalog.games.flatMap { game in
            game.items.compactMap { item in
                // Sử dụng hàm formatSecureURL ở đây
                guard let url = formatSecureURL(item.fileURL) else { return nil }
                return (item.id, url)
            }
        }
        await withTaskGroup(of: Void.self) { group in
            for (itemID, remoteURL) in urls {
                group.addTask {
                    _ = try? await ensureLocalPackage(itemID: itemID, remoteURL: remoteURL)
                }
            }
        }
    }

    @MainActor
    static func replacementRuleCounts(
        from catalog: GameCatalog,
        progress: ((Int, Int) -> Void)? = nil
    ) async -> [String: Int] {
        let items = catalog.games.flatMap(\.items)
        return await withTaskGroup(of: (String, Int)?.self, returning: [String: Int].self) { group in
            for item in items {
                group.addTask {
                    // Sử dụng hàm formatSecureURL ở đây
                    guard let remoteURL = formatSecureURL(item.fileURL),
                          let localURL = try? await ensureLocalPackage(itemID: item.id, remoteURL: remoteURL),
                          let data = try? Data(contentsOf: localURL),
                          let decoded = try? PatchPackageCodec.decode(data, password: item.resolvedPackagePassword)
                    else { return nil }
                    return (item.id, decoded.project.rules.count)
                }
            }
            var result: [String: Int] = [:]
            var completed = 0
            for await entry in group {
                if let entry { result[entry.0] = entry.1 }
                completed += 1
                progress?(completed, items.count)
            }
            return result
        }
    }

    static func ensureLocalPackage(itemID: String, remoteURL: URL) async throws -> URL {
        // Kiểm tra Proxy và chống Debug an toàn
        if SecureNetworkManager.shared.isProxyEnabled() || AntiDebug.isDebuggerAttached() {
            throw NSError(domain: "Security", code: -999, userInfo: [NSLocalizedDescriptionKey: "Phát hiện Proxy/Debug! Hủy tải file."])
        }

        let localURL = try localPackageURL(itemID: itemID)
        let sourceURL = localURL.appendingPathExtension("source")
        let currentSource = try? String(contentsOf: sourceURL, encoding: .utf8)
        
        if FileManager.default.fileExists(atPath: localURL.path),
           (try? localURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0 > 64,
           currentSource == remoteURL.absoluteString {
            return localURL
        }
        
        var request = URLRequest(url: remoteURL)
        request.httpMethod = "GET"
        
        // Lấy Key và DeviceID hiện tại
        let currentKey = CustomAuthManager.shared.savedKey
        let deviceId = AppDeviceIdentity.value
        
        // Sinh mã Token động 30 giây khớp với file sovereignsolitude.php trên Server
        let dynamicToken = SecurityTokenGenerator.generate30sToken(key: currentKey, deviceId: deviceId)
        
        // Đính kèm các Header bảo mật bắt buộc
        request.setValue(currentKey, forHTTPHeaderField: "X-License-Key")
        request.setValue(deviceId, forHTTPHeaderField: "X-Device-ID")
        request.setValue(dynamicToken, forHTTPHeaderField: "X-Dynamic-Token")
        request.setValue("SolitudeApp-v3105-Secured", forHTTPHeaderField: "User-Agent")
        
        let secureSession = SecureNetworkManager.shared.createSecureSession()
        let (temporaryURL, response) = try await secureSession.download(for: request)
        
        defer { try? FileManager.default.removeItem(at: temporaryURL) }
        
        if let http = response as? HTTPURLResponse {
            if http.statusCode == 401 || http.statusCode == 403 {
                throw NSError(domain: "Security", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "Sai Key/Token hoặc bị chặn bởi máy chủ!"])
            }
            if !(200...299).contains(http.statusCode) {
                throw PatchPackageError.remoteImportFailed
            }
        }
        
        try FileManager.default.createDirectory(at: localURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: localURL.path) {
            try FileManager.default.removeItem(at: localURL)
        }
        try FileManager.default.copyItem(at: temporaryURL, to: localURL)
        try remoteURL.absoluteString.write(to: sourceURL, atomically: true, encoding: .utf8)
        return localURL
    }

    static func enable(item: GameCatalogItem) async throws {
        // Sử dụng hàm formatSecureURL ở đây
        guard let remoteURL = formatSecureURL(item.fileURL) else { throw PatchPackageError.invalidImportLink }

        let localURL = try await ensureLocalPackage(itemID: item.id, remoteURL: remoteURL)
        let password = item.resolvedPackagePassword
        let packageID = try await Task.detached(priority: .userInitiated) {
            let data = try Data(contentsOf: localURL)
            let summary = try PatchPackageCodec.inspect(data)
            if summary.isPasswordProtected {
                guard let password, !password.isEmpty else { throw PatchPackageError.invalidPasswordOrCorruptedPackage }
            }
            let decoded = try PatchPackageCodec.decode(data, password: password)
            _ = try DevicePatchService.apply(project: decoded.project)
            return decoded.project.id
        }.value
        try setApplied(true, itemID: item.id)
        try rememberPackageID(itemID: item.id, packageID: packageID)
    }

    static func disable(item: GameCatalogItem) async throws {
        let packageID: UUID? = {
            if let remembered = try? rememberedPackageID(itemID: item.id) { return remembered }
            if let local = try? localPackageURL(itemID: item.id),
               FileManager.default.fileExists(atPath: local.path),
               let data = try? Data(contentsOf: local),
               let summary = try? PatchPackageCodec.inspect(data) { return summary.packageID }
            return nil
        }()

        guard let packageID else {
            try setApplied(false, itemID: item.id)
            return
        }

        try await Task.detached(priority: .userInitiated) {
            guard let receipt = DevicePatchService.latestReceipt(projectID: packageID) else {
                throw PatchPackageError.restoreFailed
            }
            try DevicePatchService.restore(receipt: receipt)
        }.value
        try setApplied(false, itemID: item.id)
    }

    private static func packagesRootURL() throws -> URL {
        let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let root = base.appendingPathComponent("APEX", isDirectory: true).appendingPathComponent(packagesFolderName, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private static func localPackageURL(itemID: String) throws -> URL {
        let safe = itemID.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: ":", with: "_")
        return try packagesRootURL().appendingPathComponent("\(safe).3105", isDirectory: false)
    }

    private static func stateURL() throws -> URL {
        try packagesRootURL().appendingPathComponent(stateFileName, isDirectory: false)
    }

    private static let mapFileName = "item-package-map.json"

    private static func mapURL() throws -> URL {
        try packagesRootURL().appendingPathComponent(mapFileName, isDirectory: false)
    }

    private static func rememberPackageID(itemID: String, packageID: UUID) throws {
        var map = loadPackageMap()
        map[itemID] = packageID.uuidString
        let data = try JSONSerialization.data(withJSONObject: map, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: mapURL(), options: .atomic)
    }

    private static func rememberedPackageID(itemID: String) throws -> UUID? {
        guard let raw = loadPackageMap()[itemID] else { return nil }
        return UUID(uuidString: raw)
    }

    private static func loadPackageMap() -> [String: String] {
        guard let url = try? mapURL(),
              let data = try? Data(contentsOf: url),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: String]
        else { return [:] }
        return object
    }
}
