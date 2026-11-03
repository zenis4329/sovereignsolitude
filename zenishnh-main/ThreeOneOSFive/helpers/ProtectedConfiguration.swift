import Foundation

enum ProtectedConfiguration {
    private static func decodeMasked(cipher: [UInt8], mask: [UInt8], checksum: UInt64) -> String {
        guard cipher.count == mask.count else { return "" }
        let bytes = zip(cipher, mask).enumerated().map { index, pair -> UInt8 in
            let position = UInt8(truncatingIfNeeded: (index &* 29) &+ 0x53)
            return (pair.0 &- position) ^ pair.1
        }
        guard let value = String(bytes: bytes, encoding: .utf8) else { return "" }
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return hash == checksum ? value : ""
    }

    private static func decode(_ bytes: [UInt8], seed: UInt8) -> String {
        let decoded = bytes.enumerated().map { index, byte in
            byte ^ (seed &+ UInt8(truncatingIfNeeded: index &* 17))
        }
        return String(bytes: decoded, encoding: .utf8) ?? ""
    }

    private static func verified(_ bytes: [UInt8], seed: UInt8, checksum: UInt64) -> String {
        let value = decode(bytes, seed: seed)
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return hash == checksum ? value : ""
    }

    static var packageToken: String {
        decodeMasked(
            cipher: [
                207, 0, 6, 100, 28, 19, 32, 248, 156, 190, 89, 211, 126, 113,
                69, 250, 57, 162, 19, 192, 207, 182, 52, 34, 180, 161, 125,
                89, 59, 34, 81, 75, 143, 135, 36, 176
            ],
            mask: [
                12, 251, 30, 229, 0, 95, 50, 233, 52, 3, 134, 45, 168, 231,
                26, 177, 92, 11, 238, 117, 80, 111, 2, 121, 132, 19, 86, 189,
                248, 247, 234, 65, 172, 27, 190, 5
            ],
            checksum: 0x93D8690958105F50
        )
    }

    // ĐÃ XÓA LINK ZENISCONFIG.PHP, KHÔNG CHO APP GỌI ĐẾN NỮA
    static var catalogURL: URL? {
        return nil
    }
}
