import Foundation

public func shellProcessViolation() throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/sh")
    try process.run()
    process.waitUntilExit()
}
