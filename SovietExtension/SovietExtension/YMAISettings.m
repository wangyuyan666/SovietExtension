#import "YMAISettings.h"
#import "YMAIService.h"
#import "YMAIPromptStore.h"
#import <Security/Security.h>
#import <QuartzCore/QuartzCore.h>

NSString * const YMAISettingsChangedNotification = @"YMAISettingsChangedNotification";
static NSString * const YMAIPreferencesKey = @"YMAI.Settings.SOVIET";
static NSString * const YMAIKeyService = @"com.mustangym.SovietExtension.AI";
static NSString * const YMAIDeepSeekBaseURL = @"https://api.deepseek.com";

NSDictionary<NSString *, NSString *> *YMAILoadSettings(void) {
    NSDictionary *saved = [NSUserDefaults.standardUserDefaults dictionaryForKey:YMAIPreferencesKey] ?: @{};
    NSString *provider = [YMAIProviderIDs() containsObject:saved[@"provider"]] ? saved[@"provider"] : @"openai";
    NSString *model = [saved[@"model"] isKindOfClass:NSString.class] ? saved[@"model"] : @"";
    NSString *baseURL = [provider isEqualToString:@"deepseek"] ? YMAIDeepSeekBaseURL :
        ([saved[@"baseURL"] isKindOfClass:NSString.class] ? saved[@"baseURL"] : @"");
    return @{@"provider": provider, @"model": model, @"baseURL": baseURL};
}
NSString *YMAICredentialScope(NSString *provider, NSString *baseURL, NSError **error) {
    if (!YMAIEndpoint(provider, baseURL, error)) return nil;
    NSString *base = YMAINormalizeBaseURL(baseURL, error);
    NSData *scope = [NSJSONSerialization dataWithJSONObject:@[provider, base] options:0 error:error];
    return scope ? [@"endpoint-v1:" stringByAppendingString:[scope base64EncodedStringWithOptions:0]] : nil;
}
static NSMutableDictionary *YMAIKeyQuery(NSString *provider, NSString *baseURL, NSError **error) {
    NSString *scope = YMAICredentialScope(provider, baseURL, error);
    if (!scope) return nil;
    return [@{(__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
              (__bridge id)kSecAttrService: YMAIKeyService,
              (__bridge id)kSecAttrAccount: scope} mutableCopy];
}
NSString *YMAIReadKey(NSString *provider, NSString *baseURL, NSError **error) {
    NSMutableDictionary *query = YMAIKeyQuery(provider, baseURL, error);
    if (!query) return nil;
    query[(__bridge id)kSecReturnData] = @YES;
    query[(__bridge id)kSecMatchLimit] = (__bridge id)kSecMatchLimitOne;
    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    NSData *data = CFBridgingRelease(result);
    if (status != errSecSuccess) {
        if (error) *error = YMAIError(status == errSecItemNotFound ? @"此接口协议和 Base URL 尚未保存 API Key；旧厂商配置的密钥不会自动沿用，请在 AI 设置中重新填写。" :
            @"无法访问钥匙串。请检查授权；重签名或更新微信后可能需要重新授权。");
        return nil;
    }
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}
BOOL YMAIWriteKey(NSString *provider, NSString *baseURL, NSString *key, NSError **error) {
    if (![YMAIProviderIDs() containsObject:provider] || key.length > 4096 ||
        [key rangeOfCharacterFromSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].location != NSNotFound) {
        if (error) *error = YMAIError(@"API Key 不能包含空白字符或超过 4096 字符。"); return NO;
    }
    NSMutableDictionary *query = YMAIKeyQuery(provider, baseURL, error);
    if (!query) return NO;
    OSStatus status;
    if (!key.length) {
        status = SecItemDelete((__bridge CFDictionaryRef)query);
        if (status == errSecItemNotFound) status = errSecSuccess;
    } else {
        NSDictionary *values = @{(__bridge id)kSecValueData: [key dataUsingEncoding:NSUTF8StringEncoding]};
        status = SecItemUpdate((__bridge CFDictionaryRef)query, (__bridge CFDictionaryRef)values);
        if (status == errSecItemNotFound) {
            [query addEntriesFromDictionary:values];
            query[(__bridge id)kSecAttrAccessible] = (__bridge id)kSecAttrAccessibleWhenUnlockedThisDeviceOnly;
            status = SecItemAdd((__bridge CFDictionaryRef)query, NULL);
        }
    }
    if (status != errSecSuccess && error) *error = YMAIError(@"钥匙串保存失败，设置未保存。请检查钥匙串访问权限。");
    return status == errSecSuccess;
}

@interface YMAIPromptClipView : NSClipView
@end

@implementation YMAIPromptClipView
- (void)scrollToPoint:(NSPoint)point {
    NSRect proposed = self.bounds;
    proposed.origin = point;
    [super scrollToPoint:[self constrainBoundsRect:proposed].origin];
}
- (NSRect)constrainBoundsRect:(NSRect)proposedBounds {
    NSRect bounds = [super constrainBoundsRect:proposedBounds];
    bounds.origin.x = 0;
    return bounds;
}
@end

// Independent draft: switching templates preserves edits; closing without saving discards them.
@interface YMAIPromptController : NSWindowController <NSWindowDelegate>
@property(nonatomic, strong) NSPopUpButton *selection;
@property(nonatomic, strong) NSPopUpButton *defaultSelection;
@property(nonatomic, strong) NSTextView *editor;
@property(nonatomic, strong) NSTextField *status;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *draft;
@property(nonatomic, copy) NSString *editingIdentifier;
@end

@implementation YMAIPromptController
- (instancetype)init {
    NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 660, 580)
        styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskResizable
        backing:NSBackingStoreBuffered defer:NO];
    self = [super initWithWindow:window];
    if (!self) return nil;
    window.title = @"AI 话术管理";
    window.releasedWhenClosed = NO;
    window.minSize = NSMakeSize(580, 460);
    [window center];
    NSStackView *stack = [[NSStackView alloc] init];
    stack.orientation = NSUserInterfaceLayoutOrientationVertical;
    stack.alignment = NSLayoutAttributeLeading;
    stack.spacing = 12;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [window.contentView addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:window.contentView.leadingAnchor constant:20],
        [stack.trailingAnchor constraintEqualToAnchor:window.contentView.trailingAnchor constant:-20],
        [stack.topAnchor constraintEqualToAnchor:window.contentView.topAnchor constant:20],
        [stack.bottomAnchor constraintEqualToAnchor:window.contentView.bottomAnchor constant:-20]]];
    NSTextField *intro = [NSTextField wrappingLabelWithString:
        @"话术会随正文一起提交给 AI。仅调整内容和语气；JSON 格式、仅使用已提供文本及不自动发送等固定约束不可修改。保存后下次分析生效；关闭不保存会放弃修改。"];
    [stack addArrangedSubview:intro];
    [intro.widthAnchor constraintEqualToAnchor:stack.widthAnchor].active = YES;
    self.defaultSelection = [[NSPopUpButton alloc] init];
    self.selection = [[NSPopUpButton alloc] init];
    [self.selection addItemWithTitle:@"公共提示词"];
    for (NSString *identifier in YMAIPromptIDs()) {
        [self.selection addItemWithTitle:YMAIPromptTitle(identifier)];
        [self.defaultSelection addItemWithTitle:YMAIPromptTitle(identifier)];
    }
    self.selection.accessibilityLabel = @"编辑话术";
    self.defaultSelection.accessibilityLabel = @"默认话术";
    self.selection.target = self;
    self.selection.action = @selector(selectionChanged:);
    for (NSArray *pair in @[@[@"默认话术", self.defaultSelection], @[@"编辑话术", self.selection]]) {
        NSStackView *row = [NSStackView stackViewWithViews:@[[NSTextField labelWithString:pair[0]], pair[1]]];
        row.spacing = 12;
        [stack addArrangedSubview:row];
    }
    NSScrollView *scroll = [[NSScrollView alloc] init];
    scroll.contentView = [[YMAIPromptClipView alloc] init];
    scroll.hasVerticalScroller = YES;
    scroll.hasHorizontalScroller = NO;
    scroll.horizontalScrollElasticity = NSScrollElasticityNone;
    scroll.borderType = NSNoBorder;
    scroll.wantsLayer = YES;
    scroll.layer.cornerRadius = 12.0;
    scroll.layer.masksToBounds = YES;
    self.editor = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 620, 300)];
    self.editor.richText = NO;
    self.editor.font = [NSFont systemFontOfSize:13];
    self.editor.textColor = NSColor.textColor;
    self.editor.backgroundColor = NSColor.textBackgroundColor;
    self.editor.textContainerInset = NSMakeSize(10, 8);
    self.editor.autoresizingMask = NSViewWidthSizable;
    self.editor.verticallyResizable = YES;
    self.editor.horizontallyResizable = NO;
    self.editor.textContainer.widthTracksTextView = YES;
    self.editor.textContainer.containerSize = NSMakeSize(620, CGFLOAT_MAX);
    self.editor.accessibilityLabel = @"提示词正文";
    self.editor.allowsUndo = YES;
    scroll.documentView = self.editor;
    [stack addArrangedSubview:scroll];
    [scroll.widthAnchor constraintEqualToAnchor:stack.widthAnchor].active = YES;
    [scroll.heightAnchor constraintGreaterThanOrEqualToConstant:180].active = YES;
    self.status = [NSTextField wrappingLabelWithString:@""];
    self.status.accessibilityLabel = @"话术保存状态";
    [stack addArrangedSubview:self.status];
    [self.status.widthAnchor constraintEqualToAnchor:stack.widthAnchor].active = YES;
    NSStackView *buttons = [NSStackView stackViewWithViews:@[
        [NSButton buttonWithTitle:@"恢复当前默认" target:self action:@selector(restore:)],
        [NSButton buttonWithTitle:@"取消" target:self action:@selector(cancel:)],
        [NSButton buttonWithTitle:@"保存话术" target:self action:@selector(save:)]]];
    buttons.spacing = 12;
    [stack addArrangedSubview:buttons];
    return self;
}
- (void)reload {
    self.draft = [YMAIPromptStore.sharedStore.prompts mutableCopy];
    [self.defaultSelection selectItemAtIndex:[YMAIPromptIDs() indexOfObject:YMAIPromptStore.sharedStore.selectedIdentifier]];
    [self.selection selectItemAtIndex:0];
    self.editingIdentifier = @"common";
    [self loadEditor];
    self.status.stringValue = @"每段限 12000 字符。公共提示词应用于全部场景。";
}
- (void)loadEditor {
    self.editor.string = self.draft[self.editingIdentifier];
    [self.editor.undoManager removeAllActions];
    [self.editor scrollRangeToVisible:NSMakeRange(0, 0)];
}
- (void)selectionChanged:(id)sender {
    self.draft[self.editingIdentifier] = [self.editor.string copy];
    NSInteger index = self.selection.indexOfSelectedItem;
    self.editingIdentifier = index == 0 ? @"common" : YMAIPromptIDs()[index - 1];
    [self loadEditor];
}
- (void)restore:(id)sender {
    self.draft[self.editingIdentifier] = YMAIDefaultPrompts()[self.editingIdentifier];
    [self loadEditor];
    self.status.stringValue = @"当前话术已恢复默认，点击「保存话术」后生效。";
}
- (void)cancel:(id)sender { [self.window close]; }
- (void)save:(id)sender {
    self.draft[self.editingIdentifier] = [self.editor.string copy];
    NSError *error = nil;
    if (![YMAIPromptStore.sharedStore savePrompts:self.draft
        selectedIdentifier:YMAIPromptIDs()[self.defaultSelection.indexOfSelectedItem] error:&error]) {
        self.status.stringValue = error.localizedDescription;
        return;
    }
    self.status.stringValue = @"已保存，下次分析生效；自定义内容不会被插件更新覆盖。";
    [NSNotificationCenter.defaultCenter postNotificationName:YMAISettingsChangedNotification object:nil];
}
@end

@interface YMAISettingsController : NSWindowController <NSWindowDelegate, NSTextFieldDelegate>
@property(nonatomic, strong) YMAIPromptController *promptController;
@property(nonatomic, strong) NSPopUpButton *provider;
@property(nonatomic, strong) NSTextField *model;
@property(nonatomic, strong) NSTextField *baseURL;
@property(nonatomic, strong) NSSecureTextField *key;
@property(nonatomic, strong) NSTextField *endpoint;
@property(nonatomic, strong) NSTextField *status;
@property(nonatomic, copy) NSString *editingProvider;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *models;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *baseURLs;
@end

@implementation YMAISettingsController
- (instancetype)init {
    NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 540, 530)
        styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable backing:NSBackingStoreBuffered defer:NO];
    self = [super initWithWindow:window];
    if (!self) return nil;
    window.title = @"AI 设置";
    window.releasedWhenClosed = NO;
    window.delegate = self;
    [window center];
    NSStackView *stack = [[NSStackView alloc] init];
    stack.orientation = NSUserInterfaceLayoutOrientationVertical;
    stack.alignment = NSLayoutAttributeLeading;
    stack.spacing = 12;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [window.contentView addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:window.contentView.leadingAnchor constant:24],
        [stack.trailingAnchor constraintEqualToAnchor:window.contentView.trailingAnchor constant:-24],
        [stack.topAnchor constraintEqualToAnchor:window.contentView.topAnchor constant:24]]];
    NSTextField *intro = [NSTextField wrappingLabelWithString:@"仅在消息右键选择「AI 分析」时提交内容。回复建议只复制，不会自动发送。"];
    [stack addArrangedSubview:intro];
    [intro.widthAnchor constraintEqualToAnchor:stack.widthAnchor].active = YES;
    self.provider = [[NSPopUpButton alloc] init];
    for (NSString *provider in YMAIProviderIDs()) [self.provider addItemWithTitle:YMAIProviderName(provider)];
    self.provider.target = self; self.provider.action = @selector(providerChanged:);
    self.baseURL = [NSTextField textFieldWithString:@""];
    self.baseURL.placeholderString = @"https://HOST/v1（填写 API 根地址）";
    self.baseURL.delegate = self;
    self.model = [NSTextField textFieldWithString:@""];
    self.model.placeholderString = @"填写此账户可用、支持 JSON 输出的文本模型 ID";
    self.key = [[NSSecureTextField alloc] init];
    self.key.placeholderString = @"留空只保留当前地址的密钥；新地址需填写";
    NSArray *controls = @[self.provider, self.baseURL, self.model, self.key];
    NSArray *labels = @[@"接口协议", @"Base URL", @"模型 ID", @"API Key"];
    for (NSUInteger i = 0; i < controls.count; i++) {
        NSView *control = controls[i];
        control.accessibilityLabel = labels[i];
        NSTextField *label = [NSTextField labelWithString:labels[i]];
        [label.widthAnchor constraintEqualToConstant:78].active = YES;
        NSStackView *row = [NSStackView stackViewWithViews:@[label, control]];
        row.orientation = NSUserInterfaceLayoutOrientationHorizontal;
        row.spacing = 12;
        [stack addArrangedSubview:row];
        [row.widthAnchor constraintEqualToAnchor:stack.widthAnchor].active = YES;
        [control.widthAnchor constraintEqualToConstant:390].active = YES;
    }
    self.endpoint = [NSTextField wrappingLabelWithString:@""];
    self.endpoint.font = [NSFont systemFontOfSize:12];
    self.endpoint.textColor = NSColor.secondaryLabelColor;
    self.endpoint.selectable = YES;
    self.endpoint.lineBreakMode = NSLineBreakByCharWrapping;
    self.endpoint.maximumNumberOfLines = 4;
    [stack addArrangedSubview:self.endpoint];
    [self.endpoint.widthAnchor constraintEqualToAnchor:stack.widthAnchor].active = YES;
    self.status = [NSTextField wrappingLabelWithString:@"密钥按接口协议和地址隔离。DeepSeek 固定官方地址并关闭思考。"];
    self.status.accessibilityLabel = @"设置状态";
    [stack addArrangedSubview:self.status];
    [self.status.widthAnchor constraintEqualToAnchor:stack.widthAnchor].active = YES;
    NSButton *save = [NSButton buttonWithTitle:@"保存" target:self action:@selector(save:)];
    NSButton *remove = [NSButton buttonWithTitle:@"删除当前地址密钥…" target:self action:@selector(removeKey:)];
    NSButton *prompts = [NSButton buttonWithTitle:@"话术管理…" target:self action:@selector(managePrompts:)];
    NSStackView *buttons = [NSStackView stackViewWithViews:@[prompts, remove, save]];
    buttons.spacing = 16;
    [stack addArrangedSubview:buttons];
    return self;
}
- (void)reload {
    NSDictionary *settings = YMAILoadSettings();
    self.models = [[NSUserDefaults.standardUserDefaults dictionaryForKey:@"YMAI.Models.SOVIET"] mutableCopy] ?: [NSMutableDictionary dictionary];
    self.models[settings[@"provider"]] = settings[@"model"];
    self.baseURLs = [[NSUserDefaults.standardUserDefaults dictionaryForKey:@"YMAI.BaseURLs.SOVIET"] mutableCopy] ?: [NSMutableDictionary dictionary];
    self.baseURLs[settings[@"provider"]] = settings[@"baseURL"];
    self.editingProvider = settings[@"provider"];
    [self.provider selectItemAtIndex:[YMAIProviderIDs() indexOfObject:self.editingProvider]];
    [self loadProvider];
    self.status.stringValue = @"密钥按接口协议和地址隔离。DeepSeek 固定官方地址并关闭思考。";
}
- (void)managePrompts:(id)sender {
    if (!self.promptController) self.promptController = [[YMAIPromptController alloc] init];
    if (!self.promptController.window.visible) [self.promptController reload];
    [self.promptController showWindow:nil];
    [self.promptController.window makeKeyAndOrderFront:nil];
}
- (void)loadProvider {
    id model = self.models[self.editingProvider];
    self.model.stringValue = [model isKindOfClass:NSString.class] ? model : @"";
    id base = self.baseURLs[self.editingProvider];
    BOOL deepSeek = [self.editingProvider isEqualToString:@"deepseek"];
    self.baseURL.stringValue = deepSeek ? YMAIDeepSeekBaseURL : ([base isKindOfClass:NSString.class] ? base : @"");
    self.baseURL.editable = !deepSeek;
    self.key.stringValue = @"";
    [self updateEndpoint];
}
- (void)updateEndpoint {
    NSError *error = nil;
    NSURL *endpoint = YMAIEndpoint(self.editingProvider, self.baseURL.stringValue, &error);
    NSString *protocol = [self.editingProvider isEqual:@"openai"] ? @"Responses" : @"Chat Completions";
    NSString *description = [self.editingProvider isEqualToString:@"deepseek"] ? @"DeepSeek 官方 · Chat Completions · 思考关闭" :
        [NSString stringWithFormat:@"%@（需目标服务支持）", protocol];
    self.endpoint.stringValue = [NSString stringWithFormat:@"协议：%@\n%@", description,
        endpoint ? [@"请求地址：" stringByAppendingString:endpoint.absoluteString] : error.localizedDescription];
    self.endpoint.toolTip = endpoint.absoluteString;
}
- (void)controlTextDidChange:(NSNotification *)notification {
    if (notification.object != self.baseURL) return;
    // Never carry an unsaved secret across edits to the destination.
    self.key.stringValue = @"";
    self.status.stringValue = @"地址已编辑，未保存的密钥输入已清空。请先确认地址，再填写对应密钥。";
    [self updateEndpoint];
}
- (void)providerChanged:(id)sender {
    self.models[self.editingProvider] = self.model.stringValue;
    self.baseURLs[self.editingProvider] = self.baseURL.stringValue;
    self.editingProvider = YMAIProviderIDs()[self.provider.indexOfSelectedItem];
    [self loadProvider];
}
- (void)save:(id)sender {
    NSError *error = nil;
    NSString *base = YMAINormalizeBaseURL(self.baseURL.stringValue, &error);
    if (!base) { self.status.stringValue = error.localizedDescription; return; }
    NSString *provider = [self.editingProvider copy];
    if (!YMAIEndpoint(provider, base, &error)) { self.status.stringValue = error.localizedDescription; return; }
    NSString *model = [self.model.stringValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!model.length || model.length > 128) { self.status.stringValue = @"请填写有效的模型 ID（不超过 128 字符）。"; return; }
    // Only the selected provider's key is written, so a failed save has no partial multi-key transaction.
    if (self.key.stringValue.length && !YMAIWriteKey(provider, base, self.key.stringValue, &error)) {
        self.status.stringValue = error.localizedDescription; return;
    }
    self.models[provider] = model;
    self.baseURLs[provider] = base;
    [NSUserDefaults.standardUserDefaults setObject:self.models forKey:@"YMAI.Models.SOVIET"];
    [NSUserDefaults.standardUserDefaults setObject:self.baseURLs forKey:@"YMAI.BaseURLs.SOVIET"];
    [NSUserDefaults.standardUserDefaults setObject:@{@"provider": provider, @"model": model,
        @"baseURL": base} forKey:YMAIPreferencesKey];
    [NSUserDefaults.standardUserDefaults removeObjectForKey:@"YMAI.Consent.SOVIET"];
    self.key.stringValue = @"";
    self.baseURL.stringValue = base;
    [self updateEndpoint];
    self.status.stringValue = @"已保存。新地址需对应 API Key；下次分析将重新确认上传目标。";
    [NSNotificationCenter.defaultCenter postNotificationName:YMAISettingsChangedNotification object:nil];
}
- (void)removeKey:(id)sender {
    NSString *provider = [self.editingProvider copy];
    NSError *error = nil;
    NSString *base = YMAINormalizeBaseURL(self.baseURL.stringValue, &error);
    if (!base) { self.status.stringValue = error.localizedDescription; return; }
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = [NSString stringWithFormat:@"删除 %@ 当前地址的 API Key？", YMAIProviderName(provider)];
    alert.informativeText = base;
    [alert addButtonWithTitle:@"删除"]; [alert addButtonWithTitle:@"取消"];
    [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse response) {
        if (response != NSAlertFirstButtonReturn) return;
        NSError *error = nil;
        if (!YMAIWriteKey(provider, base, @"", &error)) { self.status.stringValue = error.localizedDescription; return; }
        self.key.stringValue = @"";
        [NSUserDefaults.standardUserDefaults removeObjectForKey:@"YMAI.Consent.SOVIET"];
        self.status.stringValue = @"已删除密钥。";
        [NSNotificationCenter.defaultCenter postNotificationName:YMAISettingsChangedNotification object:nil];
    }];
}
- (void)windowWillClose:(NSNotification *)notification {
    self.key.stringValue = @"";
}
@end

void YMAIShowSettings(void) {
    static YMAISettingsController *controller;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ controller = [[YMAISettingsController alloc] init]; });
    if (!controller.window.visible) [controller reload];
    [controller showWindow:nil];
    [controller.window makeKeyAndOrderFront:nil];
}
