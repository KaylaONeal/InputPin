import Carbon
import Foundation
import InputPinCore

struct InputSource: Identifiable, Equatable {
    let id: String
    let name: String
}

final class SystemInputEnvironment: InputEnvironment {
    static let weTypeID = "com.tencent.inputmethod.wetype.pinyin"

    private func property(_ source: TISInputSource, _ key: CFString) -> AnyObject? {
        guard let pointer = TISGetInputSourceProperty(source, key) else { return nil }
        return Unmanaged<AnyObject>.fromOpaque(pointer).takeUnretainedValue()
    }

    var currentID: String {
        property(TISCopyCurrentKeyboardInputSource().takeRetainedValue(), kTISPropertyInputSourceID) as? String ?? ""
    }

    var isSecure: Bool { IsSecureEventInputEnabled() }

    private var selectable: [TISInputSource] {
        (TISCreateInputSourceList(nil, false).takeRetainedValue() as! [TISInputSource]).filter {
            property($0, kTISPropertyInputSourceCategory) as? String == kTISCategoryKeyboardInputSource as String
                && property($0, kTISPropertyInputSourceIsSelectCapable) as? Bool == true
                && property($0, kTISPropertyInputSourceIsEnabled) as? Bool == true
        }
    }

    var sources: [InputSource] {
        selectable.compactMap {
            guard let id = property($0, kTISPropertyInputSourceID) as? String else { return nil }
            return InputSource(id: id, name: property($0, kTISPropertyLocalizedName) as? String ?? id)
        }
    }

    func isAvailable(_ id: String) -> Bool { sources.contains { $0.id == id } }

    func select(_ id: String) -> Int32 {
        guard let source = selectable.first(where: { property($0, kTISPropertyInputSourceID) as? String == id }) else { return -50 }
        return TISSelectInputSource(source)
    }
}
