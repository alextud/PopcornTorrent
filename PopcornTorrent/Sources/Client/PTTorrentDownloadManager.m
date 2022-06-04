

#import "PTTorrentDownloadManager.h"
#import "PTTorrentDownload.h"
#import <objc/runtime.h>
#if TARGET_OS_IOS
#import <UIKit/UIApplication.h>
#endif
#import "PTTorrentDownloadManagerListener.h"

@interface PTTorrentDownloadManager () <PTTorrentDownloadManagerListener>

@property (strong, nonatomic, nonnull) NSHashTable<id<PTTorrentDownloadManagerListener>> *listeners;

@end

@implementation PTTorrentDownloadManager {
    NSMutableArray<PTTorrentDownload *> *_activeDownloads;
    NSMutableArray<PTTorrentDownload *> *_completedDownloads;
}

+ (instancetype)sharedManager {
    static dispatch_once_t onceToken;
    static PTTorrentDownloadManager *sharedManager;
    dispatch_once(&onceToken, ^{
        sharedManager = [[PTTorrentDownloadManager alloc] init];
    });
    return sharedManager;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _listeners = [NSHashTable weakObjectsHashTable];
        _activeDownloads = [NSMutableArray array];
        _completedDownloads = [NSMutableArray array];
      
#if TARGET_OS_IOS
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidEnterBackground)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationWillEnterForeground)
                                                     name:UIApplicationWillEnterForegroundNotification
                                                   object:nil];
#endif
        
        NSString *path = [PTTorrentDownload downloadDirectory];
        
        if (!path) return self;
        
        NSArray<NSURL *> *URLs = [self fileURLsInDirectory:[NSURL fileURLWithPath:path]];
        
        for (NSURL *fileURL in URLs) {
            if (![[fileURL pathExtension] isEqualToString: @"plist"]) continue;
            PTTorrentDownload *download = [[PTTorrentDownload alloc] initFromPlist:[fileURL path]];
            if (!download) continue;
            download.downloadStatus == PTTorrentDownloadStatusFinished ? [_completedDownloads addObject:download] : [_activeDownloads addObject:download];
            download.delegate = self;
        }
    }
    return self;
}

- (NSArray<NSURL *>*)fileURLsInDirectory:(NSURL *)URL {
    NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtURL:URL includingPropertiesForKeys:@[NSURLIsDirectoryKey] options:NSDirectoryEnumerationSkipsHiddenFiles errorHandler:^BOOL(NSURL *url, NSError *error) { return YES; }];
    
    NSMutableArray<NSURL *> *mutableFileURLs = [NSMutableArray array];
    
    for (NSURL *fileURL in enumerator) {
        NSNumber *isDirectory;
        [fileURL getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil];
        
        if (![isDirectory boolValue]) {
            [mutableFileURLs addObject:fileURL];
        }
    }
    
    return mutableFileURLs;
}

- (void)applicationDidEnterBackground {
#if TARGET_OS_IOS
    __block UIBackgroundTaskIdentifier backgroundTaskIdentifier = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        
        [[UIApplication sharedApplication] endBackgroundTask:backgroundTaskIdentifier];

        backgroundTaskIdentifier = UIBackgroundTaskInvalid;
    }];
#endif
    
    __weak __typeof__(self) weakSelf = self;
    
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
    dispatch_async(queue, ^{
        
        for (PTTorrentDownload *download in weakSelf.activeDownloads) {
            [download pause];
            [download save];
        }
        
        for (PTTorrentDownload *download in weakSelf.completedDownloads) {
            [download save];
        }
#if TARGET_OS_IOS
        [[UIApplication sharedApplication] endBackgroundTask:backgroundTaskIdentifier];
        
        backgroundTaskIdentifier = UIBackgroundTaskInvalid;
#endif
    });
}

- (void)applicationWillEnterForeground {
    for (PTTorrentDownload *download in _activeDownloads) {
        [download resume];
    }
}

- (void)addListener:(id<PTTorrentDownloadManagerListener>)listener {
    if (![_listeners containsObject:listener]) {
        [_listeners addObject:listener];
    }
}

- (void)removeListener:(id<PTTorrentDownloadManagerListener>)listener {
    [_listeners removeObject:listener];
}

- (PTTorrentDownload *)startDownloadingFromFileOrMagnetLink:(NSString *)filePathOrMagnetLink mediaMetadata:(NSDictionary<NSString *, id> *)mediaMetadata selectFileTDownload:(PTTorrentStreamerSelection)callback {
    PTTorrentDownload *download = [[PTTorrentDownload alloc] initWithMediaMetadata:mediaMetadata downloadStatus:PTTorrentDownloadStatusProcessing];
    download.delegate = self;
    
    [_activeDownloads addObject:download];
    [download startDownloadingFromFileOrMagnetLink:filePathOrMagnetLink selectFileTDownload:callback];
    
    return download;
}

- (NSArray<PTTorrentDownload *> *)activeDownloads {
    return _activeDownloads;
}

- (NSArray<PTTorrentDownload *> *)completedDownloads {
    return _completedDownloads;
}

- (void)stopDownload:(PTTorrentDownload *)download {
    [download stop];
    download.delegate = nil;
}

- (void)resumeDownload:(PTTorrentDownload *)download {
    [download resume];
}

- (void)pauseDownload:(PTTorrentDownload *)download {
    [download pause];
}

- (BOOL)deleteDownload:(PTTorrentDownload *)download {
    [_completedDownloads removeObject:download];
    download.delegate = nil;
    return [download delete];
}

- (BOOL)saveDownload:(PTTorrentDownload *)download {
    return [download save];
}

- (void)playDownload:(PTTorrentDownload *)download withHandler:(PTTorrentStreamerReadyToPlay)handler {
    [download playWithHandler:handler];
}

#pragma mark - PTTorrentDownloadManagerListener

- (void)torrentStatusDidChange:(PTTorrentStatus)torrentStatus forDownload:(PTTorrentDownload *)download {
    for (id<PTTorrentDownloadManagerListener> listener in _listeners) {
        if (listener && [listener respondsToSelector:@selector(torrentStatusDidChange:forDownload:)]) {
            [listener torrentStatusDidChange:download.torrentStatus forDownload:download];
        }
    }
}


- (void)downloadStatusDidChange:(PTTorrentDownloadStatus)downloadStatus forDownload:(PTTorrentDownload *)download {
    if (downloadStatus == PTTorrentDownloadStatusFinished || downloadStatus == PTTorrentDownloadStatusFailed) {
        [_activeDownloads removeObject:download];
    }
    
    if (downloadStatus == PTTorrentDownloadStatusFinished) {
        [_completedDownloads addObject:download];
        [download save];
    }
    
    for (id<PTTorrentDownloadManagerListener> listener in _listeners) {
        if (listener && [listener respondsToSelector:@selector(downloadStatusDidChange:forDownload:)]) {
            [listener downloadStatusDidChange:download.downloadStatus forDownload:download];
        }
    }
}

- (void)downloadDidFail:(PTTorrentDownload *)download withError:(NSError *)error {
    for (id<PTTorrentDownloadManagerListener> listener in _listeners) {
        if (listener && [listener respondsToSelector:@selector(downloadDidFail:withError:)]) {
            [listener downloadDidFail:download withError:error];
        }
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
