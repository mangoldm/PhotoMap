//
//  PlacesTableViewController.h
//  PhotoMap
//
//  Created by Michael Mangold on 2/24/12.
//  Copyright (c) 2012 Michael Mangold. All rights reserved.
//  CS193P (Fall, 2011) Assignment #5
//
//  This class displays Flickr's top places, then passes
//  the 50 most recent photos to the destination view controller.
//

#import <UIKit/UIKit.h>
#import "MapViewController.h"

@interface PlacesTableViewController : UITableViewController <UINavigationBarDelegate>
@property (nonatomic, strong) NSArray *places;
@end