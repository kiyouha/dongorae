import CoreData

struct AssetMutationUseCase {
    let context: NSManagedObjectContext

    func create(input: AssetEditorInput) throws {
        let now = Date()
        let account = Account(context: context)
        account.id = UUID()
        account.name = resolvedName(input.name)
        account.note = trimmedOrNil(input.note)
        account.isActive = input.isActive
        account.createdAt = now
        account.updatedAt = now
        account.accountNumber = trimmedOrNil(input.accountNumber)
        account.institution = trimmedOrNil(input.institution)
        account.type = input.assetClass
        setValueIfAttributeExists(on: account, key: "assetKind", value: AssetKind.account.rawValue)
        setValueIfAttributeExists(on: account, key: "owner", value: trimmedOrNil(input.owner))
        syncAssetTags(for: account, tagsText: input.tagsText)
    }

    func update(_ account: Account, input: AssetEditorInput) throws {
        account.name = resolvedName(input.name)
        account.note = trimmedOrNil(input.note)
        account.isActive = input.isActive
        account.updatedAt = Date()
        account.accountNumber = trimmedOrNil(input.accountNumber)
        account.institution = trimmedOrNil(input.institution)
        account.type = input.assetClass
        setValueIfAttributeExists(on: account, key: "owner", value: trimmedOrNil(input.owner))
        syncAssetTags(for: account, tagsText: input.tagsText)
    }

    func delete(_ asset: Asset) throws {
        context.delete(asset)
    }

    private func syncAssetTags(for asset: Asset, tagsText: String) {
        let existing = (asset.tags as? Set<AssetTag>) ?? []
        for join in existing {
            context.delete(join)
        }

        for name in Set(parseCommaList(tagsText)) {
            let join = AssetTag(context: context)
            join.asset = asset
            join.tag = findOrCreateTag(named: name, kind: .category)
            setValueIfAttributeExists(on: join, key: "isAuto", value: false)
        }
    }

    private func findOrCreateTag(named name: String, kind: TagKind) -> Tag {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let request: NSFetchRequest<Tag> = Tag.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "name ==[c] %@", trimmed)
        if let existing = try? context.fetch(request).first {
            existing.updatedAt = Date()
            return existing
        }
        let now = Date()
        let tag = Tag(context: context)
        tag.id = UUID()
        tag.name = trimmed
        tag.kindEnum = kind
        tag.colorHex = "6ABF9E"
        tag.createdAt = now
        tag.updatedAt = now
        return tag
    }

    private func parseCommaList(_ text: String) -> [String] {
        text.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func resolvedName(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "이름 없는 자산" : trimmed
    }

    private func trimmedOrNil(_ text: String?) -> String? {
        guard let text else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func setValueIfAttributeExists(on object: NSManagedObject, key: String, value: Any?) {
        guard object.entity.attributesByName[key] != nil else { return }
        object.setValue(value, forKey: key)
    }
}
