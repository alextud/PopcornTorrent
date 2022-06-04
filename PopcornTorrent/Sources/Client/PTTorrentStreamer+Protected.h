
#import "PTTorrentStreamer.h"
#import <libtorrent/session.hpp>
#import <libtorrent/torrent_info.hpp>
#import <libtorrent/add_torrent_params.hpp>
#import <libtorrent/magnet_uri.hpp>
#import <libtorrent/read_resume_data.hpp>
#import <libtorrent/write_resume_data.hpp>

#import <GCDWebServer.h>

/**
 Variables to be used by `PTTorrentStreamer` subclasses only.
 */
@interface PTTorrentStreamer () {
    @protected
    libtorrent::session *_session;
    PTTorrentStatus _torrentStatus;
    NSString *_fileName;
    long long _requiredSpace;
    long long _totalDownloaded;
    NSString *_savePath;
    std::vector<libtorrent::piece_index_t> required_pieces;
    libtorrent::piece_index_t firstPiece;
    libtorrent::piece_index_t endPiece;
    std::mutex mtx;
    int MIN_PIECES; //they are calculated by divind the 5% of a torrent file size with the size of a torrent piece / selected file in case we load a multi movie torrent
    int selectedFileIndex;
}

@property (nonatomic, strong, nullable) dispatch_queue_t alertsQueue;
@property (nonatomic, getter=isAlertsLoopActive) BOOL alertsLoopActive;
@property (nonatomic, getter=isStreaming) BOOL streaming;
@property (nonatomic, strong, nonnull) NSMutableDictionary *requestedRangeInfo;

@property (nonatomic, copy, nullable) PTTorrentStreamerProgress progressBlock;
@property (nonatomic, copy, nullable) PTTorrentStreamerReadyToPlay readyToPlayBlock;
@property (nonatomic, copy, nullable) PTTorrentStreamerFailure failureBlock;
@property (nonatomic, copy, nullable) PTTorrentStreamerSelection selectionBlock;
@property (nonatomic, strong, nonnull) GCDWebServer *mediaServer;
@property (nonatomic) libtorrent::torrent_status status;
@property (nonatomic) bool isFinished;

- (void)startWebServerAndPlay;

@end
