//
//  Header.h
//  
//
//  Created by Alexandru Tudose on 21.09.2022.
//
#import <Foundation/Foundation.h>
#import "PTTorrentStreamer.h"
#import <libtorrent/torrent.hpp>

@interface PTTorrentsSession: NSObject

@property (nonatomic, strong) NSMutableDictionary<NSString *, PTTorrentStreamer *> *streamers; // hash Id as key

+ (instancetype)sharedSession;

- (libtorrent::torrent_handle)addTorrent:(PTTorrentStreamer *)torrentStreamer params:(libtorrent::add_torrent_params)torrentParams error:(NSError **)error;
- (void)removeTorrent:(PTTorrentStreamer *)torrentStreamer;

@end

