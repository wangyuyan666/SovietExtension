#import "YMAIWindowController.h"
#import "YMAISettings.h"
#import "YMAIService.h"
#import "YMAIPromptStore.h"
#import <QuartzCore/QuartzCore.h>

@interface YMAIWindowController : NSWindowController <NSWindowDelegate>
@property(nonatomic, strong) NSPopUpButton *promptSelection;
@property(nonatomic, strong) NSTextField *destination;
@property(nonatomic, strong) NSTextView *source;
@property(nonatomic, strong) NSTextView *analysis;
@property(nonatomic, strong) NSStackView *analysisSection;
@property(nonatomic, strong) NSTextField *status;
@property(nonatomic, strong) NSButton *generate;
@property(nonatomic, strong) NSButton *cancelButton;
@property(nonatomic, strong) NSProgressIndicator *spinner;
@property(nonatomic, strong) NSArray<NSTextView *> *replyViews;
@property(nonatomic, strong) NSArray<NSButton *> *replyCopyButtons;
@property(nonatomic, copy) NSString *message;
@property(nonatomic, copy) BOOL (^isCurrentAccount)(void);
@property(nonatomic, strong) YMAIRequest *request;
@property(nonatomic, strong) NSTimer *accountTimer;
@property(nonatomic) NSUInteger generation;
@property(nonatomic) BOOL busy;
@property(nonatomic) BOOL invalidAccount;
@property(nonatomic, strong) NSStackView *outer;
@property(nonatomic, strong) NSStackView *content;
@property(nonatomic, strong) NSScrollView *body;
@property(nonatomic) BOOL sizingWindow;
@property(nonatomic) BOOL windowSizeUpdatePending;
@end

@interface YMAIContentClipView : NSClipView
@property(nonatomic) BOOL allowsVerticalScrolling;
@end

@implementation YMAIContentClipView
- (BOOL)isFlipped { return YES; }
- (void)scrollToPoint:(NSPoint)point {
    NSRect proposed = self.bounds;
    proposed.origin = point;
    [super scrollToPoint:[self constrainBoundsRect:proposed].origin];
}
- (NSRect)constrainBoundsRect:(NSRect)proposedBounds {
    NSRect bounds = [super constrainBoundsRect:proposedBounds];
    bounds.origin.x = 0;
    if (!self.allowsVerticalScrolling) bounds.origin.y = 0;
    return bounds;
}
@end

@interface YMAIContentStackView : NSStackView
@property(nonatomic, copy) void (^layoutChanged)(void);
@end

@implementation YMAIContentStackView
- (BOOL)isFlipped { return YES; }
- (void)layout {
    [super layout];
    if (self.layoutChanged) self.layoutChanged();
}
@end

@interface YMAIAutoSizingTextArea : NSScrollView
@property(nonatomic, strong) NSLayoutConstraint *contentHeight;
@end

@implementation YMAIAutoSizingTextArea
- (void)textStorageChanged:(NSNotification *)notification {
    [self.contentView scrollToPoint:NSZeroPoint];
    self.needsLayout = YES;
}
- (void)layout {
    [super layout];
    NSTextView *view = (NSTextView *)self.documentView;
    CGFloat width = self.contentSize.width;
    if (!view || width <= 0) return;
    // Measure at the actual viewport width, including text-container padding.
    [view setFrameSize:NSMakeSize(width, view.frame.size.height)];
    view.textContainer.containerSize = NSMakeSize(MAX(1, width - 2 * view.textContainerInset.width), CGFLOAT_MAX);
    [view.layoutManager ensureLayoutForTextContainer:view.textContainer];
    CGFloat textHeight = NSMaxY([view.layoutManager usedRectForTextContainer:view.textContainer]);
    if (view.layoutManager.extraLineFragmentTextContainer == view.textContainer) {
        textHeight = MAX(textHeight, NSMaxY(view.layoutManager.extraLineFragmentRect));
    }
    // Keep the viewport fixed while the document grows enough to scroll all text.
    CGFloat height = MAX(self.contentSize.height, ceil(textHeight + 2 * view.textContainerInset.height));
    view.minSize = NSMakeSize(0, 0);
    [view setFrameSize:NSMakeSize(width, height)];
    [self.contentView scrollToPoint:self.contentView.bounds.origin];
}
- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}
@end

static NSScrollView *YMAITextArea(NSTextView **out, NSString *label, CGFloat height) {
    YMAIAutoSizingTextArea *scroll = [[YMAIAutoSizingTextArea alloc] init];
    YMAIContentClipView *clip = [[YMAIContentClipView alloc] init];
    clip.allowsVerticalScrolling = YES;
    scroll.contentView = clip;
    scroll.hasVerticalScroller = YES;
    scroll.scrollerStyle = NSScrollerStyleOverlay;
    scroll.hasHorizontalScroller = NO;
    scroll.horizontalScrollElasticity = NSScrollElasticityNone;
    scroll.verticalScrollElasticity = NSScrollElasticityNone;
    scroll.borderType = NSNoBorder;
    scroll.wantsLayer = YES;
    scroll.layer.cornerRadius = 12.0;
    scroll.layer.masksToBounds = YES;
    NSTextView *view = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 520, 48)];
    view.editable = NO;
    view.selectable = YES;
    view.richText = NO;
    view.font = [NSFont systemFontOfSize:13];
    view.textColor = NSColor.textColor;
    view.backgroundColor = NSColor.textBackgroundColor;
    view.textContainerInset = NSMakeSize(24, 12);
    view.autoresizingMask = NSViewWidthSizable;
    view.verticallyResizable = YES;
    view.horizontallyResizable = NO;
    view.textContainer.widthTracksTextView = YES;
    view.textContainer.containerSize = NSMakeSize(520, CGFLOAT_MAX);
    view.accessibilityLabel = label;
    scroll.documentView = view;
    scroll.contentHeight = [scroll.heightAnchor constraintEqualToConstant:height];
    scroll.contentHeight.active = YES;
    [NSNotificationCenter.defaultCenter addObserver:scroll selector:@selector(textStorageChanged:)
        name:NSTextStorageDidProcessEditingNotification object:view.textStorage];
    *out = view;
    return scroll;
}

@implementation YMAIWindowController
- (instancetype)init {
    NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 600, 820)
        styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskResizable
        backing:NSBackingStoreBuffered defer:NO];
    self = [super initWithWindow:window];
    if (!self) return nil;
    window.title = @"AI 分析";
    window.releasedWhenClosed = NO;
    window.contentMinSize = NSMakeSize(520, 240);
    window.delegate = self;
    [window center];
    YMAIContentStackView *outer = [[YMAIContentStackView alloc] init];
    self.outer = outer;
    __weak typeof(self) weakSelf = self;
    outer.layoutChanged = ^{ [weakSelf scheduleWindowSizeUpdate]; };
    outer.orientation = NSUserInterfaceLayoutOrientationVertical;
    outer.alignment = NSLayoutAttributeLeading;
    outer.spacing = 12;
    outer.translatesAutoresizingMaskIntoConstraints = NO;
    [window.contentView addSubview:outer];
    [NSLayoutConstraint activateConstraints:@[
        [outer.topAnchor constraintEqualToAnchor:window.contentView.topAnchor constant:20],
        [outer.bottomAnchor constraintLessThanOrEqualToAnchor:window.contentView.bottomAnchor constant:-20],
        [outer.leadingAnchor constraintEqualToAnchor:window.contentView.leadingAnchor constant:20],
        [outer.trailingAnchor constraintEqualToAnchor:window.contentView.trailingAnchor constant:-20]]];
    self.destination = [NSTextField wrappingLabelWithString:@""];
    self.destination.font = [NSFont systemFontOfSize:12];
    self.destination.textColor = NSColor.secondaryLabelColor;

    NSScrollView *body = [[NSScrollView alloc] init];
    self.body = body;
    YMAIContentClipView *bodyClip = [[YMAIContentClipView alloc] init];
    bodyClip.allowsVerticalScrolling = YES;
    body.contentView = bodyClip;
    body.hasVerticalScroller = YES;
    body.hasHorizontalScroller = NO;
    body.horizontalScrollElasticity = NSScrollElasticityNone;
    body.drawsBackground = NO;
    [outer addArrangedSubview:body];
    [body.widthAnchor constraintEqualToAnchor:outer.widthAnchor].active = YES;
    [body.heightAnchor constraintGreaterThanOrEqualToConstant:48].active = YES;
    YMAIContentStackView *content = [[YMAIContentStackView alloc] init];
    self.content = content;
    content.layoutChanged = ^{ [weakSelf scheduleWindowSizeUpdate]; };
    content.orientation = NSUserInterfaceLayoutOrientationVertical;
    content.alignment = NSLayoutAttributeLeading;
    content.spacing = 10;
    content.translatesAutoresizingMaskIntoConstraints = NO;
    body.documentView = content;
    [NSLayoutConstraint activateConstraints:@[
        [content.widthAnchor constraintEqualToAnchor:body.contentView.widthAnchor],
        [content.leadingAnchor constraintEqualToAnchor:body.contentView.leadingAnchor],
        [content.topAnchor constraintEqualToAnchor:body.contentView.topAnchor]]];
    // Fit short content without a trailing gap; allow scrolling when the page is taller than the window.
    NSLayoutConstraint *bodyContentHeight = [body.heightAnchor constraintEqualToAnchor:content.heightAnchor];
    bodyContentHeight.priority = NSLayoutPriorityDefaultHigh;
    bodyContentHeight.active = YES;
    NSTextView *source, *analysis;
    [content addArrangedSubview:[NSTextField labelWithString:@"本次上传：以下正文及所选话术"]];
    NSScrollView *sourceArea = YMAITextArea(&source, @"选中消息原文", 80);
    [content addArrangedSubview:sourceArea];
    [sourceArea.widthAnchor constraintEqualToAnchor:content.widthAnchor].active = YES;
    self.source = source;
    NSScrollView *analysisArea = YMAITextArea(&analysis, @"分析结果", 120);
    self.analysisSection = [NSStackView stackViewWithViews:@[
        [NSTextField labelWithString:@"分析结果"], analysisArea]];
    self.analysisSection.orientation = NSUserInterfaceLayoutOrientationVertical;
    self.analysisSection.alignment = NSLayoutAttributeLeading;
    self.analysisSection.spacing = 10;
    [content addArrangedSubview:self.analysisSection];
    [self.analysisSection.widthAnchor constraintEqualToAnchor:content.widthAnchor].active = YES;
    [analysisArea.widthAnchor constraintEqualToAnchor:self.analysisSection.widthAnchor].active = YES;
    self.analysis = analysis;
    NSMutableArray *views = [NSMutableArray array], *buttons = [NSMutableArray array];
    for (NSInteger i = 0; i < 3; i++) {
        NSTextField *title = [NSTextField labelWithString:[NSString stringWithFormat:@"回复建议 %ld", (long)i + 1]];
        NSButton *copy = [NSButton buttonWithTitle:@"复制" target:self action:@selector(copyReply:)];
        copy.tag = i; copy.enabled = NO;
        copy.accessibilityLabel = [NSString stringWithFormat:@"复制回复建议 %ld", (long)i + 1];
        NSStackView *row = [NSStackView stackViewWithViews:@[title, copy]];
        row.spacing = 16;
        [content addArrangedSubview:row];
        NSTextView *reply;
        NSScrollView *area = YMAITextArea(&reply, title.stringValue, 60);
        [content addArrangedSubview:area];
        [area.widthAnchor constraintEqualToAnchor:content.widthAnchor].active = YES;
        [views addObject:reply]; [buttons addObject:copy];
    }
    self.replyViews = views; self.replyCopyButtons = buttons;
    self.promptSelection = [[NSPopUpButton alloc] init];
    for (NSString *identifier in YMAIPromptIDs()) [self.promptSelection addItemWithTitle:YMAIPromptTitle(identifier)];
    self.promptSelection.accessibilityLabel = @"本次话术";
    self.promptSelection.target = self;
    self.promptSelection.action = @selector(promptChanged:);
    NSStackView *promptRow = [NSStackView stackViewWithViews:@[[NSTextField labelWithString:@"本次话术"], self.promptSelection]];
    promptRow.spacing = 12;
    [outer addArrangedSubview:promptRow];
    self.status = [NSTextField wrappingLabelWithString:@"AI 建议可能有误，请核对后使用；不会自动发送。"];
    self.status.font = [NSFont systemFontOfSize:12];
    [outer addArrangedSubview:self.status];
    [self.status.widthAnchor constraintEqualToAnchor:outer.widthAnchor].active = YES;
    self.spinner = [[NSProgressIndicator alloc] init];
    self.spinner.style = NSProgressIndicatorStyleSpinning;
    self.spinner.controlSize = NSControlSizeSmall;
    self.spinner.displayedWhenStopped = NO;
    self.generate = [NSButton buttonWithTitle:@"重新分析" target:self action:@selector(generate:)];
    self.cancelButton = [NSButton buttonWithTitle:@"取消" target:self action:@selector(cancel:)];
    self.cancelButton.enabled = NO;
    NSButton *settings = [NSButton buttonWithTitle:@"AI 设置…" target:self action:@selector(settings:)];
    NSStackView *actions = [NSStackView stackViewWithViews:@[settings, self.spinner, self.cancelButton, self.generate]];
    actions.spacing = 12;
    [outer addArrangedSubview:actions];
    [outer addArrangedSubview:self.destination];
    [self.destination.widthAnchor constraintEqualToAnchor:outer.widthAnchor].active = YES;
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(settingsChanged:)
                                              name:YMAISettingsChangedNotification object:nil];
    [self scheduleWindowSizeUpdate];
    return self;
}
- (void)scheduleWindowSizeUpdate {
    if (self.sizingWindow || self.windowSizeUpdatePending) return;
    self.windowSizeUpdatePending = YES;
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        typeof(self) self = weakSelf;
        if (!self) return;
        self.windowSizeUpdatePending = NO;
        [self fitWindowToContent];
    });
}
- (void)fitWindowToContent {
    if (self.sizingWindow || self.window.inLiveResize) return;
    self.sizingWindow = YES;
    [self.window.contentView layoutSubtreeIfNeeded];
    CGFloat height = 40;
    NSUInteger count = 0;
    for (NSView *view in self.outer.arrangedSubviews) {
        if (view.hidden) continue;
        height += view == self.body ? self.content.fittingSize.height : view.frame.size.height;
        count++;
    }
    if (count > 1) height += (count - 1) * self.outer.spacing;
    NSScreen *screen = self.window.screen ?: NSScreen.mainScreen;
    NSRect frame = self.window.frame;
    CGFloat chromeHeight = frame.size.height - self.window.contentView.frame.size.height;
    CGFloat maximumHeight = screen ? screen.visibleFrame.size.height - chromeHeight : height;
    height = ceil(MIN(MAX(240, height), maximumHeight));
    if (fabs(self.window.contentView.frame.size.height - height) > 0.5) {
        CGFloat frameHeight = height + chromeHeight;
        frame.origin.y = NSMaxY(frame) - frameHeight;
        frame.size.height = frameHeight;
        if (screen) frame.origin.y = MAX(NSMinY(screen.visibleFrame), MIN(frame.origin.y, NSMaxY(screen.visibleFrame) - frameHeight));
        [self.window setFrame:frame display:YES];
        [self.window.contentView layoutSubtreeIfNeeded];
    }
    self.sizingWindow = NO;
}
- (void)windowDidResize:(NSNotification *)notification {
    [self scheduleWindowSizeUpdate];
}
- (void)windowDidEndLiveResize:(NSNotification *)notification {
    [self scheduleWindowSizeUpdate];
}
- (void)windowDidChangeScreen:(NSNotification *)notification {
    [self scheduleWindowSizeUpdate];
}
- (void)setRunning:(BOOL)running {
    self.busy = running;
    self.promptSelection.enabled = !running && !self.invalidAccount;
    self.generate.enabled = !running && !self.invalidAccount;
    self.cancelButton.enabled = running;
    if (running) [self.spinner startAnimation:nil]; else [self.spinner stopAnimation:nil];
}
- (void)clearResults {
    self.analysis.string = @"";
    for (NSTextView *view in self.replyViews) view.string = @"";
    for (NSButton *button in self.replyCopyButtons) button.enabled = NO;
}
- (void)cancel:(id)sender {
    self.generation++;
    [self.request cancel]; self.request = nil;
    if (self.window.attachedSheet) [self.window endSheet:self.window.attachedSheet returnCode:NSModalResponseCancel];
    [self setRunning:NO];
    self.status.stringValue = @"已取消；没有发送回复。";
}
- (BOOL)checkAccount {
    if (self.invalidAccount) return NO;
    if (!self.isCurrentAccount || !self.isCurrentAccount()) {
        self.invalidAccount = YES;
        [self cancel:nil]; [self clearResults];
        self.message = nil; self.source.string = @"";
        self.status.stringValue = @"账号已变化或无法确认，已清除内容。请重新右键选择消息。";
        return NO;
    }
    return YES;
}
- (void)presentText:(NSString *)text session:(NSString *)session sender:(NSString *)sender
           account:(BOOL (^)(void))account {
    [self cancel:nil]; [self clearResults];
    self.invalidAccount = NO;
    self.isCurrentAccount = account;
    self.message = text;
    [self.promptSelection selectItemAtIndex:[YMAIPromptIDs() indexOfObject:YMAIPromptStore.sharedStore.selectedIdentifier]];
    self.source.string = text;
    [self setRunning:NO];
    [self fitWindowToContent];
    [self showWindow:nil]; [self.window makeKeyAndOrderFront:nil];
    [self.accountTimer invalidate];
    __weak typeof(self) weakSelf = self;
    self.accountTimer = [NSTimer timerWithTimeInterval:0.5 repeats:YES block:^(NSTimer *timer) { [weakSelf checkAccount]; }];
    [NSRunLoop.mainRunLoop addTimer:self.accountTimer forMode:NSRunLoopCommonModes];
    [self generate:nil];
}
- (void)promptChanged:(id)sender {
    [self cancel:nil]; [self clearResults];
    self.status.stringValue = @"话术已切换，点击「重新分析」生成新建议。";
}
- (void)settings:(id)sender { YMAIShowSettings(); }
- (void)settingsChanged:(NSNotification *)notification {
    [self cancel:nil]; [self clearResults];
    [self.promptSelection selectItemAtIndex:[YMAIPromptIDs() indexOfObject:YMAIPromptStore.sharedStore.selectedIdentifier]];
    self.status.stringValue = @"AI 设置已变更。请点击「重新分析」，确认新的上传目标。";
    [self updateDestination];
}
- (void)updateDestination {
    NSDictionary *settings = YMAILoadSettings();
    NSURL *endpoint = YMAIEndpoint(settings[@"provider"], settings[@"baseURL"], NULL);
    self.destination.stringValue = [NSString stringWithFormat:@"%@ · %@\n%@ · 不额外上传会话及账号标识",
        YMAIProviderName(settings[@"provider"]), [settings[@"model"] length] ? settings[@"model"] : @"尚未配置模型",
        endpoint.absoluteString ?: @"请先填写有效的 Base URL"];
    self.destination.toolTip = endpoint.absoluteString;
    self.destination.maximumNumberOfLines = 3;
    self.destination.lineBreakMode = NSLineBreakByTruncatingMiddle;
}
- (void)generate:(id)sender {
    if (self.busy || ![self checkAccount]) return;
    [self updateDestination];
    NSMutableDictionary *settings = [YMAILoadSettings() mutableCopy];
    settings[@"prompts"] = YMAIPromptStore.sharedStore.prompts;
    settings[@"promptIdentifier"] = YMAIPromptIDs()[self.promptSelection.indexOfSelectedItem];
    NSError *error = nil;
    NSURL *endpoint = YMAIEndpoint(settings[@"provider"], settings[@"baseURL"], &error);
    if (!endpoint) { self.status.stringValue = error.localizedDescription; return; }
    if (!YMAIRequestBody(settings[@"provider"], settings[@"model"], settings[@"prompts"], settings[@"promptIdentifier"], self.message,
                        &error)) { self.status.stringValue = error.localizedDescription; return; }
    NSString *consent = YMAICredentialScope(settings[@"provider"], settings[@"baseURL"], NULL);
    NSUInteger token = ++self.generation;
    if (![[NSUserDefaults.standardUserDefaults stringForKey:@"YMAI.Consent.SOVIET"] isEqual:consent]) {
        [self setRunning:YES];
        self.status.stringValue = @"等待上传确认，尚未发送请求。";
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"允许向以下自定义地址发送聊天正文和 API 凭据？";
        alert.informativeText = [NSString stringWithFormat:@"接口协议：%@\n目标地址：%@\n提交窗口中的正文及公共和所选场景话术，不读取其他聊天。内容可能包含私人信息，保留政策以目标服务为准。\n确认后，后续主动点击「AI 分析」或「重新分析」将提交内容。切换配置会重新确认。",
            YMAIProviderName(settings[@"provider"]), endpoint.absoluteString];
        [alert addButtonWithTitle:@"同意并分析"]; [alert addButtonWithTitle:@"取消"];
        [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse result) {
            if (token != self.generation) return;
            [self setRunning:NO];
            if (result != NSAlertFirstButtonReturn) { self.status.stringValue = @"已取消上传。"; return; }
            if (![self checkAccount]) return;
            [NSUserDefaults.standardUserDefaults setObject:consent forKey:@"YMAI.Consent.SOVIET"];
            [self submit:settings token:token];
        }];
    } else [self submit:settings token:token];
}
- (void)submit:(NSDictionary *)settings token:(NSUInteger)token {
    if (![self checkAccount]) return;
    NSError *error = nil;
    NSString *key = YMAIReadKey(settings[@"provider"], settings[@"baseURL"], &error);
    // Keychain may present a permission dialog and run a nested event loop.
    if (token != self.generation || !self.window.visible || ![self checkAccount]) return;
    if (!key.length) { self.status.stringValue = error.localizedDescription ?: @"请先在 AI 设置中保存 API Key。"; return; }
    [self clearResults]; [self setRunning:YES];
    self.status.stringValue = @"正在分析，可取消。关闭窗口会停止等待；已上传的内容无法撤回。";
    self.request = [[YMAIRequest alloc] init];
    __weak typeof(self) weakSelf = self;
    [self.request startProvider:settings[@"provider"] baseURL:settings[@"baseURL"] model:settings[@"model"] key:key
        prompts:settings[@"prompts"] promptIdentifier:settings[@"promptIdentifier"]
        text:self.message configuration:NSURLSessionConfiguration.ephemeralSessionConfiguration
        completion:^(NSDictionary *result, NSError *requestError) {
            typeof(self) self = weakSelf;
            if (!self || token != self.generation || !self.window.visible || ![self checkAccount]) return;
            self.request = nil;
            [self setRunning:NO];
            if (requestError) { self.status.stringValue = requestError.localizedDescription; return; }
            self.analysis.string = result[@"analysis"];
            NSArray *replies = result[@"replies"];
            for (NSUInteger i = 0; i < replies.count; i++) {
                self.replyViews[i].string = replies[i]; self.replyCopyButtons[i].enabled = YES;
            }
            self.status.stringValue = @"生成完成。AI 建议可能有误，请核对后复制；不会自动发送。";
        }];
}
- (void)copyReply:(NSButton *)sender {
    if (![self checkAccount] || sender.tag < 0 || sender.tag >= (NSInteger)self.replyViews.count) return;
    NSString *text = self.replyViews[sender.tag].string;
    if (!text.length) return;
    [NSPasteboard.generalPasteboard clearContents];
    BOOL ok = [NSPasteboard.generalPasteboard setString:text forType:NSPasteboardTypeString];
    self.status.stringValue = ok ? @"已复制。请确认目标会话后自行粘贴；剪贴板可能被其他应用读取。" : @"复制失败，请手动选择文本复制。";
}
- (void)windowWillClose:(NSNotification *)notification {
    [self cancel:nil]; [self.accountTimer invalidate]; self.accountTimer = nil;
    self.message = nil; self.isCurrentAccount = nil; self.source.string = @"";
    [self clearResults];
}
@end

void YMAIShowAnalysis(NSString *text, NSString *session, NSString *sender, BOOL (^isCurrentAccount)(void)) {
    NSCAssert(NSThread.isMainThread, @"AI UI requires the main thread");
    static YMAIWindowController *controller;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ controller = [[YMAIWindowController alloc] init]; });
    [controller presentText:[text copy] session:[session copy] sender:[sender copy] account:isCurrentAccount];
}
