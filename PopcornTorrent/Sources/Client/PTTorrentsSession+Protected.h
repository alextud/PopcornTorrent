//
//  Header.h
//  
//
//  Created by Alexandru Tudose on 27.09.2022.
//

#import "PTTorrentsSession.h"
#import "PTTorrentStreamer.h"
#import <libtorrent/torrent.hpp>

@interface PTTorrentsSession()

- (libtorrent::torrent_handle)addTorrent:(PTTorrentStreamer *)torrentStreamer params:(libtorrent::add_torrent_params)torrentParams error:(NSError **)error;
- (void)removeTorrent:(PTTorrentStreamer *)torrentStreamer;

@end
