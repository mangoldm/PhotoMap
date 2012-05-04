//
//  ScrollingPhotoViewController.h
//  PhotoMap
//
//  Created by Michael Mangold on 3/6/12.
//  Copyright (c) 2012 Michael Mangold. All rights reserved.
//  CS193P (Fall, 2011) Assignment #5
//
//  Displays a single photo which can be zoomed and scrolled.
//

#import <UIKit/UIKit.h>
#import "PhotosTableViewController.h"

#define MAXIMUM_CACHE_SIZE 10000000 // 10MB

@interface ScrollingPhotoViewController : UIViewController <UINavigationBarDelegate, PhotosTableViewControllerDelegate>
- (IBAction)dismissPhoto:(UITapGestureRecognizer *)sender;
@property (nonatomic, strong) id chosenPhoto;
@end