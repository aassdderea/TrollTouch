#import "AppDelegate.h"
#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>

@interface AppDelegate ()
@property (nonatomic, strong) AVAudioPlayer *silentPlayer;
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)opt {
    [self setupAudio];

    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController = [ViewController new];
    self.window.backgroundColor = UIColor.blackColor;
    [self.window makeKeyAndVisible];

    return YES;
}

- (void)setupAudio {
    NSError *err;
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback
                                      withOptions:AVAudioSessionCategoryOptionMixWithOthers
                                            error:&err];
    [[AVAudioSession sharedInstance] setActive:YES error:&err];

    NSData *wav = [self silentWAV];
    self.silentPlayer = [[AVAudioPlayer alloc] initWithData:wav error:&err];
    self.silentPlayer.numberOfLoops = -1;
    self.silentPlayer.volume = 0.0;
    [self.silentPlayer prepareToPlay];
}

- (NSData *)silentWAV {
    int sampleRate = 44100, bits = 16, ch = 1, durSec = 4;
    int byteRate = sampleRate * ch * bits / 8;
    int block = ch * bits / 8;
    int dataSize = sampleRate * durSec * block;
    int fileSize = 36 + dataSize;

    NSMutableData *d = [NSMutableData data];
    [d appendBytes:"RIFF" length:4];
    [d appendBytes:&fileSize length:4];
    [d appendBytes:"WAVE" length:4];
    [d appendBytes:"fmt " length:4];
    int32_t fsz = 16; [d appendBytes:&fsz length:4];
    int16_t fmt = 1;  [d appendBytes:&fmt length:2];
    int16_t chn = ch; [d appendBytes:&chn length:2];
    int32_t sr = sampleRate; [d appendBytes:&sr length:4];
    int32_t br = byteRate;   [d appendBytes:&br length:4];
    int16_t ba = block;      [d appendBytes:&ba length:2];
    int16_t bp = bits;       [d appendBytes:&bp length:2];
    [d appendBytes:"data" length:4];
    [d appendBytes:&dataSize length:4];
    uint8_t *zero = calloc(dataSize, 1);
    [d appendBytes:zero length:dataSize];
    free(zero);
    return d;
}

- (void)applicationDidEnterBackground:(UIApplication *)app {
    [self.silentPlayer play];
}

- (void)applicationWillEnterForeground:(UIApplication *)app {
    [self.silentPlayer pause];
}

@end
