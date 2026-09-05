import CoreImage
import Foundation

/// A parsed Adobe Cube (`.cube`) 3D lookup table, ready for `CIColorCube`.
///
/// `data` holds `dimension^3` RGBA `Float32` texels ordered with red varying
/// fastest, then green, then blue. That is exactly the layout Core Image's
/// colour-cube filters expect, so no repacking happens at render time.
struct CubeLUT: Sendable, Equatable {
    let title: String?
    let dimension: Int
    let data: Data
    let domainMin: SIMD3<Float>
    let domainMax: SIMD3<Float>
}

enum LUTError: Error, LocalizedError, Equatable {
    case missingSize
    case unsupportedSize(Int)
    case unsupported1DLUT
    case malformedEntry(line: Int)
    case entryCountMismatch(expected: Int, found: Int)
    case fileNotFound(String)

    var errorDescription: String? {
        switch self {
        case .missingSize:
            "The LUT does not declare LUT_3D_SIZE."
        case .unsupportedSize(let n):
            "LUT_3D_SIZE \(n) is out of the supported range 2...128."
        case .unsupported1DLUT:
            "1D LUTs are not supported; export a 3D LUT."
        case .malformedEntry(let line):
            "Line \(line) is not three numbers."
        case .entryCountMismatch(let expected, let found):
            "Expected \(expected) colour entries but found \(found)."
        case .fileNotFound(let name):
            "No LUT named \(name) in the app bundle."
        }
    }
}

enum CubeLUTParser {

    /// Core Image allocates `dimension^3 * 16` bytes for the cube; 128 caps that
    /// at 32 MB, well past any LUT a photo app has reason to ship.
    static let maxDimension = 128

    static func parse(_ text: String) throws -> CubeLUT {
        var title: String?
        var dimension: Int?
        var domainMin = SIMD3<Float>(0, 0, 0)
        var domainMax = SIMD3<Float>(1, 1, 1)
        var texels: [Float] = []

        for (offset, rawLine) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            // '#' is the Cube comment marker; blank lines are legal filler.
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }

            let fields = line.split(whereSeparator: \.isWhitespace)
            guard let keyword = fields.first else { continue }

            switch keyword {
            case "TITLE":
                title = line
                    .dropFirst("TITLE".count)
                    .trimmingCharacters(in: .whitespaces)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            case "LUT_3D_SIZE":
                guard let n = Int(fields.dropFirst().first ?? "") else {
                    throw LUTError.malformedEntry(line: offset + 1)
                }
                guard (2...maxDimension).contains(n) else { throw LUTError.unsupportedSize(n) }
                dimension = n
                texels.reserveCapacity(n * n * n * 4)
            case "LUT_1D_SIZE":
                throw LUTError.unsupported1DLUT
            case "DOMAIN_MIN":
                domainMin = try vector(fields.dropFirst(), line: offset + 1)
            case "DOMAIN_MAX":
                domainMax = try vector(fields.dropFirst(), line: offset + 1)
            default:
                // Anything else must be a colour triplet.
                guard fields.count >= 3,
                      let r = Float(fields[0]), let g = Float(fields[1]), let b = Float(fields[2]) else {
                    throw LUTError.malformedEntry(line: offset + 1)
                }
                texels.append(contentsOf: [r, g, b, 1])
            }
        }

        guard let dimension else { throw LUTError.missingSize }
        let expected = dimension * dimension * dimension * 4
        guard texels.count == expected else {
            throw LUTError.entryCountMismatch(expected: expected / 4, found: texels.count / 4)
        }

        return CubeLUT(
            title: title,
            dimension: dimension,
            data: texels.withUnsafeBufferPointer { Data(buffer: $0) },
            domainMin: domainMin,
            domainMax: domainMax
        )
    }

    private static func vector(
        _ fields: ArraySlice<Substring>, line: Int
    ) throws -> SIMD3<Float> {
        let values = fields.compactMap { Float($0) }
        guard values.count >= 3 else { throw LUTError.malformedEntry(line: line) }
        return SIMD3(values[0], values[1], values[2])
    }
}

/// Bundle-backed loader with a parse cache.
///
/// Parsing a 33³ cube allocates ~575 KB and walks ~36k lines, so it must never
/// happen per frame. Entries are cached for the process lifetime; the bundled
/// set is small and fixed.
final class LUTStore: @unchecked Sendable {
    static let shared = LUTStore()

    private let lock = NSLock()
    private var cache: [String: CubeLUT] = [:]
    private let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    func lut(named name: String) throws -> CubeLUT {
        lock.lock()
        if let hit = cache[name] {
            lock.unlock()
            return hit
        }
        lock.unlock()

        guard let url = bundle.url(forResource: name, withExtension: "cube")
                ?? bundle.url(forResource: name, withExtension: "cube", subdirectory: "LUTs") else {
            throw LUTError.fileNotFound(name)
        }
        let parsed = try CubeLUTParser.parse(String(contentsOf: url, encoding: .utf8))

        lock.lock()
        cache[name] = parsed
        lock.unlock()
        return parsed
    }
}
