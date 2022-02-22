//
//  ViewController.m
//  XPC Web Server
//
//  Created by Jean-Baptiste Waring on 2022-01-31.
//

#import "ViewController.h"
#import <Foundation/Foundation.h>

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [[NSNotificationCenter defaultCenter]
         addObserverForName:@"XPConnectError"
         object:nil
         queue:nil
         usingBlock:^(NSNotification *note)
         {
        [self->_ServerStatusLabel setStringValue:@"Could not connect to X-Plane"];
         }];
    [[NSNotificationCenter defaultCenter]
         addObserverForName:@"XPConnectOK"
         object:nil
         queue:nil
         usingBlock:^(NSNotification *note)
         {
        NSString *statusMessage = [[NSString alloc] initWithFormat:@"Server is Connected at : %@:%@", note.object[0], note.object[1]];
        NSMutableAttributedString *statusMessageAsAttributedString = [[NSMutableAttributedString alloc] initWithString:statusMessage];
        [statusMessageAsAttributedString setAlignment:NSTextAlignmentCenter range:NSMakeRange(0, statusMessage.length-1)];
        [self->_ServerStatusLabel setAttributedStringValue:statusMessageAsAttributedString];
         }];
    
    
    // Do any additional setup after loading the view.
}


- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}



@end
