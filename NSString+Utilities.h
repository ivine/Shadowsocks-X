//
//  ExtendNSString.h
//  ShadowsocksX
//
//  Created by Delphi Yuan on 10/13/17.
//  Copyright © 2017 AFEGames. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (Utilities)

- (int) indexOf:(NSString *)text;
- (bool) containsString: (NSString*) substring;

@end
