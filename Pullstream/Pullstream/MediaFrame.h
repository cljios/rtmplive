//
//  MediaFrame.h
//  Pullstream
//
//  Created by clj on 16/10/20.
//  Copyright © 2016年 clj. All rights reserved.
//

#import <Foundation/Foundation.h>
#include "SYStruct.h"

@interface MediaFrame : NSObject
{

@public
    
    MediaFrameType _frame_info;
}
+ (instancetype)createFrameWithInfo:(MediaFrameType )frame_info;
@end
