//
//  FlickrPhotoAnnotation.h
//  PhotoMap
//
//  Created by Michael Mangold on 4/21/12.
//  Copyright (c) 2012 Michael Mangold. All rights reserved.
//  CS193P (Fall, 2011) Assignment #5
//
//  This class represents part of the controller in the MVC heirarchy of this app
//

#import <Foundation/Foundation.h>
#import "MapKit/MapKit.h"

@interface FlickrPhotoAnnotation : NSObject <MKAnnotation>

+ (FlickrPhotoAnnotation *)annotationForPhoto:(NSDictionary *)photo; // Flickr photo dictionary

@property (nonatomic, strong)NSDictionary *photo;

@end
