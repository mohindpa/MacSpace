// MacSpace — Mac side
// Turns an iPad (or any browser on the LAN) into a keyboard, trackpad and
// remote control for this Mac. Keystrokes land as real CoreGraphics events.
//
// Build: ./build.sh   (or: swiftc -O -swift-version 5 -o MacSpace src/main.swift)
// Run:   ./run.sh     (serves http://<your-mac>.local:8787)

import Foundation
import Network
import CoreGraphics
import ApplicationServices
import AppKit
import IOKit.ps

let VERSION = "1.1.0"

// MARK: - Logger

final class Log {
    static var path = NSHomeDirectory() + "/MacSpace/server.log"
    static let queue = DispatchQueue(label: "log")
    static var handle: FileHandle?

    static func open(_ p: String) {
        path = p
        let fm = FileManager.default
        let dir = (p as NSString).deletingLastPathComponent
        try? fm.createDirectory(atPath: dir, withIntermediateDirectories: true)
        if !fm.fileExists(atPath: p) { fm.createFile(atPath: p, contents: nil) }
        handle = FileHandle(forWritingAtPath: p)
        handle?.seekToEndOfFile()
    }

    static func line(_ s: String) {
        let ts = ISO8601DateFormatter().string(from: Date())
        let out = "[\(ts)] \(s)\n"
        queue.async {
            FileHandle.standardOutput.write(out.data(using: .utf8)!)
            handle?.write(out.data(using: .utf8)!)
        }
    }
}

// MARK: - Key tables (US ANSI)

let keyCodes: [String: CGKeyCode] = [
    "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9,
    "b": 11, "q": 12, "w": 13, "e": 14, "r": 15, "y": 16, "t": 17,
    "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23, "=": 24, "9": 25, "7": 26,
    "-": 27, "8": 28, "0": 29, "]": 30, "o": 31, "u": 32, "[": 33, "i": 34, "p": 35,
    "return": 36, "enter": 36, "l": 37, "j": 38, "'": 39, "k": 40, ";": 41, "\\": 42,
    ",": 43, "/": 44, "n": 45, "m": 46, ".": 47,
    "tab": 48, "space": 49, "`": 50,
    "delete": 51, "backspace": 51, "esc": 53, "escape": 53,
    "rcmd": 54, "cmd": 55, "command": 55, "shift": 56, "capslock": 57, "caps": 57,
    "option": 58, "alt": 58, "opt": 58, "control": 59, "ctrl": 59,
    "rshift": 60, "ropt": 61, "roption": 61, "rctrl": 62, "rcontrol": 62, "fn": 63,
    "f17": 64, "kp.": 65, "kp*": 67, "kp+": 69, "kpclear": 71, "kp/": 75, "kpenter": 76,
    "kp-": 78, "f18": 79, "f19": 80, "kp=": 81, "kp0": 82, "kp1": 83, "kp2": 84,
    "kp3": 85, "kp4": 86, "kp5": 87, "kp6": 88, "kp7": 89, "f20": 90, "kp8": 91, "kp9": 92,
    "f5": 96, "f6": 97, "f7": 98, "f3": 99, "f8": 100, "f9": 101, "f11": 103,
    "f13": 105, "f16": 106, "f14": 107, "f10": 109, "f12": 111, "f15": 113,
    "help": 114, "home": 115, "pageup": 116, "forwarddelete": 117, "f4": 118,
    "end": 119, "f2": 120, "pagedown": 121, "f1": 122,
    "left": 123, "leftarrow": 123, "right": 124, "rightarrow": 124,
    "down": 125, "downarrow": 125, "up": 126, "uparrow": 126,
]

let modKeyCodes: [String: CGKeyCode] = [
    "cmd": 55, "command": 55, "rcmd": 54,
    "shift": 56, "rshift": 60,
    "option": 58, "opt": 58, "alt": 58, "ropt": 61, "roption": 61,
    "control": 59, "ctrl": 59, "rctrl": 62, "rcontrol": 62,
    "fn": 63,
]

// modifier name -> CGEventFlags bit
func modFlag(_ name: String) -> CGEventFlags? {
    switch name {
    case "cmd", "command", "rcmd": return .maskCommand
    case "shift", "rshift": return .maskShift
    case "option", "opt", "alt", "ropt", "roption": return .maskAlternate
    case "control", "ctrl", "rctrl", "rcontrol": return .maskControl
    case "fn": return .maskSecondaryFn
    default: return nil
    }
}

// printable US ASCII -> (keycode, needs shift)
let asciiKeys: [Character: (CGKeyCode, Bool)] = [
    "a": (0, false), "s": (1, false), "d": (2, false), "f": (3, false), "h": (4, false),
    "g": (5, false), "z": (6, false), "x": (7, false), "c": (8, false), "v": (9, false),
    "b": (11, false), "q": (12, false), "w": (13, false), "e": (14, false), "r": (15, false),
    "y": (16, false), "t": (17, false), "1": (18, false), "2": (19, false), "3": (20, false),
    "4": (21, false), "6": (22, false), "5": (23, false), "=": (24, false), "9": (25, false),
    "7": (26, false), "-": (27, false), "8": (28, false), "0": (29, false), "]": (30, false),
    "o": (31, false), "u": (32, false), "[": (33, false), "i": (34, false), "p": (35, false),
    "l": (37, false), "j": (38, false), "'": (39, false), "k": (40, false), ";": (41, false),
    "\\": (42, false), ",": (43, false), "/": (44, false), "n": (45, false), "m": (46, false),
    ".": (47, false), " ": (49, false), "`": (50, false),
    "!": (18, true), "@": (19, true), "#": (20, true), "$": (21, true), "%": (23, true),
    "^": (22, true), "&": (26, true), "*": (28, true), "(": (25, true), ")": (29, true),
    "_": (27, true), "+": (24, true), "{": (33, true), "}": (30, true), "|": (42, true),
    ":": (41, true), "\"": (39, true), "<": (43, true), ">": (47, true), "?": (44, true),
    "~": (50, true), "\n": (36, false), "\t": (48, false),
]

// MARK: - Injection

final class Injector {
    let dryRun: Bool
    private let src = CGEventSource(stateID: .hidSystemState)

    init(dryRun: Bool) { self.dryRun = dryRun }

    func post(_ e: CGEvent?) {
        guard let e else { return }
        if dryRun { return }
        e.post(tap: .cghidEventTap)
    }

    /// Down / up of a bare modifier key (flagsChanged-style).
    func modifier(_ name: String, down: Bool, activeFlags: CGEventFlags) {
        guard let kc = modKeyCodes[name.lowercased()] else { return }
        let e = CGEvent(keyboardEventSource: src, virtualKey: kc, keyDown: down)
        e?.flags = activeFlags
        e?.type = .flagsChanged
        post(e)
    }

    /// Modifiers the iPad is currently holding down (momentary hold, not latching).
    private var heldFlags: CGEventFlags = []

    /// Human-readable list of the modifiers an event will actually carry —
    /// used in the log so a held modifier can be verified without guessing.
    func flagsSummary(_ extra: [String]) -> String {
        var names = extra
        if heldFlags.contains(.maskCommand) { names.append("cmd") }
        if heldFlags.contains(.maskShift) { names.append("shift") }
        if heldFlags.contains(.maskAlternate) { names.append("opt") }
        if heldFlags.contains(.maskControl) { names.append("ctrl") }
        if capsLockOn() { names.append("caps") }
        return names.joined(separator: "+")
    }

    /// A bare modifier key pressed/released from the iPad changes what every
    /// following event is modified by — apps read the flags off each event, so
    /// a synthetic ⌘-down alone does not make the next key a ⌘-shortcut.
    func holdFlag(named name: String, down: Bool) {
        guard let f = modFlag(name) else { return }
        if down { heldFlags.insert(f) } else { heldFlags.remove(f) }
    }

    /// Posted events carry the modifier state authoritatively, so a plain
    /// keystroke with empty flags wipes Caps Lock. Preserve the alpha-shift bit
    /// and any modifier the iPad is holding, or they silently do nothing.
    func carryFlags(_ flags: CGEventFlags) -> CGEventFlags {
        var f = flags
        f.formUnion(heldFlags)
        if capsLockOn() { f.insert(.maskAlphaShift) }
        return f
    }

    /// A single key tap, optionally with modifiers held.
    func tap(keycode: CGKeyCode, mods: [String], action: String = "tap") {
        var flags: CGEventFlags = []
        var ordered: [CGKeyCode] = []
        for m in mods {
            if let f = modFlag(m) { flags.insert(f) }
            if let kc = modKeyCodes[m.lowercased()] { ordered.append(kc) }
        }

        let emitDown = action == "tap" || action == "down"
        let emitUp = action == "tap" || action == "up"

        if emitDown {
            var acc: CGEventFlags = []
            for m in mods {
                if let f = modFlag(m) { acc.insert(f) }
                modifier(m, down: true, activeFlags: carryFlags(acc))
            }
            let d = CGEvent(keyboardEventSource: src, virtualKey: keycode, keyDown: true)
            d?.flags = carryFlags(flags)
            post(d)
        }
        if emitUp {
            let u = CGEvent(keyboardEventSource: src, virtualKey: keycode, keyDown: false)
            u?.flags = carryFlags(flags)
            post(u)
            var acc = flags
            for m in mods.reversed() {
                if let f = modFlag(m) { acc.remove(f) }
                modifier(m, down: false, activeFlags: carryFlags(acc))
            }
            _ = ordered
        }
    }

    /// One printable character, preferring real keycodes (most compatible).
    func character(_ ch: Character) {
        if let (kc, shift) = asciiKeys[ch] {
            tap(keycode: kc, mods: shift ? ["shift"] : [])
        } else {
            unicode(String(ch))
        }
    }

    /// Post "up" for every modifier so no stale flag leaks into later text.
    /// Without this a stuck ⌘ turns typed letters into shortcuts (⌘X → cut).
    func releaseAll() {
        heldFlags = []
        for kc in [55, 54, 56, 60, 58, 61, 59, 62, 63] as [CGKeyCode] {
            guard let e = CGEvent(keyboardEventSource: src, virtualKey: kc, keyDown: false) else { continue }
            e.flags = carryFlags([])
            e.type = .flagsChanged
            post(e)
        }
    }

    /// Arbitrary text through CGEventKeyboardSetUnicodeString (non-ASCII, emoji, CJK).
    func unicode(_ s: String) {
        let chars = Array(s.utf16)
        var i = 0
        while i < chars.count {
            let n = min(16, chars.count - i)
            let chunk = Array(chars[i..<(i + n)])
            for isDown in [true, false] {
                guard let e = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: isDown) else { continue }
                e.flags = carryFlags([])
                chunk.withUnsafeBufferPointer { p in
                    if let base = p.baseAddress {
                        e.keyboardSetUnicodeString(stringLength: n, unicodeString: base)
                    }
                }
                post(e)
            }
            i += n
            usleep(1500)
        }
    }

    /// Most compatible path for long / exotic text: clipboard + Cmd-V.
    func paste(_ s: String) {
        if dryRun { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(s, forType: .string)
        usleep(30000)
        tap(keycode: 9, mods: ["cmd"])
    }

    // MARK: mouse

    private var dragButton: CGMouseButton? = nil

    private func currentPoint() -> CGPoint {
        return CGEvent(source: nil)?.location ?? CGPoint(x: 0, y: 0)
    }

    func moveMouse(dx: Double, dy: Double) {
        let cur = currentPoint()
        let pt = CGPoint(x: cur.x + dx, y: cur.y + dy)
        let type: CGEventType = dragButton == nil ? .mouseMoved : .leftMouseDragged
        let e = CGEvent(mouseEventSource: src, mouseType: type, mouseCursorPosition: pt,
                        mouseButton: dragButton ?? .left)
        e?.post(tap: .cghidEventTap)
    }

    func click(button: String, count: Int) {
        let cur = currentPoint()
        let isRight = button == "right"
        let (downType, upType, btn): (CGEventType, CGEventType, CGMouseButton) = isRight
            ? (.rightMouseDown, .rightMouseUp, .right)
            : (.leftMouseDown, .leftMouseUp, .left)
        for i in 1...max(1, count) {
            let d = CGEvent(mouseEventSource: src, mouseType: downType, mouseCursorPosition: cur, mouseButton: btn)
            d?.setIntegerValueField(.mouseEventClickState, value: Int64(i))
            post(d)
            let u = CGEvent(mouseEventSource: src, mouseType: upType, mouseCursorPosition: cur, mouseButton: btn)
            u?.setIntegerValueField(.mouseEventClickState, value: Int64(i))
            post(u)
        }
    }

    func mouseButton(_ button: String, down: Bool) {
        let cur = currentPoint()
        let isRight = button == "right"
        let type: CGEventType = isRight ? (down ? .rightMouseDown : .rightMouseUp)
                                        : (down ? .leftMouseDown : .leftMouseUp)
        let btn: CGMouseButton = isRight ? .right : .left
        let e = CGEvent(mouseEventSource: src, mouseType: type, mouseCursorPosition: cur, mouseButton: btn)
        post(e)
        dragButton = down ? btn : nil
    }

    func scroll(dx: Double, dy: Double) {
        let e = CGEvent(scrollWheelEvent2Source: src, units: .pixel, wheelCount: 2,
                        wheel1: Int32(dy), wheel2: Int32(dx), wheel3: 0)
        post(e)
    }

    // MARK: caps lock

    /// Read the real Caps Lock state from the HID system state.
    func capsLockOn() -> Bool {
        return CGEventSource.flagsState(.hidSystemState).contains(.maskAlphaShift)
    }

    /// Caps Lock must be sent as a flagsChanged event carrying maskAlphaShift —
    /// a plain keyDown/keyUp of keycode 57 is silently ignored by macOS.
    /// Returns the state it switched to (the HID read settles a beat later).
    @discardableResult
    func toggleCapsLock() -> Bool {
        let want = !capsLockOn()
        for isDown in [true, false] {
            guard let e = CGEvent(keyboardEventSource: src, virtualKey: 57, keyDown: isDown) else { continue }
            e.type = .flagsChanged
            e.flags = want ? [.maskAlphaShift] : []
            post(e)
        }
        return want
    }

    func setCapsLock(_ on: Bool) {
        if capsLockOn() != on { toggleCapsLock() }
    }

    func typeText(_ s: String, preferPaste: Bool = false) {
        if preferPaste || s.count > 40 || s.contains("\n") {
            paste(s)
            return
        }
        for ch in s { character(ch) }
    }
}

// MARK: - Config

final class Config {
    var port: UInt16 = 8787
    var dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("MacSpace", isDirectory: true).path
    var webDir = ""
    var token = ""
    var dryRun = false

    static func load() -> Config {
        let c = Config()
        let args = Array(CommandLine.arguments.dropFirst())
        var i = 0
        while i < args.count {
            switch args[i] {
            case "--port": if i + 1 < args.count, let p = UInt16(args[i + 1]) { c.port = p; i += 1 }
            case "--dir": if i + 1 < args.count { c.dir = (args[i + 1] as NSString).expandingTildeInPath; i += 1 }
            case "--web": if i + 1 < args.count { c.webDir = (args[i + 1] as NSString).expandingTildeInPath; i += 1 }
            case "--token": if i + 1 < args.count { c.token = args[i + 1]; i += 1 }
            case "--dry-run": c.dryRun = true
            default: break
            }
            i += 1
        }
        if c.webDir.isEmpty,
           let bundledWeb = Bundle.main.resourceURL?.appendingPathComponent("web", isDirectory: true).path,
           FileManager.default.fileExists(atPath: bundledWeb) {
            c.webDir = bundledWeb
        }
        if c.webDir.isEmpty { c.webDir = c.dir + "/web" }
        // persistent token, stored next to the project
        try? FileManager.default.createDirectory(atPath: c.dir, withIntermediateDirectories: true)
        let tokenPath = c.dir + "/token"
        if c.token.isEmpty {
            if let t = try? String(contentsOfFile: tokenPath, encoding: .utf8) {
                c.token = t.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        if c.token.isEmpty {
            let alphabet = Array("abcdefghjkmnpqrstuvwxyz23456789")
            c.token = String((0..<6).map { _ in alphabet.randomElement()! })
            try? c.token.write(toFile: tokenPath, atomically: true, encoding: .utf8)
        }
        return c
    }
}

// MARK: - HTTP helpers

struct Request {
    let method: String
    let path: String
    let query: [String: String]
    let body: Data
}

struct Response {
    var status = 200
    var reason = "OK"
    var contentType = "application/json"
    var body = Data()
    var noCache = false
}

func httpDate() -> String {
    let f = DateFormatter()
    f.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
    f.timeZone = TimeZone(identifier: "GMT")
    return f.string(from: Date())
}

final class Connection {
    let conn: NWConnection
    let server: Server
    var buffer = Data()
    private var closed = false

    init(_ conn: NWConnection, server: Server) {
        self.conn = conn
        self.server = server
    }

    func start() {
        conn.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.receive()
            case .failed, .cancelled:
                self?.finish()
            default:
                break
            }
        }
        conn.start(queue: server.queue)
    }

    func finish() {
        if closed { return }
        closed = true
        server.release(self)
    }

    func receive() {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 1 << 16) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data, !data.isEmpty {
                self.buffer.append(data)
                self.drain()
            }
            if isComplete || error != nil {
                self.conn.cancel()
                self.finish()
            } else {
                self.receive()
            }
        }
    }

    func drain() {
        while true {
            guard let hdrRange = buffer.range(of: Data("\r\n\r\n".utf8)) else { return }
            let headerData = buffer.subdata(in: 0..<hdrRange.lowerBound)
            guard let headerText = String(data: headerData, encoding: .utf8) else {
                conn.cancel(); return
            }
            var lines = headerText.components(separatedBy: "\r\n")
            guard let requestLine = lines.first else { conn.cancel(); return }
            lines.removeFirst()
            let parts = requestLine.split(separator: " ")
            guard parts.count >= 2 else { conn.cancel(); return }
            let method = String(parts[0])
            let target = String(parts[1])

            var contentLength = 0
            for l in lines {
                let kv = l.split(separator: ":", maxSplits: 1)
                if kv.count == 2, kv[0].lowercased() == "content-length" {
                    contentLength = Int(kv[1].trimmingCharacters(in: .whitespaces)) ?? 0
                }
            }

            let bodyStart = hdrRange.upperBound
            let total = bodyStart + contentLength
            if buffer.count < total { return } // wait for more

            let body = buffer.subdata(in: bodyStart..<total)
            buffer.removeSubrange(0..<total)

            var path = target
            var query: [String: String] = [:]
            if let qIdx = target.firstIndex(of: "?") {
                path = String(target[target.startIndex..<qIdx])
                let qs = String(target[target.index(after: qIdx)...])
                for pair in qs.split(separator: "&") {
                    let kv = pair.split(separator: "=", maxSplits: 1)
                    if kv.count == 2 {
                        query[String(kv[0])] = String(kv[1]).removingPercentEncoding ?? String(kv[1])
                    } else if kv.count == 1 {
                        query[String(kv[0])] = ""
                    }
                }
            }

            let req = Request(method: method, path: path, query: query, body: body)
            let res = server.handle(req)
            respond(res, keepAlive: true)
        }
    }

    func respond(_ res: Response, keepAlive: Bool) {
        var head = "HTTP/1.1 \(res.status) \(res.reason)\r\n"
        head += "Content-Type: \(res.contentType)\r\n"
        head += "Content-Length: \(res.body.count)\r\n"
        head += "Access-Control-Allow-Origin: *\r\n"
        head += "Access-Control-Allow-Headers: *\r\n"
        head += "Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n"
        if res.noCache { head += "Cache-Control: no-store\r\n" }
        head += "Connection: \(keepAlive ? "keep-alive" : "close")\r\n\r\n"
        var out = Data(head.utf8)
        out.append(res.body)
        conn.send(content: out, completion: .contentProcessed { _ in })
        if !keepAlive { conn.cancel() }
    }
}

// MARK: - Server

final class Server {
    let config: Config
    let injector: Injector
    let queue = DispatchQueue(label: "server")   // serial: keystrokes must not interleave
    private let listenQueue = DispatchQueue(label: "listen")
    private var live: [ObjectIdentifier: Connection] = [:]
    private let liveLock = NSLock()
    private var iconCache: [String: String] = [:]   // bundle id -> 48px PNG (base64)

    /// Encoding app icons is the expensive part of /apps; the iPad polls the list
    /// every few seconds, so keep them. Icons only change when an app updates.
    private func cachedIcon(key: String, app: NSRunningApplication) -> String? {
        if let hit = iconCache[key] { return hit }
        guard let icon = app.icon, let b64 = pngBase64(icon, size: 48) else { return nil }
        if iconCache.count > 200 { iconCache.removeAll() }
        iconCache[key] = b64
        return b64
    }

    init(config: Config) {
        self.config = config
        self.injector = Injector(dryRun: config.dryRun)
    }

    func retain(_ c: Connection) {
        liveLock.lock()
        live[ObjectIdentifier(c)] = c
        liveLock.unlock()
    }

    func release(_ c: Connection) {
        liveLock.lock()
        live.removeValue(forKey: ObjectIdentifier(c))
        liveLock.unlock()
    }

    func json(_ obj: [String: Any], status: Int = 200) -> Response {
        var r = Response()
        r.status = status
        r.body = (try? JSONSerialization.data(withJSONObject: obj, options: [.sortedKeys])) ?? Data("{}".utf8)
        r.noCache = true
        return r
    }

    func authorized(_ req: Request) -> Bool {
        if let t = req.query["t"], t == config.token { return true }
        if let t = req.query["token"], t == config.token { return true }
        return false
    }

    func handle(_ req: Request) -> Response {
        if req.method == "OPTIONS" { return json(["ok": true]) }

        if req.path == "/" || req.path == "/index.html" {
            return serveFile(config.webDir + "/index.html", type: "text/html; charset=utf-8")
        }
        if req.path == "/health" {
            let ax = AXIsProcessTrusted()
            return json([
                "ok": true, "version": VERSION, "host": Host.current().localizedName ?? "mac",
                "ax": ax, "dryRun": config.dryRun, "port": Int(config.port),
            ])
        }
        if req.path == "/favicon.ico" { return Response(status: 204, reason: "No Content", contentType: "image/x-icon", body: Data()) }

        guard authorized(req) else {
            Log.line("DENIED \(req.method) \(req.path) (bad token)")
            return json(["ok": false, "error": "unauthorized"], status: 401)
        }

        var obj: [String: Any] = [:]
        if !req.body.isEmpty {
            guard let parsed = try? JSONSerialization.jsonObject(with: req.body),
                  let dict = parsed as? [String: Any] else {
                return json(["ok": false, "error": "bad json"], status: 400)
            }
            obj = dict
        }

        switch req.path {
        case "/key":
            let k = (obj["k"] as? String) ?? ""
            let mods = (obj["m"] as? [String]) ?? []
            let action = (obj["d"] as? String) ?? "tap"
            let lower = k.lowercased()
            if lower == "capslock" || lower == "caps" {
                let on = injector.toggleCapsLock()
                Log.line("CAPS LOCK -> \(on ? "on" : "off")")
                return json(["ok": true, "caps": on])
            }
            if let kc = keyCodes[lower] {
                injector.tap(keycode: kc, mods: mods, action: action)
                // momentary hold of a bare modifier: remember it for later keys
                if mods.isEmpty, action == "down" || action == "up" {
                    injector.holdFlag(named: lower, down: action == "down")
                }
                let eff = injector.flagsSummary([])
                Log.line("KEY \(lower)\(mods.isEmpty ? "" : "+" + mods.joined(separator: "+")) [\(action)]\(eff.isEmpty ? "" : " flags=\(eff)")")
                return json(["ok": true])
            }
            if k.count == 1, let ch = k.first {
                injector.character(ch)
                Log.line("CHAR \(k)")
                return json(["ok": true])
            }
            Log.line("UNKNOWN KEY '\(k)'")
            return json(["ok": false, "error": "unknown key"], status: 400)

        case "/text":
            let s = (obj["s"] as? String) ?? ""
            let mode = (obj["mode"] as? String) ?? "auto"
            injector.releaseAll()
            switch mode {
            case "paste": injector.paste(s)
            case "type": for ch in s { injector.character(ch) }
            default: injector.typeText(s)
            }
            let how = mode == "paste" ? " (paste)" : (mode == "type" ? " (type)" : "")
            Log.line("TEXT \(s.count) chars\(how)")
            return json(["ok": true])

        case "/ping":
            return json(["ok": true, "ax": AXIsProcessTrusted(), "caps": injector.capsLockOn()])

        case "/mouse":
            let t = (obj["t"] as? String) ?? ""
            switch t {
            case "move":
                injector.moveMouse(dx: (obj["dx"] as? Double) ?? 0, dy: (obj["dy"] as? Double) ?? 0)
            case "click":
                let n = (obj["n"] as? Int) ?? 1
                injector.click(button: (obj["btn"] as? String) ?? "left", count: n)
                Log.line("MOUSE click \((obj["btn"] as? String) ?? "left") x\(n)")
            case "scroll":
                injector.scroll(dx: (obj["dx"] as? Double) ?? 0, dy: (obj["dy"] as? Double) ?? 0)
            case "down":
                injector.mouseButton((obj["btn"] as? String) ?? "left", down: true)
                Log.line("MOUSE down")
            case "up":
                injector.mouseButton((obj["btn"] as? String) ?? "left", down: false)
                Log.line("MOUSE up")
            default:
                return json(["ok": false, "error": "unknown mouse op"], status: 400)
            }
            return json(["ok": true])

        case "/apps":
            let frontPid = frontmostPid()
            let withIcons = (req.query["icons"] ?? "1") != "0"
            var pids = Set<pid_t>()

            // Live source 1: the window server. Always current, never cached.
            if let info = CGWindowListCopyWindowInfo([.excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] {
                for w in info {
                    guard let p = w[kCGWindowOwnerPID as String] as? Int, p > 0 else { continue }
                    if let layer = w[kCGWindowLayer as String] as? Int, layer != 0 { continue }
                    pids.insert(pid_t(p))
                }
            }
            // Live source 2: NSWorkspace's registry (covers windowless apps), unioned
            // because it can go stale in a long-running process.
            for a in NSWorkspace.shared.runningApplications where a.activationPolicy == .regular {
                pids.insert(a.processIdentifier)
            }
            if frontPid > 0 { pids.insert(frontPid) }
            pids.remove(getpid())

            let apps = pids.compactMap { pid -> [String: Any]? in
                guard let app = NSRunningApplication(processIdentifier: pid),
                      app.activationPolicy == .regular else { return nil }
                var d: [String: Any] = [
                    "pid": Int(pid),
                    "name": app.localizedName ?? "?",
                    "active": pid == frontPid,
                ]
                if let b = app.bundleIdentifier { d["bundle"] = b }
                if withIcons, let key = app.bundleIdentifier ?? app.localizedName,
                   let icon = cachedIcon(key: key, app: app) {
                    d["icon"] = icon
                }
                return d
            }
            .sorted { a, b in
                let aa = (a["active"] as? Bool ?? false), bb = (b["active"] as? Bool ?? false)
                if aa != bb { return aa }
                return (a["name"] as? String ?? "") < (b["name"] as? String ?? "")
            }
            return json(["ok": true, "apps": apps, "frontmost": Int(frontPid)])

        case "/focus":
            let pid = (obj["pid"] as? Int) ?? (Int(req.query["pid"] ?? "") ?? 0)
            guard pid > 0, let app = NSRunningApplication(processIdentifier: pid_t(pid)) else {
                return json(["ok": false, "error": "no such app"], status: 404)
            }
            let ok: Bool
            if #available(macOS 14.0, *) { ok = app.activate() }
            else { ok = app.activate(options: [.activateIgnoringOtherApps]) }
            if ok {
                for _ in 0..<10 {                       // let the switch settle
                    usleep(60000)
                    if frontmostPid() == pid_t(pid) { break }
                }
            }
            let front = frontmostPid()
            Log.line("FOCUS \(app.localizedName ?? "?") -> \(ok), frontmost now \(front)")
            return json(["ok": ok, "name": app.localizedName ?? "?", "frontmost": Int(front), "switched": front == pid_t(pid)])

        case "/clipboard":
            if req.method == "GET" {
                let s = NSPasteboard.general.string(forType: .string) ?? ""
                return json(["ok": true, "text": String(s.prefix(4000)), "length": s.count])
            }
            let s = (obj["s"] as? String) ?? ""
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString(s, forType: .string)
            Log.line("CLIPBOARD set \(s.count) chars")
            if (obj["paste"] as? Bool) == true {
                usleep(60000)
                injector.tap(keycode: 9, mods: ["cmd"])
            }
            return json(["ok": true])

        case "/status":
            var d: [String: Any] = [
                "ok": true,
                "host": Host.current().localizedName ?? "mac",
                "version": VERSION,
                "ax": AXIsProcessTrusted(),
                "caps": injector.capsLockOn(),
                "uptime": Int(ProcessInfo.processInfo.systemUptime),
                "apps": NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }.count,
            ]
            if let p = CGEvent(source: nil)?.location { d["cursor"] = [Int(p.x), Int(p.y)] }
            if let b = batteryInfo() { d["battery"] = b.0; d["charging"] = b.1 }
            return json(d)

        default:
            return json(["ok": false, "error": "not found"], status: 404)
        }
    }

    func serveFile(_ path: String, type: String) -> Response {
        var r = Response()
        r.contentType = type
        r.noCache = true
        if let data = FileManager.default.contents(atPath: path) {
            r.body = data
        } else {
            r.status = 404
            r.reason = "Not Found"
            r.body = Data("index.html not found at \(path)".utf8)
        }
        return r
    }

    func start() {
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        let listener: NWListener
        do {
            listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: config.port)!)
        } catch {
            Log.line("FATAL could not bind port \(config.port): \(error)")
            exit(1)
        }
        listener.newConnectionHandler = { [weak self] conn in
            guard let self else { return }
            let c = Connection(conn, server: self)
            self.retain(c)
            c.start()
        }
        listener.stateUpdateHandler = { state in
            if case .failed(let e) = state {
                Log.line("listener failed: \(e)")
                exit(1)
            }
        }
        listener.start(queue: listenQueue)
    }
}

// MARK: - Mac helpers (icons, battery, frontmost app)

/// Who is frontmost, according to the window server.
/// NSWorkspace's frontmostApplication / NSRunningApplication.isActive both go
/// stale in a process with no NSApplication run loop, so ask the AX server.
func frontmostPid() -> pid_t {
    let systemWide = AXUIElementCreateSystemWide()
    var focused: CFTypeRef?
    if AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString, &focused) == .success,
       let raw = focused {
        let el: AXUIElement = unsafeBitCast(raw, to: AXUIElement.self)
        var pid: pid_t = 0
        if AXUIElementGetPid(el, &pid) == .success { return pid }
    }
    return NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0
}

func pngBase64(_ image: NSImage, size: Int) -> String? {
    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                                     bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                     colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    image.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])?.base64EncodedString()
}

func batteryInfo() -> (Int, Bool)? {
    guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
          let list = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else { return nil }
    for ps in list {
        guard let desc = IOPSGetPowerSourceDescription(snapshot, ps)?.takeUnretainedValue() as? [String: Any] else { continue }
        let level = desc[kIOPSCurrentCapacityKey as String] as? Int ?? -1
        let state = desc[kIOPSPowerSourceStateKey as String] as? String ?? ""
        return (level, state == (kIOPSACPowerValue as String))
    }
    return nil
}

// MARK: - LAN address

func lanIP() -> String? {
    var address: String?
    var ifaddr: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
    defer { freeifaddrs(ifaddr) }
    for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
        let interface = ptr.pointee
        let family = interface.ifa_addr.pointee.sa_family
        guard family == UInt8(AF_INET) else { continue }
        let name = String(cString: interface.ifa_name)
        guard name == "en0" || name == "en1" else { continue }
        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        if getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                       &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0 {
            address = String(cString: hostname)
        }
        if address != nil { break }
    }
    return address
}

// MARK: - Menu bar

final class StatusController: NSObject {
    private let url: String
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    init(url: String) {
        self.url = url
        super.init()

        statusItem.button?.title = "⌨︎"
        statusItem.button?.toolTip = "MacSpace"

        let menu = NSMenu()
        menu.addItem(withTitle: "MacSpace", action: nil, keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Copy iPad URL", action: #selector(copyIPadURL), keyEquivalent: "c")
        menu.addItem(withTitle: "Open Accessibility Settings", action: #selector(openAccessibilitySettings), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Quit MacSpace", action: #selector(quit), keyEquivalent: "q")
        for item in menu.items { item.target = self }
        statusItem.menu = menu
    }

    @objc private func copyIPadURL() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url, forType: .string)
        statusItem.button?.toolTip = "iPad URL copied"
    }

    @objc private func openAccessibilitySettings() {
        guard let settings = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(settings)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

// MARK: - Main

let config = Config.load()
Log.open(config.dir + "/server.log")
let server = Server(config: config)
server.start()

let hostName = ProcessInfo.processInfo.hostName.replacingOccurrences(of: ".local", with: "")
let ip = lanIP() ?? "your-mac-ip"
let trusted = AXIsProcessTrusted()
let iPadURL = "http://\(ip):\(config.port)/?t=\(config.token)"
let nsapp = NSApplication.shared
let statusController = StatusController(url: iPadURL)

Log.line("MacSpace v\(VERSION) starting on port \(config.port)")
Log.line("  token: \(config.token)")
Log.line("  open on iPad:  \(iPadURL)")
Log.line("  or:            http://\(hostName).local:\(config.port)/?t=\(config.token)")
if config.dryRun { Log.line("  DRY RUN — keystrokes will be logged, not injected") }
if !trusted {
    Log.line("  ACCESSIBILITY: NOT GRANTED — keystrokes cannot be injected yet.")
    Log.line("  Fix: System Settings > Privacy & Security > Accessibility > enable this app.")
    if !config.dryRun {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)
    }
} else {
    Log.line("  ACCESSIBILITY: granted ✓")
}

// Keep a real run loop alive, not dispatchMain(): NSWorkspace only refreshes its
// registry of running apps when its launch/quit notifications can be delivered,
// which needs a CFRunLoop on the main thread. Without this the app list freezes at
// whatever was open when the helper started — new apps never show up.
nsapp.setActivationPolicy(.accessory)   // never steal focus from the user
nsapp.run()
