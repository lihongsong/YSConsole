//
//  LogInWindow.m
//
//  Created by kagenZhao on 2017/5/23.
//  Copyright © 2017年 kagenZhao. All rights reserved.
//

#import "LogInWindow.h"
#import <sys/uio.h>
#import <stdio.h>
#import <fishhook/fishhook.h>

@interface LogTextView : UITextView

@end

@interface OutPutWindow : UIWindow
@property (nonatomic, strong) LogTextView *textView;
@property (nonatomic, strong) UIButton *cleanButton;
@end

@interface logInWindowManager()

@property (nonatomic, strong) dispatch_source_t sourt_t;


@property (nonatomic, strong) OutPutWindow * window;
@property (nonatomic, copy, readwrite) NSString *printString;
- (void)addPrintWithMessage:(NSString *)msg needReturn:(BOOL)needReturn;
+ (instancetype)share;
- (void)setupInWindow;
- (void)hideFromWindow;
@end

void logInWindow(bool flag) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (flag) {
            [[logInWindowManager share] setupInWindow];
        } else {
            [[logInWindowManager share] hideFromWindow];
        }
    });
}

// 这两个方法是 swift 的print调用的
// 修复 swift4
static char *__chineseChar = {0};
static int __buffIdx = 0;
static NSString *__syncToken = @"token";
static size_t (*orig_fwrite)(const void * __restrict, size_t, size_t, FILE * __restrict);
size_t new_fwrite(const void * __restrict ptr, size_t size, size_t nitems, FILE * __restrict stream) {
    
    char *str = (char *)ptr;
    __block NSString *s = [NSString stringWithCString:str encoding:NSUTF8StringEncoding];
    dispatch_async(dispatch_get_main_queue(), ^{
        @synchronized (__syncToken) {
            if (__chineseChar != NULL) {
                if (str[0] == '\n' && __chineseChar[0] != '\0') {
                    s = [[NSString stringWithCString:__chineseChar encoding:NSUTF8StringEncoding] stringByAppendingString:s];
                    __buffIdx = 0;
                    __chineseChar = calloc(1, sizeof(char));
                }
            } else {
               
            }
        }
        [[logInWindowManager share] addPrintWithMessage:s needReturn:false];
    });
    return orig_fwrite(ptr, size, nitems, stream);
}

static int (*orin___swbuf)(int, FILE *);
static int new___swbuf(int c, FILE *p) {
    @synchronized (__syncToken) {
        __chineseChar = realloc(__chineseChar, sizeof(char) * (__buffIdx + 2));
        __chineseChar[__buffIdx] = (char)c;
        __chineseChar[__buffIdx + 1] = '\0';
        __buffIdx++;
    }
    return orin___swbuf(c, p);
}

/**
 对 writev 函数进行 fishhook，NSLog 方法也会被抓取到
 */
static ssize_t (*orig_writev)(int, const struct iovec *, int);
static ssize_t new_writev(int a, const struct iovec *v, int v_len) {
    NSMutableString *string = [NSMutableString string];
    for (int i = 0; i < v_len; i++) {
        char *c = (char *)v[i].iov_base;
        [string appendString:[NSString stringWithCString:c encoding:NSUTF8StringEncoding]];
    }
    ssize_t result = orig_writev(a, v, v_len);
    dispatch_async(dispatch_get_main_queue(), ^{
        [[logInWindowManager share] addPrintWithMessage:string needReturn:false];
    });
    return result;
}

/**
 对 printf 函数进行 fishhook
 */
static int (*orig_printf)(const char * __restrict, va_list args);
static int new_printf(const char * __restrict __format, va_list args) {

    NSString *formatStr = [NSString stringWithUTF8String:__format];
    NSString *message = [[NSString alloc] initWithFormat:formatStr arguments:args];
    [[logInWindowManager share] addPrintWithMessage:message needReturn:false];
    return orig_printf(__format, args);
}

/**
 函数绑定 printf、writev、fwrite、__swbuf
 */
static void rebindFunction() {
    int error = 0;
    
    error = rebind_symbols((struct rebinding[1]){{"printf", new_printf, (void *)&orig_printf}}, 1);
    if (error < 0) {
        NSLog(@"错误 printf");
    }
    error = rebind_symbols((struct rebinding[1]){{"writev", new_writev, (void *)&orig_writev}}, 1);
    if (error < 0) {
        NSLog(@"错误 writev");
    }
    error = rebind_symbols((struct rebinding[1]){{"fwrite", new_fwrite, (void *)&orig_fwrite}}, 1);
    if (error < 0) {
        NSLog(@"错误 fwrite");
    }
    error = rebind_symbols((struct rebinding[1]){{"__swbuf", new___swbuf, (void *)&orin___swbuf}}, 1);
    if (error < 0) {
        NSLog(@"错误 __swbuf");
    }
}


@implementation LogTextView
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame textContainer:nil];
    if (self) {
        self.font = [UIFont systemFontOfSize:12];
        self.textColor = [UIColor greenColor];
        self.backgroundColor = [UIColor blackColor];
        self.scrollsToTop = false;
        self.editable = false;
        self.selectable = false;
        self.userInteractionEnabled = false;
    }
    return self;
}
@end

@implementation OutPutWindow
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.windowLevel = UIWindowLevelAlert;
        self.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.3];
        _textView = [[LogTextView alloc] initWithFrame:self.bounds];
        [self addSubview:_textView];
        
        _cleanButton = [UIButton buttonWithType:UIButtonTypeSystem];
        _cleanButton.hidden = true;
        [_cleanButton setTitle:@"清空" forState:UIControlStateNormal];
        [_cleanButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        [self addSubview:_cleanButton];
    }
    return self;
}
- (void)setFrame:(CGRect)frame {
    [super setFrame:frame];
    _textView.frame = self.bounds;
}

@end

@implementation logInWindowManager

+ (instancetype)share {
    static logInWindowManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[logInWindowManager alloc] init];
        instance.window = [[OutPutWindow alloc] initWithFrame:CGRectMake(0, 20, 50, 50)];
        UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:instance action:@selector(doubleTapAction:)];
        doubleTap.numberOfTapsRequired = 2;
        [instance.window addGestureRecognizer:doubleTap];
        UIPanGestureRecognizer *longP = [[UIPanGestureRecognizer alloc] initWithTarget:instance action:@selector(longGestureAction:)];
        [instance.window addGestureRecognizer:longP];
        rebindFunction();
    });
    return instance;
}

static BOOL __isShow = false;

- (void)longGestureAction: (UIPanGestureRecognizer *)longP {
    static BOOL isBegin = false;
    if (__isShow) {
        if (isBegin) {
            [UIView animateWithDuration:0.2 animations:^{
                self.window.transform = CGAffineTransformMakeScale(1.2, 1.2);
            }];
            isBegin = false;
        }
        return;
    }
    switch (longP.state) {
        case UIGestureRecognizerStateBegan:
            if (!isBegin) {
                [UIView animateWithDuration:0.2 animations:^{
                    self.window.transform = CGAffineTransformMakeScale(1.2, 1.2);
                }];
                isBegin = true;
            }
            break;
        case UIGestureRecognizerStateChanged:
            if (isBegin) {
                CGPoint oldCenter = self.window.center;
                CGFloat newX = oldCenter.x + [longP translationInView:self.window].x;
                CGFloat newY = oldCenter.y + [longP translationInView:self.window].y;
                
                CGPoint newCenter = CGPointMake(newX, newY);
                [longP setTranslation:CGPointZero inView:self.window];
                self.window.center = newCenter;
            }
            break;
        default:
            if (isBegin) {
                [UIView animateWithDuration:0.2 animations:^{
                    self.window.transform = CGAffineTransformIdentity;
                }];
                isBegin = false;
            }
            break;
    }
}

//+ (void)redirectNSLogToDocumentFolder {
//    //获取Document目录下的Log文件夹,若没有则新建
//    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
//    NSString *logDirectory = [[paths objectAtIndex:0] stringByAppendingPathComponent:@"Log"];
//    NSFileManager *fileManager = [NSFileManager defaultManager];
//    BOOL fileExists = [fileManager fileExistsAtPath:logDirectory];
//    if (!fileExists) {
//        [fileManager createDirectoryAtPath:logDirectory withIntermediateDirectories:YES attributes:nil error:nil];
//
//    }
//    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
//    [formatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"zh_CN"]];
//    [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
//    //每次启动后都保存一个新的日志文件中
//    //NSString *dateStr = [formatter stringFromDate:[NSDate date]];
//    NSString *logFilePath = [logDirectory stringByAppendingFormat:@"/%@.txt",@"log"];
//    //  printf --> stdout    NSLog --> stderr  stdin是标准输入流，默认为键盘；stdout是标准输出流，默认为屏幕；stderr是标准错误流，一般把屏幕设为默认
//    freopen([logFilePath cStringUsingEncoding:NSASCIIStringEncoding], "a+", stdout);
//    freopen([logFilePath cStringUsingEncoding:NSASCIIStringEncoding], "a+", stderr);
//}
//+ (NSString *)readFromLogFile
//{
//    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
//    NSString *logDirectory = [[paths objectAtIndex:0] stringByAppendingPathComponent:@"Log"];
//    NSFileManager *fileManager = [NSFileManager defaultManager];
//    BOOL fileExists = [fileManager fileExistsAtPath:logDirectory];
//    if (!fileExists) {
//        [fileManager createDirectoryAtPath:logDirectory withIntermediateDirectories:YES attributes:nil error:nil];
//    }
//    NSString *logFilePath = [logDirectory stringByAppendingFormat:@"/%@.txt",@"log"];
//    NSString *content = [[NSString alloc] initWithContentsOfFile:logFilePath encoding:NSUTF8StringEncoding error:nil];
//    return content;
//}
//+ (void)removeLogFile
//{
//    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
//    NSString *logDirectory = [[paths objectAtIndex:0] stringByAppendingPathComponent:@"Log"];
//    NSString *logFilePath = [logDirectory stringByAppendingFormat:@"/%@.txt",@"log"];
//    NSFileManager *fileManage = [NSFileManager defaultManager];
//    if ([fileManage fileExistsAtPath:logFilePath]) {
//        [fileManage removeItemAtPath:logFilePath error:nil];
//        [self redirectNSLogToDocumentFolder];
//    }
//}

- (void)doubleTapAction:(UITapGestureRecognizer *)ges {
    if (ges.numberOfTapsRequired == 2) {
        if (!__isShow) {
            
            [UIView animateWithDuration:0.5 animations:^{
                self.window.cleanButton.hidden = false;
                self.window.frame = CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height);
                self.window.textView.frame = CGRectMake(0, 40, self.window.bounds.size.width, self.window.bounds.size.height - 40);
                self.window.cleanButton.frame = CGRectMake(0, 0, self.window.bounds.size.width, 40);
            }];
            self.window.textView.userInteractionEnabled = true;
        } else {
            [UIView animateWithDuration:0.5 animations:^{
                self.window.cleanButton.hidden = true;
                self.window.frame = CGRectMake(0, 0, 50, 50);
                self.window.textView.frame = self.window.bounds;
            }];
            self.window.textView.userInteractionEnabled = false;
        }
        __isShow = !__isShow;
    }
}

- (void)setupInWindow {
    if (![UIApplication sharedApplication].keyWindow) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self setupInWindow];
        });
        return;
    }
    [self.window makeKeyAndVisible];
}

- (void)hideFromWindow {
    [self.window resignKeyWindow];
}

- (void)addPrintWithMessage:(NSString *)msg needReturn:(BOOL)needReturn{
    dispatch_async(dispatch_get_main_queue(), ^{
        @synchronized (self) {
            if (self.window.textView.text.length) {
                if (needReturn) {
                    self.window.textView.text = [NSString stringWithFormat:@"%@\n%@", self.window.textView.text, msg];
                } else {
                    self.window.textView.text = [NSString stringWithFormat:@"%@%@", self.window.textView.text, msg];
                }
            } else {
                self.window.textView.text = msg;
            }
            if (!__isShow) {
                [self.window.textView scrollRangeToVisible:NSMakeRange(MAX((self.window.textView.text.length - 1), 0), self.window.textView.text.length ? 1 : 0)];
            }
        }
    });
}

@end
