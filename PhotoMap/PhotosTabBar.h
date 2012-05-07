//
//  PhotosTabBar.h
//  PhotoMap
//
//  Created by Michael Mangold on 5/6/12.
//  Copyright (c) 2012 Michael Mangold. All rights reserved.
//
//  Presents a UITabBarController with a 'chosenPlace' property to pass from the MapViewController detail
//  view to the PlacesTableViewController in the master view of a UISplitViewController. 
//

#import <UIKit/UIKit.h>
#import "MapViewController.h"
#import "SplitViewBarButtonItemPresenter.h"

@interface PhotosTabBar : UITabBarController <UISplitViewControllerDelegate>
@property (nonatomic) id chosenPlace;

@end
