import Foundation

extension Data {
    /// Atomic write that preserves a symlink at `url`. Plain `write(to:options:.atomic)` does a
    /// temp-file + `rename()` onto the path, which *replaces* a symlink with a regular file. We
    /// resolve the link first and write onto the real target, so the rename happens inside the
    /// target's directory and the symlink (e.g. a dotfiles-managed config) stays intact.
    func writePreservingSymlink(to url: URL) throws {
        try write(to: url.resolvingSymlinksInPath(), options: .atomic)
    }
}
