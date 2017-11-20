//
//  NetConfig.h
//  ShadowsocksX
//
//  Created by Delphi Yuan on 9/21/17.
//  Copyright © 2017 AFEGames. All rights reserved.
//

#ifndef NetConfig_h
#define NetConfig_h

#ifdef __cplusplus
extern "C" {
#endif
    
    /*
     * this function will clear http,https,socks5,auto proxy settings and then set socks5 setting acorddingly
     *
     * @enabled if set to false,it will clear the socks5 proxy settings
     * @bypassList if set to nil,it will bypass normal private ip address
     */
    void configSocks5Proxy(NSString* localHost,int localPort, NSArray* bypassList, bool enabled);
    
#ifdef __cplusplus
}
#endif





#endif /* NetworkConfig_h */
