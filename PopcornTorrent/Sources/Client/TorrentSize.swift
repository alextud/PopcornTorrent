import Foundation

/// A class used to define the size of a torrent
public class TorrentSize: @unchecked Sendable {
    private let byteCount: Int64

    public init(bytes: Int64) {
        self.byteCount = bytes
    }

    public convenience init(number: NSNumber) {
        self.init(bytes: number.int64Value)
    }

    public static var zero: TorrentSize {
        return TorrentSize(bytes: 0)
    }

    /// The size expressed as a human-readable string
    public var stringValue: String {
        ByteCountFormatter.string(fromByteCount: byteCount, countStyle: .file)
    }

    /// The size expressed as an Int64
    public var int64Value: Int64 {
        return byteCount
    }

    /// The size wrapped in an NSNumber
    public var numberValue: NSNumber {
        return NSNumber(value: byteCount)
    }

    public func compare(_ otherSize: TorrentSize) -> ComparisonResult {
        if byteCount < otherSize.byteCount {
            return .orderedAscending
        } else if byteCount > otherSize.byteCount {
            return .orderedDescending
        } else {
            return .orderedSame
        }
    }
}

extension TorrentSize: Equatable {
    public static func == (lhs: TorrentSize, rhs: TorrentSize) -> Bool {
        return lhs.byteCount == rhs.byteCount
    }
}

extension TorrentSize: Comparable {
    public static func < (lhs: TorrentSize, rhs: TorrentSize) -> Bool {
        return lhs.byteCount < rhs.byteCount
    }
}
