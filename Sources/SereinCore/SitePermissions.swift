import Foundation

public enum SiteCapability: String, Codable, CaseIterable, Sendable {
    case camera, microphone, location
}

public enum SitePermissionDecision: String, Codable, CaseIterable, Sendable {
    case ask, allow, deny
}

/// Embedded sites receive a separate policy for each top-level origin.
/// Paths never broaden a grant to a different scheme, host, or port.
public struct SitePermissionKey: Hashable, Codable, Sendable {
    public let topLevel: SiteOrigin
    public let requesting: SiteOrigin
    public let capability: SiteCapability
    public init(topLevel: SiteOrigin, requesting: SiteOrigin, capability: SiteCapability) {
        self.topLevel = topLevel
        self.requesting = requesting
        self.capability = capability
    }
}

public struct SitePermissionRecord: Codable, Identifiable, Equatable, Sendable {
    public var id: SitePermissionKey { key }
    public let key: SitePermissionKey
    public var decision: SitePermissionDecision
}

public struct SitePermissionPolicy: Codable, Sendable {
    public private(set) var records: [SitePermissionRecord] = []
    public init() {}

    public func decision(for keys: [SitePermissionKey]) -> SitePermissionDecision {
        // Never grant an unknown/empty capability request.
        guard !keys.isEmpty else { return .deny }
        let decisions = keys.map { key in records.first { $0.key == key }?.decision ?? .ask }
        if decisions.contains(.deny) { return .deny }
        return decisions.allSatisfy { $0 == .allow } ? .allow : .ask
    }

    public mutating func set(_ decision: SitePermissionDecision, for key: SitePermissionKey) {
        records.removeAll { $0.key == key }
        if decision != .ask { records.append(SitePermissionRecord(key: key, decision: decision)) }
    }

    public mutating func reset() { records.removeAll() }
}
