#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN
// Own strings only; isCurrentAccount runs on the main thread and must not borrow message memory.
FOUNDATION_EXPORT void YMAIShowAnalysis(NSString *text, NSString *session, NSString *sender,
                                      BOOL (^isCurrentAccount)(void));
NS_ASSUME_NONNULL_END
