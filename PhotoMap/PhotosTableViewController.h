//
//  PhotosTableViewController.h
//  PhotoMap
//
//  Created by Michael Mangold on 2/24/12.
//  Copyright (c) 2012 Michael Mangold. All rights reserved.
//  CS193P (Fall, 2011) Assignment #5
//
//  Displays a table of up to 50 flickr photos that are passed to it
//

#import <UIKit/UIKit.h>

#define DEFAULT_COLOR [UIColor colorWithRed:0.596 green:0.247 blue:0.082 alpha:1.0] // Indicates imgage is not in cache.
#define CACHE_COLOR [UIColor blackColor]                                            // Indicates image is in cache.

@class PhotosTableViewController;

// Protocol to pass the chosen photo
@protocol PhotosTableViewControllerDelegate <NSObject>
@optional - (void)viewController:(UIViewController *)sender chosePhoto:(id)photo;
@end

@interface PhotosTableViewController: UITableViewController <PhotosTableViewControllerDelegate>
@property (nonatomic, strong) IBOutlet UIActivityIndicatorView *spinner;
@property (nonatomic, strong) NSArray *photos;
@property (nonatomic, strong) id chosenPhoto;
@property (nonatomic, weak) id <PhotosTableViewControllerDelegate> delegate;
@end
