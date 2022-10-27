//
//  File.swift
//  
//
//  Created by Alexandru Tudose on 26.10.2022.
//

import XCTest
@testable import PopcornTorrent

class PopcornTorrentTests: XCTestCase {
    
    var completeSeasonMagnetLink = "magnet:?xt=urn:btih:c17d1a8de4254ae098206d245aeb78754d798f9f&amp;dn=House.of.the.Dragon.S01.COMPLETE.720p.HMAX.WEBRip.x264-GalaxyTV&amp;tr=udp%3A%2F%2Fopen.stealth.si%3A80%2Fannounce&amp;tr=udp%3A%2F%2Fexodus.desync.com%3A6969%2Fannounce&amp;tr=udp%3A%2F%2Ftracker.cyberia.is%3A6969%2Fannounce&amp;tr=udp%3A%2F%2Ftracker.opentrackr.org%3A1337%2Fannounce&amp;tr=udp%3A%2F%2Ftracker.torrent.eu.org%3A451%2Fannounce&amp;tr=udp%3A%2F%2Fexplodie.org%3A6969%2Fannounce&amp;tr=udp%3A%2F%2Ftracker.birkenwald.de%3A6969%2Fannounce&amp;tr=udp%3A%2F%2Ftracker.moeking.me%3A6969%2Fannounce&amp;tr=udp%3A%2F%2Fipv4.tracker.harry.lu%3A80%2Fannounce&amp;tr=udp%3A%2F%2F9.rarbg.me%3A2970%2Fannounce"
    
    func test1MultiTorrentStreaming() {
        let expectation = self.expectation(description: "Multiple torrent streaming")
        var count = 3
        let completion = {
            count -= 1
            if count == 0 {
                expectation.fulfill()
            }
        }
        magnetLinkStreaming(magnetLink: completeSeasonMagnetLink, fileIndex: 2, deleteFileAfter: false, completion: completion)
        torrentFileStreaming(deleteFileAfter: true, completion: completion)
        let sameTorrentexpectation =  self.expectation(description:"Same magnet link, second file");
        magnetLinkStreaming(magnetLink: completeSeasonMagnetLink, fileIndex: 3, deleteFileAfter: true, completion: {
            sameTorrentexpectation.fulfill()
            completion()
        })
        
        //Wait 10 minutes
        self.waitForExpectations(timeout: 60.0 * 10, handler: { _ in })
    }
    
    func test2TorrentResuming() {
        let expectation =  self.expectation(description:"Torrent resume");
        magnetLinkStreaming(magnetLink: completeSeasonMagnetLink, fileIndex: 2, deleteFileAfter: true, completion: { expectation.fulfill() })
        // wait for 10 seconds
        self.waitForExpectations(timeout: 60*10, handler: { _ in })
    }
    
    func magnetLinkStreaming(magnetLink: String, fileIndex: Int, deleteFileAfter: Bool, completion: @escaping () -> Void) {
        let expectation = self.expectation(description: "Selective Magnet link streaming")
        print("Selective Magnet link streaming")
        let streamer = PTTorrentStreamer()
        var selectedTorrent: String? = nil
        streamer.startStreaming(fromMultiTorrentFileOrMagnetLink: magnetLink) { status in
            print("Progress fileIndex - \(fileIndex): ", status.totalProgress)
        } readyToPlay: { videoFileURL, videoUrl in
            print(videoFileURL)
            XCTAssertNotNil(videoFileURL, "No file URL")
            XCTAssertEqual(videoUrl.lastPathComponent, selectedTorrent)
            streamer.cancelStreamingAndDeleteData(deleteFileAfter)
            expectation.fulfill()
            completion()
        } failure: { error in
            XCTFail(error.localizedDescription)
            expectation.fulfill()
            completion()
        } selectFileToStream: { torrentNames, fileSizes in
            XCTAssertNotEqual(torrentNames.count, 0);
            print("Available names are \n", torrentNames.joined(separator: "\n"))
            selectedTorrent = torrentNames[fileIndex]
            return Int32(fileIndex);
        }
    }
    
    func torrentFileStreaming(deleteFileAfter: Bool, completion: @escaping () -> Void) {
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
            completion()
        } failure: { error in
            XCTFail(error.localizedDescription);
            expectation.fulfill()
            completion()
        } selectFileToStream: { torrentNames, fileSizes in
            return 1; // 2 file
        }
    }
}

