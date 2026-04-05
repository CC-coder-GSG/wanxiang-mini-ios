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
