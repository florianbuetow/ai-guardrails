import Foundation

public func coreFileIOViolation(at fileURL: URL) throws -> Data {
  try Data(contentsOf: fileURL)
}
