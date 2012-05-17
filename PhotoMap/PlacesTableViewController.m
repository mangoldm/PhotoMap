//
//  PlacesTableViewController.m
//  PhotoMap
//
//  Created by Michael Mangold on 2/24/12.
//  Copyright (c) 2012 Michael Mangold. All rights reserved.
//  CS193P (Fall, 2011) Assignment #5
//

#import "PlacesTableViewController.h"
#import "FlickrFetcher.h"
#import "PhotosTableViewController.h"

@interface PlacesTableViewController () <MapViewControllerDelegate>
@end

@implementation PlacesTableViewController
@synthesize spinner     = _spinner;
@synthesize places      = _places;
@synthesize chosenPlace = _chosenPlace;

- (void)updateSplitViewDetail
{
    id detail = [self.splitViewController.viewControllers lastObject];
    if ([detail isKindOfClass:[MapViewController class]]) {
        MapViewController *mapVC = (MapViewController *)detail;
        mapVC.annotations = [self mapAnnotations];
    }
}

- (void)setPlaces:(NSArray *)places
{
    if (_places != places) {
        _places = places;
        if ([self.splitViewController.viewControllers lastObject]) [self updateSplitViewDetail];
        if (self.tableView.window) [self.tableView reloadData];
    }
}

// Sets self.places to the 50 most recent places on Flickr
- (void)RecentPlaces;
{
    [self.spinner startAnimating];
    
    // create GCD queue then dispatch
    dispatch_queue_t downloadQueue = dispatch_queue_create("flickr downloader", NULL);
    dispatch_async(downloadQueue, ^{
        NSArray *placesArray = [FlickrFetcher topPlaces];
        
        // Sort topPlaces
        NSSortDescriptor *placeName = [[NSSortDescriptor alloc] initWithKey:FLICKR_PLACE_NAME ascending:YES];
        NSArray	   *sortDescriptors = [NSArray arrayWithObjects:placeName, nil];
        NSArray	 *sortedPlacesArray = [placesArray sortedArrayUsingDescriptors:sortDescriptors];
        
        // keep UI processing on main thread
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.spinner stopAnimating];
            self.places = sortedPlacesArray;
        });
    });
    dispatch_release(downloadQueue);
}

// Refresh button on "Top Places" tab.
- (IBAction)refresh:(id)sender
{
    [self RecentPlaces];
}

#pragma mark - Table view data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    return [self.places count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Flickr Place";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
    }
    
    NSDictionary   *place = [self.places objectAtIndex:indexPath.row];
    NSString   *tempPlace = [place objectForKey:FLICKR_PLACE_NAME];
    NSArray *parsedPlaces = [tempPlace componentsSeparatedByString:@","];
    NSString        *city = [parsedPlaces	objectAtIndex:0];
    NSString      *region = @"No Region";
    NSString  *tempRegion = nil;
    
    // Build the region string (e.g. Washington, DC, United States)
    int  parsedPlacesCount = [parsedPlaces count];
    for (int i = 1; i <= parsedPlacesCount; i++) {
        tempRegion = [parsedPlaces objectAtIndex:i - 1];
        if (i == 1) region = tempRegion;
        else {
            region = [region stringByAppendingString:@","];
            region = [region stringByAppendingString:tempRegion];
        }
    }
    
    cell.textLabel.text       = city;
    cell.detailTextLabel.text = region;
    return cell;
}

- (void)sendPhotosForPlace:(id)place toViewController:(PhotosTableViewController *)photosTableViewController;
{
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
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    id place;
    
    // Build switch values for segue identifier
    int segueIndentifier;
    if ([[segue identifier] isEqualToString:@"Show Photos from Table on iPhone"])           segueIndentifier = 0;
    if ([[segue identifier] isEqualToString:@"Map Places from Table on iPhone"])            segueIndentifier = 1;
    if ([[segue identifier] isEqualToString:@"Map Recent Photos on iPhone"])                segueIndentifier = 2;
    if ([[segue identifier] isEqualToString:@"Show Photos for Place Annotation on iPhone"]) segueIndentifier = 3;
    if ([[segue identifier] isEqualToString:@"Map Photos for Place Recents on iPhone"])     segueIndentifier = 4;
    if ([[segue identifier] isEqualToString:@"Show Photos for Place Annotation on iPad"])   segueIndentifier = 5;
    if ([[segue identifier] isEqualToString:@"Show Photos from Table on iPad"])             segueIndentifier = 6;
    if ([[segue identifier] isEqualToString:@"Show Image for Photo Annotation on iPad"])    segueIndentifier = 7;
    if ([[segue identifier] isEqualToString:@"Show Image from Table on iPad"])              segueIndentifier = 8;
    if ([[segue identifier] isEqualToString:@"Show Image from Recently Viewed on iPad"])    segueIndentifier = 9;
    
    switch (segueIndentifier) {
        case 0: // Show Photos from Table on iPhone
        {
            // Get reference to the place and the table cell
            NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
            UITableViewCell *cell  = [self.tableView cellForRowAtIndexPath:indexPath];
            place = [self.places objectAtIndex:indexPath.row];
            
            // Create spinning 'wait' indicator in cell
            UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
            [cell addSubview:spinner];
            spinner.frame = CGRectMake(0, 0, 24, 24);
            cell.accessoryView = spinner;
            [spinner startAnimating];
            
            // Pass the list of photos for the place to the destination view controller
            PhotosTableViewController *photosTableViewController = [segue destinationViewController];
            [self sendPhotosForPlace:place toViewController:photosTableViewController];
            
            // Turn off spinning 'wait' indicator and restore table cell's accessoryView
            [spinner stopAnimating];
            cell.accessoryView = nil;
            
        }
            break;
        case 1: // Map Places from Table on iPhone
        case 2: // Map Recent Photos on iPhone
        case 3: // Show Photos for Place Annotation on iPhone
        case 4: // Map Photos for Place Recents on iPhone
        {
            MapViewController *mapVC = segue.destinationViewController;
            mapVC.annotations        = [self mapAnnotations];
            mapVC.delegate           = self;
            mapVC.title              = self.navigationItem.title;
        }
            break;
        case 5: // Show Photos for Place Annotation on iPad
        {
            MapViewController *detail = [self.splitViewController.viewControllers lastObject]; 
            
            // Get reference to the place and pass its list of photos to the destination view controller                                   
            place = detail.chosenAnnotation.photo;
            PhotosTableViewController *photosTableViewController = [segue destinationViewController];
            [self sendPhotosForPlace:place toViewController:photosTableViewController];
        }
            break;
        case 6: // Show Photos from Table on iPad
        {
            // Check if this is a passthrough from place annotation callout accessory
            id detail = [self.splitViewController.viewControllers lastObject];
            if ([detail isKindOfClass:[MapViewController class]]) {
                MapViewController *mapViewController = detail;
                if (mapViewController.chosePlaceAnnotation) { // if segued from map
                    MapViewController *detail = [self.splitViewController.viewControllers lastObject];                                    
                    place = detail.chosenAnnotation.photo;
                } else { // Regular workflow
                    // Get reference to the place and the table cell
                    NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
                    place = [self.places objectAtIndex:indexPath.row];
                }
            }
            
            // Pass the list of photos for the place to the destination view controller
            PhotosTableViewController *photosTableViewController = [segue destinationViewController];
            [self sendPhotosForPlace:place toViewController:photosTableViewController];
        }
            break;
            
            
    }
}

#pragma mark - Map View Controller Delegate

// Sets places as map annotations
- (NSArray *) mapAnnotations
{
    NSMutableArray *annotations = [NSMutableArray arrayWithCapacity:[self.places count]];
    for (NSDictionary *place in self.places) {
        [annotations addObject:[FlickrPhotoAnnotation annotationForPhoto:place]];
    }
    return annotations;
}

#pragma mark - View lifecycle

- (void)viewWillAppear:(BOOL)animated
{
    BOOL updateRecentPlaces;
    [super viewWillAppear:animated];
    self.navigationController.navigationBar.tintColor = DEFAULT_COLOR;
    
    // If segued from place annotation callout accessory on iPad, just pass through to the photosTableViewController.
    // Otherwise, update the list of recent places from Flickr
    if (self.splitViewController) {
        id detail = [self.splitViewController.viewControllers lastObject];
        if ([detail isKindOfClass:[MapViewController class]]) {
            MapViewController *mapViewController = detail;
            if (!mapViewController.chosePlaceAnnotation) {
                updateRecentPlaces = YES;
            } else {
                updateRecentPlaces = NO;
            }
        }
    } else {
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) updateRecentPlaces = YES;
    }
    if (updateRecentPlaces) {
        if (self.places) {
            [self.tableView reloadData];
            [self updateSplitViewDetail];
        } else {
            [self RecentPlaces];
        }
    }
}  

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    // Check if segued from place annotation callout accessory
    id detail = [self.splitViewController.viewControllers lastObject];
    if ([detail isKindOfClass:[MapViewController class]]) {
        MapViewController *mapViewController = detail;
        if (mapViewController.chosePlaceAnnotation) { // if segued from map
            [self performSegueWithIdentifier:@"Show Photos from Table on iPad" sender:self];
        }
    }
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return YES;
}

@end
