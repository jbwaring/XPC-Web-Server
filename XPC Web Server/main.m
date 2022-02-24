//
//  main.m
//  XPC Web Server
//
//  Created by Jean-Baptiste Waring on 2022-01-31.
//

#import <Cocoa/Cocoa.h>

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // Setup code that might create autoreleased objects goes here.
    }
    #if DEBUG
    NSLog(@"XPC Connect Web Server\n(c) Jean-Baptiste Waring 2022");
    #endif
    return NSApplicationMain(argc, argv);
}



/*
 [readUDP] ERROR: Select command error
 [getDREFs] ERROR: Read operation failed.
*/
