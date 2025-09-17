import CoreData

extension Transaction {
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        // Automatically assign a UUID when the object is first inserted into a context
        if self.value(forKey: "id") == nil {
            self.setValue(UUID(), forKey: "id")
        }
    }
}
