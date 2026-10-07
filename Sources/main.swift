import AppKit
import ServiceManagement

// Auto-mute — coupe le son du Mac après un certain temps d'inactivité.
// Vit dans la barre de menus ; aucune fenêtre, aucune permission particulière.

let kEnabled = "enabled"
let kThreshold = "thresholdSeconds"
let kMuteCount = "muteCount"

func idleSeconds() -> TimeInterval {
    if let any = CGEventType(rawValue: ~0) {
        return CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: any)
    }
    let types: [CGEventType] = [.mouseMoved, .leftMouseDown, .rightMouseDown,
                                .keyDown, .scrollWheel, .flagsChanged]
    return types.map { CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: $0) }.min() ?? 0
}

func runAppleScript(_ source: String) {
    var error: NSDictionary?
    NSAppleScript(source: source)?.executeAndReturnError(&error)
    if let error { NSLog("Auto-mute: AppleScript error %@", error) }
}

func setMuted(_ muted: Bool) {
    runAppleScript("set volume output muted \(muted)")
}

func isMuted() -> Bool {
    var error: NSDictionary?
    let result = NSAppleScript(source: "output muted of (get volume settings)")?
        .executeAndReturnError(&error)
    return result?.booleanValue ?? false
}

func formatDuration(_ seconds: TimeInterval) -> String {
    let s = Int(seconds)
    if s < 60 { return "\(s) s" }
    let m = s / 60
    if m < 60 { return "\(m) min" }
    return "\(m / 60) h \(m % 60) min"
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var statusItem: NSStatusItem!
    var timer: Timer?
    var didMute = false
    let defaults = UserDefaults.standard
    let thresholdChoices: [TimeInterval] = [120, 300, 600, 900, 1800, 3600]

    var enabled: Bool {
        get { defaults.bool(forKey: kEnabled) }
        set { defaults.set(newValue, forKey: kEnabled); didMute = false; refresh() }
    }
    var threshold: TimeInterval {
        get { defaults.double(forKey: kThreshold) }
        set { defaults.set(newValue, forKey: kThreshold); didMute = false; refresh() }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        defaults.register(defaults: [kEnabled: true, kThreshold: 600.0])

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.menu = buildMenu()
        statusItem.menu?.delegate = self
        refresh()

        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            self?.tick()
        }
        timer?.tolerance = 5
    }

    // MARK: - Boucle

    func tick() {
        guard enabled else { return }
        let idle = idleSeconds()
        if idle >= threshold {
            if !didMute {
                setMuted(true)
                didMute = true
                defaults.set(defaults.integer(forKey: kMuteCount) + 1, forKey: kMuteCount)
                NSLog("Auto-mute: son coupé après %.0f s d'inactivité", idle)
                refresh()
            }
        } else if didMute {
            didMute = false
            refresh()
        }
    }

    // MARK: - Barre de menus

    func refresh() {
        let name: String
        if !enabled {
            name = "speaker.slash"
        } else if didMute {
            name = "speaker.slash.fill"
        } else {
            name = "speaker.wave.2"
        }
        let image = NSImage(systemSymbolName: name, accessibilityDescription: "Auto-mute")
        image?.isTemplate = true
        statusItem.button?.image = image
        statusItem.button?.appearsDisabled = !enabled
    }

    func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let status = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        status.tag = 1
        status.isEnabled = false
        menu.addItem(status)

        menu.addItem(.separator())

        let toggle = NSMenuItem(title: "Activé", action: #selector(toggleEnabled), keyEquivalent: "")
        toggle.target = self
        toggle.tag = 2
        menu.addItem(toggle)

        let delay = NSMenuItem(title: "Couper le son après", action: nil, keyEquivalent: "")
        let delayMenu = NSMenu()
        for choice in thresholdChoices {
            let item = NSMenuItem(title: formatDuration(choice), action: #selector(pickThreshold(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = choice
            delayMenu.addItem(item)
        }
        delay.submenu = delayMenu
        delay.tag = 3
        menu.addItem(delay)

        menu.addItem(.separator())

        let now = NSMenuItem(title: "Couper le son maintenant", action: #selector(muteNow), keyEquivalent: "")
        now.target = self
        menu.addItem(now)

        let back = NSMenuItem(title: "Rétablir le son", action: #selector(unmuteNow), keyEquivalent: "")
        back.target = self
        menu.addItem(back)

        menu.addItem(.separator())

        let login = NSMenuItem(title: "Lancer au login", action: #selector(toggleLogin), keyEquivalent: "")
        login.target = self
        login.tag = 4
        menu.addItem(login)

        let quit = NSMenuItem(title: "Quitter Auto-mute", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        return menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        let idle = idleSeconds()
        if let item = menu.item(withTag: 1) {
            if !enabled {
                item.title = "En veille"
            } else if didMute {
                item.title = "Son coupé — inactif depuis \(formatDuration(idle))"
            } else {
                item.title = "Inactif depuis \(formatDuration(idle))"
            }
        }
        menu.item(withTag: 2)?.state = enabled ? .on : .off
        if let delay = menu.item(withTag: 3) {
            delay.submenu?.items.forEach { item in
                item.state = (item.representedObject as? TimeInterval) == threshold ? .on : .off
            }
            delay.title = "Couper le son après \(formatDuration(threshold))"
        }
        menu.item(withTag: 4)?.state = loginEnabled ? .on : .off
    }

    // MARK: - Actions

    @objc func toggleEnabled() { enabled = !enabled }

    @objc func pickThreshold(_ sender: NSMenuItem) {
        if let value = sender.representedObject as? TimeInterval { threshold = value }
    }

    @objc func muteNow() { setMuted(true); didMute = true; refresh() }

    @objc func unmuteNow() { setMuted(false); didMute = false; refresh() }

    var loginEnabled: Bool { SMAppService.mainApp.status == .enabled }

    @objc func toggleLogin() {
        do {
            if loginEnabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("Auto-mute: login item %@", error.localizedDescription)
            NSWorkspace.shared.open(
                URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension")!)
        }
    }

    @objc func quit() { NSApp.terminate(nil) }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
