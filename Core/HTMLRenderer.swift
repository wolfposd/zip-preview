import Foundation

public enum HTMLRenderer {
    public static func render(listing: ArchiveListing, fileName: String, fileSize: Int64?) -> String {
        let root = TreeNode.build(from: listing.entries)

        var format = listing.formatName
        if !listing.filters.isEmpty {
            format += " · " + listing.filters.joined(separator: " + ")
        }
        var stats = [
            "\(root.fileCount) \(root.fileCount == 1 ? "file" : "files")",
            "\(root.folderCount) \(root.folderCount == 1 ? "folder" : "folders")",
            "\(formatSize(root.totalSize)) uncompressed",
        ]
        if let fileSize { stats.append("\(formatSize(fileSize)) on disk") }

        var body = """
        <header>
          <h1>\(escape(fileName))</h1>
          <p class="meta">\(escape(format))</p>
          <p class="meta">\(escape(stats.joined(separator: " · ")))</p>
        </header>
        """
        if let warning = listing.warning {
            body += "<p class=\"notice\">Stopped reading early: \(escape(warning))</p>"
        }
        if root.children.isEmpty {
            body += "<p class=\"empty\">This archive is empty.</p>"
        } else {
            body += "<div class=\"list\"><div class=\"row head\"><span class=\"name\">Name</span>"
                + "<span class=\"size\">Size</span><span class=\"date\">Modified</span></div>"
            renderChildren(of: root, depth: 0, into: &body)
            body += "</div>"
        }
        if listing.omittedCount > 0 {
            body += "<p class=\"notice\">…and \(listing.omittedCount) more entries not shown.</p>"
        }
        return page(title: fileName, body: body)
    }

    public static func renderError(_ message: String, fileName: String) -> String {
        page(title: fileName, body: """
        <header><h1>\(escape(fileName))</h1></header>
        <p class="notice">Could not read this archive: \(escape(message))</p>
        """)
    }

    private static func renderChildren(of node: TreeNode, depth: Int, into html: inout String) {
        // Keep wrapper folders open so a zip containing a single top-level folder shows its contents.
        let autoOpen = depth == 0 || node.children.count == 1
        for child in node.children {
            if child.isDirectory {
                let summary = row(icon: "📁", name: child.name, size: child.totalSize, date: child.modified,
                                  extra: child.entry?.isEncrypted == true ? " 🔒" : "")
                html += "<details\(autoOpen && child.children.count > 0 ? " open" : "")><summary>\(summary)</summary>"
                html += "<div class=\"children\">"
                renderChildren(of: child, depth: depth + 1, into: &html)
                html += "</div></details>"
            } else {
                let entry = child.entry
                let icon = entry?.isSymlink == true ? "🔗" : "📄"
                html += "<div class=\"file\">"
                    + row(icon: icon, name: child.name, size: entry?.size, date: entry?.modified,
                          extra: entry?.isEncrypted == true ? " 🔒" : "")
                    + "</div>"
            }
        }
    }

    private static func row(icon: String, name: String, size: Int64?, date: Date?, extra: String) -> String {
        "<span class=\"row\"><span class=\"name\" title=\"\(escape(name))\"><span class=\"icon\">\(icon)</span>"
            + "\(escape(name))\(extra)</span>"
            + "<span class=\"size\">\(size.map(formatSize) ?? "—")</span>"
            + "<span class=\"date\">\(date.map(formatDate) ?? "")</span></span>"
    }

    private static let sizeFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    static func formatSize(_ bytes: Int64) -> String { sizeFormatter.string(fromByteCount: bytes) }
    static func formatDate(_ date: Date) -> String { dateFormatter.string(from: date) }

    static func escape(_ text: String) -> String {
        var result = ""
        result.reserveCapacity(text.count)
        for character in text {
            switch character {
            case "&": result += "&amp;"
            case "<": result += "&lt;"
            case ">": result += "&gt;"
            case "\"": result += "&quot;"
            case "'": result += "&#39;"
            default: result.append(character)
            }
        }
        return result
    }

    private static func page(title: String, body: String) -> String {
        """
        <!doctype html>
        <html><head><meta charset="utf-8"><title>\(escape(title))</title>
        <style>\(css)</style></head>
        <body>\(body)</body></html>
        """
    }

    private static let css = """
    :root { color-scheme: light dark; --fg: #1d1d1f; --muted: #6e6e73; --line: #e5e5ea; --hover: #f2f2f7; --bg: #ffffff; }
    @media (prefers-color-scheme: dark) {
      :root { --fg: #f5f5f7; --muted: #98989d; --line: #38383a; --hover: #2c2c2e; --bg: #1e1e1e; }
    }
    * { box-sizing: border-box; }
    body { margin: 0; padding: 16px 20px; font: 13px -apple-system, system-ui, sans-serif; color: var(--fg); background: var(--bg); }
    header { margin-bottom: 12px; }
    h1 { font-size: 17px; font-weight: 600; margin: 0 0 4px; word-break: break-all; }
    .meta { margin: 0; color: var(--muted); }
    .notice { color: #d70015; }
    .empty { color: var(--muted); }
    .list { border-top: 1px solid var(--line); }
    .row { display: flex; align-items: center; gap: 12px; padding: 3px 4px; min-width: 0; }
    .head { color: var(--muted); font-size: 11px; font-weight: 600; border-bottom: 1px solid var(--line); padding-left: 22px; }
    .name { flex: 1; min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
    .icon { margin-right: 6px; }
    .size { width: 80px; text-align: right; font-variant-numeric: tabular-nums; color: var(--muted); }
    .date { width: 150px; color: var(--muted); white-space: nowrap; }
    .file { padding-left: 18px; }
    .file:hover > .row, summary:hover > .row { background: var(--hover); border-radius: 4px; }
    .children { padding-left: 16px; }
    summary { list-style: none; cursor: default; display: flex; align-items: center; }
    summary::-webkit-details-marker { display: none; }
    summary::before { content: "▸"; width: 18px; flex: none; text-align: center; color: var(--muted); }
    details[open] > summary::before { content: "▾"; }
    summary > .row { flex: 1; }
    """
}
