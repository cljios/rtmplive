//
//  AudioClock.m
//  Pullstream
//
//  Created by clj on 16/10/25.
//  Copyright © 2016年 clj. All rights reserved.
//

#import "AudioClock.h"

@implementation AudioClock
{
    mach_timebase_info_data_t info;

}
- (instancetype)init{

    if (self = [super init]) {
        if (mach_timebase_info(&info) != KERN_SUCCESS){
            NSLog(@"mach_timebase_info error");
        }

    }
    return self;
}

- (void)startTiming{

     _start_time = mach_absolute_time ();
    
}

- (void)endTiming{

    _end_time = mach_absolute_time ();

}

- (UInt64)calculateTime{
    // Convert the mach time to milliseconds
    uint64_t millis = (((self.end_time - self.start_time) / 1000000) * info.numer) / info.denom;
    
    return millis;

}

@end
