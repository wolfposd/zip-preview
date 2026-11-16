import Foundation
import QuickLookUI
import UniformTypeIdentifiers

final class PreviewProvider: QLPreviewProvider, QLPreviewingController {
    func providePreview(for request: QLFilePreviewRequest) async throws -> QLPreviewReply {
        let url = request.fileURL
        let fileName = url.lastPathComponent
        let fileSize = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map { Int64($0) }

        let html: String
        do {
            let listing = try ArchiveReader.list(url: url)
            html = HTMLRenderer.render(listing: listing, fileName: fileName, fileSize: fileSize)
        } catch {
            html = HTMLRenderer.renderError(String(describing: error), fileName: fileName)
        }

        let reply = QLPreviewReply(dataOfContentType: .html, contentSize: CGSize(width: 800, height: 600)) { _ in
            Data(html.utf8)
        }
        reply.stringEncoding = .utf8
        reply.title = fileName
        return reply
    }
}
