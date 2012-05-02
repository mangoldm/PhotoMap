//
//  FlickrPhotoAnnotation.m
//  PhotoMap
//
//  Created by Michael Mangold on 4/21/12.
//  Copyright (c) 2012 Michael Mangold. All rights reserved.
//  CS193P (Fall, 2011) Assignment #5
//

#import "FlickrPhotoAnnotation.h"
#import "FlickrFetcher.h"
@implementation FlickrPhotoAnnotation

@synthesize photo = _photo;

+ (FlickrPhotoAnnotation *)annotationForPhoto:(NSDictionary *)photo
{
    FlickrPhotoAnnotation *annotation = [[FlickrPhotoAnnotation alloc] init];
    annotation.photo = photo;
    return annotation;
}

- (NSString *)title
{
    NSString *tempTitle = [self.photo objectForKey:FLICKR_PHOTO_TITLE];
    if (!tempTitle) {
        tempTitle = [self.photo objectForKey:FLICKR_PLACE_NAME];
    }
    return tempTitle;
}

- (NSString *)subtitle
{
    return [self.photo valueForKeyPath:FLICKR_PHOTO_DESCRIPTION];
}

- (CLLocationCoordinate2D)coordinate
{
    CLLocationCoordinate2D coordinate;
    coordinate.latitude  = [[self.photo objectForKey:FLICKR_LATITUDE] doubleValue];
    coordinate.longitude = [[self.photo objectForKey:FLICKR_LONGITUDE] doubleValue];
    return coordinate;
}

@end
