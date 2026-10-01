import Foundation
import CryptoKit
import Security

/// Identity of the original signed archive, not an endorsement by a store or CA.
public struct SignedExtensionIdentity: Codable, Equatable, Sendable {
    public let format: String
    public let extensionID: String
    public let publicKeySHA256: String
    public let packageSHA256: String
}

public struct CRXPackage: Sendable {
    public let archive: Data
    public let identity: SignedExtensionIdentity
    public static let maximumPackageBytes = 65 * 1024 * 1024

    /// CRX3's signed bytes and proof algorithms follow Chromium's verifier.
    /// All proofs must validate; one must bind the declared ID to its public key.
    public static func verify(_ input: Data) throws -> CRXPackage {
        let data = Data(input)
        guard data.count >= 12, data.count <= maximumPackageBytes,
              data.prefix(4) == Data("Cr24".utf8) else { throw invalid("Invalid or oversized CRX package.") }
        let version = little32(data, 4)
        guard version == 3 else { throw invalid("CRX version \(version) is unsupported. This build verifies CRX3; legacy CRX2 is not implemented.") }
        let headerSize = Int(little32(data, 8))
        guard headerSize > 0, headerSize <= 1024 * 1024, headerSize < data.count - 12 else {
            throw invalid("Invalid or oversized CRX3 header.")
        }
        let header = data.subdata(in: 12..<(12 + headerSize))
        // Match Chromium's rejection of ZIP end-directory tokens in the wrapper.
        let tokens: [[UInt8]] = [[0x50,0x4b,0x05,0x06], [0x50,0x4b,0x06,0x06], [0x50,0x4b,0x06,0x07]]
        for token in tokens {
            guard header.range(of: Data(token)) == nil else { throw invalid("ZIP directory token in CRX3 header.") }
        }
        let fields = try Proto.fields(header)
        let signedHeader = try Proto.one(10000, in: fields)
        let declaredID = try Proto.one(1, in: Proto.fields(signedHeader))
        guard declaredID.count == 16 else { throw invalid("CRX3 extension ID must be 16 bytes.") }
        let proofs = fields.filter { $0.number == 2 || $0.number == 3 }
        guard !proofs.isEmpty, proofs.count <= 32 else { throw invalid("CRX3 requires one to 32 signature proofs.") }
        let archive = data.subdata(in: (12 + headerSize)..<data.count)
        var hasher = SHA256()
        hasher.update(data: Data("CRX3 SignedData\0".utf8))
        var length = UInt32(signedHeader.count).littleEndian
        withUnsafeBytes(of: &length) { hasher.update(data: Data($0)) }
        hasher.update(data: signedHeader)
        hasher.update(data: archive)
        let digest = hasher.finalize()
        var developerKey: Data?
        for proof in proofs {
            guard let payload = proof.payload else { throw invalid("Invalid CRX3 proof wire type.") }
            let fields = try Proto.fields(payload)
            let publicKey = try Proto.one(1, in: fields), signature = try Proto.one(2, in: fields)
            guard !publicKey.isEmpty, publicKey.count <= 8192, !signature.isEmpty, signature.count <= 8192 else {
                throw invalid("Invalid or oversized CRX3 key/signature.")
            }
            let valid: Bool
            if proof.number == 2 {
                let pkcs1 = try rsaPublicKey(publicKey)
                let attributes: [CFString: Any] = [kSecAttrKeyType:kSecAttrKeyTypeRSA, kSecAttrKeyClass:kSecAttrKeyClassPublic]
                var error: Unmanaged<CFError>?
                guard let key = SecKeyCreateWithData(pkcs1 as CFData, attributes as CFDictionary, &error),
                      let size = (SecKeyCopyAttributes(key) as? [CFString:Any])?[kSecAttrKeySizeInBits] as? Int,
                      size <= 8192 else { throw invalid("Invalid or oversized CRX3 RSA public key.") }
                valid = SecKeyVerifySignature(key, .rsaSignatureDigestPKCS1v15SHA256,
                                              Data(digest) as CFData, signature as CFData, &error)
            } else {
                do {
                    let key = try P256.Signing.PublicKey(derRepresentation: publicKey)
                    let signature = try P256.Signing.ECDSASignature(derRepresentation: signature)
                    valid = key.isValidSignature(signature, for: digest)
                } catch { throw invalid("Invalid CRX3 P-256 key or signature encoding.") }
            }
            guard valid else { throw invalid("CRX3 signature verification failed.") }
            if Data(SHA256.hash(data: publicKey).prefix(16)) == declaredID { developerKey = publicKey }
        }
        guard let developerKey else { throw invalid("No verified CRX3 developer key matches the declared extension ID.") }
        try ExtensionArchive.validate(archive)
        let alphabet = Array("abcdefghijklmnop")
        let id = String(declaredID.flatMap { [alphabet[Int($0 >> 4)], alphabet[Int($0 & 15)]] })
        return CRXPackage(archive: archive, identity: SignedExtensionIdentity(format: "CRX3", extensionID: id,
            publicKeySHA256: hex(SHA256.hash(data: developerKey)), packageSHA256: hex(SHA256.hash(data: data))))
    }

    private static func little32(_ data: Data, _ offset: Int) -> UInt32 {
        data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: UInt32.self).littleEndian }
    }
    private static func hex<T: Sequence>(_ bytes: T) -> String where T.Element == UInt8 {
        bytes.map { String(format: "%02x", $0) }.joined()
    }
    private static func invalid(_ message: String) -> ExtensionValidationError { .invalid(message) }

    /// Security imports RSA public keys as PKCS#1. CRX carries an X.509 SPKI.
    private static func rsaPublicKey(_ spki: Data) throws -> Data {
        var outer = DER(spki)
        var sequence = DER(try outer.element(0x30)); try outer.requireEnd()
        var algorithm = DER(try sequence.element(0x30))
        guard try algorithm.element(0x06) == Data([0x2a,0x86,0x48,0x86,0xf7,0x0d,0x01,0x01,0x01]) else {
            throw invalid("CRX3 RSA proof has the wrong key algorithm.")
        }
        if !algorithm.atEnd { guard try algorithm.element(0x05).isEmpty else { throw invalid("Invalid RSA parameters.") } }
        try algorithm.requireEnd()
        let bits = try sequence.element(0x03); try sequence.requireEnd()
        guard bits.count > 1, bits.first == 0 else { throw invalid("Invalid RSA public-key bit string.") }
        return Data(bits.dropFirst())
    }
}

private struct Proto {
    struct Field { let number: Int; let payload: Data? }
    static func one(_ number: Int, in fields: [Field]) throws -> Data {
        let matching = fields.filter { $0.number == number }
        guard matching.count == 1, let payload = matching[0].payload else {
            throw ExtensionValidationError.invalid("Missing, repeated or invalid CRX3 field \(number).")
        }
        return payload
    }
    static func fields(_ data: Data) throws -> [Field] {
        let bytes = Array(data); var cursor = 0; var fields: [Field] = []
        func varint() throws -> UInt64 {
            var result: UInt64 = 0
            for shift in stride(from: 0, through: 63, by: 7) {
                guard cursor < bytes.count else { throw ExtensionValidationError.invalid("Truncated CRX3 varint.") }
                let byte = bytes[cursor]; cursor += 1
                guard shift < 63 || byte <= 1 else { throw ExtensionValidationError.invalid("CRX3 varint overflow.") }
                result |= UInt64(byte & 0x7f) << shift
                if byte & 0x80 == 0 { return result }
            }
            throw ExtensionValidationError.invalid("Invalid CRX3 varint.")
        }
        while cursor < bytes.count {
            guard fields.count < 4096 else { throw ExtensionValidationError.invalid("Too many CRX3 fields.") }
            let key = try varint(), number = key >> 3
            guard number > 0, number <= 0x1fffffff else { throw ExtensionValidationError.invalid("Invalid CRX3 field number.") }
            var payload: Data?
            switch key & 7 {
            case 0: _ = try varint()
            case 1, 5:
                let size = key & 7 == 1 ? 8 : 4
                guard size <= bytes.count - cursor else { throw ExtensionValidationError.invalid("Truncated CRX3 field.") }
                cursor += size
            case 2:
                let size = try varint()
                guard size <= UInt64(bytes.count - cursor) else { throw ExtensionValidationError.invalid("Truncated CRX3 field.") }
                payload = Data(bytes[cursor..<(cursor + Int(size))]); cursor += Int(size)
            default: throw ExtensionValidationError.invalid("Unsupported CRX3 protobuf wire type.")
            }
            fields.append(Field(number: Int(number), payload: payload))
        }
        return fields
    }
}

private struct DER {
    let bytes: [UInt8]; var cursor = 0
    init(_ data: Data) { bytes = Array(data) }
    var atEnd: Bool { cursor == bytes.count }
    func requireEnd() throws { guard atEnd else { throw ExtensionValidationError.invalid("Trailing CRX3 key data.") } }
    mutating func element(_ tag: UInt8) throws -> Data {
        guard cursor + 2 <= bytes.count, bytes[cursor] == tag else { throw ExtensionValidationError.invalid("Invalid CRX3 key DER.") }
        cursor += 1
        let first = bytes[cursor]; cursor += 1
        var length = Int(first)
        if first & 0x80 != 0 {
            let count = Int(first & 0x7f)
            guard count > 0, count <= 4, count <= bytes.count - cursor, bytes[cursor] != 0 else { throw ExtensionValidationError.invalid("Invalid CRX3 DER length.") }
            length = 0
            for _ in 0..<count { length = length << 8 | Int(bytes[cursor]); cursor += 1 }
            guard length >= 128 else { throw ExtensionValidationError.invalid("Noncanonical CRX3 DER length.") }
        }
        guard length <= bytes.count - cursor else { throw ExtensionValidationError.invalid("Truncated CRX3 key DER.") }
        defer { cursor += length }
        return Data(bytes[cursor..<(cursor + length)])
    }
}
