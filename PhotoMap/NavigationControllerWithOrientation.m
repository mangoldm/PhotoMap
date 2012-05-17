//
//  NavigationControllerWithOrientation.m
//  PhotoMap
//
//  Created by Michael Mangold on 5/16/12.
//  Copyright (c) 2012 Michael Mangold. All rights reserved.
//

#import "NavigationControllerWithOrientation.h"

@interface NavigationControllerWithOrientation ()

@end

@implementation NavigationControllerWithOrientation

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	return YES;
}

@end
