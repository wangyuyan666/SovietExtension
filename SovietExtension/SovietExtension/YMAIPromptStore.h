#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
FOUNDATION_EXPORT NSArray<NSString *> *YMAIPromptIDs(void);
FOUNDATION_EXPORT NSString *YMAIPromptTitle(NSString *identifier);
FOUNDATION_EXPORT NSDictionary<NSString *, NSString *> *YMAIDefaultPrompts(void);
// Keys are "common" and the five stable scenario IDs. Store only user overrides.
@interface YMAIPromptStore : NSObject
+ (instancetype)sharedStore;
- (instancetype)initWithDefaults:(NSUserDefaults *)defaults;
- (NSDictionary<NSString *, NSString *> *)prompts;
- (NSString *)selectedIdentifier;
- (BOOL)savePrompts:(NSDictionary<NSString *, NSString *> *)prompts
 selectedIdentifier:(NSString *)identifier error:(NSError **)error;
@end
NS_ASSUME_NONNULL_END
