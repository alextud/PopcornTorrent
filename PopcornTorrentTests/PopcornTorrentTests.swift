//
//  File.swift
//  
//
//  Created by Alexandru Tudose on 26.10.2022.
//

import XCTest
@testable import PopcornTorrent

class PopcornTorrentTests: XCTestCase {
    
    func testMultiTorrentStreaming() {
        let expectation = self.expectation(description: "Multiple torrent streaming")
        var count = 2
        let completion = {
            count -= 1
            if count == 0 {
                expectation.fulfill()
            }
        }
        magnetLinkStreaming(deleteFileAfter: false, completion: completion)
        selectiveMagnetLinkStreaming(deleteFileAfter: true, completion: completion)
        //Wait 10 minutes
        self.waitForExpectations(timeout: 60.0 * 10, handler: { _ in })
    }
    
    func testTorrentResuming() {
        let expectation =  self.expectation(description:"Torrent resume");
        magnetLinkStreaming(deleteFileAfter: true, completion: { expectation.fulfill() })
        // wait for 10 seconds
        self.waitForExpectations(timeout: 10, handler: { _ in })
    }
    
    func magnetLinkStreaming(deleteFileAfter: Bool, completion: @escaping () -> Void) {
        print("Selective Magnet link streaming")
        let streamer = PTTorrentStreamer()
        streamer.startStreaming(fromMultiTorrentFileOrMagnetLink: "magnet:?xt=urn:btih:0F29E13E18C63B6066EE7DA89D6181F3ABBE9D97&amp;dn=Top+Gun+%3A+Maverick+%282022%29+1080p+HDCAM+x264+AAC+-+QRips&amp;tr=udp%3A%2F%2Ftracker.opentrackr.org%3A1337%2Fannounce&amp;tr=udp%3A%2F%2Fexodus.desync.com%3A6969%2Fannounce&amp;tr=udp%3A%2F%2F9.rarbg.me%3A2970%2Fannounce&amp;tr=udp%3A%2F%2Ftracker.opentrackr.org%3A1337%2Fannounce&amp;tr=udp%3A%2F%2Ftracker.tiny-vps.com%3A6969%2Fannounce&amp;tr=udp%3A%2F%2Ftracker.internetwarriors.net%3A1337%2Fannounce&amp;tr=udp%3A%2F%2Fopentor.org%3A2710%2Fannounce&amp;tr=udp%3A%2F%2Ftracker.torrent.eu.org%3A451%2Fannounce&amp;tr=udp%3A%2F%2Fexplodie.org%3A6969%2Fannounce&amp;tr=udp%3A%2F%2Ftracker.moeking.me%3A6969%2Fannounce&amp;tr=udp%3A%2F%2Ftracker.cyberia.is%3A6969%2Fannounce&amp;tr=udp%3A%2F%2F9.rarbg.me%3A2980%2Fannounce&amp;tr=udp%3A%2F%2F9.rarbg.to%3A2940%2Fannounce&amp;tr=udp%3A%2F%2Ftracker.uw0.xyz%3A6969%2Fannounce&amp;tr=udp%3A%2F%2Ftracker.opentrackr.org%3A1337%2Fannounce&amp;tr=http%3A%2F%2Ftracker.openbittorrent.com%3A80%2Fannounce&amp;tr=udp%3A%2F%2Fopentracker.i2p.rocks%3A6969%2Fannounce&amp;tr=udp%3A%2F%2Ftracker.internetwarriors.net%3A1337%2Fannounce&amp;tr=udp%3A%2F%2Ftracker.leechers-paradise.org%3A6969%2Fannounce&amp;tr=udp%3A%2F%2Fcoppersurfer.tk%3A6969%2Fannounce&amp;tr=udp%3A%2F%2Ftracker.zer0day.to%3A1337%2Fannounce") { status in
            print("Progress: ", status.totalProgress)
        } readyToPlay: { videoFileURL, videoUrl in
            print(videoFileURL)
            XCTAssertNotNil(videoFileURL, "No file URL");
            streamer.cancelStreamingAndDeleteData(deleteFileAfter)
            completion()
        } failure: { error in
            XCTFail(error.localizedDescription)
            completion()
        } selectFileToStream: { torrentNames, fileSizes in
            return 0; // first file
        }
    }
    
    func selectiveMagnetLinkStreaming(deleteFileAfter: Bool, completion: @escaping () -> Void) {
        print("Selective Magnet link streaming")
        let streamer = PTTorrentStreamer()
        var selectedTorrent: String? = nil
        streamer.startStreaming(fromMultiTorrentFileOrMagnetLink: "magnet:?xt=urn:btih:D4161A18932C75F598853910C581ECCFA2A43929&dn=La+Casa+De+Papel+AKA+Money+Heist+%282019%29+Season+03+Complete+720p+WEB-DL+x264+AAC+ESub+%5BEnglish+DD5.1%5D+3.3GB+%5BCraZzyBoY%5D&tr=udp%3A%2F%2Ftracker.coppersurfer.tk%3A6969%2Fannounce&tr=udp%3A%2F%2Ftracker.open-internet.nl%3A6969%2Fannounce&tr=udp%3A%2F%2Ftracker.leechers-paradise.org%3A6969%2Fannounce&tr=udp%3A%2F%2Ftracker.opentrackr.org%3A1337%2Fannounce&tr=udp%3A%2F%2Ftracker.internetwarriors.net%3A1337%2Fannounce&tr=udp%3A%2F%2F9.rarbg.me%3A2710%2Fannounce&tr=udp%3A%2F%2F9.rarbg.to%3A2710%2Fannounce&tr=udp%3A%2F%2Ftracker.openbittorrent.com%3A80%2Fannounce&tr=http%3A%2F%2Ftracker3.itzmx.com%3A6961%2Fannounce&tr=http%3A%2F%2Ftracker1.itzmx.com%3A8080%2Fannounce&tr=udp%3A%2F%2Ftracker.zer0day.to%3A1337%2Fannounce&tr=udp%3A%2F%2Ftracker.leechers-paradise.org%3A6969%2Fannounce&tr=udp%3A%2F%2Fcoppersurfer.tk%3A6969%2Fannounce") { status in
            print("Progress: ", status.totalProgress)
        } readyToPlay: { videoFileURL, videoUrl in
            print(videoFileURL)
            XCTAssertNotNil(videoFileURL, "No file URL")
            XCTAssertEqual(videoUrl.lastPathComponent, selectedTorrent)
            streamer.cancelStreamingAndDeleteData(deleteFileAfter)
            completion()
        } failure: { error in
            XCTFail(error.localizedDescription)
            completion()
        } selectFileToStream: { torrentNames, fileSizes in
            XCTAssertNotEqual(torrentNames.count, 0);
            print("Available names are \n", torrentNames.joined(separator: "\n"))
            selectedTorrent = torrentNames[2]
            return 2; // first file
        }
    }
    
    func testTorrentFileStreaming() {
        let expectation = self.expectation(description: "Torrent file streaming")
        
        let filePath = Bundle.module.path(forResource: "big-buck-bunny", ofType: "torrent")
        print("torrent file: ", filePath!);
        
        let streamer = PTTorrentStreamer()
        streamer.startStreaming(fromMultiTorrentFileOrMagnetLink: filePath!) { status in
            print("Progress: ", status.totalProgress)
        } readyToPlay: { videoFileURL, videoUrl in
            print(videoFileURL)
            streamer.cancelStreamingAndDeleteData(true)
            XCTAssertNotNil(videoFileURL, "No file URL")
            expectation.fulfill()
        } failure: { error in
            XCTFail(error.localizedDescription);
            expectation.fulfill()
        } selectFileToStream: { torrentNames, fileSizes in
            return 1; // 2 file
        }
        // Wait 5 minutes
        waitForExpectations(timeout: 60.0 * 5)
    }
}

