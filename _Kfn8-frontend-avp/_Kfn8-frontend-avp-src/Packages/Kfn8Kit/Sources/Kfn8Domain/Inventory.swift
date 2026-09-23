import Foundation
import simd

/// A retailer offer as last retrieved. Never inferred; generics have none.
public struct PricedOffer: Sendable, Equatable, Codable {
    public var amountMinor: Int
    public var currency: String
    public var available: Bool
    public var retailerURL: URL?
    public var fetchedAt: Date
    public init(amountMinor: Int, currency: String, available: Bool, retailerURL: URL?, fetchedAt: Date) {
        self.amountMinor = amountMinor; self.currency = currency; self.available = available; self.retailerURL = retailerURL; self.fetchedAt = fetchedAt
    }
}

public struct InventorySource: Sendable, Equatable {
    public var name: String
    public var sizeMetres: SIMD3<Float>
    public var offer: PricedOffer?
    public var isAvailable: Bool
    public init(name: String, sizeMetres: SIMD3<Float>, offer: PricedOffer? = nil, isAvailable: Bool = true) {
        self.name = name; self.sizeMetres = sizeMetres; self.offer = offer; self.isAvailable = isAvailable
    }
}

public struct InventoryLine: Sendable, Equatable, Identifiable {
    public var id: AssetReference { reference }
    public var reference: AssetReference
    public var name: String
    public var quantity: Int
    public var dimensionsLabel: String
    public var offer: PricedOffer?
    /// Rights-revoked or otherwise missing asset: shown as a labelled absence, never substituted.
    public var isMissing: Bool

    /// e.g. "£249.00 each · checked 3 Sep" or "No longer sold · £249.00 on 3 Sep". Nil for unpriced generics.
    public func priceText(locale: Locale = .current, calendar: Calendar = .current) -> String? {
        guard let o = offer else { return nil }
        let money = Inventory.format(o.amountMinor, currency: o.currency, locale: locale)
        var style = Date.FormatStyle.dateTime.day().month(.abbreviated).locale(locale)
        style.timeZone = calendar.timeZone
        let date = o.fetchedAt.formatted(style)
        return o.available ? "\(money) each · checked \(date)" : "No longer sold · \(money) on \(date)"
    }
}

public struct InventorySubtotal: Sendable, Equatable {
    public var currency: String
    public var amountMinor: Int
    public var earliest: Date
    public var latest: Date
    /// True only when some lines are unpriced; then the label says "priced items only".
    public var pricedItemsOnly: Bool

    public func text(locale: Locale = .current, calendar: Calendar = .current) -> String {
        let money = Inventory.format(amountMinor, currency: currency, locale: locale)
        var style = Date.FormatStyle.dateTime.day().month(.abbreviated).locale(locale)
        style.timeZone = calendar.timeZone
        let dates = calendar.isDate(earliest, inSameDayAs: latest) ? earliest.formatted(style) : "\(earliest.formatted(style)) – \(latest.formatted(style))"
        return "\(money)\(pricedItemsOnly ? " · priced items only" : "") · prices from \(dates)"
    }
}

public enum Inventory {
    /// Groups a Design's placements by asset revision into lines with quantities.
    public static func lines(for design: Design, source: (AssetReference) -> InventorySource?) -> [InventoryLine] {
        var order: [AssetReference] = []
        var counts: [AssetReference: Int] = [:]
        for p in design.placements {
            let key = AssetReference(assetID: p.asset.assetID, revisionID: p.asset.revisionID)
            if counts[key] == nil { order.append(key) }
            counts[key, default: 0] += 1
        }
        return order.map { ref in
            let s = source(ref)
            let d = s.map { PreviewFit(itemSize: $0.sizeMetres, volumeSize: $0.sizeMetres).dimensionLabel } ?? ""
            return InventoryLine(reference: ref, name: s?.name ?? "Unavailable item", quantity: counts[ref]!, dimensionsLabel: d,
                                 offer: s?.offer, isMissing: s == nil || s?.isAvailable == false)
        }
    }

    /// One subtotal per currency (no FX conversion). Empty when nothing is priced: a generic-only list has no total.
    /// Delisted items keep their dated price in the line but are excluded from the subtotal.
    public static func subtotals(_ lines: [InventoryLine]) -> [InventorySubtotal] {
        let priced = lines.filter { $0.offer?.available == true }
        guard !priced.isEmpty else { return [] }
        let someUnpriced = priced.count < lines.count
        return Dictionary(grouping: priced, by: { $0.offer!.currency }).map { currency, group in
            let dates = group.map { $0.offer!.fetchedAt }
            return InventorySubtotal(currency: currency, amountMinor: group.reduce(0) { $0 + $1.offer!.amountMinor * $1.quantity },
                                     earliest: dates.min()!, latest: dates.max()!, pricedItemsOnly: someUnpriced)
        }.sorted { $0.currency < $1.currency }
    }

    static func format(_ minor: Int, currency: String, locale: Locale) -> String {
        let digits = currency == "JPY" ? 0 : 2
        let value = Decimal(minor) / pow(10, digits)
        return value.formatted(.currency(code: currency).locale(locale).precision(.fractionLength(digits)))
    }
}
