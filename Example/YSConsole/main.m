//
//  main.m
//  YSConsole
//
//  Created by 357997194@qq.com on 11/01/2019.
//  Copyright (c) 2019 357997194@qq.com. All rights reserved.
//

@import UIKit;
#import "YSAppDelegate.h"
#import <YSConsole/LogInWindow.h>

int main(int argc, char * argv[])
{
    @autoreleasepool {
        logInWindow(YES);
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([YSAppDelegate class]));
    }
}
