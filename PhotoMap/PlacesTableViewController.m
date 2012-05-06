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
@synthesize places = _places;
@synthesize chosenPlace = _chosenPlace;

- (void)updateSplitViewDetail
{
    UINavigationController *detailNav = [self.splitViewController.viewControllers lastObject];
    id detail = [detailNav.viewControllers lastObject];
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

// Refresh button on "Top Places" tab.
- (IBAction)refresh:(id)sender
{
    // Create spinning 'wait' indicator
    UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    [spinner startAnimating];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:spinner];
    
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
            self.navigationItem.leftBarButtonItem = sender; // Turn off spinning indicator
            self.places	= sortedPlacesArray;
        });
    });
    dispatch_release(downloadQueue);
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

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"Show Photos"])
    {
        // Get place and cell from selected row
        NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
        UITableViewCell *cell  = [self.tableView cellForRowAtIndexPath:indexPath];
        id place = [self.places objectAtIndex:indexPath.row];
        
        // Create spinning 'wait' indicator and place in cell
        UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
        [cell addSubview:spinner];
        spinner.frame = CGRectMake(0, 0, 24, 24);
        cell.accessoryView = spinner;
        [spinner startAnimating];
        
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
        [spinner stopAnimating]; // turn off spinning wait indicator
        cell.accessoryView = nil; // restore accessoryView
    } else {
        if ([[segue identifier] isEqualToString:@"Map Places"] || [[segue identifier] isEqualToString:@"Map Recent Photos"]) {
            MapViewController *mapVC = segue.destinationViewController;
            mapVC.annotations        = [self mapAnnotations];
            mapVC.delegate           = self;
            mapVC.title              = self.navigationItem.title;
        }
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

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return YES;
}

- (void)viewWillAppear:(BOOL)animated
{
    
    NSLog(@"self:%@",self);
    [super viewWillAppear:animated];
    self.navigationController.navigationBar.tintColor = DEFAULT_COLOR;
    if (self.places) {
        [self updateSplitViewDetail];
    }
}

@end
