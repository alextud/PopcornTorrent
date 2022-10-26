

#import <XCTest/XCTest.h>
#import <PopcornTorrent.h>

@interface PopcornTorrentTests : XCTestCase

@end

@implementation PopcornTorrentTests

- (void)testMultiTorrentStreaming {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Multiple torrent streaming"];
    [self magnetLinkStreaming:expectation deleteFileAfter:NO];
    [self selectiveMagnetLinkStreaming:expectation deleteFileAfter:YES];
    // Wait 10 minutes
    [self waitForExpectationsWithTimeout:60.0 * 10 handler:nil];
}


- (void)testTorrentResuming {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Torrent resume"];
    [self magnetLinkStreaming:expectation deleteFileAfter:YES];
    // Wait 5 minutes
    [self waitForExpectationsWithTimeout:60.0 * 5 handler:nil];
}

- (void)magnetLinkStreaming:(XCTestExpectation *)expectation deleteFileAfter:(BOOL)deleteFileAfter {
    NSLog(@"Magnet link streaming");
    PTTorrentStreamer *streamer = [[PTTorrentStreamer alloc] init];
    [streamer startStreamingFromMultiTorrentFileOrMagnetLink:@"magnet:?xt=urn:btih:0F29E13E18C63B6066EE7DA89D6181F3ABBE9D97&amp;dn=Top+Gun+%3A+Maverick+%282022%29+1080p+HDCAM+x264+AAC+-+QRips&amp;tr=udp%3A%2F%2Ftracker.opentrackr.org%3A1337%2Fannounce&amp;tr=udp%3A%2F%2Fexodus.desync.com%3A6969%2Fannounce&amp;tr=udp%3A%2F%2F9.rarbg.me%3A2970%2Fannounce&amp;tr=udp%3A%2F%2Ftracker.opentrackr.org%3A1337%2Fannounce&amp;tr=udp%3A%2F%2Ftracker.tiny-vps.com%3A6969%2Fannounce&amp;tr=udp%3A%2F%2Ftracker.internetwarriors.net%3A1337%2Fannounce&amp;tr=udp%3A%2F%2Fopentor.org%3A2710%2Fannounce&amp;tr=udp%3A%2F%2Ftracker.torrent.eu.org%3A451%2Fannounce&amp;tr=udp%3A%2F%2Fexplodie.org%3A6969%2Fannounce&amp;tr=udp%3A%2F%2Ftracker.moeking.me%3A6969%2Fannounce&amp;tr=udp%3A%2F%2Ftracker.cyberia.is%3A6969%2Fannounce&amp;tr=udp%3A%2F%2F9.rarbg.me%3A2980%2Fannounce&amp;tr=udp%3A%2F%2F9.rarbg.to%3A2940%2Fannounce&amp;tr=udp%3A%2F%2Ftracker.uw0.xyz%3A6969%2Fannounce&amp;tr=udp%3A%2F%2Ftracker.opentrackr.org%3A1337%2Fannounce&amp;tr=http%3A%2F%2Ftracker.openbittorrent.com%3A80%2Fannounce&amp;tr=udp%3A%2F%2Fopentracker.i2p.rocks%3A6969%2Fannounce&amp;tr=udp%3A%2F%2Ftracker.internetwarriors.net%3A1337%2Fannounce&amp;tr=udp%3A%2F%2Ftracker.leechers-paradise.org%3A6969%2Fannounce&amp;tr=udp%3A%2F%2Fcoppersurfer.tk%3A6969%2Fannounce&amp;tr=udp%3A%2F%2Ftracker.zer0day.to%3A1337%2Fannounce" progress:^(PTTorrentStatus status) {
        NSLog(@"Progress: %f",status.totalProgress);
    } readyToPlay:^(NSURL *videoFileURL, NSURL* video) {
        NSLog(@"%@", videoFileURL);
        XCTAssertNotNil(videoFileURL, @"No file URL");
        [streamer cancelStreamingAndDeleteData:deleteFileAfter];
        [expectation fulfill];
    } failure:^(NSError *error) {
        XCTFail(@"%@", error.localizedDescription);
        [expectation fulfill];
    } selectFileToStream:^int(NSArray<NSString*> *torrentNames, NSArray<NSString*> *fileSizes) {
        return 0; // first file
    }];
}

- (void)selectiveMagnetLinkStreaming:(XCTestExpectation *)expectation deleteFileAfter:(BOOL)deleteFileAfter {
    NSLog(@"Selective Magnet link streaming");
    __block NSString *selectedTorrent;
    PTTorrentStreamer *streamer = [[PTTorrentStreamer alloc] init];
    [streamer startStreamingFromMultiTorrentFileOrMagnetLink:@"magnet:?xt=urn:btih:D4161A18932C75F598853910C581ECCFA2A43929&dn=La+Casa+De+Papel+AKA+Money+Heist+%282019%29+Season+03+Complete+720p+WEB-DL+x264+AAC+ESub+%5BEnglish+DD5.1%5D+3.3GB+%5BCraZzyBoY%5D&tr=udp%3A%2F%2Ftracker.coppersurfer.tk%3A6969%2Fannounce&tr=udp%3A%2F%2Ftracker.open-internet.nl%3A6969%2Fannounce&tr=udp%3A%2F%2Ftracker.leechers-paradise.org%3A6969%2Fannounce&tr=udp%3A%2F%2Ftracker.opentrackr.org%3A1337%2Fannounce&tr=udp%3A%2F%2Ftracker.internetwarriors.net%3A1337%2Fannounce&tr=udp%3A%2F%2F9.rarbg.me%3A2710%2Fannounce&tr=udp%3A%2F%2F9.rarbg.to%3A2710%2Fannounce&tr=udp%3A%2F%2Ftracker.openbittorrent.com%3A80%2Fannounce&tr=http%3A%2F%2Ftracker3.itzmx.com%3A6961%2Fannounce&tr=http%3A%2F%2Ftracker1.itzmx.com%3A8080%2Fannounce&tr=udp%3A%2F%2Ftracker.zer0day.to%3A1337%2Fannounce&tr=udp%3A%2F%2Ftracker.leechers-paradise.org%3A6969%2Fannounce&tr=udp%3A%2F%2Fcoppersurfer.tk%3A6969%2Fannounce" progress:^(PTTorrentStatus status) {
        NSLog(@"Progress: %f",status.totalProgress);
    } readyToPlay:^(NSURL *videoFileURL, NSURL* video) {
        NSLog(@"%@", videoFileURL);
        XCTAssertNotNil(videoFileURL, @"No file URL");
        XCTAssertEqualObjects(video.lastPathComponent, selectedTorrent);
        [streamer cancelStreamingAndDeleteData:deleteFileAfter];
        [expectation fulfill];
    } failure:^(NSError *error) {
        XCTFail(@"%@", error.localizedDescription);
        [expectation fulfill];
    }
    selectFileToStream:^int(NSArray<NSString*> *torrentNames, NSArray<NSString*> *fileSizes) {
        NSString* torrents = [[NSString alloc] init];
        for (NSString* name in torrentNames)torrents = [torrents stringByAppendingFormat:@"%@\n",name];
        XCTAssertNotEqual(torrents, @"");
        NSLog(@"Available names are \n%@",torrents);
        selectedTorrent = [torrentNames objectAtIndex:2];
        return 2;
    }];
}

-(void)testTorrentFileStreaming {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Torrent file streaming"];
    
    NSString *filePath = [[[NSBundle bundleForClass:[self class]] resourcePath] stringByAppendingString:@"/PopcornTorrent_PopcornTorrent-Tests.bundle/big-buck-bunny.torrent"];
    NSLog(@"torrent file: %@", filePath);
    PTTorrentStreamer *streamer = [[PTTorrentStreamer alloc] init];
    [streamer startStreamingFromMultiTorrentFileOrMagnetLink:filePath progress:^(PTTorrentStatus status) {
        NSLog(@"Progress: %f", status.totalProgress);
    } readyToPlay:^(NSURL *videoFileURL, NSURL* video) {
        NSLog(@"%@", videoFileURL);
        [streamer cancelStreamingAndDeleteData:YES];
        XCTAssertNotNil(videoFileURL, @"No file URL");
        [expectation fulfill];
        
    } failure:^(NSError *error) {
        XCTFail(@"%@", error.localizedDescription);
        [expectation fulfill];
    } selectFileToStream:^int(NSArray<NSString*> *torrentNames, NSArray<NSString*> *fileSizes) {
        return 1; // 2 file
    }];
    // Wait 5 minutes
    [self waitForExpectationsWithTimeout:60.0 * 5 handler:nil];
}

@end
