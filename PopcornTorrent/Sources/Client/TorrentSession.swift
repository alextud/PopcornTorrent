import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Main torrent session manager - replaces PTTorrentsSession
public class TorrentSession {
    private var session: OpaquePointer?
    private var streamers: [String: TorrentStreamer] = [:]
    private let alertQueue: DispatchQueue
    private var isAlertsLoopActive: Bool = false
    private let lock = NSLock()

    // Singleton instance
    private static var _sharedSession: TorrentSession?
    private static let sessionLock = NSLock()

    public static var shared: TorrentSession {
        sessionLock.lock()
        defer { sessionLock.unlock() }

        if _sharedSession == nil {
            _sharedSession = TorrentSession()

            #if os(tvOS)
            // tvOS workaround for background/foreground transitions
            var lastDate: Date?
            let backgroundDuration: TimeInterval = 5 * 60 // 5 minutes

            NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil) { _ in
                lastDate = Date()
            }

            NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: nil) { _ in
                if let date = lastDate, -date.timeIntervalSinceNow > backgroundDuration {
                    _sharedSession = TorrentSession()
                }
                lastDate = nil
            }
            #endif
        }

        return _sharedSession!
    }

    public init() {
        self.alertQueue = DispatchQueue(label: "com.popcorntimetv.popcorntorrent.alerts", attributes: [], autoreleaseFrequency: .workItem)
        setupSession()
        setupAlertLoop()
    }

    deinit {
        isAlertsLoopActive = false
        if let session = session {
            lt_session_destroy(session)
        }
    }

    private func setupSession() {
        // Create default settings
        guard let pack = lt_settings_pack_create_default() else {
            print("Failed to create settings pack")
            return
        }
        defer { lt_settings_pack_destroy(pack) }

        // Configure DHT bootstrap nodes
        let dhtNodes = "router.bittorrent.com:6881,router.utorrent.com:6881,router.bitcomet.com:6881,dht.transmissionbt.com:6881,dht.aelitis.com:6881"
        lt_settings_pack_set_str(pack, Int32(lt_settings_dht_bootstrap_nodes.rawValue), dhtNodes)

        // Configure listen interfaces
        lt_settings_pack_set_str(pack, Int32(lt_settings_listen_interfaces.rawValue), "0.0.0.0:6881,[::]:6881")
        lt_settings_pack_set_int(pack, Int32(lt_settings_max_retry_port_bind.rawValue), 8)

        // Configure alert mask
        let alertMask = 0x1 | 0x200 | 0x800 // status_notification | piece_progress_notification | storage_notification
        lt_settings_pack_set_int(pack, Int32(lt_settings_alert_mask.rawValue), Int32(alertMask))

        // Configure other settings
        lt_settings_pack_set_bool(pack, Int32(lt_settings_listen_system_port_fallback.rawValue), false)
        lt_settings_pack_set_bool(pack, Int32(lt_settings_suggest_read_cache.rawValue), false)
        lt_settings_pack_set_bool(pack, Int32(lt_settings_enable_upnp.rawValue), false)
        lt_settings_pack_set_bool(pack, Int32(lt_settings_enable_natpmp.rawValue), false)
        lt_settings_pack_set_bool(pack, Int32(lt_settings_upnp_ignore_nonrouters.rawValue), true)
        lt_settings_pack_set_int(pack, Int32(lt_settings_file_pool_size.rawValue), 2)

        // Create session
        var error = lt_error_t(code: 0, message: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
        self.session = lt_session_create(pack, &error)

        if error.code != 0 {
            let errorMsg = withUnsafeBytes(of: error.message) { ptr -> String in
                let buffer = ptr.bindMemory(to: CChar.self)
                return String(cString: buffer.baseAddress!)
            }
            print("Failed to create session: \(errorMsg)")
            return
        }

        // Add extensions
        if let session = self.session {
            lt_session_add_extension_smart_ban(session)
            lt_session_add_extension_ut_metadata(session)
        }
    }

    private func setupAlertLoop() {
        isAlertsLoopActive = true
        alertQueue.async { [weak self] in
            self?.alertsLoop()
        }
    }

    private func alertsLoop() {
        let maxAlerts = 100
        var alerts = [lt_alert_info_t](repeating: lt_alert_info_t(
            type: lt_alert_none,
            handle: nil,
            piece_index: 0,
            message: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
            params: nil
        ), count: maxAlerts)

        while isAlertsLoopActive {
            guard let session = self.session else { break }

            // Wait for alerts (500ms timeout)
            let hasAlert = lt_session_wait_for_alert(session, 500)
            if !isAlertsLoopActive { break }

            if hasAlert {
                let count = lt_session_pop_alerts(session, &alerts, Int32(maxAlerts))

                for i in 0..<Int(count) {
                    let alert = alerts[i]
                    handleAlert(alert)

                    // Clean up alert handle
                    if let handle = alert.handle {
                        // Note: We don't delete the handle here as it's managed by the session
                    }

                    // Clean up params if present
                    if let params = alert.params {
                        lt_add_torrent_params_destroy(params)
                    }
                }
            }
        }
    }

    private func handleAlert(_ alert: lt_alert_info_t) {
        guard let handle = alert.handle else { return }

        switch alert.type {
        case lt_alert_metadata_received:
            metadataReceivedAlert(handle)
        case lt_alert_piece_finished:
            pieceFinishedAlert(handle, pieceIndex: alert.piece_index)
        case lt_alert_torrent_finished:
            torrentFinishedAlert(handle)
        case lt_alert_save_resume_data:
            if let params = alert.params {
                saveResumeDataAlert(handle, params: params)
            }
        case lt_alert_file_error:
            let message = withUnsafeBytes(of: alert.message) { ptr -> String in
                let buffer = ptr.bindMemory(to: CChar.self)
                return String(cString: buffer.baseAddress!)
            }
            fileErrorAlert(handle, message: message)
        default:
            break
        }
    }

    private func hashID(for handle: OpaquePointer) -> String {
        var buffer = [CChar](repeating: 0, count: 41)  // 40 hex chars + null terminator
        lt_torrent_handle_get_info_hash_hex(handle, &buffer, 41)
        return String(cString: buffer)
    }

    func torrentStreamer(for handle: OpaquePointer) -> TorrentStreamer? {
        let hashID = self.hashID(for: handle)
        lock.lock()
        defer { lock.unlock() }
        return streamers[hashID]
    }

    private func metadataReceivedAlert(_ handle: OpaquePointer) {
        torrentStreamer(for: handle)?.metadataReceivedAlert(handle)
    }

    private func pieceFinishedAlert(_ handle: OpaquePointer, pieceIndex: Int32) {
        torrentStreamer(for: handle)?.pieceFinishedAlert(handle, pieceIndex: pieceIndex)
    }

    private func torrentFinishedAlert(_ handle: OpaquePointer) {
        let streamer = torrentStreamer(for: handle)
        streamer?.torrentFinishedAlert(handle)
        if let streamer = streamer {
            removeTorrent(streamer)
        }
    }

    private func saveResumeDataAlert(_ handle: OpaquePointer, params: OpaquePointer) {
        let status = lt_torrent_handle_status(handle)
        var buffer = [CChar](repeating: 0, count: 512)

        // Get save path from status (simplified - would need proper implementation)
        let directory = NSTemporaryDirectory() + "/Downloads/resumeData.fastresume"

        var error = lt_error_t(code: 0, message: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
        lt_save_resume_data_to_file(params, directory, &error)
    }

    private func fileErrorAlert(_ handle: OpaquePointer, message: String) {
        let error = NSError(domain: "com.popcorntimetv.popcorntorrent.error", code: -4, userInfo: [NSLocalizedDescriptionKey: message])
        torrentStreamer(for: handle)?.handleTorrentError(error)
    }

    func addTorrent(_ streamer: TorrentStreamer, params: OpaquePointer) throws -> OpaquePointer {
        guard let session = self.session else {
            throw NSError(domain: "com.popcorntimetv.popcorntorrent.error", code: -1, userInfo: [NSLocalizedDescriptionKey: "Session not initialized"])
        }

        var error = lt_error_t(code: 0, message: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
        guard let handle = lt_session_add_torrent(session, params, &error) else {
            let errorMsg = withUnsafeBytes(of: error.message) { ptr -> String in
                let buffer = ptr.bindMemory(to: CChar.self)
                return String(cString: buffer.baseAddress!)
            }
            throw NSError(domain: "com.popcorntimetv.popcorntorrent.error", code: Int(error.code), userInfo: [NSLocalizedDescriptionKey: errorMsg])
        }

        // Configure torrent
        lt_torrent_handle_set_sequential_download(handle, true)
        lt_torrent_handle_set_max_connections(handle, 60)
        lt_torrent_handle_set_max_uploads(handle, 10)

        let hashID = self.hashID(for: handle)

        lock.lock()
        defer { lock.unlock() }

        if streamers[hashID] != nil {
            throw NSError(domain: "com.popcorntimetv.popcorntorrent.error", code: -2, userInfo: [NSLocalizedDescriptionKey: "Torrent already added"])
        }

        streamers[hashID] = streamer

        #if os(iOS)
        DispatchQueue.main.async {
            UIApplication.shared.isNetworkActivityIndicatorVisible = true
        }
        #endif

        return handle
    }

    func removeTorrent(_ streamer: TorrentStreamer) {
        guard let handle = streamer.torrentHandle, lt_torrent_handle_is_valid(handle) else {
            return
        }

        let hashID = self.hashID(for: handle)

        lock.lock()
        defer { lock.unlock() }

        streamers[hashID] = nil

        if lt_torrent_handle_need_save_resume_data(handle) {
            lt_torrent_handle_save_resume_data(handle)
        }
        lt_torrent_handle_flush_cache(handle)
        lt_torrent_handle_pause(handle)

        #if os(iOS)
        if streamers.isEmpty {
            DispatchQueue.main.async {
                UIApplication.shared.isNetworkActivityIndicatorVisible = false
            }
        }
        #endif
    }

    func tryToResume(params: OpaquePointer, atPath path: String) -> Bool {
        let resumePath = (path as NSString).appendingPathComponent("resumeData.fastresume")
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: resumePath)) else {
            return false
        }

        var error = lt_error_t(code: 0, message: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
        let success = data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) -> Bool in
            guard let baseAddress = ptr.baseAddress else { return false }
            return lt_add_torrent_params_load_resume_data(params, baseAddress.assumingMemoryBound(to: UInt8.self), Int64(data.count), &error)
        }

        return success && error.code == 0
    }
}

// Forward declaration - will be implemented in TorrentStreamer.swift
public class TorrentStreamer {
    var torrentHandle: OpaquePointer?

    func metadataReceivedAlert(_ handle: OpaquePointer) {}
    func pieceFinishedAlert(_ handle: OpaquePointer, pieceIndex: Int32) {}
    func torrentFinishedAlert(_ handle: OpaquePointer) {}
    func handleTorrentError(_ error: Error) {}
}
