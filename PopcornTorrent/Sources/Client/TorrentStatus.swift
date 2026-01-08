import Foundation

/// Status of a torrent download/stream
public struct TorrentStatus: Sendable {
    /// Buffering progress of the current piece (0.0 to 1.0)
    public let bufferingProgress: Float

    /// Overall download progress (0.0 to 1.0)
    public let totalProgress: Float

    /// Current download speed in bytes per second
    public let downloadSpeed: Int

    /// Current upload speed in bytes per second
    public let uploadSpeed: Int

    /// Number of seeds
    public let seeds: Int

    /// Number of peers
    public let peers: Int

    public init(bufferingProgress: Float = 0, totalProgress: Float = 0, downloadSpeed: Int = 0, uploadSpeed: Int = 0, seeds: Int = 0, peers: Int = 0) {
        self.bufferingProgress = bufferingProgress
        self.totalProgress = totalProgress
        self.downloadSpeed = downloadSpeed
        self.uploadSpeed = uploadSpeed
        self.seeds = seeds
        self.peers = peers
    }
}

/// Download status for torrent downloads
public enum TorrentDownloadStatus: Int, Sendable {
    case paused = 1
    case downloading
    case finished
    case failed
    case processing
}

/// Notification posted when torrent status changes
public extension Notification.Name {
    static let torrentStatusDidChange = Notification.Name("com.popcorntimetv.popcorntorrent.status.change")
}
