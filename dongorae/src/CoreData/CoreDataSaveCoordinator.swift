import CoreData

enum CoreDataSaveCoordinator {
    static func save(_ context: NSManagedObjectContext) throws {
        guard context.hasChanges else { return }
        let now = Date()

        let targets = Set(context.insertedObjects).union(context.updatedObjects)
        for object in targets {
            normalize(object, now: now)
        }

        try context.save()
    }

    static func message(for error: Error) -> String {
        let nsError = error as NSError
        let lines = flattenValidationMessages(from: nsError)
        if !lines.isEmpty {
            return lines.joined(separator: "\n")
        }
        return "[\(nsError.domain):\(nsError.code)] \(nsError.localizedDescription)"
    }

    private static func flattenValidationMessages(from error: NSError) -> [String] {
        var messages: [String] = []
        appendMessages(from: error, into: &messages)

        var unique: [String] = []
        var seen = Set<String>()
        for line in messages where !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if seen.insert(line).inserted {
                unique.append(line)
            }
        }
        return unique
    }

    private static func appendMessages(from error: NSError, into messages: inout [String]) {
        if let detailed = error.userInfo[NSDetailedErrorsKey] as? [NSError], !detailed.isEmpty {
            for item in detailed {
                appendMessages(from: item, into: &messages)
            }
            return
        }

        if let nested = error.userInfo[NSUnderlyingErrorKey] as? NSError {
            appendMessages(from: nested, into: &messages)
        } else if let nestedArray = error.userInfo[NSUnderlyingErrorKey] as? [NSError] {
            for nested in nestedArray {
                appendMessages(from: nested, into: &messages)
            }
        }

        if let key = error.userInfo[NSValidationKeyErrorKey] as? String,
           let object = error.userInfo[NSValidationObjectErrorKey] as? NSManagedObject {
            let entity = object.entity.name ?? "-"
            messages.append("[\(entity).\(key)] \(error.localizedDescription)")
            return
        }

        if error.code == NSValidationMultipleErrorsError {
            messages.append("여러 필드 검증 오류가 있습니다.")
            return
        }

        let text = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty, text != "Multiple validation errors occurred." {
            messages.append(text)
        }
    }

    private static func normalize(_ object: NSManagedObject, now: Date) {
        switch object.entity.name {
        case "Transaction":
            setAttributeIfMissing(object, key: "id", value: UUID())
            setAttributeIfMissing(object, key: "createdAt", value: now)
            object.setValue(now, forKey: "updatedAt")
            setAttributeIfMissing(object, key: "date", value: object.value(forKey: "executionDate") as? Date ?? now)
            let title = ((object.value(forKey: "title") as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if title.isEmpty {
                object.setValue("거래", forKey: "title")
            }

        case "Asset", "Account":
            setAttributeIfMissing(object, key: "id", value: UUID())
            setAttributeIfMissing(object, key: "createdAt", value: now)
            setAttributeIfMissing(object, key: "updatedAt", value: now)
            let name = ((object.value(forKey: "name") as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if name.isEmpty {
                object.setValue("자산", forKey: "name")
            }

        case "Leg", "CashLeg", "PositionLeg":
            setAttributeIfMissing(object, key: "id", value: UUID())
            setAttributeIfMissing(object, key: "createdAt", value: now)
            setAttributeIfMissing(object, key: "updatedAt", value: now)
            setAttributeIfMissing(object, key: "order", value: Int16(0))
            setAttributeIfMissing(object, key: "role", value: Int16(0))
            setAttributeIfMissing(object, key: "direction", value: Int16(0))
            setAttributeIfMissing(object, key: "isRequired", value: false)

            if object.entity.name == "CashLeg" {
                setAttributeIfMissing(object, key: "amount", value: NSDecimalNumber.zero)
                let currency = ((object.value(forKey: "currency") as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                if currency.isEmpty {
                    object.setValue("KRW", forKey: "currency")
                }
            }

            if object.entity.name == "PositionLeg" {
                setAttributeIfMissing(object, key: "quantity", value: NSDecimalNumber.zero)
                let unit = ((object.value(forKey: "unit") as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                if unit.isEmpty {
                    object.setValue("share", forKey: "unit")
                }
                if object.value(forKey: "ticker") as? String == nil {
                    object.setValue("", forKey: "ticker")
                }
                if object.value(forKey: "market") as? String == nil {
                    object.setValue("", forKey: "market")
                }
            }

        case "Tag":
            setAttributeIfMissing(object, key: "id", value: UUID())
            setAttributeIfMissing(object, key: "createdAt", value: now)
            setAttributeIfMissing(object, key: "updatedAt", value: now)
            setAttributeIfMissing(object, key: "kind", value: Int16(0))
            let name = ((object.value(forKey: "name") as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if name.isEmpty {
                object.setValue("태그", forKey: "name")
            }
            let colorHex = ((object.value(forKey: "colorHex") as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if colorHex.isEmpty {
                object.setValue("6ABF9E", forKey: "colorHex")
            }

        case "TransactionCategory":
            setAttributeIfMissing(object, key: "id", value: UUID())
            setAttributeIfMissing(object, key: "createdAt", value: now)
            setAttributeIfMissing(object, key: "updatedAt", value: now)
            setAttributeIfMissing(object, key: "order", value: Int16(0))
            let title = ((object.value(forKey: "title") as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if title.isEmpty {
                object.setValue("미분류", forKey: "title")
            }

        case "AssetTag", "TransactionTag":
            setAttributeIfMissing(object, key: "isAuto", value: false)

        default:
            break
        }
    }

    private static func setAttributeIfMissing(_ object: NSManagedObject, key: String, value: Any) {
        guard object.entity.attributesByName[key] != nil else { return }
        if object.value(forKey: key) == nil {
            object.setValue(value, forKey: key)
        }
    }
}
