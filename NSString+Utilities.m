//
//  ExtendNSString.m
//  ShadowsocksX
//
//  Created by Delphi Yuan on 10/13/17.
//  Copyright © 2017 AFEGames. All rights reserved.
//

#import "NSString+Utilities.h"

@implementation NSString (util)

- (int) indexOf:(NSString *)text {
    NSRange range = [self rangeOfString:text];
    if ( range.length > 0 ) {
        return (int)range.location;
    } else {
        return -1;
    }
}

- (bool) containsString: (NSString*) substring
{
    NSRange range = [self rangeOfString : substring];
    bool found = ( range.location != NSNotFound );
    return found;
}

@end

