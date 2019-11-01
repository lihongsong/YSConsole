//
//  YSViewController.m
//  YSConsole
//
//  Created by 357997194@qq.com on 11/01/2019.
//  Copyright (c) 2019 357997194@qq.com. All rights reserved.
//

#import "YSViewController.h"
#import "YSConsole_Example-Swift.h"

@interface YSViewController ()

@end

@implementation YSViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self _logSomething];
	// Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}



- (void)_logSomething {
    
    printf("[DEBUG] printf");

    printf("[DEBUG] printf\n");
    NSLog(@"[DEBUG] NSLog");
    
    
    [HJAAA log];
}

@end
