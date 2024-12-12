// See http://iphonedevwiki.net/index.php/Logos

#if TARGET_OS_SIMULATOR
#error Do not support the simulator, please use the real iPhone Device.
#endif

#import <UIKit/UIKit.h>

#pragma mark - 定义

#define kRedEnvelopTitle @"红包开关"
#define kRedEnvelopSwitch @"kRedEnvelopSwitch"

#define kLocationTitle @"定位开关"
#define kLocationSwitch @"kLocationSwitch"

#pragma mark - 设置
@interface DTSectionItem : NSObject
@property(copy, nonatomic) NSArray *dataSource; // @synthesize dataSource=_dataSource;
@end

@interface DTCellItem : NSObject
@property(copy, nonatomic) NSString *title; // @synthesize title=_title;
+ (id)cellItemForSwitcherStyleWithTitle:(id)arg1 isSwitcherOn:(_Bool)arg2 switcherValueDidChangeBlock:(id)arg3;
@end

#pragma mark - 红包
@interface DTRedEnvelopServiceIMP : NSObject
- (void)pickRedEnvelopCluster:(long long)arg1 clusterId:(id)arg2 successBlock:(id)arg3 failureBlock:(id)arg4;
@end

@interface WKBizConversation : NSObject
@property(retain, nonatomic) NSString *latestMessageJson; // @synthesize latestMessageJson=_latestMessageJson;
@end

#pragma mark - 定位
@interface LAActionResponse : NSObject
@property(copy, nonatomic) NSString *actionName; // @synthesize actionName=_actionName;
@property(copy, nonatomic) NSString *pluginName; // @synthesize pluginName=_pluginName;
@end

@interface LAActionRequest : NSObject
@property(readonly, copy, nonatomic) NSString *domain; // @synthesize domain=_domain;
@property(copy, nonatomic) NSString *url; // @synthesize url=_url;
@property(copy, nonatomic) NSDictionary *args; // @synthesize args=_args;
@property(nonatomic) __weak id ctnHandler; // @synthesize ctnHandler=_ctnHandler;
@end

#pragma mark - 设置
///设置里增加抢红包开关，修改定位开关
%hook DTSettingListViewController
- (id)notificationCellItem {
    BOOL redSwitchOn = [[NSUserDefaults standardUserDefaults] boolForKey:kRedEnvelopSwitch];
    id redBlock = ^(DTCellItem *cellItem, id cell, UISwitch *aSwitch){
        [[NSUserDefaults standardUserDefaults] setBool:aSwitch.on forKey:kRedEnvelopSwitch];
        [[NSUserDefaults standardUserDefaults] synchronize];
    };
    DTCellItem *redItem = [NSClassFromString(@"DTCellItem") cellItemForSwitcherStyleWithTitle:kRedEnvelopTitle isSwitcherOn:redSwitchOn switcherValueDidChangeBlock:redBlock];
    return redItem;
}

- (id)privacyCellItem {
    BOOL locationSwitchOn = [[NSUserDefaults standardUserDefaults] boolForKey:kLocationSwitch];
    id locationBlock = ^(DTCellItem *cellItem, id cell, UISwitch *aSwitch){
        [[NSUserDefaults standardUserDefaults] setBool:aSwitch.on forKey:kLocationSwitch];
        [[NSUserDefaults standardUserDefaults] synchronize];
    };
    DTCellItem *locationItem = [NSClassFromString(@"DTCellItem") cellItemForSwitcherStyleWithTitle:kLocationTitle isSwitcherOn:locationSwitchOn switcherValueDidChangeBlock:locationBlock];
    return locationItem;
}
%end

#pragma mark - 红包
static DTRedEnvelopServiceIMP *redEnvelopService = nil;

%hook DTRedEnvelopServiceIMP
- (id)init {
    id obj = %orig;
    ///初始化时给全局抢红包service赋值
    redEnvelopService = obj;
    return obj;
}
%end

%hook DTConversationListDataSource
- (void)controller:(id)arg1 didChangeObject:(id)arg2 atIndex:(unsigned long long)arg3 forChangeType:(long long)arg4 newIndex:(unsigned long long)arg5 {
    %orig;
    BOOL switchOn = [[NSUserDefaults standardUserDefaults] boolForKey:kRedEnvelopSwitch];
    ///判断是红包类型消息
    if ([arg2 isKindOfClass:NSClassFromString(@"WKBizConversation")] && switchOn) {
        WKBizConversation *conversation = (WKBizConversation *)arg2;
        if (conversation.latestMessageJson.length > 0) {
            NSData *conversationData = [conversation.latestMessageJson dataUsingEncoding:NSUTF8StringEncoding];
            NSDictionary *conversationDic = [NSJSONSerialization JSONObjectWithData:conversationData options:NSJSONReadingMutableLeaves error:nil];
            if (conversationDic.count > 0) {
                NSString *attachmentsJson = conversationDic[@"attachmentsJson"];
                if (attachmentsJson.length > 0) {
                    NSData *attachmentsJsonData = [attachmentsJson dataUsingEncoding:NSUTF8StringEncoding];
                    NSDictionary *attachmentsJsonDic = [NSJSONSerialization JSONObjectWithData:attachmentsJsonData options:NSJSONReadingMutableLeaves error:nil];
                    if (attachmentsJsonDic.count > 0) {
                        int contentType = [attachmentsJsonDic[@"contentType"] intValue];
                        if (contentType == 901 || contentType == 902 || contentType == 905) {
                            NSArray *attachments = attachmentsJsonDic[@"attachments"];
                            for (NSDictionary *dic in attachments) {
                                NSDictionary *extension = dic[@"extension"];
                                if (extension.count > 0) {
                                    NSString *clusterid = extension[@"clusterid"];
                                    long long sid = [extension[@"sid"] longLongValue];
                                    if (clusterid.length > 0 && sid > 0) {
                                        ///调用抢红包函数
                                        [redEnvelopService pickRedEnvelopCluster:sid clusterId:clusterid successBlock:nil failureBlock:nil];
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
%end

#pragma mark - 位置
%hook LAActionResponse
- (void)_callbackWithResult:(NSDictionary *)arg1 keep:(_Bool)arg2 errorCode:(long long)arg3 errorMessage:(id)arg4 {

    BOOL locationSwitchOn = [[NSUserDefaults standardUserDefaults] boolForKey:kLocationSwitch];
    if (!locationSwitchOn) {
        %orig;
        return;
    }
    if (![arg1 isKindOfClass:[NSDictionary class]]) {
        %orig;
        return;
    }
    if (![self.pluginName isEqualToString:@"device.geolocation"]) {
        %orig;
        return;
    }
    if (![self.actionName isEqualToString:@"get"] &&
        ![self.actionName isEqualToString:@"start"]) {
        %orig;
        return;
    }

    if (arg1[@"accuracy"]) {
        NSString *latitude = @"00.0000000";
        NSString *longitude = @"000.0000000";
        for (int i = 0; i  < 7; i ++) {
            latitude = [NSString stringWithFormat:@"%@%d",latitude, arc4random()%10];
            longitude = [NSString stringWithFormat:@"%@%d",longitude, arc4random()%10];
        }
        
        NSMutableDictionary *dict = [[NSMutableDictionary alloc] initWithDictionary:arg1];
        [dict setValue:@"xx省xx市" forKey:@"address"];
        [dict setValue:@"xx市" forKey:@"city"];
        [dict setValue:@000 forKey:@"cityAdcode"];
        [dict setValue:@"中国" forKey:@"country"];
        [dict setValue:@"xxx区" forKey:@"district"];
        [dict setValue:@000000 forKey:@"districtAdcode"];
        [dict setValue:@"xx省" forKey:@"province"];
        [dict setValue:@"" forKey:@"road"];
        [dict setValue:@"" forKey:@"streetNumber"];
        [dict setValue:latitude forKey:@"latitude"];
        [dict setValue:longitude forKey:@"longitude"];
        NSLog(@"========== arg1: %@ \n %@ \n %@", self.actionName, self.pluginName, dict);
        %orig(dict.copy, arg2, arg3, arg4);
    } else {
        %orig;
    }
}

%end
