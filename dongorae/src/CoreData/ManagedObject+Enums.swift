import CoreData

extension Leg {
    var directionEnum: LegDirection {
        get { LegDirection(rawValue: self.direction) ?? .out }
        set { self.direction = newValue.rawValue }
    }

    var roleEnum: LegRole {
        get { LegRole(rawValue: self.role) ?? .expense }
        set { self.role = newValue.rawValue }
    }
}

extension Tag {
    var kindEnum: TagKind {
        get { TagKind(rawValue: self.kind) ?? .category }
        set { self.kind = newValue.rawValue }
    }
}

extension Asset {
    var assetKindEnum: AssetKind {
        get {
            guard entity.attributesByName["assetKind"] != nil else { return .account }
            let raw = (value(forKey: "assetKind") as? Int16) ?? AssetKind.account.rawValue
            return AssetKind(rawValue: raw) ?? .account
        }
        set {
            guard entity.attributesByName["assetKind"] != nil else { return }
            setValue(newValue.rawValue, forKey: "assetKind")
        }
    }
}
