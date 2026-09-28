#pragma once
#import "MessageMenuPatch.h"

#if defined(__aarch64__)
std::function<void()> YMAIMessageAction(std::shared_ptr<YMMessageSnapshot> message, NSString *session);
#endif
