//
//  XPCRequestHandler.h
//  XPC Web Server
//
//  Created by Jean-Baptiste Waring on 2022-01-31.
//

#import <Foundation/Foundation.h>
#import <PSWebSocketServer.h>
#import "xplaneConnect.h"

NS_ASSUME_NONNULL_BEGIN

@interface XPCRequestHandler : NSObject

@property (class, atomic) XPCSocket xpcSocket;

+(void) handleRequest:(id) message andSocket:(PSWebSocket*)socket;
+(void) handleMultipleDREFsRequest:(NSMutableDictionary*)request andSocket:(PSWebSocket*)socket;
+(int) testXPlaneConnect;
+(void) handleCommandConnect:(PSWebSocket*)socket;
+(void) getPosition:(PSWebSocket*)socket;
@end

NS_ASSUME_NONNULL_END
