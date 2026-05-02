import Foundation
import AppKit
import Carbon.HIToolbox

public enum HotkeyAction: Hashable, Sendable {
    case mute
    case interrupt
    case openSettings
    case pushToTalk
}

/// Registers global hotkeys via Carbon's `RegisterEventHotKey`. Carbon is
/// still the supported way to get system-wide keyboard shortcuts on macOS as
/// of macOS 14, even from Swift.
public final class HotkeyService {
    private struct Entry {
        let id: UInt32
        let ref: EventHotKeyRef
        let action: HotkeyAction
    }

    private var entries: [HotkeyAction: Entry] = [:]
    private var nextID: UInt32 = 1
    private var handler: EventHandlerRef?
    private var callbacks: [HotkeyAction: () -> Void] = [:]

    public init() {
        installEventHandler()
    }

    deinit {
        if let handler { RemoveEventHandler(handler) }
        for entry in entries.values { UnregisterEventHotKey(entry.ref) }
    }

    public func setCallback(for action: HotkeyAction, _ block: @escaping () -> Void) {
        callbacks[action] = block
    }

    public func register(action: HotkeyAction, hotkey: Hotkey) {
        unregister(action: action)
        guard hotkey.enabled, hotkey.keyCode != 0 || hotkey.modifiers != 0 else { return }

        let id = nextID; nextID += 1
        var hotKeyID = EventHotKeyID(signature: OSType(0x4A454646), id: id) // 'JEFF'
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(hotkey.keyCode),
            UInt32(hotkey.modifiers),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        guard status == noErr, let ref else { return }
        entries[action] = Entry(id: id, ref: ref, action: action)
    }

    public func unregister(action: HotkeyAction) {
        guard let entry = entries.removeValue(forKey: action) else { return }
        UnregisterEventHotKey(entry.ref)
    }

    private func installEventHandler() {
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let userData = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData -> OSStatus in
                guard let event, let userData else { return noErr }
                let service = Unmanaged<HotkeyService>.fromOpaque(userData).takeUnretainedValue()
                var hkID = EventHotKeyID()
                let err = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hkID
                )
                if err == noErr {
                    service.handle(id: hkID.id)
                }
                return noErr
            },
            1,
            &spec,
            userData,
            &handler
        )
    }

    private func handle(id: UInt32) {
        if let action = entries.first(where: { $0.value.id == id })?.key,
           let cb = callbacks[action] {
            DispatchQueue.main.async(execute: cb)
        }
    }
}
