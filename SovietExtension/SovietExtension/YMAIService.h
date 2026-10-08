#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
FOUNDATION_EXPORT NSArray<NSString *> *YMAIProviderIDs(void);
FOUNDATION_EXPORT NSString *YMAIProviderName(NSString *provider);
// HTTPS API root including any version prefix; no query, credentials or endpoint suffix.
FOUNDATION_EXPORT NSString * _Nullable YMAINormalizeBaseURL(NSString *baseURL, NSError **error);
FOUNDATION_EXPORT NSURL * _Nullable YMAIEndpoint(NSString *provider, NSString *baseURL, NSError **error);
FOUNDATION_EXPORT NSError *YMAIError(NSString *message);
FOUNDATION_EXPORT NSDictionary * _Nullable YMAIRequestBody(NSString *provider, NSString *model,
    NSDictionary<NSString *, NSString *> *prompts, NSString *promptIdentifier, NSString *text, NSError **error);
FOUNDATION_EXPORT NSDictionary * _Nullable YMAIParseResponse(NSString *provider, NSData *data, NSError **error);

// One bounded, non-streaming request. No cookies, disk cache, redirects, tools or automatic retries.
@interface YMAIRequest : NSObject <NSURLSessionDataDelegate>
- (void)startProvider:(NSString *)provider baseURL:(NSString *)baseURL model:(NSString *)model key:(NSString *)key
               prompts:(NSDictionary<NSString *, NSString *> *)prompts
    promptIdentifier:(NSString *)promptIdentifier text:(NSString *)text
       configuration:(NSURLSessionConfiguration *)configuration
          completion:(void (^)(NSDictionary * _Nullable result, NSError * _Nullable error))completion;
- (void)cancel;
@end
NS_ASSUME_NONNULL_END
