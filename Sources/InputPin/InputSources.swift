import Carbon
import Foundation
import InputPinCore

struct InputSource: Identifiable, Equatable {
    let id: String
    let name: String
}

protocol InputSourceProviding: InputEnvironment {
    var sources: [InputSource] { get }
    func invalidateSources()
}

final class SystemInputEnvironment: InputSourceProviding {
    static let weTypeID = "com.tencent.inputmethod.wetype.pinyin"
    private var cachedSelectable: [TISInputSource]?

    func invalidateSources() { cachedSelectable = nil }

    private func property(_ source: TISInputSource, _ key: CFString) -> AnyObject? {
        guard let pointer = TISGetInputSourceProperty(source, key) else { return nil }
        return Unmanaged<AnyObject>.fromOpaque(pointer).takeUnretainedValue()
    }

    var currentID: String {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else { return "" }
        return property(source, kTISPropertyInputSourceID) as? String ?? ""
    }

    var isSecure: Bool { IsSecureEventInputEnabled() }

    private var selectable: [TISInputSource] {
        if let cachedSelectable { return cachedSelectable }
        let sources = (TISCreateInputSourceList(nil, false)?.takeRetainedValue() as? [TISInputSource] ?? []).filter {
            property($0, kTISPropertyInputSourceCategory) as? String == kTISCategoryKeyboardInputSource as String
                && property($0, kTISPropertyInputSourceIsSelectCapable) as? Bool == true
                && property($0, kTISPropertyInputSourceIsEnabled) as? Bool == true
        }
        cachedSelectable = sources
        return sources
    }

    var sources: [InputSource] {
        selectable.compactMap {
            guard let id = property($0, kTISPropertyInputSourceID) as? String else { return nil }
            return InputSource(id: id, name: property($0, kTISPropertyLocalizedName) as? String ?? id)
        }
    }

    func isAvailable(_ id: String) -> Bool {
        selectable.contains { property($0, kTISPropertyInputSourceID) as? String == id }
    }

    func select(_ id: String) -> Int32 {
        // Revalidate at the point of selection, even if an enabled-source
        // notification has not reached the main run loop yet.
        invalidateSources()
        guard let source = selectable.first(where: { property($0, kTISPropertyInputSourceID) as? String == id }) else { return -50 }
        return TISSelectInputSource(source)
    }
}
