#import "YMAIMessageAction.h"
#import "YMAIWindowController.h"
#import "SelfRevokePatch.h"
#include <string>
#include <cstring>

#if defined(__aarch64__)
static NSString *YMAIOwnString(const std::string &value, size_t maximum) {
    if (value.empty() || value.size() > maximum) return nil;
    return [[NSString alloc] initWithBytes:value.data() length:value.size() encoding:NSUTF8StringEncoding];
}
std::function<void()> YMAIMessageAction(std::shared_ptr<YMMessageSnapshot> message, NSString *session) {
    // Called only inside the existing 269079/arm64 UUID + instruction-fingerprint guarded menu.
    // MessageData differs from MessageWrap: body +0xb0 is confirmed in ForwardToSelfPatch.mm.
    // Sender +0x10 and session +0x58 are also used by YMIsRetainedSelfMessage.
    NSString *account = [YMSelfRevokeAccount() copy];
    return [message, session = [session copy], account] {
        @autoreleasepool {
            NSString *failure = nil;
            if (!NSThread.isMainThread || !account.length || ![YMSelfRevokeAccount() isEqual:account]) {
                failure = @"无法确认当前账号或账号已变化，请重新选择消息。";
            } else {
                const uint8_t *data = message->storage;
                uint32_t type = 0; memcpy(&type, data + 8, sizeof(type));
                if (type != 1) failure = @"首版仅支持普通文本消息，暂不分析图片、语音、文件或引用消息。";
                else {
                    NSString *text = YMAIOwnString(*(const std::string *)(data + 0xb0), 48000);
                    NSString *sender = YMAIOwnString(*(const std::string *)(data + 0x10), 128);
                    if (!text.length || text.length > 12000 || !sender.length) {
                        failure = @"消息为空、过长或无法安全读取。未上传任何内容。";
                    } else {
                        // Strip only an exact, known group sender prefix, never split arbitrary user text.
                        NSString *prefix = [sender stringByAppendingString:@":\n"];
                        if ([session hasSuffix:@"@chatroom"] && [text hasPrefix:prefix]) {
                            text = [text substringFromIndex:prefix.length];
                        }
                        YMAIShowAnalysis(text, session, sender, ^BOOL {
                            return [YMSelfRevokeAccount() isEqual:account];
                        });
                        return;
                    }
                }
            }
            NSAlert *alert = [[NSAlert alloc] init];
            alert.messageText = @"暂时无法分析";
            alert.informativeText = failure;
            [alert addButtonWithTitle:@"知道了"];
            [alert runModal];
        }
    };
}
#endif
