import Foundation

/// A folder hierarchy built from an archive's flat path list.
public final class TreeNode {
    public let name: String
    public private(set) var isDirectory: Bool
    public private(set) var entry: ArchiveEntry?
    public private(set) var children: [TreeNode] = []
    private var childIndex: [String: TreeNode] = [:]

    /// Sum of all file sizes below (or of) this node.
    public private(set) var totalSize: Int64 = 0
    public private(set) var fileCount = 0
    public private(set) var folderCount = 0

    init(name: String, isDirectory: Bool) {
        self.name = name
        self.isDirectory = isDirectory
    }

    public var modified: Date? { entry?.modified }

    fileprivate func child(named name: String, isDirectory: Bool) -> TreeNode {
        if let existing = childIndex[name] {
            if isDirectory { existing.isDirectory = true }
            return existing
        }
        let node = TreeNode(name: name, isDirectory: isDirectory)
        childIndex[name] = node
        children.append(node)
        return node
    }

    fileprivate func finalize() {
        children.sort {
            if $0.isDirectory != $1.isDirectory { return $0.isDirectory }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
        totalSize = isDirectory ? 0 : (entry?.size ?? 0)
        fileCount = 0
        folderCount = 0
        for child in children {
            child.finalize()
            totalSize += child.totalSize
            fileCount += child.isDirectory ? child.fileCount : 1
            folderCount += child.isDirectory ? child.folderCount + 1 : child.folderCount
        }
    }

    /// Builds a tree, synthesizing parent folders that the archive doesn't list explicitly.
    public static func build(from entries: [ArchiveEntry]) -> TreeNode {
        let root = TreeNode(name: "", isDirectory: true)
        for entry in entries {
            let components = entry.path.split(separator: "/").map(String.init)
            guard !components.isEmpty else { continue }
            var node = root
            for (index, component) in components.enumerated() {
                let isLast = index == components.count - 1
                node = node.child(named: component, isDirectory: isLast ? entry.isDirectory : true)
            }
            node.entry = entry
        }
        root.finalize()
        return root
    }
}
