import Foundation
import Security

/// 使用服务端公钥对密码做 RSA PKCS#1 v1.5 加密
/// 公钥来源：sinognss.cn 前端 JS 硬编码
enum RSAEncryptor {

    // SubjectPublicKeyInfo (PKCS#8) 格式的 RSA-2048 公钥
    private static let publicKeyBase64 =
        "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAjtu1w4s79b6tN8NmYxHh" +
        "0oNmW+CmAh1MpSJaZbkI2Un/3TMqQx3m2fvHnqYPRCNAILn4oueWfYNJjPtnKMH" +
        "2XXbUWq/li1/uqwr2zUkey1pWf7UlDKKP5gUMdCmxOFGHcG98BZIF46AsLlEvOr" +
        "FDTy3pnDWv6h7thsLi7CmqlFTye0XvesTsxwELvmV8BShEo3PXNPpFbnoT9R7FT" +
        "si7cGRE8uISyavCzImRBa4lVqdK3Z33V4/CRjbtDL2W1hxAJm25coODUbI1AOA2" +
        "LMjs8EN7zKUfRNA+mCAtSIlmG5KvIrlAYcBEBlFcdbZmsFVpvCCZoeXrETaQ9ZEW" +
        "fQbMMQIDAQAB"

    // SubjectPublicKeyInfo 头固定为 24 字节，去掉后得到 PKCS#1 格式
    private static let pkcs8HeaderLength = 24

    static func encrypt(_ plainText: String) throws -> String {
        guard let keyData = Data(base64Encoded: publicKeyBase64) else {
            throw RSAError.invalidKey
        }

        // 去掉 PKCS#8 头，得到 iOS Security 框架所需的 PKCS#1 DER 格式
        let pkcs1Data = keyData.dropFirst(pkcs8HeaderLength)

        let attributes: [CFString: Any] = [
            kSecAttrKeyType:       kSecAttrKeyTypeRSA,
            kSecAttrKeyClass:      kSecAttrKeyClassPublic,
            kSecAttrKeySizeInBits: 2048
        ]
        var cfError: Unmanaged<CFError>?
        guard let secKey = SecKeyCreateWithData(pkcs1Data as CFData, attributes as CFDictionary, &cfError) else {
            throw RSAError.keyCreationFailed(cfError?.takeRetainedValue().localizedDescription ?? "unknown")
        }

        guard let plainData = plainText.data(using: .utf8) else {
            throw RSAError.encodingFailed
        }

        guard let encryptedData = SecKeyCreateEncryptedData(secKey, .rsaEncryptionPKCS1, plainData as CFData, &cfError) else {
            throw RSAError.encryptionFailed(cfError?.takeRetainedValue().localizedDescription ?? "unknown")
        }

        return (encryptedData as Data).base64EncodedString()
    }

    enum RSAError: LocalizedError {
        case invalidKey
        case keyCreationFailed(String)
        case encodingFailed
        case encryptionFailed(String)

        var errorDescription: String? {
            switch self {
            case .invalidKey:               return "RSA公钥无效"
            case .keyCreationFailed(let e): return "RSA密钥创建失败：\(e)"
            case .encodingFailed:           return "密码编码失败"
            case .encryptionFailed(let e):  return "RSA加密失败：\(e)"
            }
        }
    }
}
