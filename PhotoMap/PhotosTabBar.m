//
//  PhotosTabBar.m
//  PhotoMap
//
//  Created by Michael Mangold on 5/6/12.
//  Copyright (c) 2012 Michael Mangold. All rights reserved.
//

#import "PhotosTabBar.h"

@interface PhotosTabBar ()

@end

@implementation PhotosTabBar
@synthesize chosenPlace = _chosenPlace;

- (id <SplitViewBarButtonItemPresenter>)splitViewBarButtonItemPresenter
{
    id detail = [self.splitViewController.viewControllers lastObject];
    if (![detail conformsToProtocol:@protocol(SplitViewBarButtonItemPresenter)]) {
        detail = nil;
    }
    return detail;
}

- (BOOL)splitViewController:(UISplitViewController *)svc
   shouldHideViewController:(UIViewController *)vc
              inOrientation:(UIInterfaceOrientation)orientation
{
    return [self splitViewBarButtonItemPresenter] ? UIInterfaceOrientationIsPortrait(orientation) : NO;
}

- (void)splitViewController:(UISplitViewController*)svc
     willHideViewController:(UIViewController *)aViewController
          withBarButtonItem:(UIBarButtonItem*)barButtonItem
       forPopoverController:(UIPopoverController*)pc
{
    barButtonItem.title = self.title;
    [self splitViewBarButtonItemPresenter].splitViewBarButtonItem = barButtonItem;
    // if we are not in a UINavigationController this method (appropriately) does nothing
}

- (void)splitViewController:(UISplitViewController*)svc
     willShowViewController:(UIViewController *)aViewController
  invalidatingBarButtonItem:(UIBarButtonItem*)button
{
    [self splitViewBarButtonItemPresenter].splitViewBarButtonItem = nil;
}

#pragma mark - view life cycle

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
    
    self.splitViewController.delegate = self;
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
