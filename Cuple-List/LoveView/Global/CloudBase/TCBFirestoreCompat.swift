//
//  TCBFirestoreCompat.swift
//  Cuple-List
//
//  Firestore API 兼容层 → 腾讯云开发云函数 coupleListDb（HTTP）。
//  实时监听：轮询集合，与云端 HTTP 能力对齐。
//

import Foundation

// MARK: - Firebase 同名类型（避免改业务代码）

public final class FieldValue: NSObject {
    private override init() { super.init() }
    public static func serverTimestamp() -> FieldValue { FieldValue() }
}

public final class Timestamp: NSObject {
    public let seconds: Int64
    public let nanoseconds: Int32
    public init(seconds: Int64, nanoseconds: Int32) {
        self.seconds = seconds
        self.nanoseconds = nanoseconds
        super.init()
    }
    public init(date: Date) {
        let t = date.timeIntervalSince1970
        self.seconds = Int64(floor(t))
        self.nanoseconds = Int32((t - Double(seconds)) * 1_000_000_000)
        super.init()
    }
    public func dateValue() -> Date {
        Date(timeIntervalSince1970: Double(seconds) + Double(nanoseconds) / 1_000_000_000)
    }
}

public enum DocumentChangeType: Int {
    case added = 0
    case modified = 1
    case removed = 2
}

public struct DocumentChange {
    public let type: DocumentChangeType
    public let document: DocumentSnapshot
}

public final class DocumentSnapshot: NSObject {
    public let documentID: String
    public let exists: Bool
    private let storedData: [String: Any]?
    public let reference: DocumentReference
    public func data() -> [String: Any]? { storedData }
    init(documentID: String, exists: Bool, data: [String: Any]?, reference: DocumentReference) {
        self.documentID = documentID
        self.exists = exists
        self.storedData = data
        self.reference = reference
        super.init()
    }
}

public final class QuerySnapshot: NSObject {
    public let documents: [DocumentSnapshot]
    public let documentChanges: [DocumentChange]
    init(documents: [DocumentSnapshot], documentChanges: [DocumentChange]) {
        self.documents = documents
        self.documentChanges = documentChanges
        super.init()
    }
}

public final class ListenerRegistration {
    fileprivate var timer: DispatchSourceTimer?
    fileprivate var cancelled = false
    public func remove() {
        cancelled = true
        timer?.cancel()
        timer = nil
    }
}

// MARK: - Wire

private enum TCBWire {
    static func invoke(_ body: [String: Any], completion: @escaping (Result<[String: Any], Error>) -> Void) {
        guard let _ = CloudBaseConfig.gatewayHost else {
            completion(.failure(TCBCompatError.notConfigured))
            return
        }
        let token = CloudBaseConfig.accessToken
        guard !token.isEmpty else {
            completion(.failure(TCBCompatError.noToken))
            return
        }
        CloudBaseHTTPClient.shared.authorizationBearerToken = token
        CloudBaseHTTPClient.shared.invokeFunction(name: CloudBaseConfig.dbProxyFunctionName, payload: body) { result in
            switch result {
            case let .failure(e):
                completion(.failure(e))
            case let .success(data):
                guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    completion(.failure(TCBCompatError.badResponse))
                    return
                }
                let payload = root["result"] as? [String: Any] ?? root
                if payload["error"] as? Bool == true {
                    let msg = payload["message"] as? String ?? "cloud error"
                    completion(.failure(TCBCompatError.server(msg)))
                    return
                }
                completion(.success(payload))
            }
        }
    }

    static func jsonSafe(_ v: Any) -> Any {
        if v is FieldValue { return ["__srvTs": true] }
        if let ts = v as? Timestamp {
            return ["__ts": ["s": ts.seconds, "ns": ts.nanoseconds]]
        }
        if let d = v as? [String: Any] {
            var o: [String: Any] = [:]
            for (k, val) in d { o[k] = jsonSafe(val) }
            return o
        }
        if let arr = v as? [Any] { return arr.map { jsonSafe($0) } }
        return v
    }

    static func decodeValue(_ v: Any) -> Any {
        if let n = v as? NSNumber {
            if CFGetTypeID(n) == CFBooleanGetTypeID() { return n.boolValue }
            let d = n.doubleValue
            if d.rounded() == d, d >= Double(Int.min), d <= Double(Int.max) { return Int(truncating: n) }
            return d
        }
        if var dict = v as? [String: Any] {
            if (dict["__type"] as? String) == "timestamp" {
                let s = Int64((dict["seconds"] as? NSNumber)?.int64Value ?? 0)
                let ns = Int32((dict["nanoseconds"] as? NSNumber)?.int32Value ?? 0)
                return Timestamp(seconds: s, nanoseconds: ns)
            }
            for k in Array(dict.keys) {
                dict[k] = decodeValue(dict[k]!)
            }
            return dict
        }
        if let arr = v as? [Any] { return arr.map { decodeValue($0) } }
        return v
    }

    static func decodeDocumentData(_ v: Any?) -> [String: Any]? {
        guard let v, let d = v as? [String: Any] else { return nil }
        return decodeValue(d) as? [String: Any]
    }

    static func getDoc(path: [String], completion: @escaping (DocumentSnapshot?, Error?) -> Void) {
        let ref = DocumentReference(segments: path)
        invoke(["op": "getDoc", "path": path]) { result in
            switch result {
            case let .failure(e):
                completion(nil, e)
            case let .success(p):
                let exists = p["exists"] as? Bool ?? false
                let id = p["id"] as? String ?? path.last ?? ""
                let data = decodeDocumentData(p["data"])
                completion(DocumentSnapshot(documentID: id, exists: exists, data: data, reference: ref), nil)
            }
        }
    }

    static func setDoc(path: [String], data: [String: Any], merge: Bool, completion: ((Error?) -> Void)?) {
        let safe = jsonSafe(data) as! [String: Any]
        invoke(["op": "setDoc", "path": path, "data": safe, "merge": merge]) { result in
            switch result {
            case let .failure(e): completion?(e)
            case .success: completion?(nil)
            }
        }
    }

    static func updateDoc(path: [String], data: [String: Any], completion: ((Error?) -> Void)?) {
        let safe = jsonSafe(data) as! [String: Any]
        invoke(["op": "updateDoc", "path": path, "data": safe]) { result in
            switch result {
            case let .failure(e): completion?(e)
            case .success: completion?(nil)
            }
        }
    }

    static func deleteDoc(path: [String], completion: ((Error?) -> Void)?) {
        invoke(["op": "deleteDoc", "path": path]) { result in
            switch result {
            case let .failure(e): completion?(e)
            case .success: completion?(nil)
            }
        }
    }

    static func query(
        path: [String],
        whereClauses: [[Any]],
        orderBy: [Any]?,
        limit: Int?,
        completion: @escaping (QuerySnapshot?, Error?) -> Void
    ) {
        var body: [String: Any] = ["op": "query", "path": path, "where": whereClauses]
        if let orderBy { body["orderBy"] = orderBy }
        if let limit { body["limit"] = limit }
        invoke(body) { result in
            switch result {
            case let .failure(e):
                completion(nil, e)
            case let .success(p):
                guard let rawDocs = p["documents"] as? [[String: Any]] else {
                    completion(QuerySnapshot(documents: [], documentChanges: []), nil)
                    return
                }
                var snaps: [DocumentSnapshot] = []
                for rd in rawDocs {
                    let id = rd["id"] as? String ?? ""
                    let data = decodeDocumentData(rd["data"])
                    let dpath = path + [id]
                    let ref = DocumentReference(segments: dpath)
                    snaps.append(DocumentSnapshot(documentID: id, exists: true, data: data, reference: ref))
                }
                let changes = snaps.map { DocumentChange(type: .added, document: $0) }
                completion(QuerySnapshot(documents: snaps, documentChanges: changes), nil)
            }
        }
    }
}

private enum TCBFirestoreDataEq {
    static func equal(_ a: [String: Any], _ b: [String: Any]) -> Bool {
        guard let da = try? JSONSerialization.data(withJSONObject: TCBWire.jsonSafe(a), options: [.sortedKeys]),
              let db = try? JSONSerialization.data(withJSONObject: TCBWire.jsonSafe(b), options: [.sortedKeys]) else { return false }
        return da == db
    }
}

private enum TCBCompatError: LocalizedError {
    case notConfigured
    case noToken
    case badResponse
    case server(String)
    var errorDescription: String? {
        switch self {
        case .notConfigured: return "CloudBaseEnvID 未配置"
        case .noToken: return "CloudBaseAccessToken 未配置"
        case .badResponse: return "云函数响应无法解析"
        case let .server(m): return m
        }
    }
}

// MARK: - References

public final class Firestore {
    public static let firestore = Firestore()
    private init() {}
    public func collection(_ collectionPath: String) -> CollectionReference {
        let segs = CollectionReference.parseSegments(collectionPath)
        return CollectionReference(segments: segs)
    }
}

public final class CollectionReference {
    let segments: [String]
    init(segments: [String]) {
        self.segments = segments
    }

    static func parseSegments(_ collectionPath: String) -> [String] {
        let t = collectionPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if t.isEmpty { return [] }
        return t.split(separator: "/").map(String.init)
    }

    public func document(_ documentPath: String) -> DocumentReference {
        DocumentReference(segments: segments + [documentPath])
    }

    public func addSnapshotListener(_ listener: @escaping (QuerySnapshot?, Error?) -> Void) -> ListenerRegistration {
        let reg = ListenerRegistration()
        var previous: [String: [String: Any]] = [:]
        var first = true
        let queue = DispatchQueue(label: "tcb.col." + segments.joined(separator: "."))
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: CloudBaseConfig.snapshotPollInterval)
        timer.setEventHandler { [weak reg] in
            guard let reg, !reg.cancelled else { return }
            TCBWire.query(path: segments, whereClauses: [], orderBy: nil, limit: nil) { snap, err in
                if let err {
                    DispatchQueue.main.async { listener(nil, err) }
                    return
                }
                guard let snap else { return }
                var current: [String: [String: Any]] = [:]
                for d in snap.documents {
                    current[d.documentID] = d.data() ?? [:]
                }
                var changes: [DocumentChange] = []
                if first {
                    first = false
                    for d in snap.documents { changes.append(DocumentChange(type: .added, document: d)) }
                    previous = current
                    let out = QuerySnapshot(documents: snap.documents, documentChanges: changes)
                    DispatchQueue.main.async { listener(out, nil) }
                    return
                }
                let oldIds = Set(previous.keys)
                let newIds = Set(current.keys)
                for id in newIds.subtracting(oldIds) {
                    let ref = DocumentReference(segments: segments + [id])
                    let ds = DocumentSnapshot(documentID: id, exists: true, data: current[id], reference: ref)
                    changes.append(DocumentChange(type: .added, document: ds))
                }
                for id in oldIds.subtracting(newIds) {
                    let ref = DocumentReference(segments: segments + [id])
                    let ds = DocumentSnapshot(documentID: id, exists: false, data: nil, reference: ref)
                    changes.append(DocumentChange(type: .removed, document: ds))
                }
                for id in newIds.intersection(oldIds) {
                    let od = previous[id] ?? [:]
                    let nw = current[id] ?? [:]
                    if !TCBFirestoreDataEq.equal(od, nw) {
                        let ref = DocumentReference(segments: segments + [id])
                        let ds = DocumentSnapshot(documentID: id, exists: true, data: nw, reference: ref)
                        changes.append(DocumentChange(type: .modified, document: ds))
                    }
                }
                previous = current
                if !changes.isEmpty {
                    let out = QuerySnapshot(documents: snap.documents, documentChanges: changes)
                    DispatchQueue.main.async { listener(out, nil) }
                }
            }
        }
        reg.timer = timer
        timer.resume()
        return reg
    }

    public func getDocuments(completion: @escaping (QuerySnapshot?, Error?) -> Void) {
        Query(collection: self, wheres: [], order: nil, lim: nil).getDocuments(completion: completion)
    }

    public func order(by field: String, descending: Bool) -> Query {
        Query(collection: self, wheres: [], order: [field, descending ? "desc" : "asc"], lim: nil)
    }

    public func whereField(_ field: String, isEqualTo value: Any) -> Query {
        Query(collection: self, wheres: [[field, "eq", value]], order: nil, lim: nil)
    }

    public func whereField(_ field: String, isGreaterThanOrEqualTo value: Any) -> Query {
        Query(collection: self, wheres: [[field, "gte", value]], order: nil, lim: nil)
    }

    public func whereField(_ field: String, isGreaterThan value: Any) -> Query {
        Query(collection: self, wheres: [[field, "gt", value]], order: nil, lim: nil)
    }
}

public final class DocumentReference {
    let segments: [String]
    init(segments: [String]) {
        self.segments = segments
    }

    public func collection(_ collectionPath: String) -> CollectionReference {
        CollectionReference(segments: segments + CollectionReference.parseSegments(collectionPath))
    }

    public func getDocument(completion: @escaping (DocumentSnapshot?, Error?) -> Void) {
        TCBWire.getDoc(path: segments, completion: completion)
    }

    public func setData(_ documentData: [String: Any], merge: Bool = false, completion: ((Error?) -> Void)? = nil) {
        TCBWire.setDoc(path: segments, data: documentData, merge: merge, completion: completion)
    }

    public func updateData(_ fields: [String: Any], completion: ((Error?) -> Void)? = nil) {
        TCBWire.updateDoc(path: segments, data: fields, completion: completion)
    }

    public func delete(completion: ((Error?) -> Void)? = nil) {
        TCBWire.deleteDoc(path: segments, completion: completion)
    }

    public func addSnapshotListener(_ listener: @escaping (DocumentSnapshot?, Error?) -> Void) -> ListenerRegistration {
        let reg = ListenerRegistration()
        var previousData: [String: Any]?
        var first = true
        let queue = DispatchQueue(label: "tcb.doc." + segments.joined(separator: "."))
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: CloudBaseConfig.snapshotPollInterval)
        timer.setEventHandler { [weak reg] in
            guard let reg, !reg.cancelled else { return }
            TCBWire.getDoc(path: segments) { snap, err in
                if let err {
                    DispatchQueue.main.async { listener(nil, err) }
                    return
                }
                guard let snap else { return }
                let data = snap.data()
                if first {
                    first = false
                    DispatchQueue.main.async { listener(snap, nil) }
                    previousData = data
                    return
                }
                let same: Bool = {
                    guard let data, let pd = previousData else { return data == nil && previousData == nil }
                    return TCBFirestoreDataEq.equal(data, pd)
                }()
                if !same {
                    previousData = data
                    DispatchQueue.main.async { listener(snap, nil) }
                }
            }
        }
        reg.timer = timer
        timer.resume()
        return reg
    }
}

public final class Query {
    private let collection: CollectionReference
    private var wheres: [[Any]]
    private var order: [Any]?
    private var lim: Int?

    init(collection: CollectionReference, wheres: [[Any]], order: [Any]?, lim: Int?) {
        self.collection = collection
        self.wheres = wheres
        self.order = order
        self.lim = lim
    }

    public func whereField(_ field: String, isEqualTo value: Any) -> Query {
        var w = wheres
        w.append([field, "eq", value])
        return Query(collection: collection, wheres: w, order: order, lim: lim)
    }

    public func whereField(_ field: String, isGreaterThanOrEqualTo value: Any) -> Query {
        var w = wheres
        w.append([field, "gte", value])
        return Query(collection: collection, wheres: w, order: order, lim: lim)
    }

    public func whereField(_ field: String, isGreaterThan value: Any) -> Query {
        var w = wheres
        w.append([field, "gt", value])
        return Query(collection: collection, wheres: w, order: order, lim: lim)
    }

    public func order(by field: String, descending: Bool) -> Query {
        Query(collection: collection, wheres: wheres, order: [field, descending ? "desc" : "asc"], lim: lim)
    }

    public func limit(to limit: Int) -> Query {
        Query(collection: collection, wheres: wheres, order: order, lim: limit)
    }

    public func getDocuments(completion: @escaping (QuerySnapshot?, Error?) -> Void) {
        TCBWire.query(path: collection.segments, whereClauses: wheres, orderBy: order, limit: lim) { snap, err in
            guard let snap else {
                completion(nil, err)
                return
            }
            let fullChanges = snap.documents.map { DocumentChange(type: .added, document: $0) }
            completion(QuerySnapshot(documents: snap.documents, documentChanges: fullChanges), err)
        }
    }
}
