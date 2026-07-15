import Foundation
import Compression

enum EPGError: LocalizedError {
    case decompressionFailed
    case parseFailed

    var errorDescription: String? {
        switch self {
        case .decompressionFailed: "The EPG file could not be decompressed."
        case .parseFailed: "The EPG guide could not be parsed."
        }
    }
}

/// Downloads and parses XMLTV guides (plain or gzip-compressed).
enum EPGService {

    /// Only keep programs inside this window to bound memory usage.
    private static let pastWindow: TimeInterval = 3 * 3600
    private static let futureWindow: TimeInterval = 48 * 3600

    static func loadXMLTV(from url: URL) async throws -> EPGSnapshot {
        var (data, _) = try await URLSession.shared.data(from: url)
        if data.count > 2, data[data.startIndex] == 0x1f, data[data.startIndex + 1] == 0x8b {
            data = try gunzip(data)
        }
        let payload = data
        return try await Task.detached(priority: .utility) {
            try parse(payload)
        }.value
    }

    // MARK: - XML Parsing

    private static func parse(_ data: Data) throws -> EPGSnapshot {
        let delegate = XMLTVParserDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.shouldResolveExternalEntities = false
        guard parser.parse() || !delegate.programs.isEmpty else {
            throw EPGError.parseFailed
        }

        var byChannel: [String: [EPGProgram]] = [:]
        for program in delegate.programs {
            byChannel[program.channelID.lowercased(), default: []].append(program)
        }
        for key in byChannel.keys {
            byChannel[key]?.sort { $0.start < $1.start }
        }
        return EPGSnapshot(programsByChannel: byChannel, updatedAt: .now)
    }

    private final class XMLTVParserDelegate: NSObject, XMLParserDelegate {
        var programs: [EPGProgram] = []

        private var currentChannelID: String?
        private var currentStart: Date?
        private var currentEnd: Date?
        private var currentTitle = ""
        private var currentDesc = ""
        private var currentElement = ""

        private let windowStart = Date().addingTimeInterval(-EPGService.pastWindow)
        private let windowEnd = Date().addingTimeInterval(EPGService.futureWindow)

        func parser(
            _ parser: XMLParser,
            didStartElement elementName: String,
            namespaceURI: String?,
            qualifiedName qName: String?,
            attributes attributeDict: [String: String] = [:]
        ) {
            currentElement = elementName
            if elementName == "programme" {
                currentChannelID = attributeDict["channel"]
                currentStart = EPGService.parseDate(attributeDict["start"])
                currentEnd = EPGService.parseDate(attributeDict["stop"])
                currentTitle = ""
                currentDesc = ""
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            switch currentElement {
            case "title": currentTitle += string
            case "desc": currentDesc += string
            default: break
            }
        }

        func parser(
            _ parser: XMLParser,
            didEndElement elementName: String,
            namespaceURI: String?,
            qualifiedName qName: String?
        ) {
            currentElement = ""
            guard elementName == "programme" else { return }
            defer {
                currentChannelID = nil
                currentStart = nil
                currentEnd = nil
            }
            guard let channelID = currentChannelID,
                  let start = currentStart,
                  let end = currentEnd,
                  end > windowStart, start < windowEnd
            else { return }

            programs.append(
                EPGProgram(
                    channelID: channelID,
                    title: currentTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                    desc: currentDesc.isEmpty ? nil : currentDesc.trimmingCharacters(in: .whitespacesAndNewlines),
                    start: start,
                    end: end
                )
            )
        }
    }

    // MARK: - Dates

    private static let dateFormatters: [DateFormatter] = {
        ["yyyyMMddHHmmss Z", "yyyyMMddHHmmss"].map { format in
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            return formatter
        }
    }()

    private static func parseDate(_ string: String?) -> Date? {
        guard let string else { return nil }
        for formatter in dateFormatters {
            if let date = formatter.date(from: string) {
                return date
            }
        }
        return nil
    }

    // MARK: - Gzip

    private static func gunzip(_ data: Data) throws -> Data {
        let bytes = [UInt8](data)
        guard bytes.count > 18 else { throw EPGError.decompressionFailed }

        var index = 10
        let flags = bytes[3]
        if flags & 0x04 != 0 { // FEXTRA
            guard index + 2 <= bytes.count else { throw EPGError.decompressionFailed }
            let extraLength = Int(bytes[index]) | (Int(bytes[index + 1]) << 8)
            index += 2 + extraLength
        }
        if flags & 0x08 != 0 { // FNAME
            while index < bytes.count, bytes[index] != 0 { index += 1 }
            index += 1
        }
        if flags & 0x10 != 0 { // FCOMMENT
            while index < bytes.count, bytes[index] != 0 { index += 1 }
            index += 1
        }
        if flags & 0x02 != 0 { // FHCRC
            index += 2
        }
        guard index < bytes.count - 8 else { throw EPGError.decompressionFailed }

        return try inflateRaw(data.subdata(in: index..<(data.count - 8)))
    }

    private static func inflateRaw(_ input: Data) throws -> Data {
        var output = Data()
        let bufferSize = 512 * 1024
        let destination = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { destination.deallocate() }

        var stream = compression_stream(
            dst_ptr: destination,
            dst_size: bufferSize,
            src_ptr: destination,
            src_size: 0,
            state: nil
        )
        guard compression_stream_init(&stream, COMPRESSION_STREAM_DECODE, COMPRESSION_ZLIB) == COMPRESSION_STATUS_OK else {
            throw EPGError.decompressionFailed
        }
        defer { compression_stream_destroy(&stream) }

        try input.withUnsafeBytes { (source: UnsafeRawBufferPointer) in
            guard let base = source.bindMemory(to: UInt8.self).baseAddress else {
                throw EPGError.decompressionFailed
            }
            stream.src_ptr = base
            stream.src_size = input.count

            var status = COMPRESSION_STATUS_OK
            repeat {
                stream.dst_ptr = destination
                stream.dst_size = bufferSize
                status = compression_stream_process(&stream, Int32(COMPRESSION_STREAM_FINALIZE.rawValue))
                guard status != COMPRESSION_STATUS_ERROR else {
                    throw EPGError.decompressionFailed
                }
                output.append(destination, count: bufferSize - stream.dst_size)
            } while status == COMPRESSION_STATUS_OK
        }
        return output
    }
}
