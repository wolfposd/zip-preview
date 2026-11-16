import XCTest

final class ArchiveCoreTests: XCTestCase {
    private let fixtures = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures")

    private let expectedFiles: Set<String> = [
        "project/README.md",
        "project/src/main.py",
        "project/src/deep/er/zeros.bin",
        "project/docs/notes.txt",
        "project/docs/<b> & quote.txt",
    ]

    private func filePaths(_ name: String) throws -> Set<String> {
        let listing = try ArchiveReader.list(url: fixtures.appendingPathComponent(name))
        return Set(listing.entries.filter { !$0.isDirectory }.map(\.path))
    }

    func testZip() throws {
        XCTAssertEqual(try filePaths("sample.zip"), expectedFiles)
    }

    func testTarGz() throws {
        let listing = try ArchiveReader.list(url: fixtures.appendingPathComponent("sample.tar.gz"))
        XCTAssertEqual(Set(listing.entries.filter { !$0.isDirectory }.map(\.path)), expectedFiles)
        XCTAssertEqual(listing.filters, ["gzip"])
    }

    func test7z() throws {
        XCTAssertEqual(try filePaths("sample.7z"), expectedFiles)
    }

    func testSizesAndDates() throws {
        let listing = try ArchiveReader.list(url: fixtures.appendingPathComponent("sample.zip"))
        let zeros = try XCTUnwrap(listing.entries.first { $0.path.hasSuffix("zeros.bin") })
        XCTAssertEqual(zeros.size, 4096)
        XCTAssertNotNil(zeros.modified)
    }

    func testSingleCompressedFile() throws {
        let listing = try ArchiveReader.list(url: fixtures.appendingPathComponent("single.txt.gz"))
        XCTAssertEqual(listing.entries.map(\.path), ["single.txt"])
    }

    func testCorruptFileThrows() {
        XCTAssertThrowsError(try ArchiveReader.list(url: fixtures.appendingPathComponent("corrupt.zip")))
    }

    func testMaxEntries() throws {
        let listing = try ArchiveReader.list(url: fixtures.appendingPathComponent("sample.7z"), maxEntries: 3)
        XCTAssertEqual(listing.entries.count, 3)
        XCTAssertEqual(listing.omittedCount, 7)
    }

    func testNormalize() {
        XCTAssertEqual(ArchiveReader.normalize("./a//b/"), "a/b")
        XCTAssertEqual(ArchiveReader.normalize("/abs/path"), "abs/path")
        XCTAssertTrue(ArchiveReader.isHidden("__MACOSX/x/._y"))
        XCTAssertTrue(ArchiveReader.isHidden("dir/._file"))
        XCTAssertFalse(ArchiveReader.isHidden("dir/file"))
    }

    func testTreeSynthesizesFoldersAndAggregates() {
        let root = TreeNode.build(from: [
            ArchiveEntry(path: "b/c/file.txt", size: 10),
            ArchiveEntry(path: "b/other.txt", size: 5),
            ArchiveEntry(path: "a.txt", size: 1),
        ])
        XCTAssertEqual(root.children.map(\.name), ["b", "a.txt"])  // folders first
        XCTAssertEqual(root.totalSize, 16)
        XCTAssertEqual(root.fileCount, 3)
        XCTAssertEqual(root.folderCount, 2)
        XCTAssertEqual(root.children[0].children.map(\.name), ["c", "other.txt"])
    }

    func testHTMLEscapesNames() throws {
        let listing = ArchiveListing(
            entries: [ArchiveEntry(path: "<script>alert(1)</script>", size: 1)],
            formatName: "ZIP", filters: [], omittedCount: 0, warning: nil
        )
        let html = HTMLRenderer.render(listing: listing, fileName: "a&b.zip", fileSize: 100)
        XCTAssertFalse(html.contains("<script>"))
        XCTAssertTrue(html.contains("&lt;script&gt;"))
        XCTAssertTrue(html.contains("a&amp;b.zip"))
    }

    func testHTMLForFixture() throws {
        let listing = try ArchiveReader.list(url: fixtures.appendingPathComponent("sample.zip"))
        let html = HTMLRenderer.render(listing: listing, fileName: "sample.zip", fileSize: 1538)
        XCTAssertTrue(html.contains("5 files"))
        XCTAssertTrue(html.contains("5 folders"))
        XCTAssertFalse(html.contains("__MACOSX"))
    }
}
