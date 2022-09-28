//
//  Header.h
//  
//
//  Created by Alexandru Tudose on 21.09.2022.
//
#import <Foundation/Foundation.h>

@interface PTTorrentsSession: NSObject

/// instantiate shared session used for torrents
/// call early in app life cycle for faster DHT boostrap
+ (instancetype)sharedSession;

@end

