//
//  AppDelegate.h
//  XPC Web Server
//
//  Created by Jean-Baptiste Waring on 2022-01-31.
//

#import <Cocoa/Cocoa.h>
#import <PSWebSocketServer.h>

@interface AppDelegate : PSWebSocketServer <PSWebSocketServerDelegate>

@property (nonatomic, strong) PSWebSocketServer *server;

@end

