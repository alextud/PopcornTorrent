//
//  PTtorrentsSession.m
//  
//
//  Created by Alexandru Tudose on 21.09.2022.
//

#import <Foundation/Foundation.h>
#import "PTTorrentsSession.h"
#import "PTTorrentStreamer+Protected.h"
#import <libtorrent/session.hpp>
#import <libtorrent/torrent.hpp>
#import <libtorrent/alert.hpp>
#import <libtorrent/alert_types.hpp>
#import <libtorrent/bencode.hpp>
#import <libtorrent/write_resume_data.hpp>
#include "libtorrent/hex.hpp" // to_hex

using namespace libtorrent;

#define ALERTS_LOOP_WAIT_MILLIS 500

@interface PTTorrentsSession () {
}

@property (nonatomic, strong, nullable) dispatch_queue_t alertsQueue;
@property (nonatomic, getter=isAlertsLoopActive) BOOL alertsLoopActive;

@end

@implementation PTTorrentsSession {
    libtorrent::session *_session;
}

+ (instancetype)sharedSession {
    static dispatch_once_t onceToken;
    static PTTorrentsSession *sharedSession;
    dispatch_once(&onceToken, ^{
        sharedSession = [[PTTorrentsSession alloc] init];
    });
    return sharedSession;
}

- (instancetype)init {
    self.streamers = [@{} mutableCopy];
    [self setupSession];
    [self setupAlertLoop];
    return self;
}

- (void)setupSession {
    _session = new session();
    settings_pack pack = default_settings();
    
    pack.set_str(settings_pack::listen_interfaces, "0.0.0.0:6881,[::]:6881");
    pack.set_int(settings_pack::max_retry_port_bind, 6889 - 6881);
    
    pack.set_int(settings_pack::alert_mask,
                 alert::status_notification |
                 alert::piece_progress_notification |
                 alert::storage_notification
                 //                 alert::all_categories
                 );
    
    pack.set_bool(settings_pack::listen_system_port_fallback, false);
    pack.set_bool(settings_pack::suggest_read_cache, false);
    // libtorrent 1.1 enables UPnP & NAT-PMP by default
    // turn them off before `libt::session` ctor to avoid split second effects
    pack.set_bool(settings_pack::enable_upnp, false);
    pack.set_bool(settings_pack::enable_natpmp, false);
    pack.set_bool(settings_pack::upnp_ignore_nonrouters, true);
    pack.set_int(settings_pack::file_pool_size, 2);
    _session->apply_settings(pack);
}

- (void)setupAlertLoop {
    self.alertsQueue = dispatch_queue_create("com.popcorntimetv.popcorntorrent.alerts", DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL);
    self.alertsLoopActive = YES;
    dispatch_async(self.alertsQueue, ^{
        [self alertsLoop];
    });
}

- (void)alertsLoop {
    @autoreleasepool {
        
        std::vector<alert *> deque;
        time_duration max_wait = milliseconds(ALERTS_LOOP_WAIT_MILLIS);
        
        while ([self isAlertsLoopActive]) {
            const alert *ptr = _session->wait_for_alert(max_wait);
            if (![self isAlertsLoopActive]) {
                break;
            }
            
            try {
                if (ptr != nullptr && _session != nullptr) {
                    _session->pop_alerts(&deque);
                    for (alert* alert : deque) {
                        switch (alert->type()) {
                            case metadata_received_alert::alert_type:
                                [self metadataReceivedAlert:((metadata_received_alert *)alert)->handle];
                                break;
                                
                            case piece_finished_alert::alert_type:
                                [self pieceFinishedAlert:((piece_finished_alert *)alert)->handle forPieceIndex:((piece_finished_alert *)alert)->piece_index];
                                break;
                                // In case the video file is already fully downloaded
                            case torrent_finished_alert::alert_type:
                                [self torrentFinishedAlert:((torrent_finished_alert *)alert)->handle];
                                break;
                            case save_resume_data_alert::alert_type: {
                                [self resumeDataReadyAlertWithData:(save_resume_data_alert *)alert];
                                break;
                            }
                            case file_error_alert::alert_type: {
                                [self fileErrorAlert:(file_error_alert *)alert];
                                break;
                            }
                            default:
                                break;
                        }
                    }
                    deque.clear();
                    deque.shrink_to_fit();
                }
            } catch (const std::exception& e) {
                NSLog(@"%s", e.what());
            }
        }
    }
}

- (NSString *)hashIDForTorrentHandle:(torrent_handle)th {
    NSString *hashId = [NSString stringWithCString:aux::to_hex(th.info_hash()).c_str() encoding:NSUTF8StringEncoding];
    return  hashId;
}

- (void)metadataReceivedAlert:(torrent_handle)th {
    NSString *hashID = [self hashIDForTorrentHandle:th];
    [self.streamers[hashID] metadataReceivedAlert:th];
}

- (void)pieceFinishedAlert:(torrent_handle)th forPieceIndex:(piece_index_t)index {
    NSString *hashID = [self hashIDForTorrentHandle:th];
    [self.streamers[hashID] pieceFinishedAlert:th forPieceIndex:index];
}

- (torrent_handle)addTorrent:(PTTorrentStreamer *)torrentStreamer params:(add_torrent_params)torrentParams error:(NSError **)error {
    error_code ec_1;
    torrent_handle th = _session->add_torrent(torrentParams, ec_1);
    
    if (ec_1) {
        *error = [[NSError alloc] initWithDomain:@"com.popcorntimetv.popcorntorrent.error" code:-1 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithCString:ec_1.message().c_str() encoding:NSUTF8StringEncoding]}];
        return th;
    }
    
    //    th.set_sequential_download(true);
    th.set_flags(libtorrent::torrent_flags::sequential_download);
    th.set_max_connections(60);
    th.set_max_uploads(10);
    
    NSString *hashId = [NSString stringWithCString:aux::to_hex(th.info_hash()).c_str() encoding:NSUTF8StringEncoding];
    self.streamers[hashId] = torrentStreamer;
    
#if TARGET_OS_IOS
    dispatch_async(dispatch_get_main_queue(), ^{
        [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    });
#endif
}

- (void)torrentFinishedAlert:(torrent_handle)th {
    NSString *hashID = [self hashIDForTorrentHandle:th];
    [self.streamers[hashID] torrentFinishedAlert:th];
    [self removeTorrent:self.streamers[hashID]];
    
    if (_session->get_torrents().empty()) {
#if TARGET_OS_IOS
        dispatch_async(dispatch_get_main_queue(), ^{
            [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
        });
#endif
    }
}

- (void)removeTorrent:(PTTorrentStreamer *)torrentStreamer {
    if (!torrentStreamer.torrentHandle.is_valid()) {
        return;
    }
    
    auto torrent = torrentStreamer.torrentHandle;
    NSString *hashId = [NSString stringWithCString:aux::to_hex(torrent.info_hash()).c_str() encoding:NSUTF8StringEncoding];
    if (!self.streamers[hashId]) {
        return;
    }
    
    self.streamers[hashId] = NULL;
    
    torrent.pause();
    if (torrent.need_save_resume_data()) {
        torrent.save_resume_data();
    }
    torrent.flush_cache();
    
    _session->remove_torrent(torrent);
}

- (void)resumeDataReadyAlertWithData:(save_resume_data_alert *)alert {
    torrent_status st = alert->handle.status(torrent_handle::query_save_path
                                             | torrent_handle::query_name);
    NSString *directory =  [NSString stringWithUTF8String:(st.save_path + "/resumeData.fastresume").c_str()];
    NSString *hashID = [self hashIDForTorrentHandle:alert->handle];
    [self.streamers[hashID] resumeDataReadyAlertWithData:alert->params andSaveDirectory:directory];
}

- (void)fileErrorAlert:(file_error_alert *)alert {
    auto torrent = alert->handle;
    
    NSString *description = [NSString stringWithFormat:@"%s", alert->message().c_str()];
    NSError *error = [[NSError alloc] initWithDomain:@"com.popcorntimetv.popcorntorrent.error" code:-4 userInfo:@{NSLocalizedDescriptionKey: description}];
    NSString *hashID = [self hashIDForTorrentHandle:alert->handle];
    [self.streamers[hashID] handleTorrentError:error];
}

@end
