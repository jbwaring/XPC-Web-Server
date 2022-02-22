//
//  AppDelegate.m
//  XPC Web Server
//
//  Created by Jean-Baptiste Waring on 2022-01-31.
//

#import "AppDelegate.h"
#import "XPCRequestHandler.h"

@implementation AppDelegate


- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    NSString *serverIP = @"127.0.0.1";
    NSUInteger serverPort = 9001;
    _server = [PSWebSocketServer serverWithHost:serverIP port:serverPort];
    _server.delegate = self;
    [_server start];
    
    if([XPCRequestHandler testXPlaneConnect] < 0){
        // deal with error
        NSNotification* notifyXPlaneConnectionError = [[NSNotification alloc] initWithName:@"XPConnectError" object:NULL userInfo:NULL];
        [[NSNotificationCenter defaultCenter] postNotification:notifyXPlaneConnectionError];
    } else {
        
        NSArray *serverInfo = @[serverIP, [NSString stringWithFormat:@"%ld", serverPort] ];
        
        NSNotification* notifyXPlaneConnectionOK = [[NSNotification alloc] initWithName:@"XPConnectOK" object:serverInfo userInfo:NULL];
        
        [[NSNotificationCenter defaultCenter] postNotification:notifyXPlaneConnectionOK];
    }
}

#pragma mark - PSWebSocketServerDelegate

- (void)serverDidStart:(PSWebSocketServer *)server {
    NSLog(@"Server did start…");
}
- (void)serverDidStop:(PSWebSocketServer *)server {
    NSLog(@"Server did stop…");
}
- (BOOL)server:(PSWebSocketServer *)server acceptWebSocketWithRequest:(NSURLRequest *)request {
    NSLog(@"Server should accept request: %@", request);
    return YES;
}
- (void)server:(PSWebSocketServer *)server webSocket:(PSWebSocket *)webSocket didReceiveMessage:(id)message {
    
    [XPCRequestHandler handleRequest:message andSocket:webSocket];
    
}
- (void)server:(PSWebSocketServer *)server webSocketDidOpen:(PSWebSocket *)webSocket {
    NSLog(@"Server websocket did open");
}
- (void)server:(PSWebSocketServer *)server webSocket:(PSWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean {
    NSLog(@"Server websocket did close with code: %@, reason: %@, wasClean: %@", @(code), reason, @(wasClean));
}
- (void)server:(PSWebSocketServer *)server webSocket:(PSWebSocket *)webSocket didFailWithError:(NSError *)error {
    NSLog(@"Server websocket did fail with error: %@", error);
}

- (void)server:(PSWebSocketServer *)server didFailWithError:(NSError *)error {
    NSLog(@"%@", [error debugDescription]);
}

@end
