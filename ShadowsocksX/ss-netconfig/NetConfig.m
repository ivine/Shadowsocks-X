//
//  NetConfig.m
//  ShadowsocksX
//
//  Created by Delphi Yuan on 9/19/17.
//  Copyright © 2017 AFEGames. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import "AFEConstant.h"

#ifndef NETCONFIG_AS_SHELL_COMMAND

static AuthorizationRef authRef;

bool getAuthorization()
{
    authRef = NULL;
    static AuthorizationFlags authFlags;
    authFlags =   kAuthorizationFlagDefaults
    | kAuthorizationFlagExtendRights
    | kAuthorizationFlagInteractionAllowed
    | kAuthorizationFlagPreAuthorize;
    OSStatus authErr = AuthorizationCreate(nil, kAuthorizationEmptyEnvironment, authFlags, &authRef);
    if (authErr != noErr)
    {
        authRef = nil;
        NSLog(@"Error when create authorization");
        return false;
    }
    else
    {
        if (authRef == NULL)
        {
            NSLog(@"No authorization has been granted to modify network configuration");
            return false;
        }
        return true;
    }
}

/*
 * @enabled if set to false,it will clear the socks5 proxy settings
 * @bypassList if set to nil,it will bypass normal private ip address
 */
void configSocks5Proxy(NSString* localHost,int localPort, NSArray* bypassList, bool enabled)
{
    if(!getAuthorization())
        return;
    
    SCPreferencesRef prefRef = SCPreferencesCreateWithAuthorization(nil, CFSTR("ShadowsocksX"), nil, authRef);
    NSDictionary *sets = (__bridge NSDictionary *)SCPreferencesGetValue(prefRef, kSCPrefNetworkServices);
    
    NSMutableDictionary *proxies = [[NSMutableDictionary alloc] init];
    //clear all settings first
    [proxies setObject:[NSNumber numberWithInt:0] forKey:(NSString *)kCFNetworkProxiesHTTPEnable];
    [proxies setObject:[NSNumber numberWithInt:0] forKey:(NSString *)kCFNetworkProxiesHTTPSEnable];
    [proxies setObject:[NSNumber numberWithInt:0] forKey:(NSString *)kCFNetworkProxiesProxyAutoConfigEnable];
    [proxies setObject:[NSNumber numberWithInt:0] forKey:(NSString *)kCFNetworkProxiesSOCKSEnable];
    [proxies setObject:@[] forKey:(NSString *)kCFNetworkProxiesExceptionsList];
    
    // 遍历系统中的网络设备列表，设置 AirPort 和 Ethernet 的代理
    for (NSString *key in [sets allKeys])
    {
        NSMutableDictionary *dict = [sets objectForKey:key];
        NSString *hardware = [dict valueForKeyPath:@"Interface.Hardware"];
        NSLog(@"hardware: %@", hardware);
        BOOL modify = NO;
        if ([hardware isEqualToString:@"AirPort"] || [hardware isEqualToString:@"Wi-Fi"] || [hardware isEqualToString:@"Ethernet"])
        {
            modify = YES;
        }
        
        if (modify)
        {
            NSString* prefPath = [NSString stringWithFormat:@"/%@/%@/%@", kSCPrefNetworkServices, key, kSCEntNetProxies];
            NSLog(@"prefPath=%@",prefPath);
            
            if(enabled == false)
            {//we need to turn off the socks5 settings
                //check if this is setting by us,if the host,port are the same,and it's enabled,we clear it,if not enabled,we won't clear
                NSDictionary* oldProxies = (__bridge NSDictionary*)SCPreferencesPathGetValue(prefRef, (__bridge CFStringRef)prefPath);
                if (([oldProxies[(NSString*)kCFNetworkProxiesSOCKSProxy] isEqualToString:localHost]
                     &&[oldProxies[(NSString*)kCFNetworkProxiesSOCKSPort] isEqualTo:[NSNumber numberWithInteger:localPort]]
                     &&[oldProxies[(NSString*)kCFNetworkProxiesSOCKSEnable] isEqual:[NSNumber numberWithInt:1]])
                    )
                {
                    SCPreferencesPathSetValue(prefRef, (__bridge CFStringRef)prefPath, (__bridge CFDictionaryRef)proxies);
                }
            }
            else
            {//set socks5 proxy settings
                [proxies setObject:localHost forKey:(NSString *)kCFNetworkProxiesSOCKSProxy];
                [proxies setObject:[NSNumber numberWithInteger:localPort] forKey:(NSString*)kCFNetworkProxiesSOCKSPort];
                [proxies setObject:[NSNumber numberWithInt:1] forKey:(NSString*)kCFNetworkProxiesSOCKSEnable];
                
                if(bypassList == nil)
                    bypassList = @[@"127.0.0.1", @"192.168.0.0/16",@"172.16.0.0/12", @"10.0.0.0/8", @"localhost"];
                [proxies setObject:bypassList forKey:(NSString *)kCFNetworkProxiesExceptionsList];
                /*
                 if (privoxyPort != 0)
                 {
                 [proxies setObject:@"127.0.0.1" forKey:(NSString *)
                 kCFNetworkProxiesHTTPProxy];
                 [proxies setObject:[NSNumber numberWithInteger:privoxyPort] forKey:(NSString*)
                 kCFNetworkProxiesHTTPPort];
                 [proxies setObject:[NSNumber numberWithInt:1] forKey:(NSString*)
                 kCFNetworkProxiesHTTPEnable];
                 
                 [proxies setObject:@"127.0.0.1" forKey:(NSString *)
                 kCFNetworkProxiesHTTPSProxy];
                 [proxies setObject:[NSNumber numberWithInteger:privoxyPort] forKey:(NSString*)
                 kCFNetworkProxiesHTTPSPort];
                 [proxies setObject:[NSNumber numberWithInt:1] forKey:(NSString*)
                 kCFNetworkProxiesHTTPSEnable];
                 }
                 */
                SCPreferencesPathSetValue(prefRef, (__bridge CFStringRef)prefPath  , (__bridge CFDictionaryRef)proxies);
            }
            
        }
    }
    //submit the changes
    SCPreferencesCommitChanges(prefRef);
    SCPreferencesApplyChanges(prefRef);
    SCPreferencesSynchronize(prefRef);
    AuthorizationFree(authRef, kAuthorizationFlagDefaults);
    
}

#else

// A library for parsing command line.
// https://github.com/stephencelis/BRLOptionParser
#import "BRLOptionParser/BRLOptionParser.h"

int main(int argc, const char * argv[])
{
    NSString* mode;
    NSString* pacURL;
    NSString* portString;
    NSString* privoxyPortString;
    
    BRLOptionParser *options = [BRLOptionParser new];
    [options setBanner:@"Usage: %s [-v] [-m auto|global|off] [-u <url>] [-p <port>] [-r <port>]", argv[0]];

    // Version
    [options addOption:"version" flag:'v' description:@"Print the version number." block:^{
        printf("%s", AFE_NETWORK_CONFIG_VERSION);
        exit(EXIT_SUCCESS);
    }];

    // Help
    __weak typeof(options) weakOptions = options;
    [options addOption:"help" flag:'h' description:@"Show this message" block:^{
        printf("%s", [[weakOptions description] UTF8String]);
        exit(EXIT_SUCCESS);
    }];
    
    // Mode
    [options addOption:"mode" flag:'m' description:@"Proxy mode, may be: auto,global,off" argument:&mode];
    [options addOption:"pac-url" flag:'u' description:@"PAC file url for auto mode. for example: http://127.0.0.1/proxy.pac" argument:&pacURL];
    [options addOption:"port" flag:'p' description:@"Socks5 local isten port for global mode." argument:&portString];
    [options addOption:"privoxy-port" flag:'r' description:@"Privoxy Port for global mode." argument:&privoxyPortString];
    
    NSMutableSet* networkServiceKeys = [NSMutableSet set];
    [options addOption:"network-service" flag:'n' description:@"Manually specify the network name to set proxy." blockWithArgument:^(NSString* value){
        [networkServiceKeys addObject:value];
    }];
    
    NSError *error = nil;
    if (![options parseArgc:argc argv:argv error:&error]) {
        const char * message = error.localizedDescription.UTF8String;
        fprintf(stderr, "%s: %s\n", argv[0], message);
        exit(EXIT_FAILURE);
    }
    
    if (mode)
    {
        if ([@"auto" isEqualToString:mode])
        {
            if (!pacURL)
            {
                return 1;
            }
        }
        else if ([@"global" isEqualToString:mode])
        {
            if (!portString)
            {
                return 1;
            }
        }
        else if (![@"off" isEqualToString:mode])
        {//maybe invalid mode
            return 1;
        }
    }
    else
    {
        printf("%s", AFE_NETWORK_CONFIG_VERSION);
        return 0;
    }
    
    //get port number
    NSInteger port = 0;
    if (portString) {
        port = [portString integerValue];
        if (0 == port) {
            return 1;
        }
    }
    
    //get privoxy port
    NSInteger privoxyPort = 0;
    if (privoxyPortString)
    {//optional value
        privoxyPort = [privoxyPortString integerValue];
        if (0 == privoxyPort)
        {
            return 1;
        }
    }
    
    static AuthorizationRef authRef;
    static AuthorizationFlags authFlags;
    authFlags = kAuthorizationFlagDefaults
    | kAuthorizationFlagExtendRights
    | kAuthorizationFlagInteractionAllowed
    | kAuthorizationFlagPreAuthorize;
    OSStatus authErr = AuthorizationCreate(nil, kAuthorizationEmptyEnvironment, authFlags, &authRef);
    if (authErr != noErr) {
        authRef = nil;
        NSLog(@"Error when create authorization");
        return 1;
    }
    else
    {
        if (authRef == NULL) {
            NSLog(@"No authorization has been granted to modify network configuration");
            return 1;
        }
        
        SCPreferencesRef prefRef = SCPreferencesCreateWithAuthorization(nil, CFSTR("Shadowsocks"), nil, authRef);
        NSDictionary *sets = (__bridge NSDictionary *)SCPreferencesGetValue(prefRef, kSCPrefNetworkServices);
        
        NSMutableDictionary *proxies = [[NSMutableDictionary alloc] init];
        [proxies setObject:[NSNumber numberWithInt:0] forKey:(NSString *)kCFNetworkProxiesHTTPEnable];
        [proxies setObject:[NSNumber numberWithInt:0] forKey:(NSString *)kCFNetworkProxiesHTTPSEnable];
        [proxies setObject:[NSNumber numberWithInt:0] forKey:(NSString *)kCFNetworkProxiesProxyAutoConfigEnable];
        [proxies setObject:[NSNumber numberWithInt:0] forKey:(NSString *)kCFNetworkProxiesSOCKSEnable];
        [proxies setObject:@[] forKey:(NSString *)kCFNetworkProxiesExceptionsList];
        
        // 遍历系统中的网络设备列表，设置 AirPort 和 Ethernet 的代理
        for (NSString *key in [sets allKeys])
        {
            NSMutableDictionary *dict = [sets objectForKey:key];
            NSString *hardware = [dict valueForKeyPath:@"Interface.Hardware"];
            //        NSLog(@"%@", hardware);
            BOOL modify = NO;
            if ([networkServiceKeys count] > 0) {
                if ([networkServiceKeys containsObject:key]) {
                    modify = YES;
                }
            } else if ([hardware isEqualToString:@"AirPort"]
                       || [hardware isEqualToString:@"Wi-Fi"]
                       || [hardware isEqualToString:@"Ethernet"]) {
                modify = YES;
            }
            
            if (modify)
            {
                
                NSString* prefPath = [NSString stringWithFormat:@"/%@/%@/%@", kSCPrefNetworkServices
                                      , key, kSCEntNetProxies];
                
                if ([mode isEqualToString:@"auto"])
                {
                    
                    [proxies setObject:pacURL forKey:(NSString *)kCFNetworkProxiesProxyAutoConfigURLString];
                    [proxies setObject:[NSNumber numberWithInt:1] forKey:(NSString *)kCFNetworkProxiesProxyAutoConfigEnable];
                    
                    SCPreferencesPathSetValue(prefRef, (__bridge CFStringRef)prefPath
                                              , (__bridge CFDictionaryRef)proxies);
                }
                else if ([mode isEqualToString:@"global"])
                {
                    [proxies setObject:@"127.0.0.1" forKey:(NSString *)kCFNetworkProxiesSOCKSProxy];
                    [proxies setObject:[NSNumber numberWithInteger:port] forKey:(NSString*)kCFNetworkProxiesSOCKSPort];
                    [proxies setObject:[NSNumber numberWithInt:1] forKey:(NSString*)kCFNetworkProxiesSOCKSEnable];
                    [proxies setObject:@[@"127.0.0.1", @"192.168.0.0/16",@"172.16.0.0/12", @"10.0.0.0/8", @"localhost"] forKey:(NSString*)kCFNetworkProxiesExceptionsList];
                    
                    if (privoxyPort != 0)
                    {
                        [proxies setObject:@"127.0.0.1" forKey:(NSString *)kCFNetworkProxiesHTTPProxy];
                        [proxies setObject:[NSNumber numberWithInteger:privoxyPort] forKey:(NSString*)kCFNetworkProxiesHTTPPort];
                        [proxies setObject:[NSNumber numberWithInt:1] forKey:(NSString*)kCFNetworkProxiesHTTPEnable];
                        
                        [proxies setObject:@"127.0.0.1" forKey:(NSString *)kCFNetworkProxiesHTTPSProxy];
                        [proxies setObject:[NSNumber numberWithInteger:privoxyPort] forKey:(NSString*)kCFNetworkProxiesHTTPSPort];
                        [proxies setObject:[NSNumber numberWithInt:1] forKey:(NSString*)kCFNetworkProxiesHTTPSEnable];
                    }
                    
                    SCPreferencesPathSetValue(prefRef, (__bridge CFStringRef)prefPath, (__bridge CFDictionaryRef)proxies);
                }
                else if ([mode isEqualToString:@"off"])
                {
                    if (pacURL != nil && portString != nil)
                    {
                        // 取原来的配置，判断是否为shadowsocksX-NG设置的
                        NSDictionary* oldProxies
                        = (__bridge NSDictionary*)SCPreferencesPathGetValue(prefRef, (__bridge CFStringRef)prefPath);
                        
                        if (([oldProxies[(NSString *)kCFNetworkProxiesProxyAutoConfigURLString] isEqualToString:pacURL]
                             &&[oldProxies[(NSString *)kCFNetworkProxiesProxyAutoConfigEnable] isEqual:[NSNumber numberWithInt:1]])
                            ||([oldProxies[(NSString*)kCFNetworkProxiesSOCKSProxy] isEqualToString:@"127.0.0.1"]
                               &&[oldProxies[(NSString*)kCFNetworkProxiesSOCKSPort] isEqualTo:[NSNumber numberWithInteger:port]]
                               &&[oldProxies[(NSString*)kCFNetworkProxiesSOCKSEnable] isEqual:[NSNumber numberWithInt:1]])
                            )
                        {
                            SCPreferencesPathSetValue(prefRef, (__bridge CFStringRef)prefPath, (__bridge CFDictionaryRef)proxies);
                        }
                    }
                    else
                    {
                        SCPreferencesPathSetValue(prefRef, (__bridge CFStringRef)prefPath, (__bridge CFDictionaryRef)proxies);
                    }
                }
            }//end of for loop
        }
        
        SCPreferencesCommitChanges(prefRef);
        SCPreferencesApplyChanges(prefRef);
        SCPreferencesSynchronize(prefRef);
        AuthorizationFree(authRef, kAuthorizationFlagDefaults);
    }
    
    //printf("socks5 proxy set to mode: %s", [mode UTF8String]);
    return 0;
}

#endif
