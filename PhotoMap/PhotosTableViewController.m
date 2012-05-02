//
//  PhotosTableViewController.m
//  PhotoMap
//
//  Created by Michael Mangold on 2/24/12.
//  Copyright (c) 2012 Michael Mangold. All rights reserved.
//  CS193P (Fall, 2011) Assignment #5
//

#import "PhotosTableViewController.h"
#import "FlickrFetcher.h"
#import "PlacesTableViewController.h"
#import "ScrollingPhotoViewController.h"

@interface PhotosTableViewController () <MapViewControllerDelegate>
@end

@implementation PhotosTableViewController
@synthesize spinner  = _spinner;
@synthesize photos   = _photos;
@synthesize delegate = _delegate;

#define RECENT_PHOTOS_KEY @"ScrollingPhotoViewController.Recent"

- (void)updateSplitViewDetail
{
    UINavigationController *detailNav = [self.splitViewController.viewControllers lastObject];
    id detail = [detailNav.viewControllers lastObject];
    if ([detail isKindOfClass:[MapViewController class]]) {
        MapViewController *mapVC = (MapViewController *)detail;
        mapVC.annotations = [self mapAnnotations];
    }
}

- (void)setPhotos:(NSArray *)photos
{
	if (_photos != photos) {
		_photos = photos;
        if ([self.splitViewController.viewControllers lastObject]) [self updateSplitViewDetail];
        if (self.tableView.window) [self.tableView reloadData];
		[self.spinner stopAnimating];
	}
}

// Refresh button on "Recents" tab.
- (IBAction)refresh:(id)sender {
	
	// Create spinning 'wait' indicator
	UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
	[spinner startAnimating];
	self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:spinner];
	// create GCD queue then dispatch
	dispatch_queue_t defaultsQueue = dispatch_queue_create("defaults fetcher", NULL);
	dispatch_async(defaultsQueue, ^{
		NSArray *tempArray = [[NSUserDefaults standardUserDefaults] objectForKey:RECENT_PHOTOS_KEY];
		// send defaults to main thread
		dispatch_async(dispatch_get_main_queue(), ^{
			// Reverse photos array so the most recently-viewed is on top
			self.photos = [[tempArray reverseObjectEnumerator] allObjects];
		});
	});
	dispatch_release(defaultsQueue);
	self.navigationItem.leftBarButtonItem = sender; // Turn off spinning indicator
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"Map Photos"] || [[segue identifier] isEqualToString:@"Map Recent Photos"]) {
        MapViewController *mapVC = segue.destinationViewController;
        mapVC.annotations = [self mapAnnotations];
        mapVC.delegate = self;
        mapVC.title = self.title;
    }
}

#pragma mark - TableView Data Source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    return [self.photos count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Photo Row";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
    }
    
	NSDictionary *photo = [self.photos objectAtIndex:indexPath.row];
	NSString *tempTitle = [photo objectForKey:FLICKR_PHOTO_TITLE];
	
	// Limit Title to 30 characters
	if (tempTitle.length > 30) {
		NSString *truncatedTitle = [tempTitle substringToIndex:30];
		tempTitle = truncatedTitle;
	}
	
	NSString *tempDescription = [photo valueForKeyPath:FLICKR_PHOTO_DESCRIPTION];
	
	// Limit Description to 40 characters
	if (tempDescription.length > 40) {
		NSString *truncatedDescription = [tempDescription substringToIndex:40];
		tempDescription = truncatedDescription;
	}
	
	// Assign cell labels
	if (![tempTitle isEqualToString:@""])
		cell.textLabel.text = tempTitle;
	else
		if (![tempDescription isEqualToString:@""])
			cell.textLabel.text = tempDescription;
		else
			cell.textLabel.text = @"Unknown";
	if ([tempDescription isEqualToString:@""])
		cell.detailTextLabel.text = @"No Description";
	else
		cell.detailTextLabel.text = tempDescription;
    
    // Prefix cell label with row number
    NSString *currentRow = [NSString stringWithFormat:@"%d: ",indexPath.row + 1];
    if (cell.textLabel.text) {
        cell.textLabel.text = [currentRow stringByAppendingString: cell.textLabel.text];
    } else {
        cell.textLabel.text = currentRow;
    }
    return cell;
}

#pragma mark - TableView Delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{	
	// send chosen photo to delegate
    if (self.splitViewController) {
        UINavigationController *detailNav = [self.splitViewController.viewControllers lastObject];
        id detail = [detailNav.viewControllers lastObject];
        if ([detail isKindOfClass:[MapViewController class]]) {
            ScrollingPhotoViewController *scrollingPVC = [[ScrollingPhotoViewController alloc] init];
            id photo = [self.photos objectAtIndex:indexPath.row];
            scrollingPVC.chosenPhoto = photo;
            self.delegate = scrollingPVC;
            [detailNav pushViewController:scrollingPVC animated:YES];
        }
    } else {
        id photo = [self.photos objectAtIndex:indexPath.row];
        [self.delegate viewController:self chosePhoto:photo];
    }
}

#pragma mark - MapView Delegate

// Sets places as map annotations
- (NSArray *) mapAnnotations
{
    NSMutableArray *annotations = [NSMutableArray arrayWithCapacity:[self.photos count]];
    for (NSDictionary *photo in self.photos) {
        [annotations addObject:[FlickrPhotoAnnotation annotationForPhoto:photo]];
    }
    return annotations;
}

#pragma mark - View lifecycle

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    self.navigationController.navigationBar.tintColor = DEFAULT_COLOR;
    if (!self.title) {
        self.title = @"Recently Viewed";
    }
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return YES;
}

@end
