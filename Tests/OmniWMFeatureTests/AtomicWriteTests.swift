import Foundation
@testable import OmniWM
import Testing

@Suite struct AtomicWriteTests {
    @Test func writePreservesSymlinkAndUpdatesTarget() throws {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appendingPathComponent("omniwm-symlink-\(UUID().uuidString)")
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: dir) }

        // A real file (the "dotfiles source") and a symlink pointing at it (the config path).
        let target = dir.appendingPathComponent("real.json")
        try Data("old".utf8).write(to: target)
        let link = dir.appendingPathComponent("link.json")
        try fm.createSymbolicLink(at: link, withDestinationURL: target)

        try Data("new".utf8).writePreservingSymlink(to: link)

        // The symlink is intact (destinationOfSymbolicLink throws if it became a regular file)...
        #expect(try fm.destinationOfSymbolicLink(atPath: link.path) == target.path)
        // ...and the real target received the update.
        #expect(try String(contentsOf: target, encoding: .utf8) == "new")
    }
}
