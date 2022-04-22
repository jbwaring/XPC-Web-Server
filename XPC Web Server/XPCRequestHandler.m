//
//  XPCRequestHandler.m
//  XPC Web Server
//
//  Created by Jean-Baptiste Waring on 2022-01-31.
//

#import "XPCRequestHandler.h"


#define XPLANE_IP "127.0.0.1"

@implementation XPCRequestHandler

@synthesize xpcSocket;

+ (id) sharedManager {
    static XPCRequestHandler *sharedMyManager = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            sharedMyManager = [[self alloc] init];
        });
        return sharedMyManager;
}
- (id)init {
  if (self = [super init]) {
      xpcSocket = openUDP(XPLANE_IP);
  }
  return self;
}
-(void) handleRequest:(id) message andSocket:(PSWebSocket*)socket {
    NSData *jsonData = [message dataUsingEncoding:NSUTF8StringEncoding];
    NSError *error;
    NSMutableDictionary *data = [NSJSONSerialization JSONObjectWithData:jsonData
                                                       options:NSJSONReadingAllowFragments
                                                         error:&error];
    
//    NSLog(@"handleRequest: %@", [data debugDescription]);
    if([data objectForKey:@"isUsingMultipleDREF"] != nil){
        //Client Requested Multiple DREFS
        [[XPCRequestHandler sharedManager] handleMultipleDREFsRequest:data andSocket:socket];
    }
    if([data objectForKey:@"command"] != nil){
        //Client Requested Multiple DREFS
        if([[data objectForKey:@"command"]  isEqual:@"CONNECT"]){
            [[XPCRequestHandler sharedManager] handleCommandConnect:socket];
        }
        if([[data objectForKey:@"command"]  isEqual:@"GETPOSITION"]){
            [[XPCRequestHandler sharedManager] getPosition:socket];
        }
    }
    if([data objectForKey:@"setDREF"] != nil){
        //Client Requested Multiple DREFS
        [[XPCRequestHandler sharedManager] setDREF:data andSocket:socket];
    }
}
-(void) handleMultipleDREFsRequest:(NSMutableDictionary*)request andSocket:(PSWebSocket*)socket {
    
    NSMutableDictionary *data = [request mutableCopy];
    [data removeObjectForKey:@"isUsingMultipleDREF"];
//    NSLog(@"Looking for %lu DREFS", data.count);
    
    // Get the drefs as char**
    char** drefsAsCString;
    drefsAsCString=(char **)malloc(data.count * sizeof(char *));
    
    { //Minimum Scope for i to be re-used.
        int i = 0;
        for(NSString* key in data){
            drefsAsCString[i]= (char*) malloc( key.length * sizeof(char));
            strcpy(drefsAsCString[i], [key cStringUsingEncoding: NSUTF8StringEncoding]);
            i++;
        }
    }
    
#if DEBUG
//    for(int i = 0; i < data.count; i++){
//        printf("\nRequesting DREFs[%d] = %s", i, drefsAsCString[i]);
//    }
#endif
    
    // Get size[]
    int sizes[data.count];
    
    for(int i = 0 ; i < data.count ; i++){
        sizes[i] = 16;
    }
    
    // Get float*
    float* values[data.count];
    
    for(int i = 0 ; i < data.count ; i++){
        values[i] = (float*) malloc( sizes[i] * sizeof(float));
    }
    
    

    int getDREFResult = getDREFs([[XPCRequestHandler sharedManager] xpcSocket], (const char**)drefsAsCString, values, data.count, sizes);
    
    if(getDREFResult == -2){
//        Reading Error
        [[XPCRequestHandler sharedManager] sendResponseMessage:@{@"error": @"readingERROR", @"errorCODE":@-2} andSocket:socket];
        [[XPCRequestHandler sharedManager] resetSocket];
        return;
    }else if(getDREFResult == -1){
//        Sending Error
        [[XPCRequestHandler sharedManager] sendResponseMessage:@{@"error": @"sendingERROR", @"errorCODE":@-1} andSocket:socket];
        return;
        
    }
    
    
#if DEBUG
//    for( int i = 0 ; i < data.count ; i++){
//        printf("\n Sizes[i] updated to %d ", sizes[i]);
//    }
//    for( int i = 0 ; i < data.count ; i++){
//        printf("\nDREF %s ", drefsAsCString[i]);
//        for( int j = 0 ; j < sizes[i] ; j++) {
//            printf(" %f ", values[i][j]);
//        }
//    }
#endif
    
    // Update MutableDictionnay
    NSMutableDictionary *responseData = [[NSMutableDictionary alloc] init];
    { //Minimum Scope for i to be re-used.
        int j = 0;
        for(NSString* key in data){
            NSMutableArray* valueArray = [[data objectForKey:key] mutableCopy];
            for(int i = 0; i < [valueArray count]; i++){
                int index = (int)[[valueArray objectAtIndex:i] integerValue];
                
                [valueArray setObject:[NSNumber numberWithFloat:values[j][i]] atIndexedSubscript:index];
            }
            [responseData setObject:valueArray forKey:key];
//            NSLog(@"%@", valueArray);
            j++;
        }
    }
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:responseData
                                                       options:NSJSONWritingPrettyPrinted // Pass 0 if you don't care about the readability of the generated string
                                                         error:&error];

    if (! jsonData) {
        NSLog(@"Got an error: %@", error);
    } else {
        NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
//        NSLog(@"\n\n JSON: %@", jsonString);
        [socket send:jsonString];
    }
        
    
}


-(int) testXPlaneConnect {
    
//    XPCSocket sock = openUDP("127.0.0.1");
//    [[XPCRequestHandler sharedManager] setXpcSocket:openUDP("127.0.0.1")];
    //We are using getDREFs() to request a float value, a float array of size 10, and another float.
    const char* drefs[3] = {
        "sim/cockpit2/gauges/indicators/airspeed_kts_pilot", //indicated airspeed
        "sim/cockpit2/fuel/fuel_quantity",    //fuel quantity in each tank, a float array of size 10
        "sim/cockpit2/gauges/indicators/pitch_vacuum_deg_pilot" //pitch reading displayed on attitude indicator
    };

    //make sure to specify the same size as the number of elements you want to store,
    // see: http://stackoverflow.com/questions/10051782/array-overflow-why-does-this-work
    float* values[3];

    //number of datarefs being requested.  NOTE: since unsigned char, must be in range [0,255],
    unsigned char count = 3;
    values[0] = (float*)malloc(1 * sizeof(float)); //see: http://www.cplusplus.com/reference/cstdlib/malloc/
    values[1] = (float*)malloc(10 * sizeof(float)); //allocate a block of memory 10X larger than for a float since 10-element array
    values[2] = (float*)malloc(1 * sizeof(float));

    int sizes[3] = { 1, 10, 1 }; //allocated size of each item in "values"

    if (getDREFs([[XPCRequestHandler sharedManager] xpcSocket], drefs, values, count, sizes) < 0)
    {
        return -1;
    }
    return 0;

}



-(void) handleCommandConnect:(PSWebSocket*)socket {
//    XPCSocket xpcSocket = openUDP("127.0.0.1");

    //We are using getDREFs() to request a float value, a float array of size 10, and another float.
    const char* drefs[3] = {
        "sim/cockpit2/gauges/indicators/airspeed_kts_pilot", //indicated airspeed
        "sim/cockpit2/fuel/fuel_quantity",    //fuel quantity in each tank, a float array of size 10
        "sim/cockpit2/gauges/indicators/pitch_vacuum_deg_pilot" //pitch reading displayed on attitude indicator
    };

    //make sure to specify the same size as the number of elements you want to store,
    // see: http://stackoverflow.com/questions/10051782/array-overflow-why-does-this-work
    float* values[3];

    //number of datarefs being requested.  NOTE: since unsigned char, must be in range [0,255],
    unsigned char count = 3;
    values[0] = (float*)malloc(1 * sizeof(float)); //see: http://www.cplusplus.com/reference/cstdlib/malloc/
    values[1] = (float*)malloc(10 * sizeof(float)); //allocate a block of memory 10X larger than for a float since 10-element array
    values[2] = (float*)malloc(1 * sizeof(float));

    int sizes[3] = { 1, 10, 1 }; //allocated size of each item in "values"

    if (getDREFs([[XPCRequestHandler sharedManager] xpcSocket], drefs, values, count, sizes) < 0)
    {
//        ERROR
        NSDictionary *responseDict = @{@"code":@500,@"message": @"SOCKET-ERROR: Could not Connect to X-Plane"};
        NSError *error;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:responseDict
                                                           options:NSJSONWritingPrettyPrinted // Pass 0 if you don't care about the readability of the generated string
                                                             error:&error];

        if (! jsonData) {
            NSLog(@"Got an error: %@", error);
        } else {
            NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
            [socket send:jsonString];
//            NSLog(@"%@", jsonString);
        }
        return;
    }
    NSDictionary *responseDict = @{@"code":@200,@"message": @"SOCKET: Connected to X-Plane"};
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:responseDict
                                                       options:NSJSONWritingPrettyPrinted // Pass 0 if you don't care about the readability of the generated string
                                                         error:&error];

    if (! jsonData) {
        NSLog(@"Got an error: %@", error);
    } else {
        NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        [socket send:jsonString];
//        NSLog(@"%@", jsonString);
    }
}


-(void) getPosition:(PSWebSocket*)socket {
//    NSLog(@"GET POSITION");
    
//    XPCSocket sock = openUDP("127.0.0.1");
    double posi[7];
    
    
    
    getPOSI([[XPCRequestHandler sharedManager] xpcSocket], posi, 0);
    
    
    char* dref = "sim/flightmodel/position/mag_psi";
    float heading = 0.0F;
    int size = 1;
    
    int getDREFResult = getDREF([[XPCRequestHandler sharedManager] xpcSocket], dref, &heading, &size);
    
    if(getDREFResult == -2){
//        Reading Error
        [[XPCRequestHandler sharedManager] sendResponseMessage:@{@"error": @"readingERROR", @"errorCODE":@-2} andSocket:socket];
        [[XPCRequestHandler sharedManager] resetSocket];
        return;
    }else if(getDREFResult == -1){
//        Sending Error
        [[XPCRequestHandler sharedManager] sendResponseMessage:@{@"error": @"sendingERROR", @"errorCODE":@-1} andSocket:socket];
        return;
        
    }
    NSMutableArray *position = [[NSMutableArray alloc] initWithCapacity:0];
    for( int i = 0; i < 7; i++){
        [position addObject:[NSNumber numberWithDouble:posi[i]]];
    }
    
    NSDictionary *responseDict = @{@"position":position,@"heading":[NSNumber numberWithFloat:heading]};
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:responseDict
                                                       options:NSJSONWritingPrettyPrinted // Pass 0 if you don't care about the readability of the generated string
                                                         error:&error];

    if (! jsonData) {
        NSLog(@"Got an error: %@", error);
    } else {
        NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        [socket send:jsonString];
//        NSLog(@"%@", jsonString);
    }
    
}



- (void) sendResponseMessage:(NSDictionary*)dict andSocket:(PSWebSocket*)socket {
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict
                                                       options:NSJSONWritingPrettyPrinted // Pass 0 if you don't care about the readability of the generated string
                                                         error:&error];

    if (! jsonData) {
        NSLog(@"Got an error: %@", error);
    } else {
        NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        [socket send:jsonString];
        
//        NSLog(@"%@", jsonString);
    }
}
- (void) resetSocket {
    
    closeUDP(self.xpcSocket);
    sleep(2);    
    self.xpcSocket = openUDP(XPLANE_IP);
}

- (void) setDREF:(NSMutableDictionary*)request andSocket:(PSWebSocket*)socket {
    NSLog(@"%@", request);
    
    
    float value = (float)[[request objectForKey:@"value"] boolValue];
    NSLog(@"%f", value);
    if([[request objectForKey:@"dref"] isEqual:@"sim/cockpit/autopilot/vertical_velocity"]){
        value = (float)[[request objectForKey:@"value"] intValue];
        sendDREF([[XPCRequestHandler sharedManager] xpcSocket], (const char*)[[request objectForKey:@"dref"] cStringUsingEncoding:NSUTF8StringEncoding], &value, 1);
    }else if([[request objectForKey:@"dref"] isEqual:@"sim/cockpit/autopilot/altitude"]){
        value = (float)[[request objectForKey:@"value"] intValue];
        sendDREF([[XPCRequestHandler sharedManager] xpcSocket], (const char*)[[request objectForKey:@"dref"] cStringUsingEncoding:NSUTF8StringEncoding], &value, 1);
    }else if([[request objectForKey:@"dref"] isEqual:@"sim/cockpit/autopilot/heading_mag"]){
        value = (float)[[request objectForKey:@"value"] intValue];
        sendDREF([[XPCRequestHandler sharedManager] xpcSocket], (const char*)[[request objectForKey:@"dref"] cStringUsingEncoding:NSUTF8StringEncoding], &value, 1);
    }else if([[request objectForKey:@"dref"] isEqual:@"sim/cockpit/autopilot/airspeed"]){
        value = (float)[[request objectForKey:@"value"] intValue];
        sendDREF([[XPCRequestHandler sharedManager] xpcSocket], (const char*)[[request objectForKey:@"dref"] cStringUsingEncoding:NSUTF8StringEncoding], &value, 1);
    }else if([[request objectForKey:@"dref"] isEqual:@"sim/cockpit/autopilot/autopilot_mode"]){
        value = (float)[[request objectForKey:@"value"] intValue];
        sendDREF([[XPCRequestHandler sharedManager] xpcSocket], (const char*)[[request objectForKey:@"dref"] cStringUsingEncoding:NSUTF8StringEncoding], &value, 1);
    }else if([[request objectForKey:@"dref"] isEqual:@"sim/cockpit/autopilot/autopilot_state"]){
        value = (int)[[request objectForKey:@"value"] intValue];
        sendDREF([[XPCRequestHandler sharedManager] xpcSocket], (const char*)[[request objectForKey:@"dref"] cStringUsingEncoding:NSUTF8StringEncoding], &value, 1);
        return;
    }else{
        sendDREF([[XPCRequestHandler sharedManager] xpcSocket], (const char*)[[request objectForKey:@"dref"] cStringUsingEncoding:NSUTF8StringEncoding], &value, 1);
    }
    
    
    float newValue = 0.0F;
    int size = 1;
    int result = getDREF([[XPCRequestHandler sharedManager] xpcSocket],  (const char*)[[request objectForKey:@"dref"] cStringUsingEncoding:NSUTF8StringEncoding], &value, &size);
    NSLog(@"New Value %f", value);
    [[XPCRequestHandler sharedManager] sendResponseMessage:@{@"dref": [request objectForKey:@"dref"], @"actualValue": [NSNumber numberWithFloat:value]} andSocket:socket];
    return;
    if(result == -2){
//        Reading Error
        [[XPCRequestHandler sharedManager] sendResponseMessage:@{@"error": @"readingERROR", @"errorCODE":@-2} andSocket:socket];
        [[XPCRequestHandler sharedManager] resetSocket];
        return;
    }
    
    if(result == -1){
//        Sending Error
        [[XPCRequestHandler sharedManager] sendResponseMessage:@{@"error": @"sendingERROR", @"errorCODE":@-1} andSocket:socket];
        return;

    }
//    newValue = 1; //Use this to create errors
    NSLog(@"New Value:%f, Value:%f", newValue, value);
    if(result > -1){
        if(value != newValue)
        {
            //Send Error and actual state
            NSLog(@"Send Error");
            [[XPCRequestHandler sharedManager] sendResponseMessage:@{@"error": @"values do not match", @"dref": [request objectForKey:@"dref"], @"actualValue": [NSNumber numberWithFloat:newValue]} andSocket:socket];
            return;
        }
    }
    
}



@end
