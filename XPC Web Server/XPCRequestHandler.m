//
//  XPCRequestHandler.m
//  XPC Web Server
//
//  Created by Jean-Baptiste Waring on 2022-01-31.
//

#import "XPCRequestHandler.h"


@implementation XPCRequestHandler

@dynamic xpcSocket;

+(void) handleRequest:(id) message andSocket:(PSWebSocket*)socket {
    NSData *jsonData = [message dataUsingEncoding:NSUTF8StringEncoding];
    NSError *error;
    NSMutableDictionary *data = [NSJSONSerialization JSONObjectWithData:jsonData
                                                       options:NSJSONReadingAllowFragments
                                                         error:&error];

    if([data objectForKey:@"isUsingMultipleDREF"] != nil){
        //Client Requested Multiple DREFS
        [XPCRequestHandler handleMultipleDREFsRequest:data andSocket:socket];
    }

}

+(void) handleMultipleDREFsRequest:(NSMutableDictionary*)request andSocket:(PSWebSocket*)socket {
    
    NSMutableDictionary *data = [request mutableCopy];
    [data removeObjectForKey:@"isUsingMultipleDREF"];
    NSLog(@"Looking for %lu DREFS", data.count);
    
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
    for(int i = 0; i < data.count; i++){
        printf("\nRequesting DREFs[%d] = %s", i, drefsAsCString[i]);
    }
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
    
    //getDREFS
    XPCSocket sock = openUDP("127.0.0.1");
    getDREFs(sock, (const char**)drefsAsCString, values, data.count, sizes);
    
#if DEBUG
    for( int i = 0 ; i < data.count ; i++){
        printf("\n Sizes[i] updated to %d ", sizes[i]);
    }
    for( int i = 0 ; i < data.count ; i++){
        printf("\nDREF %s ", drefsAsCString[i]);
        for( int j = 0 ; j < sizes[i] ; j++) {
            printf(" %f ", values[i][j]);
        }
    }
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
            NSLog(@"%@", valueArray);
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
        NSLog(@"\n\n JSON: %@", jsonString);
        [socket send:jsonString];
    }
        
    
}


+(int) testXPlaneConnect {
    
    XPCSocket xpcSocket = openUDP("127.0.0.1");

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

    if (getDREFs(xpcSocket, drefs, values, count, sizes) < 0)
    {
        return -1;
    }
    return 0;

}
@end
