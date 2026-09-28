#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN
FOUNDATION_EXPORT NSString * const YMAISettingsChangedNotification;
FOUNDATION_EXPORT NSDictionary<NSString *, NSString *> *YMAILoadSettings(void);
FOUNDATION_EXPORT NSString * _Nullable YMAICredentialScope(NSString *provider, NSString *baseURL, NSError **error);
FOUNDATION_EXPORT NSString * _Nullable YMAIReadKey(NSString *provider, NSString *baseURL, NSError **error);
FOUNDATION_EXPORT BOOL YMAIWriteKey(NSString *provider, NSString *baseURL, NSString *key, NSError **error);
FOUNDATION_EXPORT void YMAIShowSettings(void);
NS_ASSUME_NONNULL_END
