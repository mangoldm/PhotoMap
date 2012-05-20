//
//  ScrollingPhotoViewController.m
//  PhotoMap
//
//  Created by Michael Mangold on 3/6/12.
//  Copyright (c) 2012 Michael Mangold. All rights reserved.
//  CS193P (Fall, 2011) Assignment #5
//

#import "ScrollingPhotoViewController.h"
#import "PhotosTableViewController.h"
#import "FlickrFetcher.h"
#import "MapViewController.h"

@interface ScrollingPhotoViewController () <UIScrollViewDelegate, MapViewControllerDelegate>
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UIScrollView *scrollView;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *spinner;
@property (weak, nonatomic) NSData *photoData;
@end

@implementation ScrollingPhotoViewController
@synthesize imageView   = _imageView;
@synthesize scrollView  = _scrollView;
@synthesize chosenPhoto = _chosenPhoto;
@synthesize spinner     = _spinner;
@synthesize photoData   = _photoData;

#define RECENT_PHOTOS_KEY @"ScrollingPhotoViewController.Recent"

- (IBAction)dismissPhoto:(UITapGestureRecognizer *)sender
{
    [self dismissModalViewControllerAnimated:YES];
}

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView
{
	return self.imageView;
}

// Stores the photo in the user's cache
- (void)cachePhoto:(NSData *)photoData withID:(NSString *)photoID {
	
    const unsigned long long maximumCacheSize = MAXIMUM_CACHE_SIZE;
    NSMutableArray *URLsArray = [[NSMutableArray alloc] initWithObjects:nil];
	
    // Find the cache directory path
    NSFileManager *fm = [[NSFileManager alloc] init];
    NSURL  *cachePath = [[fm URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask] lastObject];
	
    // Get the size of the current cache
    unsigned long long totalSize = 0;
    NSArray *enumeratorKeys = [NSArray arrayWithObjects:NSURLFileSizeKey, NSURLAttributeModificationDateKey, nil];
    NSDirectoryEnumerator *cacheSizeEnumerator = [fm enumeratorAtURL:cachePath includingPropertiesForKeys:enumeratorKeys options:0 errorHandler:nil];
    for (NSURL *url in cacheSizeEnumerator) {
        NSString *fileName;
        NSNumber *fileSize;
        NSDate   *modDate;
        [url getResourceValue:&fileName forKey:NSURLNameKey error:nil];
        [url getResourceValue:&fileSize forKey:NSURLFileSizeKey error:nil];
        [url getResourceValue:&modDate  forKey:NSURLAttributeModificationDateKey error:nil];
        if ((fileSize) && !([fileName isEqualToString:@"Cache.db"])){
            totalSize += [fileSize unsignedLongLongValue];
			
            // Create duplicate array to be used when deleting cache files
            NSArray *theObjects = [NSArray arrayWithObjects:fileName, fileSize, modDate, nil];
            NSArray *theKeys    = [NSArray arrayWithObjects:@"fileName", @"fileSize", @"modDate", nil];    
            NSDictionary *cacheDictionary = [NSDictionary dictionaryWithObjects:theObjects forKeys:theKeys];
            [URLsArray addObject:cacheDictionary];
        }
    }
    
    // Delete files when cache gets too big
    if (totalSize > maximumCacheSize) {
        
        // Sort the array of files by date
        NSSortDescriptor *modDateDescriptor = [[NSSortDescriptor alloc] initWithKey:@"modDate"  ascending:YES];
        [URLsArray sortUsingDescriptors:[NSArray arrayWithObjects:modDateDescriptor,nil]];
        
        // Delete files until cache is 80% of maximum size
        for (NSDictionary *deletionPhoto in URLsArray) {
            NSString *deletionID          = [deletionPhoto objectForKey:@"fileName"];
            NSString *cachePathString     = [cachePath absoluteString];
            NSString *completeURLAsString = [cachePathString stringByAppendingString: deletionID];
            NSURL    *deletionPath        = [NSURL URLWithString:completeURLAsString];
            BOOL removedOK = [fm removeItemAtURL:deletionPath error:nil];
            if (!removedOK) {
                NSLog(@"Error removing file.");
            } else {
                NSNumber *fileSize = [deletionPhoto objectForKey:@"fileSize"];
                totalSize -= [fileSize unsignedLongValue];
                if (totalSize < maximumCacheSize * 0.8) {
                    break;
                }
            }
        }
    }
	
    // Assign photoID to the file name
    NSString *cachePathString     = [cachePath absoluteString];
    NSString *completeURLAsString = [cachePathString stringByAppendingString: photoID];
    NSURL    *path                = [NSURL URLWithString:completeURLAsString];
    
    // Write to the file.
    BOOL writtenOK = [photoData writeToURL:path atomically:YES];
    if (!writtenOK) {
        NSLog(@"Error writing to cache.");
    }
}

// Moves an object in an array
- (NSMutableArray *)moveObjectInArray:(NSMutableArray *)array FromIndex:(int)fromIndex toIndex:(int)toIndex
{
    if (!(fromIndex >= [array count]) | (fromIndex == toIndex)) {
        id object = [array objectAtIndex:fromIndex];
        [array removeObjectAtIndex:fromIndex];
        if(toIndex >= [array count]) {
            [array addObject:object];
		}
        else {
            [array insertObject:object atIndex:toIndex];
        }
    }
    return array;
}

// Stores photo in recents list via NSUserDefaults
- (void)addToRecentPhotos
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableArray *recentPhotos = [[defaults objectForKey:RECENT_PHOTOS_KEY] mutableCopy];
    
    // Create blank array if one doesn't exist
    if (! recentPhotos) recentPhotos = [NSMutableArray array];
    
    // Store the photo if it's not a duplicate
    if (![recentPhotos containsObject:self.chosenPhoto]) {
        [recentPhotos addObject:self.chosenPhoto];
    } else {
        // If it is a duplicate, move it to the top of the table
        int currentIndex = [recentPhotos indexOfObject:self.chosenPhoto];
        recentPhotos = [self moveObjectInArray:recentPhotos FromIndex:currentIndex toIndex:[recentPhotos count]];
    }
    
    // Trim to 50 entries
    if ([recentPhotos count] > 50) {
        for (int i=0; i < [recentPhotos count]; i++) {
            [recentPhotos removeObject:[recentPhotos objectAtIndex:i]];
            if ([recentPhotos count] <= 50) break;
        }
    }
    
    [defaults setObject:recentPhotos forKey:RECENT_PHOTOS_KEY];
    [defaults synchronize];
}

// Called when a user selectes a photo
- (void)viewController:(UIViewController *)sender chosePhoto:(id)photo;
{
    __block BOOL photoInCache = NO;
    __block NSString *fileName;
    __block NSData   *dataForPhoto;
    __block UIImage  *image;
    self.chosenPhoto = photo;
	
    // set navigation bar title to photo title
    self.navigationItem.title = [photo objectForKey:FLICKR_PHOTO_TITLE];
    if ([self.navigationItem.title isEqualToString:@""]) {
        self.navigationItem.title = @"Unknown";
    }
    
    NSString *photoID = [photo objectForKey:FLICKR_PHOTO_ID];
    
    dispatch_queue_t photoQueue = dispatch_queue_create("photo downloader", NULL);
    dispatch_async(photoQueue, ^{
        // Retrieve photo from cache when possible
        NSFileManager *fm       = [[NSFileManager alloc] init];
        NSURL *cachePath        = [[fm URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask] lastObject];
        NSArray *enumeratorKeys = [NSArray arrayWithObjects:NSURLFileSizeKey, nil];
        NSDirectoryEnumerator *cacheEnumerator = [fm enumeratorAtURL:cachePath includingPropertiesForKeys:enumeratorKeys options:0 errorHandler:nil];
        for (NSURL *cacheURL in cacheEnumerator) {
            [cacheURL getResourceValue:&fileName forKey:NSURLNameKey error:nil];
            if ([fileName isEqualToString:photoID]) {
                photoInCache = YES;
                dataForPhoto = [NSData dataWithContentsOfURL:cacheURL];
                image        = [UIImage imageWithData:dataForPhoto];
                break;
            }
        }
        
        // Query Flickr for this photo if not in cache
        if (!photoInCache) {
            NSURL *urlForPhoto = [FlickrFetcher urlForPhoto:photo format:FlickrPhotoFormatLarge];
            dataForPhoto       = [NSData dataWithContentsOfURL:urlForPhoto];
            image              = [UIImage imageWithData:dataForPhoto];
        }
        
        // Add photo to recents list and save in cache.
        [self addToRecentPhotos];
        [self cachePhoto:dataForPhoto withID:photoID];
        
        dispatch_async(dispatch_get_main_queue(),^{
            // Push image to the view.
            [self.imageView setImage: image];
            self.imageView.frame = CGRectMake(0, 0, self.imageView.image.size.width, self.imageView.image.size.height);
            self.scrollView.contentSize = image.size;
            [self.view setNeedsLayout];
            
            // Append image dimensions to the title bar            
            NSString *imageWidthAsString  = [NSString stringWithFormat: @"%g", self.imageView.image.size.width];
            NSString *imageHeightAsString = [NSString stringWithFormat: @"%g", self.imageView.image.size.height];
            NSString *imageSizeAsString   = [NSString stringWithFormat: @" (%@w x %@h)", imageWidthAsString, imageHeightAsString];
            self.navigationItem.title     = [self.navigationItem.title stringByAppendingString:imageSizeAsString];
            
            // Color of navigation bar indicates cache state
            if (photoInCache) {
                self.navigationController.navigationBar.tintColor = CACHE_COLOR;
                self.scrollView.backgroundColor = CACHE_COLOR;
            } else {
                self.navigationController.navigationBar.tintColor = DEFAULT_COLOR;
                self.scrollView.backgroundColor = DEFAULT_COLOR;
            }
            
            [self.spinner stopAnimating];
        });
    });
    dispatch_release(photoQueue);
}

#pragma mark - Map View Controller Delegate

// Sets places as map annotations
- (NSArray *) mapAnnotations
{
    NSMutableArray *annotations = [NSMutableArray arrayWithCapacity:1];
    [annotations addObject:[FlickrPhotoAnnotation annotationForPhoto:self.chosenPhoto]];
    return annotations;
}

#pragma mark - View life cycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.scrollView.delegate = self;
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) { // If iPhone
        NSUInteger viewControllerCount = [self.navigationController.viewControllers count];
        PhotosTableViewController *callingViewController = [self.navigationController.viewControllers objectAtIndex:viewControllerCount - 2];
        [callingViewController setDelegate:self];
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:YES];
        
    self.scrollView.frame = self.view.frame;
    self.imageView.frame  = self.view.frame;
    self.spinner.center = self.view.center;
}

- (void)viewWillLayoutSubviews
{
    if (!self.imageView.image) return; // Sometimes, execution arrives here before the image has been retrieved
    [super viewWillLayoutSubviews];
    
    CGSize scrollViewSize = self.scrollView.bounds.size;
    CGRect imageRect = CGRectMake(0, 0, self.imageView.image.size.width, self.imageView.image.size.height);
    CGSize zoomSize  = scrollViewSize;
    CGFloat imageAspectRatio      = imageRect.size.width / imageRect.size.height;
    CGFloat scrollViewAspectRatio = scrollViewSize.width / scrollViewSize.height;
    int scaleType;
    if (imageAspectRatio < scrollViewAspectRatio) {
        scaleType = 1;
    } else {
        scaleType = 2;
    }
    switch (scaleType) {
        case 1:
            zoomSize.width  = imageRect.size.width;
            zoomSize.height = imageRect.size.width * scrollViewSize.height / scrollViewSize.width;
            break;
            
        case 2:
            zoomSize.height = imageRect.size.height;
            zoomSize.width  = imageRect.size.height * scrollViewSize.width / scrollViewSize.height;
            break;
    }
    
    [self.scrollView zoomToRect:CGRectMake(0, 0, zoomSize.width, zoomSize.height) animated:YES];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    
    // Release any retained subviews of the main view.
    [self setImageView:nil];
    [self setScrollView:nil];
    [self setSpinner:nil];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;
}

@end
