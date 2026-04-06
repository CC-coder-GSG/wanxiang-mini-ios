import Foundation

// MARK: - Auth

struct LoginResponse: Decodable {
    let code: Int
    let data: LoginData
    let message: String
}

struct LoginData: Decodable {
    let access_token: String
    let user_name: String
    let user_real_name: String
    let user_id: String
}

struct SimpleResponse: Decodable {
    let code: Int
    let message: String
}

// MARK: - Device Registration

struct RegisterInfoResponse: Decodable {
    let code: Int
    let data: RegisterData
    let message: String
}

struct RegisterData: Decodable {
    let pageModel: PageModel
}

struct PageModel: Decodable {
    let records: [RegRecord]
    let total: Int
    let size: Int
    let current: Int
    let pages: Int
}

struct RegRecord: Decodable, Identifiable {
    var id: String { sn }
    let sn: String
    let companyName: String
    let createTime: String
    let productionType: String
    let tempRegDeadline: String?
    let tempRegCodeExpireTime: String?
    let tempRegCodeHave: Bool?
    let permanentRegCodeHave: Bool
    let permanentRegCodeOn: Bool
    let isHostNet: Bool
    let isNtrip: Bool
    let offHostNetTime: String?
    let offNtripTime: String?
    let lastUpdateTime: String?
    let lastUserName: String?
    let remark: String?
    let trialDay: Int
    let trialStatus: String
    let todayCanTrial: Bool
}

struct FinalInfoResponse: Decodable {
    let code: Int
    let data: FinalInfoData
    let message: String
}

struct FinalInfoData: Decodable {
    let devRegInfo: DevRegInfo
}

struct DevRegInfo: Decodable {
    let sn: String
    let companyName: String
    let createTime: String
    let productionType: String
    let tempRegDeadline: String
    let tempRegCodeExpireTime: String
    let tempRegCodeHave: Bool
    let permanentRegCodeHave: Bool
    let isHostNet: Bool
    let isNtrip: Bool
}

struct OutResponse: Decodable {
    let code: Int
    let data: OutData?
    let message: String
}

struct OutData: Decodable {
    let tempRegDeadline: String?
}

// MARK: - Function Authorization

struct FunctionUpdateRequest: Encodable {
    let snList: [String]
    let isHostNet: Bool
    let isNtrip: Bool
    let initHostNetRegDeadline: String?
    let initNtripRegDeadline: String?
    let offHostNetTime: String?
    let offNtripTime: String?
    let isSelectall: Bool = false
    let keyword: String?   // Android passes SN here
    let lastUpdateTime: String?
    let HostNetDeadlineTimeEditable: Bool = true
    let NtripDeadlineTimeEditable: Bool = true
    let companyId: String = ""
    let trialStatus: String? = nil
    let type: Int = 2      // Android hardcodes 2
}

// MARK: - Software License

struct SoftwareListResponse: Decodable {
    let code: Int
    let data: SoftwarePageData
    let message: String
}

struct SoftwarePageData: Decodable {
    let content: [SoftwareLicense]
    let totalElements: Int?
    let totalPages: Int?
    let number: Int?
    let size: Int?
}

struct SoftwareLicense: Decodable, Identifiable {
    var id: String { self.licenseId }
    let licenseId: String
    let batchNo: String?
    let passWord: String
    let creationTime: String?
    let expirationDate: String?
    let redeemableDays: Int?
    let remark: String?
    let salesMan: String?
    let state: String?
    let functions: [SoftwareFunction]?

    enum CodingKeys: String, CodingKey {
        case licenseId = "id"
        case batchNo, passWord, creationTime, expirationDate
        case redeemableDays, remark, salesMan, state
        case functions = "function"
    }
}

struct SoftwareFunction: Decodable {
    let id: Int
    let regDays: Int
    let enable: Bool
}

struct NewSoftwareRequest: Encodable {
    let cn: Bool
    let companyId: String?
    let expirationDate: String
    let functions: [NewSoftwareFunction]
    let genNum: Int
    let isDomestic: Int
    let isExport: Bool
    let remark: String
    let salesMan: String
}

struct NewSoftwareFunction: Encodable {
    let id: Int
    let regDays: Int
}

// MARK: - CORS Accounts

struct CorsListResponse: Decodable {
    let code: Int
    let data: CorsPageData
    let message: String
}

struct CorsPageData: Decodable {
    let records: [CorsAccount]
    let total: Int
    let size: Int
    let current: Int
    let pages: Int
}

struct CorsAccount: Decodable, Identifiable {
    let id: Int
    let name: String
    let accountStatus: Int
    let accountType: Int
    let activeStatus: Int
    let activeTime: Int64?
    let expiredate: Int64?
    let registerdate: Int64?
    let remark: String?
}

struct PasswordResponse: Decodable {
    let code: Int
    let data: String
    let message: String
}

// MARK: - Cross Region

struct ReceiverResponse: Decodable {
    let code: Int
    let data: ReceiverData
    let message: String
}

struct ReceiverData: Decodable {
    let list: [DeviceItem]
    let currPage: Int?
    let pageSize: Int?
    let totalCount: Int?
}

struct DeviceItem: Decodable, Identifiable {
    let id: Int
    let sn: String
    let deviceType: String?
    let salesName: String?
    let remark: String?
    let remainingTime: Int?
    let online: Bool?
    let isFarm: Bool?
    let status: Int?
    let duration: Int?
    let createTime: Int64?
    let expireTime: Int64?
}

struct DeviceDetailResponse: Decodable {
    let code: Int
    let data: DeviceDetail
    let message: String
}

struct DeviceDetail: Decodable {
    let id: Int
    let sn: String
    let deviceType: String
    let accountType: String
    let isSpan: Bool
    let isFarm: Bool
    let salesName: String?
    let remark: String?
    let remainingTime: Int
    let duration: Int
    let status: Int
    let online: Bool
    let createTime: Int64
    let expireTime: Int64
    let creatorName: String?

    enum CodingKeys: String, CodingKey {
        case id, sn, deviceType, accountType, isSpan, isFarm
        case salesName, remark, remainingTime, duration, status
        case online, createTime, expireTime, creatorName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeLossyInt(forKey: .id)
        sn = try container.decodeLossyString(forKey: .sn)
        deviceType = try container.decodeLossyString(forKey: .deviceType, defaultValue: "—")
        accountType = try container.decodeLossyString(forKey: .accountType, defaultValue: "9")
        isSpan = try container.decodeLossyBool(forKey: .isSpan, defaultValue: false)
        isFarm = try container.decodeLossyBool(forKey: .isFarm, defaultValue: false)
        salesName = try container.decodeIfPresent(String.self, forKey: .salesName)
        remark = try container.decodeIfPresent(String.self, forKey: .remark)
        remainingTime = try container.decodeLossyInt(forKey: .remainingTime, defaultValue: 0)
        duration = try container.decodeLossyInt(forKey: .duration, defaultValue: 0)
        status = try container.decodeLossyInt(forKey: .status, defaultValue: 0)
        online = try container.decodeLossyBool(forKey: .online, defaultValue: false)
        createTime = try container.decodeLossyInt64(forKey: .createTime, defaultValue: 0)
        expireTime = try container.decodeLossyInt64(forKey: .expireTime, defaultValue: 0)
        creatorName = try container.decodeIfPresent(String.self, forKey: .creatorName)
    }
}

private extension KeyedDecodingContainer {
    func decodeLossyString(forKey key: Key, defaultValue: String? = nil) throws -> String {
        if let value = try decodeIfPresent(String.self, forKey: key) {
            return value
        }
        if let value = try decodeIfPresent(Int.self, forKey: key) {
            return String(value)
        }
        if let value = try decodeIfPresent(Int64.self, forKey: key) {
            return String(value)
        }
        if let value = try decodeIfPresent(Double.self, forKey: key) {
            return String(value)
        }
        if let value = try decodeIfPresent(Bool.self, forKey: key) {
            return value ? "true" : "false"
        }
        if let defaultValue {
            return defaultValue
        }
        throw DecodingError.keyNotFound(key, .init(codingPath: codingPath, debugDescription: "Missing string-like value"))
    }

    func decodeLossyBool(forKey key: Key, defaultValue: Bool? = nil) throws -> Bool {
        if let value = try decodeIfPresent(Bool.self, forKey: key) {
            return value
        }
        if let value = try decodeIfPresent(Int.self, forKey: key) {
            return value != 0
        }
        if let value = try decodeIfPresent(String.self, forKey: key) {
            switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "true", "1", "yes", "y":
                return true
            case "false", "0", "no", "n":
                return false
            default:
                break
            }
        }
        if let defaultValue {
            return defaultValue
        }
        throw DecodingError.keyNotFound(key, .init(codingPath: codingPath, debugDescription: "Missing bool-like value"))
    }

    func decodeLossyInt(forKey key: Key, defaultValue: Int? = nil) throws -> Int {
        if let value = try decodeIfPresent(Int.self, forKey: key) {
            return value
        }
        if let value = try decodeIfPresent(Int64.self, forKey: key) {
            return Int(value)
        }
        if let value = try decodeIfPresent(Double.self, forKey: key) {
            return Int(value)
        }
        if let value = try decodeIfPresent(String.self, forKey: key), let intValue = Int(value) {
            return intValue
        }
        if let value = try decodeIfPresent(Bool.self, forKey: key) {
            return value ? 1 : 0
        }
        if let defaultValue {
            return defaultValue
        }
        throw DecodingError.keyNotFound(key, .init(codingPath: codingPath, debugDescription: "Missing int-like value"))
    }

    func decodeLossyInt64(forKey key: Key, defaultValue: Int64? = nil) throws -> Int64 {
        if let value = try decodeIfPresent(Int64.self, forKey: key) {
            return value
        }
        if let value = try decodeIfPresent(Int.self, forKey: key) {
            return Int64(value)
        }
        if let value = try decodeIfPresent(Double.self, forKey: key) {
            return Int64(value)
        }
        if let value = try decodeIfPresent(String.self, forKey: key), let intValue = Int64(value) {
            return intValue
        }
        if let defaultValue {
            return defaultValue
        }
        throw DecodingError.keyNotFound(key, .init(codingPath: codingPath, debugDescription: "Missing int64-like value"))
    }
}

// MARK: - Diagnostic Tools

struct DiagnosticResponse: Decodable {
    let code: Int
    let data: DiagnosticData?
    let message: String
}

struct DiagnosticData: Decodable {
    let basic: DiagBasic?
    let latest: DiagLatest?
}

struct DiagBasic: Decodable {
    let name: String?
    let status: Int?       // 0=正常 1=未激活 2=已过期
    let expiredate: Int64?
}

struct DiagLatest: Decodable {
    let online: Bool?
    let lastloadtime: Int64?
    let lastunloadtime: Int64?
    let type: Int?          // 0=Ntrip 1=Tcp
    let mountPoint: String?
    let ggaTime: Int64?
    let boradCastTime: Int64?
    let state: Int?         // 定位状态: 0=未定位 1=单点 2=伪距差分 3=PPS 4=固定解 5=浮点解 6=惯性导航
}

struct UsageDetailResponse: Decodable {
    let code: Int
    let data: UsageDetailData?
    let message: String
}

struct UsageDetailData: Decodable {
    let useInfo: UseInfo?
    let statusList: [StatusSegment]?
    let stateList: [StatePoint]?
}

struct UseInfo: Decodable {
    let onlineTime: Double?
    let avgDelay: Double?
    let avgSatNum: Double?
    let ggaCount: Int?
    let invalidGga: Int?
    let fixed: String?    // 服务端返回百分比字符串，如 "90.9%"
    let floated: String?  // 服务端返回百分比字符串，如 "9.1%"
    let logIn: Int?
    let logOut: Int?
}

struct StatusSegment: Decodable, Identifiable {
    var id: UUID { UUID() }
    let online: Bool?
    let timeLength: Double?
    let startTime: Int64?
    let endTime: Int64?
}

struct StatePoint: Decodable {
    let createTime: Int64?
    let state: Int?
    let satNum: Int?
    let delay: Double?
}

struct WarnPageResponse: Decodable {
    let code: Int
    let data: WarnPageData?
    let message: String
}

struct WarnPageData: Decodable {
    let records: [WarnRecord]?
    let total: Int?
    let pages: Int?
}

struct WarnRecord: Decodable, Identifiable {
    var id: UUID { UUID() }
    let createTime: Int64?
    let event: String?      // 服务端返回中文事件名，如 "用户上线"、"用户下线"
    let ip: String?
    let port: Int?
    let mountPoint: String?
    let content: String?
}

struct DealerSearchResponse: Decodable {
    let code: Int
    let data: [DealerItem]
    let message: String
}

struct DealerItem: Decodable, Identifiable {
    let companyId: Int
    let companyName: String
    let managerId: Int
    let tel: String?

    var id: Int { companyId }
}
