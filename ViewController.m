#import "ViewController.h"
#import "TTAXController.h"

@interface ViewController () <UITextFieldDelegate>
@property (nonatomic,strong) UIScrollView *scrollView;
@property (nonatomic,strong) UITextField *xField, *yField, *intervalField;
@property (nonatomic,strong) UITextField *swFromX, *swFromY, *swToX, *swToY, *swSteps, *swDur;
@property (nonatomic,strong) UILabel *logLabel, *statusLabel;
@property (nonatomic,strong) NSMutableString *logBuf;
@property (nonatomic,strong) UIView *dotPreview;
@property (nonatomic,assign) CGPoint targetPoint;
@property (nonatomic,strong) NSTimer *repeatTimer;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithWhite:0.07 alpha:1.0];
    self.logBuf = [NSMutableString new];
    self.targetPoint = CGPointMake(200, 400);

    _scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    _scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    _scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    [self.view addSubview:_scrollView];

    CGFloat w = self.view.bounds.size.width, pad = 14.0, y = 30.0, btnH = 34.0;

    UILabel *t = [[UILabel alloc] initWithFrame:CGRectMake(pad, y, w-pad*2, 26)];
    t.text = @"TrollTouch AX"; t.font = [UIFont boldSystemFontOfSize:20];
    t.textColor = [UIColor colorWithRed:0.2 green:0.7 blue:1.0 alpha:1.0];
    [_scrollView addSubview:t]; y += 34;

    // 状态/授权
    _statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(pad, y, w-pad*2, 20)];
    _statusLabel.text = @"初始化中…";
    _statusLabel.textColor = [UIColor colorWithWhite:0.6 alpha:1.0];
    _statusLabel.font = [UIFont systemFontOfSize:13];
    [_scrollView addSubview:_statusLabel]; y += 26;

    // 坐标输入区
    [self addLabel:@"X" atX:pad y:y w:14]; _xField = [self fieldAtX:pad+16 y:y w:75 ph:@"200"];
    [self addLabel:@"Y" atX:pad+100 y:y w:14]; _yField = [self fieldAtX:pad+116 y:y w:75 ph:@"400"];
    [self addLabel:@"间隔" atX:pad+200 y:y w:30]; _intervalField = [self fieldAtX:pad+230 y:y w:75 ph:@"1.0"];
    y += btnH + 6;

    // Tap 按钮 + 循环按钮
    UIButton *tapBtn = [self btnAtX:pad y:y w:(w-pad*3)/2 h:btnH title:@"单击" color:[UIColor colorWithRed:0.12 green:0.55 blue:0.92 alpha:1.0] sel:@selector(doTap)];
    UIButton *startBtn = [self btnAtX:pad+(w-pad*3)/2+pad y:y w:(w-pad*3)/2 h:btnH title:@"开始循环" color:[UIColor colorWithRed:0.08 green:0.65 blue:0.35 alpha:1.0] sel:@selector(doStart)];
    UIButton *stopBtn = [self btnAtX:pad y:y+btnH+4 w:(w-pad*3)/2 h:btnH title:@"停止" color:[UIColor colorWithRed:0.85 green:0.25 blue:0.25 alpha:1.0] sel:@selector(doStop)];
    UIButton *swipeBtn = [self btnAtX:pad+(w-pad*3)/2+pad y:y+btnH+4 w:(w-pad*3)/2 h:btnH title:@"执行滑动" color:[UIColor colorWithWhite:1.0 alpha:0.12] sel:@selector(doSwipe)];
    [self addButtons:@[tapBtn,startBtn,stopBtn,swipeBtn]];
    y += btnH*2 + 12;

    // 滑动设置
    y = [self sectionLineAt:y text:@"-- 滑动参数 --" w:w pad:pad];
    _swFromX = [self fieldAtX:pad y:y w:60 ph:@"起X"]; _swFromX.text = @"100";
    _swFromY = [self fieldAtX:pad+68 y:y w:60 ph:@"起Y"]; _swFromY.text = @"500";
    _swToX = [self fieldAtX:pad+136 y:y w:60 ph:@"终X"]; _swToX.text = @"100";
    _swToY = [self fieldAtX:pad+204 y:y w:60 ph:@"终Y"]; _swToY.text = @"200";
    _swSteps = [self fieldAtX:pad+272 y:y w:55 ph:@"步数"]; _swSteps.text = @"10"; _swSteps.keyboardType = UIKeyboardTypeNumberPad;
    y += 36;
    _swDur = [self fieldAtX:pad y:y w:100 ph:@"总时长(秒)"]; _swDur.text = @"0.5";
    y += 38;

    // 红圈预览区
    UIView *preview = [[UIView alloc] initWithFrame:CGRectMake(pad, y, w-pad*2, 80)];
    preview.backgroundColor = [UIColor colorWithWhite:0.12 alpha:1.0];
    preview.layer.cornerRadius = 8;
    UILabel *pl = [[UILabel alloc] initWithFrame:CGRectMake(8, 4, 120, 16)];
    pl.text = @"红圈示意"; pl.textColor = [UIColor colorWithWhite:0.5 alpha:1.0]; pl.font = [UIFont systemFontOfSize:10];
    [preview addSubview:pl];
    _dotPreview = [[UIView alloc] initWithFrame:CGRectMake(40, 30, 12, 12)];
    _dotPreview.backgroundColor = [UIColor colorWithRed:1.0 green:0.15 blue:0.15 alpha:0.7];
    _dotPreview.layer.cornerRadius = 6; _dotPreview.layer.borderColor = UIColor.whiteColor.CGColor; _dotPreview.layer.borderWidth = 1.5;
    [preview addSubview:_dotPreview];
    [_scrollView addSubview:preview];
    y += 90;

    // 日志
    UILabel *logH = [[UILabel alloc] initWithFrame:CGRectMake(pad, y, w-pad*2, 18)];
    logH.text = @"-- 运行日志 --"; logH.textColor = [UIColor colorWithWhite:0.5 alpha:1.0]; logH.font = [UIFont systemFontOfSize:12];
    [_scrollView addSubview:logH]; y += 20;
    _logLabel = [[UILabel alloc] initWithFrame:CGRectMake(pad, y, w-pad*2, 140)];
    _logLabel.text = @"等待操作…"; _logLabel.textColor = [UIColor colorWithWhite:0.6 alpha:1.0]; _logLabel.font = [UIFont systemFontOfSize:10];
    _logLabel.numberOfLines = 0; [_scrollView addSubview:_logLabel]; y += 146;

    UIButton *copyBtn = [self btnAtX:pad y:y w:(w-pad*2) h:btnH title:@"复制日志" color:[UIColor colorWithWhite:1.0 alpha:0.1] sel:@selector(copyLogs)];
    [self addButtons:@[copyBtn]]; y += btnH + 30;

    _scrollView.contentSize = CGSizeMake(w, MAX(y, self.view.bounds.size.height));

    // keyboard
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(kbWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(kbWillHide:) name:UIKeyboardWillHideNotification object:nil];

    // AX setup
    TTAXController *ax = [TTAXController shared];
    __weak typeof(self) ws = self;
    [ax setLogBlock:^(NSString *m) { dispatch_async(dispatch_get_main_queue(), ^{ [ws log:m]; }); }];
    BOOL ok = [ax checkAccess];
    _statusLabel.text = ok ? @"AX 就绪，切到目标App后点「单击」" : @"请在 设置→辅助功能 中授权此App";
    _statusLabel.textColor = ok ? [UIColor colorWithRed:0.1 green:0.8 blue:0.4 alpha:1.0] : [UIColor colorWithRed:0.9 green:0.3 blue:0.2 alpha:1.0];
}

- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }

#pragma mark - helpers

- (void)addLabel:(NSString *)t atX:(CGFloat)x y:(CGFloat)y w:(CGFloat)w {
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(x, y+6, w, 20)];
    l.text = t; l.textColor = UIColor.whiteColor; l.font = [UIFont systemFontOfSize:13];
    [_scrollView addSubview:l];
}
- (UITextField *)fieldAtX:(CGFloat)x y:(CGFloat)y w:(CGFloat)w ph:(NSString *)ph {
    UITextField *tf = [[UITextField alloc] initWithFrame:CGRectMake(x, y, w, 34)];
    tf.placeholder = ph; tf.borderStyle = UITextBorderStyleRoundedRect;
    tf.keyboardType = UIKeyboardTypeDecimalPad; tf.textColor = UIColor.whiteColor;
    tf.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1.0]; tf.font = [UIFont systemFontOfSize:14];
    tf.delegate = self; [_scrollView addSubview:tf]; return tf;
}
- (UIButton *)btnAtX:(CGFloat)x y:(CGFloat)y w:(CGFloat)w h:(CGFloat)h title:(NSString *)t color:(UIColor *)c sel:(SEL)s {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    b.frame = CGRectMake(x, y, w, h); [b setTitle:t forState:UIControlStateNormal];
    [b setTitleColor:UIColor.whiteColor forState:UIControlStateNormal]; b.backgroundColor = c;
    b.layer.cornerRadius = 7; b.titleLabel.font = [UIFont boldSystemFontOfSize:13];
    [b addTarget:self action:s forControlEvents:UIControlEventTouchUpInside]; return b;
}
- (void)addButtons:(NSArray *)btns { for (UIButton *b in btns) [_scrollView addSubview:b]; }
- (CGFloat)sectionLineAt:(CGFloat)y text:(NSString *)t w:(CGFloat)w pad:(CGFloat)pad {
    UIView *line = [[UIView alloc] initWithFrame:CGRectMake(pad, y, w-pad*2, 1)];
    line.backgroundColor = [UIColor colorWithWhite:0.3 alpha:0.5]; [_scrollView addSubview:line];
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(pad, y+4, w-pad*2, 16)];
    l.text = t; l.textColor = [UIColor colorWithWhite:0.5 alpha:1.0]; l.font = [UIFont systemFontOfSize:11];
    [_scrollView addSubview:l]; return y + 20;
}
- (void)endEdit { for (UITextField *f in @[_xField,_yField,_intervalField,_swFromX,_swFromY,_swToX,_swToY,_swSteps,_swDur]) [f resignFirstResponder]; }
- (BOOL)textFieldShouldReturn:(UITextField *)tf { [self endEdit]; return YES; }

#pragma mark - keyboard

- (void)kbWillShow:(NSNotification *)n {
    CGRect kf = [n.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    _scrollView.contentInset = UIEdgeInsetsMake(0, 0, kf.size.height, 0);
}
- (void)kbWillHide:(NSNotification *)n { _scrollView.contentInset = UIEdgeInsetsZero; }

#pragma mark - log & dot

- (void)log:(NSString *)m {
    [self.logBuf appendFormat:@"%@\n", m];
    NSArray *lines = [self.logBuf componentsSeparatedByString:@"\n"];
    NSUInteger max = 14, start = lines.count > max ? lines.count - max : 0;
    self.logLabel.text = [[lines subarrayWithRange:NSMakeRange(start, MIN(lines.count-start, max))] componentsJoinedByString:@"\n"];
}
- (void)copyLogs { [UIPasteboard generalPasteboard].string = self.logBuf?:@""; [self log:@"日志已复制"]; }
- (void)updateDot:(CGPoint)p {
    CGFloat scale = 80.0 / MAX(UIScreen.mainScreen.bounds.size.width, UIScreen.mainScreen.bounds.size.height);
    CGFloat dx = p.x * scale, dy = p.y * scale;
    dx = MAX(6, MIN(80-12, dx)); dy = MAX(6, MIN(80-12, dy));
    _dotPreview.frame = CGRectMake(dx, dy, 12, 12);
}

#pragma mark - actions

- (void)doTap {
    [self endEdit];
    CGFloat x = _xField.text.floatValue, y = _yField.text.floatValue;
    if (x <= 0) x = 200; if (y <= 0) y = 400;
    self.targetPoint = CGPointMake(x, y);
    [self updateDot:self.targetPoint];
    [self log:[NSString stringWithFormat:@"AX 单击 (%.0f,%.0f)", x, y]];
    [[TTAXController shared] tapAt:self.targetPoint];
}

- (void)doStart {
    [self endEdit];
    CGFloat x = _xField.text.floatValue, y = _yField.text.floatValue;
    if (x <= 0) x = 200; if (y <= 0) y = 400;
    NSTimeInterval iv = _intervalField.text.floatValue; if (iv < 0.1) iv = 1.0;
    [self stopRepeat];
    self.targetPoint = CGPointMake(x, y);
    [self log:[NSString stringWithFormat:@"开始循环 (%.0f,%.0f) 间隔%.1fs", x, y, iv]];
    TTAXController *ax = [TTAXController shared];
    self.repeatTimer = [NSTimer scheduledTimerWithTimeInterval:iv repeats:YES block:^(NSTimer *t) {
        [ax tapAt:self.targetPoint];
    }];
    [[NSRunLoop mainRunLoop] addTimer:self.repeatTimer forMode:NSRunLoopCommonModes];
}
- (void)stopRepeat {
    [self.repeatTimer invalidate]; self.repeatTimer = nil;
    [self log:@"已停止"];
}
- (void)doStop { [self stopRepeat]; }

- (void)doSwipe {
    [self endEdit];
    CGPoint from = CGPointMake(_swFromX.text.floatValue, _swFromY.text.floatValue);
    CGPoint to   = CGPointMake(_swToX.text.floatValue, _swToY.text.floatValue);
    NSInteger steps = _swSteps.text.integerValue; if (steps < 2) steps = 8;
    NSTimeInterval dur = _swDur.text.floatValue; if (dur < 0.05) dur = 0.5;
    NSTimeInterval iv = dur / steps;
    [self log:[NSString stringWithFormat:@"滑动 (%.0f,%.0f) → (%.0f,%.0f) %ld步", from.x, from.y, to.x, to.y, (long)steps]];
    [self runSwipeStep:from to:to step:0 total:steps interval:iv];
}
- (void)runSwipeStep:(CGPoint)from to:(CGPoint)to step:(NSInteger)i total:(NSInteger)n interval:(NSTimeInterval)iv {
    if (i > n) { [self log:@"滑动完成"]; return; }
    CGFloat r = (CGFloat)i / n;
    CGPoint p = CGPointMake(from.x + (to.x - from.x) * r, from.y + (to.y - from.y) * r);
    [[TTAXController shared] tapAt:p];
    __weak typeof(self) ws = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(iv * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [ws runSwipeStep:from to:to step:i+1 total:n interval:iv];
    });
}

@end
