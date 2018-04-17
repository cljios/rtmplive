//
//  AudioClock.h
//  Pullstream
//
//  Created by clj on 16/10/25.
//  Copyright © 2016年 clj. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <mach/mach_time.h>
@interface AudioClock : NSObject

@property(nonatomic,assign)UInt64 start_time;

@property(nonatomic,assign)UInt64 end_time;

- (void)endTiming;
- (void)startTiming;
- (UInt64)calculateTime;
@end
