//
//  MapViewController.h
//  PhotoMap
//
//  Created by Michael Mangold on 4/16/12.
//  Copyright (c) 2012 Michael Mangold. All rights reserved.
//  CS193P (Fall, 2011) Assignment #5
//  
//  Displays a map with annotations for Flickr photos or places
//

#import <UIKit/UIKit.h>
#import <MapKit/MapKit.h>
#import "FlickrFetcher.h"
#import "FlickrPhotoAnnotation.h"
#import "SplitViewBarButtonItemPresenter.h"
#import "PlacesTableViewController.h"
#import "PhotosTableViewController.h"
#import "PhotosTabBar.h"
#import "ScrollingPhotoViewController.h"

@class MapViewController;
@protocol MapViewControllerDelegate <NSObject>
@optional - (void)photosTableViewController:(id *)sender chosePhoto:(id)photo;
@end

@interface MapViewController : UIViewController <MapViewControllerDelegate, SplitViewBarButtonItemPresenter>
@property (nonatomic, strong)        NSArray                    *annotations; // of id <MKAnnotation>
@property (nonatomic, strong)        FlickrPhotoAnnotation      *chosenAnnotation;
@property (nonatomic, weak) id       <MapViewControllerDelegate> delegate;
@property (nonatomic) BOOL                                       chosePlaceAnnotation; // Controls segue fallthrough
@end
