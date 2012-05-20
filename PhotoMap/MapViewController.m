//
//  MapViewController.m
//  PhotoMap
//
//  Created by Michael Mangold on 4/16/12.
//  Copyright (c) 2012 Michael Mangold. All rights reserved.
//  CS193P (Fall, 2011) Assignment #5
//

#import "MapViewController.h"

@interface MapViewController () <MKMapViewDelegate>
@property (weak, nonatomic) IBOutlet MKMapView *mapView;
@property (nonatomic, weak) IBOutlet UIToolbar *toolbar; // to put splitViewBarButtonitem in
@end

@implementation MapViewController
@synthesize mapView                = _mapView;
@synthesize annotations            = _annotations;
@synthesize delegate               = _delegate;
@synthesize chosenAnnotation       = _chosenAnnotation;
@synthesize toolbar                = _toolbar;
@synthesize splitViewBarButtonItem = _splitViewBarButtonItem;
@synthesize chosePlaceAnnotation   = _chosePlaceAnnotation;

- (void)updateMapView
{
    if (self.mapView.annotations) [self.mapView removeAnnotations:self.mapView.annotations];
    if (self.annotations) [self.mapView addAnnotations:self.annotations];
    [self moveToRegion];
}

- (void)setMapView:(MKMapView *)mapView
{
    _mapView = mapView;
    [self updateMapView];
}

- (void)setAnnotations:(NSArray *)annotations
{
    _annotations = annotations;
    [self updateMapView];
}

- (void) prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Show the image
    if ([segue.identifier isEqualToString: @"Show Image for Photo Annotation on iPhone"]) {
        [segue.destinationViewController viewController:self chosePhoto:self.chosenAnnotation.photo];
    } else if ([segue.identifier isEqualToString: @"Show Image for Photo Annotation on iPad"]) {
        UINavigationController *nav = segue.destinationViewController;
        ScrollingPhotoViewController *scrollingPhotoViewController = [nav.viewControllers objectAtIndex:0];
        [scrollingPhotoViewController viewController:self chosePhoto:self.chosenAnnotation.photo];
    } else {
        
        // Show photos for a place on iPhone
        if ([segue.identifier isEqualToString: @"Show Photos for Place Annotation on iPhone"]) {            
            id place = self.chosenAnnotation.photo;
            
            // Get reference to the destination view controller and pass the list of photos
            PhotosTableViewController *photosTableViewController = [segue destinationViewController];
            __block NSArray *tempPhotos;
            dispatch_queue_t photosQueue = dispatch_queue_create("photos downloader", NULL);
            dispatch_async(photosQueue, ^{
                tempPhotos = [FlickrFetcher photosInPlace:place maxResults:50];
                
                // Construct the place name, used as the destination view controller's title
                NSString *tempPlaceName   = [place objectForKey:FLICKR_PLACE_NAME];
                NSArray  *parsedPlaces    = [tempPlaceName componentsSeparatedByString:@","];
                NSString *placeName       = [parsedPlaces objectAtIndex:0];
                
                // Send photos to the destination view controller via the main thread
                dispatch_async(dispatch_get_main_queue(),^{
                    photosTableViewController.photos = tempPhotos;
                    photosTableViewController.title  = placeName;
                });
            });
            dispatch_release(photosQueue);
        } else {
            
            // Loop back and update PhotosTableViewController for a place on iPad
            if ([segue.identifier isEqualToString:@"Show Photos for Place Annotation on iPad"]) {
                self.chosePlaceAnnotation = YES;
            }
        }
    }
}

#pragma mark - Map View Delegate

// Called when a pin's callout is selected
- (void)mapView:(MKMapView *)mapView annotationView:(MKAnnotationView *)view calloutAccessoryControlTapped:(UIControl *)control
{
    self.chosenAnnotation = view.annotation;
    
    // Get the photo    
    FlickrPhotoAnnotation *annotation = view.annotation;
    id photo = annotation.photo;
    
    // Determine if the annotation is for an image or a place
    NSString *photoID = [photo valueForKey:FLICKR_PHOTO_ID];
    if (photoID) { // Annotation is for an image
        if (self.splitViewController) {
            [self performSegueWithIdentifier:@"Show Image for Photo Annotation on iPad" sender:view.annotation];
        } else {
            [self performSegueWithIdentifier:@"Show Image for Photo Annotation on iPhone" sender:view.annotation];
        }
    } else {  // Annotation is for a place
        if (!self.splitViewController) { // not iPad
            [self performSegueWithIdentifier:@"Show Photos for Place Annotation on iPhone" sender:view.annotation];
        } else {
            [self performSegueWithIdentifier:@"Show Photos for Place Annotation on iPad" sender:view.annotation];
        }
    }
}

// Creats the annotation "pin" points on the map
- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation
{
    MKAnnotationView *aView = [mapView dequeueReusableAnnotationViewWithIdentifier:@"MapVC"];
    if (!aView) {
        aView = [[MKPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:@"MapVC"];
        aView.canShowCallout = YES;
        aView.leftCalloutAccessoryView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 30, 30)];
    }
    aView.annotation = annotation;
    [(UIImageView *)aView.leftCalloutAccessoryView setImage:nil]; 
    
    UIButton *rightButton = [UIButton buttonWithType:UIButtonTypeDetailDisclosure];
    aView.rightCalloutAccessoryView = rightButton;
    
    return aView;
}

// Returns an image's thumbnail for use in the map annotation callout
- (UIImage *)mapViewController:(MapViewController *)sender imageForAnnotation:(id<MKAnnotation>)annotation
{
    FlickrPhotoAnnotation *fpa = (FlickrPhotoAnnotation *)annotation;
    NSURL *url = [FlickrFetcher urlForPhoto:fpa.photo format:FlickrPhotoFormatSquare];
    NSData *data = [NSData dataWithContentsOfURL:url];
    return data ? [UIImage imageWithData:data] : nil;
}

// Called when a pin is selected
- (void)mapView:(MKMapView *)mapView didSelectAnnotationView:(MKAnnotationView *)aView
{
    // Create spinning 'wait' indicator
	UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    [(UIImageView *)aView.leftCalloutAccessoryView addSubview:spinner];
	[spinner startAnimating];
    
    // Get thumbnail in separate thread
    dispatch_queue_t photosQueue = dispatch_queue_create("photos downloader", NULL);
    dispatch_async(photosQueue, ^{
        UIImage *image = [self mapViewController:self imageForAnnotation:aView.annotation];
        
        // Update callout view in main thread
		dispatch_async(dispatch_get_main_queue(), ^{
            [spinner stopAnimating];
            [(UIImageView *)aView.leftCalloutAccessoryView setImage:image];
        });
    });
    dispatch_release(photosQueue);
}

// Sets the map's focus to encompass the annotations
- (void)moveToRegion
{
    double minLatitude  = 0;
    double maxLatitude  = 90;
    double minLongitude = -179;
    double maxLongitude = 180;
    
    if (self.annotations.count > 0) {
        
        // Use first annotation as intial reference
        FlickrPhotoAnnotation *annotation = [self.annotations objectAtIndex:0];
        minLatitude  = annotation.coordinate.latitude;
        maxLatitude  = annotation.coordinate.latitude;
        minLongitude = annotation.coordinate.longitude;
        maxLongitude = annotation.coordinate.longitude;
        
        // Compare against all annotations
        for (FlickrPhotoAnnotation *annotation in self.annotations) {
            if (annotation.coordinate.latitude  < minLatitude)  minLatitude  = annotation.coordinate.latitude;
            if (annotation.coordinate.latitude  > maxLatitude)  maxLatitude  = annotation.coordinate.latitude;
            if (annotation.coordinate.longitude < minLongitude) minLongitude = annotation.coordinate.longitude;
            if (annotation.coordinate.longitude > maxLongitude) maxLongitude = annotation.coordinate.longitude;
        }
    }
    
    // Calculate the center of the region
    double latitudeDelta   = (maxLatitude       - minLatitude);
    double longitudeDelta  = (maxLongitude      - minLongitude);
    double centerLatitude  = latitudeDelta  / 2 + minLatitude;
    double centerLongitude = longitudeDelta / 2 + minLongitude;
    
    // Set region by the min and max values, with comfortable padding
    CLLocationCoordinate2D coord = {.latitude = centerLatitude, .longitude = centerLongitude};
    MKCoordinateSpan        span = {.latitudeDelta = latitudeDelta + 0.012, .longitudeDelta = longitudeDelta + 0.012};
    MKCoordinateRegion    region = {coord, span};
    [self.mapView setRegion:region];
}

#pragma  mark - SplitViewBarButtonItemPresenter

- (void)setSplitViewBarButtonItem:(UIBarButtonItem *)newSplitViewBarButtonItem
{
    if (_splitViewBarButtonItem != newSplitViewBarButtonItem) {
        NSMutableArray *toolbarItems = [self.toolbar.items mutableCopy];
        if (_splitViewBarButtonItem) [toolbarItems removeObject:_splitViewBarButtonItem];
        if (newSplitViewBarButtonItem) [toolbarItems insertObject:newSplitViewBarButtonItem atIndex:0];
        self.toolbar.items = toolbarItems;
        _splitViewBarButtonItem = newSplitViewBarButtonItem;
    }
}

#pragma mark - View Life Cycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.mapView.delegate = self;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:NO];
    self.toolbar.tintColor = DEFAULT_COLOR;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:NO];
    self.chosePlaceAnnotation = NO;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;
}

@end
