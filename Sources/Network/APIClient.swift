import Foundation

// MARK: - API Error

enum APIError: LocalizedError {
    case notLoggedIn
    case serverError(String)
    case networkError(Error)
    case decodingError(Error)
    case unknown

    var errorDescription: String? {
        switch self {
        case .notLoggedIn: return "请先登录"
        case .serverError(let msg): return msg
        case .networkError(let e): return "网络异常：\(e.localizedDescription)"
        case .decodingError(let e): return "数据解析失败：\(e.localizedDescription)"
        case .unknown: return "未知错误"
        }
    }
}

// MARK: - APIClient

final class APIClient {
    static let shared = APIClient()
    private init() {}

    private let baseURL = URL(string: "https://cloud.sinognss.com/")!

    // MARK: - Auth

    func login(username: String, password: String) async throws -> LoginData {
        let encryptedPassword = try RSAEncryptor.encrypt(password)
        var comps = URLComponents(url: baseURL.appendingPathComponent("gateway/auth/oauth/token"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            .init(name: "username", value: username),
            .init(name: "password", value: encryptedPassword),
            .init(name: "grant_type", value: "password"),
            .init(name: "client_id", value: "NaviCloud"),
            .init(name: "client_secret", value: "NaviCloud_Secret"),
            .init(name: "scope", value: "all"),
            .init(name: "isAgree", value: "false")
        ]
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "GET"
        let body: LoginResponse = try await perform(req)
        guard body.message == "操作成功" else { throw APIError.serverError(body.message) }
        return body.data
    }

    // MARK: - Device Registration

    func fetchRegisterInfo(keyword: String, token: String) async throws -> [RegRecord] {
        let body: [String: Any] = [
            "keyword": keyword,
            "orderItems": [["asc": false, "column": "create_time"]],
            "companyId": NSNull(),
            "trialStatus": NSNull(),
            "current": 1,
            "size": 10
        ]
        let resp: RegisterInfoResponse = try await postJSON("gateway/dr/deviceRegInfo/list", body: body, token: token)
        return resp.data.pageModel.records
    }

    func generateDomesticCode(sn: String, expireTime: String, token: String) async throws -> SimpleResponse {
        let body: [String: Any] = [
            "sn": sn,
            "tempRegCodeExpireTime": expireTime,
            "tempRegCodeType": "DOMESTIC"
        ]
        return try await postJSON("gateway/dr/deviceRegInfo/generateRegCodeAndPush", body: body, token: token)
    }

    func extendRegDeadline(sn: String, deadline: String, token: String) async throws -> SimpleResponse {
        let body: [String: Any] = [
            "isUpdateAll": false,
            "snList": [sn],
            "tempRegDeadline": deadline
        ]
        return try await putJSON("gateway/dr/deviceRegInfo/updateRegInfoById", body: body, token: token)
    }

    func fetchFinalRegInfo(sn: String, token: String) async throws -> DevRegInfo {
        var comps = URLComponents(url: baseURL.appendingPathComponent("gateway/dr/deviceRegInfo/getRegInfoBySn"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [.init(name: "sn", value: sn)]
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "GET"
        req.setValue("bearer \(token)", forHTTPHeaderField: "Authorization")
        let resp: FinalInfoResponse = try await perform(req)
        return resp.data.devRegInfo
    }

    func outDevice(sn: String, token: String) async throws -> SimpleResponse {
        var comps = URLComponents(url: baseURL.appendingPathComponent("gateway/dr/deviceRegInfo/updateTrialStatus"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [.init(name: "sn", value: sn)]
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "PUT"
        req.setValue("bearer \(token)", forHTTPHeaderField: "Authorization")
        let resp: OutResponse = try await perform(req)
        return SimpleResponse(code: resp.code, message: resp.message)
    }

    func pushPermanentCode(sn: String, token: String) async throws -> SimpleResponse {
        var comps = URLComponents(url: baseURL.appendingPathComponent("gateway/dr/deviceRegInfo/permanent/push"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [.init(name: "sn", value: sn)]
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "GET"
        req.setValue("bearer \(token)", forHTTPHeaderField: "Authorization")
        return try await perform(req)
    }

    func trialDevice(sn: String, token: String) async throws -> SimpleResponse {
        // Android uses @Query params: ?sn=xxx&day=1
        var comps = URLComponents(url: baseURL.appendingPathComponent("gateway/dr/deviceRegInfo/trialOne"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [.init(name: "sn", value: sn), .init(name: "day", value: "1")]
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "PUT"
        req.setValue("bearer \(token)", forHTTPHeaderField: "Authorization")
        return try await perform(req)
    }

    func updateTrialDays(sn: String, days: Int, token: String) async throws -> SimpleResponse {
        // Android uses @Query params: ?sn=xxx&day=xxx
        var comps = URLComponents(url: baseURL.appendingPathComponent("gateway/dr/deviceRegInfo/updateTrialDay"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [.init(name: "sn", value: sn), .init(name: "day", value: "\(days)")]
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "PUT"
        req.setValue("bearer \(token)", forHTTPHeaderField: "Authorization")
        return try await perform(req)
    }

    func updateTempRegDeadline(sn: String, deadline: String, token: String) async throws -> SimpleResponse {
        let body: [String: Any] = [
            "isUpdateAll": false,
            "snList": [sn],
            "tempRegDeadline": deadline
        ]
        return try await putJSON("gateway/dr/deviceRegInfo/updateRegInfoById", body: body, token: token)
    }

    // MARK: - Function Authorization

    func updateFunctions(info: FunctionUpdateRequest, token: String) async throws -> SimpleResponse {
        let body = try jsonObject(info)
        return try await putJSONRaw("gateway/dr/deviceRegSet/batchUpdate", body: body, token: token)
    }

    // MARK: - Software License

    func fetchSoftwareLicenses(keyword: String, page: Int, size: Int, token: String) async throws -> SoftwarePageData {
        // Android sends state:"" (all states), sort creationTime:""
        let body: [String: Any] = [
            "keyword": keyword,
            "page": page,
            "query": ["domestic": true, "state": ""],
            "size": size,
            "sort": ["creationTime": ""]
        ]
        let resp: SoftwareListResponse = try await postJSON("gateway/mr/redemption/paged", body: body, token: token)
        return resp.data
    }

    func createSoftwareLicense(request: NewSoftwareRequest, userId: String?, token: String) async throws -> SimpleResponse {
        // Build manually to ensure companyId is sent as null (not omitted) — matching Android Gson serializeNulls
        let fns = request.functions.map { ["id": $0.id, "regDays": $0.regDays] as [String: Any] }
        let body: [String: Any] = [
            "cn": request.cn,
            "companyId": NSNull(),
            "expirationDate": request.expirationDate,
            "functions": fns,
            "genNum": request.genNum,
            "isDomestic": request.isDomestic,
            "isExport": request.isExport,
            "remark": request.remark,
            "salesMan": request.salesMan
        ]
        return try await postJSON("gateway/mr/redemption/batchGen", body: body, token: token, extraHeaders: ["userId": userId ?? ""])
    }

    // MARK: - CORS Account

    func fetchCorsAccounts(keyword: String?, page: Int, size: Int, token: String) async throws -> CorsPageData {
        let body: [String: Any] = [
            "conditions": [
                "accountStatus": NSNull(),
                "accountType": NSNull(),
                "activeStatus": NSNull(),
                "instanceId": NSNull()
            ],
            "current": page,
            "keyword": keyword as Any,
            "size": size
        ]
        let resp: CorsListResponse = try await postJSON("gateway/BaseUser/userInfo/list", body: body, token: token)
        return resp.data
    }

    func checkCorsPassword(id: Int, token: String) async throws -> String {
        let body: [String: Any] = ["id": String(id)]
        let resp: PasswordResponse = try await postJSON("gateway/BaseUser/userInfo/checkPass", body: body, token: token)
        return resp.data
    }

    func resetCorsPassword(id: Int, token: String) async throws -> String {
        let body: [String: Any] = ["id": String(id)]
        let resp: PasswordResponse = try await postJSON("gateway/BaseUser/userInfo/resetPass", body: body, token: token)
        return resp.data
    }

    func setCustomCorsPassword(id: Int, password: String, token: String) async throws -> SimpleResponse {
        let body: [String: Any] = ["id": id, "password": password]
        return try await postJSON("gateway/BaseUser/userInfo/customPass", body: body, token: token)
    }

    // MARK: - Cross Region

    func fetchDeviceList(keyword: String, page: Int, pageSize: Int, token: String) async throws -> ReceiverData {
        let conditions = "{\"name\":\"\(keyword)\",\"status\":null}"
        let resp: ReceiverResponse = try await postForm(
            "gateway/DiffPlat/device/list",
            fields: ["currPage": "\(page)", "pageSize": "\(pageSize)", "conditions": conditions],
            token: token
        )
        return resp.data
    }

    func fetchDeviceDetail(id: Int, token: String) async throws -> DeviceDetail {
        let resp: DeviceDetailResponse = try await postForm(
            "gateway/DiffPlat/device/detail",
            fields: ["id": "\(id)"],
            token: token
        )
        return resp.data
    }

    func updateSpan(id: Int, isSpan: Bool, token: String) async throws -> SimpleResponse {
        return try await postForm(
            "gateway/DiffPlat/device/span/upadte",
            fields: ["id": "\(id)", "isSpan": isSpan ? "true" : "false"],
            token: token
        )
    }

    func updateAccountType(sn: String, accountType: String, token: String) async throws -> SimpleResponse {
        return try await postForm(
            "gateway/DiffPlat/device/accountType/update",
            fields: ["sn": sn, "accountType": accountType],
            token: token
        )
    }

    func searchDealer(keyword: String, token: String) async throws -> [DealerItem] {
        let resp: DealerSearchResponse = try await postForm(
            "gateway/DiffPlat/device/declarCompany",
            fields: ["keyword": keyword],
            token: token
        )
        return resp.data
    }

    func saveEquipment(sn: String, companyId: String?, managerId: String?, remark: String, duration: String, token: String) async throws -> SimpleResponse {
        var fields: [String: String] = [
            "sn": sn,
            "remark": remark,
            "active": "true",
            "duration": duration
        ]
        if let cid = companyId { fields["declarCompanyId"] = cid }
        if let mid = managerId { fields["decalrId"] = mid }
        return try await postForm("gateway/DiffPlat/device/save", fields: fields, token: token)
    }

    func deleteEquipment(sn: String, token: String) async throws -> SimpleResponse {
        var comps = URLComponents(url: baseURL.appendingPathComponent("gateway/DiffPlat/device/delete"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [.init(name: "sn", value: sn)]
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "GET"
        req.setValue("bearer \(token)", forHTTPHeaderField: "Authorization")
        return try await perform(req)
    }

    // MARK: - Diagnostic Tools

    func fetchDiagnostic(id: Int, name: String, token: String) async throws -> DiagnosticData {
        let body: [String: Any] = ["id": id, "name": name]
        let resp: DiagnosticResponse = try await postJSON("gateway/BaseUser/userInfo/userDiago", body: body, token: token)
        guard resp.code == 0 else { throw APIError.serverError(resp.message) }
        return resp.data ?? DiagnosticData(basic: nil, latest: nil)
    }

    func fetchUsageDetail(id: Int, name: String, st: Int64, et: Int64, token: String) async throws -> UsageDetailData {
        let body: [String: Any] = ["id": id, "name": name, "st": st, "et": et]
        let resp: UsageDetailResponse = try await postJSON("gateway/BaseUser/userInfo/usageDetail", body: body, token: token)
        guard resp.code == 0 else { throw APIError.serverError(resp.message) }
        return resp.data ?? UsageDetailData(useInfo: nil, statusList: nil, stateList: nil)
    }

    func fetchWarnPage(id: Int, name: String, st: Int64, et: Int64, page: Int, size: Int, token: String) async throws -> WarnPageData {
        let body: [String: Any] = ["id": id, "name": name, "st": st, "et": et, "current": page, "size": size]
        let resp: WarnPageResponse = try await postJSON("gateway/BaseUser/userInfo/warnPage", body: body, token: token)
        guard resp.code == 0 else { throw APIError.serverError(resp.message) }
        return resp.data ?? WarnPageData(records: nil, total: nil, pages: nil)
    }

    // MARK: - Private Helpers

    private func postJSON<T: Decodable>(_ path: String, body: [String: Any], token: String, extraHeaders: [String: String] = [:]) async throws -> T {
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.httpMethod = "POST"
        req.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        req.setValue("bearer \(token)", forHTTPHeaderField: "Authorization")
        for (k, v) in extraHeaders { req.setValue(v, forHTTPHeaderField: k) }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await perform(req)
    }

    private func postJSONRaw<T: Decodable>(_ path: String, body: [String: Any], token: String) async throws -> T {
        return try await postJSON(path, body: body, token: token)
    }

    private func putJSON<T: Decodable>(_ path: String, body: [String: Any], token: String) async throws -> T {
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.httpMethod = "PUT"
        req.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        req.setValue("bearer \(token)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await perform(req)
    }

    private func putJSONRaw<T: Decodable>(_ path: String, body: [String: Any], token: String) async throws -> T {
        return try await putJSON(path, body: body, token: token)
    }

    private func postForm<T: Decodable>(_ path: String, fields: [String: String], token: String) async throws -> T {
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded;charset=UTF-8", forHTTPHeaderField: "Content-Type")
        req.setValue("bearer \(token)", forHTTPHeaderField: "Authorization")
        req.httpBody = fields
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)
        return try await perform(req)
    }

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        do {
            print("🌐 \(request.httpMethod ?? "GET") \(request.url?.absoluteString ?? "")")
            print("📋 Headers: \(request.allHTTPHeaderFields ?? [:])")
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse {
                if http.statusCode == 401 { throw APIError.notLoggedIn }
                if http.statusCode >= 400 {
                    if let raw = String(data: data, encoding: .utf8) {
                        print("🔴 HTTP \(http.statusCode) from \(request.url?.path ?? ""): \(raw)")
                    }
                    let msg = extractGatewayError(from: data) ?? "请求失败(\(http.statusCode))"
                    throw APIError.serverError(msg)
                }
            }
            do {
                return try JSONDecoder().decode(T.self, from: data)
            } catch {
                if let raw = String(data: data, encoding: .utf8) {
                    print("❌ Decode error for \(T.self): \(error)")
                    print("📦 Raw JSON: \(raw)")
                }
                throw APIError.decodingError(error)
            }
        } catch let e as APIError {
            throw e
        } catch {
            throw APIError.networkError(error)
        }
    }

    private func extractGatewayError(from data: Data) -> String? {
        struct GatewayError: Decodable { let error: String? }
        return (try? JSONDecoder().decode(GatewayError.self, from: data))?.error
    }

    private func jsonObject<T: Encodable>(_ value: T) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        return obj
    }
}
