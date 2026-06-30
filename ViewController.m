#import "ViewController.h"
#import "TTHIDController.h"

@interface ViewController () <UITextFieldDelegate>
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) NSMutableString *logBuf;
@property (nonatomic, strong) UILabel *logLabel;
@property (nonatomic, strong) UITextField *xField, *yField, *intervalField;
@property (nonatomic, strong) UITextField *swFromX, *swFromY, *swToX, *swToY, *swSteps, *swDur;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithWhite:0.06 alpha:1.0];
    self.logBuf = [NSMutableString new];

    _scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    _scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:_scrollView];

    CGFloat w = self.view.bounds.size.width;
    CGFloat pad = 16.0, y = 40.0, btnH = 36.0;

    // 标题
    UILabel *t = [[UILabel alloc] initWithFrame:CGRectMake(pad, y, w - pad * 2, 22)];
    t.text = @"TrollTouch"; t.font = [UIFont boldSystemFontOfSize:20];
    t.textColor = [UIColor colorWithRed:0.2 green:0.7 blue:1.0 alpha:1.0];
    [_scrollView addSubview:t];
    y += 30;

    // === Tap Section ===
    y = [self addSectionLabel:@"-- Tap 点击 --" atY:y width:w pad:pad toView:_scrollView];

    _xField = [self fieldAtX:pad y:y width:90 placeholder:@"x" toView:_scrollView]; _xField.text = @"200";
    _yField = [self fieldAtX:pad + 100 y:y width:90 placeholder:@"y" toView:_scrollView]; _yField.text = @"400";
    _intervalField = [self fieldAtX:pad + 210 y:y width:100 placeholder:@"间隔(秒)" toView:_scrollView]; _intervalField.text = @"1.0";
    y += btnH + 6;

    UIButton *tapBtn = [self btnAtX:pad y:y width:w - pad * 2 height:btnH title:@"单次 Tap" color:[UIColor colorWithRed:0.15 green:0.55 blue:0.9 alpha:1.0] sel:@selector(doTap) toView:_scrollView];
    (void)tapBtn;
    y += btnH + 6;

    UIButton *startBtn = [self btnAtX:pad y:y width:(w - pad * 3) / 2 height:btnH title:@"开始循环" color:[UIColor colorWithRed:0.1 green:0.7 blue:0.4 alpha:1.0] sel:@selector(doStart) toView:_scrollView];
    UIButton *stopBtn = [self btnAtX:pad + (w - pad * 3) / 2 + pad y:y width:(w - pad * 3) / 2 height:btnH title:@"停止" color:[UIColor colorWithRed:0.85 green:0.25 blue:0.25 alpha:1.0] sel:@selector(doStop) toView:_scrollView];
    (void)startBtn; (void)stopBtn;
    y += btnH + 14;

    // === Swipe Section ===
    y = [self addSectionLabel:@"-- Swipe 滑动 --" atY:y width:w pad:pad toView:_scrollView];

    NSArray *swLabels = @[@"起点X", @"起点Y", @"终点X", @"终点Y", @"步数", @"时长"];
    for (int i = 0; i < 6; i++) {
        UITextField *tf = [self fieldAtX:pad + (i % 3) * 105 y:y + (i / 3) * (btnH + 6) width:95 placeholder:swLabels[i] toView:_scrollView];
        if (i == 0) { _swFromX = tf; tf.text = @"100"; }
        if (i == 1) { _swFromY = tf; tf.text = @"500"; }
        if (i == 2) { _swToX = tf; tf.text = @"100"; }
        if (i == 3) { _swToY = tf; tf.text = @"200"; }
        if (i == 4) { _swSteps = tf; tf.text = @"12"; tf.keyboardType = UIKeyboardTypeNumberPad; }
        if (i == 5) { _swDur = tf; tf.text = @"0.5"; tf.placeholder = @"总时长(秒)"; }
    }
    y += (btnH + 6) * 2 + 6;

    UIButton *swipeBtn = [self btnAtX:pad y:y width:w - pad * 2 height:btnH title:@"执行滑动" color:[UIColor colorWithWhite:1.0 alpha:0.15] sel:@selector(doSwipe) toView:_scrollView];
    (void)swipeBtn;
    y += btnH + 12;

    // === Status ===
    _statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(pad, y, w - pad * 2, 24)];
    _statusLabel.text = @"准备就绪";
    _statusLabel.textColor = [UIColor colorWithWhite:0.7 alpha:1.0];
    _statusLabel.font = [UIFont systemFontOfSize:14];
    [_scrollView addSubview:_statusLabel];
    y += 28;

    // === Log Section ===
    UILabel *logHeader = [[UILabel alloc] initWithFrame:CGRectMake(pad, y, w - pad * 2, 18)];
    logHeader.text = @"-- 日志 --";
    logHeader.textColor = [UIColor colorWithWhite:0.5 alpha:1.0];
    logHeader.font = [UIFont systemFontOfSize:12];
    [_scrollView addSubview:logHeader];
    y += 20;

    _logLabel = [[UILabel alloc] initWithFrame:CGRectMake(pad + 2, y, w - pad * 2 - 4, 140)];
    _logLabel.text = @"等待操作…";
    _logLabel.textColor = [UIColor colorWithWhite:0.6 alpha:1.0];
    _logLabel.font = [UIFont systemFontOfSize:10];
    _logLabel.numberOfLines = 0;
    [_scrollView addSubview:_logLabel];
    y += 146;

    UIButton *copyBtn = [self btnAtX:pad y:y width:w - pad * 2 height:btnH title:@"复制日志" color:[UIColor colorWithWhite:1.0 alpha:0.1] sel:@selector(copyLogs) toView:_scrollView];
    (void)copyBtn;
    y += btnH + 40;

    _scrollView.contentSize = CGSizeMake(w, MAX(y, self.view.bounds.size.height));

    [self log:@"控制器已启动"];
    TTHIDController *hid = [TTHIDController shared];
    __weak typeof(self) ws = self;
    [hid setLogHandler:^(NSString *msg) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [ws log:msg];
        });
    }];
    BOOL ok = [hid setup];
    [self log:ok ? @"HID 系统就绪" : @"HID 初始化失败 (检查 entitlement)"];
}

- (CGFloat)addSectionLabel:(NSString *)text atY:(CGFloat)y width:(CGFloat)w pad:(CGFloat)pad toView:(UIView *)parent {
    UIView *bar = [[UIView alloc] initWithFrame:CGRectMake(pad, y, w - pad * 2, 1)];
    bar.backgroundColor = [UIColor colorWithWhite:0.3 alpha:0.5];
    [parent addSubview:bar];
    y += 6;
    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(pad, y, w - pad * 2, 18)];
    lbl.text = text;
    lbl.textColor = [UIColor colorWithWhite:0.55 alpha:1.0];
    lbl.font = [UIFont boldSystemFontOfSize:12];
    [parent addSubview:lbl];
    return y + 20;
}

- (UITextField *)fieldAtX:(CGFloat)x y:(CGFloat)y width:(CGFloat)w placeholder:(NSString *)ph toView:(UIView *)parent {
    UITextField *tf = [[UITextField alloc] initWithFrame:CGRectMake(x, y, w, 36)];
    tf.placeholder = ph;
    tf.borderStyle = UITextBorderStyleRoundedRect;
    tf.keyboardType = UIKeyboardTypeDecimalPad;
    tf.textColor = UIColor.whiteColor;
    tf.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1.0];
    tf.font = [UIFont systemFontOfSize:14];
    tf.delegate = self;
    [parent addSubview:tf];
    return tf;
}

- (UIButton *)btnAtX:(CGFloat)x y:(CGFloat)y width:(CGFloat)w height:(CGFloat)h title:(NSString *)title color:(UIColor *)color sel:(SEL)sel toView:(UIView *)parent {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    b.frame = CGRectMake(x, y, w, h);
    [b setTitle:title forState:UIControlStateNormal];
    [b setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    b.backgroundColor = color;
    b.layer.cornerRadius = 8;
    b.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    [b addTarget:self action:sel forControlEvents:UIControlEventTouchUpInside];
    [parent addSubview:b];
    return b;
}

- (void)endEdit {
    for (UITextField *f in @[_xField, _yField, _intervalField, _swFromX, _swFromY, _swToX, _swToY, _swSteps, _swDur]) {
        [f resignFirstResponder];
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)tf { [self endEdit]; return YES; }

#pragma mark - log

- (void)log:(NSString *)m {
    [self.logBuf appendFormat:@"%@\n", m];
    NSArray *lines = [self.logBuf componentsSeparatedByString:@"\n"];
    NSUInteger max = 14, start = lines.count > max ? lines.count - max : 0;
    self.logLabel.text = [[lines subarrayWithRange:NSMakeRange(start, MIN(lines.count - start, max))] componentsJoinedByString:@"\n"];
}

- (void)copyLogs {
    [UIPasteboard generalPasteboard].string = self.logBuf ?: @"";
    [self log:@"日志已复制"];
}

#pragma mark - actions

- (void)doTap {
    [self endEdit];
    CGFloat x = _xField.text.floatValue, y = _yField.text.floatValue;
    self.statusLabel.text = [NSString stringWithFormat:@"点击 (%.0f, %.0f)", x, y];
    [self log:[NSString stringWithFormat:@"单次点击 (%.0f, %.0f)", x, y]];
    [[TTHIDController shared] tapAt:CGPointMake(x, y)];
}

- (void)doStart {
    [self endEdit];
    CGFloat x = _xField.text.floatValue, y = _yField.text.floatValue;
    NSTimeInterval iv = _intervalField.text.floatValue;
    if (iv < 0.1) iv = 1.0;
    self.statusLabel.text = [NSString stringWithFormat:@"循环中 (%.0f,%.0f) 间隔%.1fs", x, y, iv];
    [self log:[NSString stringWithFormat:@"开始循环 (%.0f,%.0f) 间隔%.1fs", x, y, iv]];
    [[TTHIDController shared] startRepeating:CGPointMake(x, y) interval:iv];
}

- (void)doStop {
    [[TTHIDController shared] stopRepeating];
    self.statusLabel.text = @"已停止";
    [self log:@"已停止"];
}

- (void)doSwipe {
    [self endEdit];
    CGPoint from = CGPointMake(_swFromX.text.floatValue, _swFromY.text.floatValue);
    CGPoint to   = CGPointMake(_swToX.text.floatValue, _swToY.text.floatValue);
    NSInteger steps = _swSteps.text.integerValue;
    if (steps < 2) steps = 8;
    NSTimeInterval dur = _swDur.text.floatValue;
    if (dur < 0.05) dur = 0.5;
    [self log:[NSString stringWithFormat:@"滑动 (%.0f,%.0f)->(%.0f,%.0f) %ld步 %.2fs",
        from.x, from.y, to.x, to.y, (long)steps, dur]];
    [[TTHIDController shared] swipeFrom:from to:to steps:steps duration:dur];
}

@end
