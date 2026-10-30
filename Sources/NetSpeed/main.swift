import AppKit

// 命令行自检模式：`NetSpeed --report [秒数]`
let arguments = CommandLine.arguments
if let index = arguments.firstIndex(of: "--report") {
    let seconds = index + 1 < arguments.count ? (Int(arguments[index + 1]) ?? 5) : 5
    HeadlessReport.run(seconds: seconds)
    exit(0)
}

// 登录项开关：`NetSpeed --login-on` / `--login-off`
if arguments.contains("--login-on") {
    LoginItem.setEnabled(true)
    print("Login item: \(LoginItem.isEnabled ? "enabled" : "failed to enable")")
    exit(LoginItem.isEnabled ? 0 : 1)
}
if arguments.contains("--login-off") {
    LoginItem.setEnabled(false)
    print("Login item: \(LoginItem.isEnabled ? "still enabled" : "disabled")")
    exit(0)
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
// 只在菜单栏显示，不出现在 Dock 与程序坞
application.setActivationPolicy(.accessory)
application.run()
