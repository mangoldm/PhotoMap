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
    NSString *photoID         = [photo objectForKey:FLICKR_PHOTO_ID];
    
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
        dispatch_async(dispatch_get_main_queue(),^{
            [self addToRecentPhotos];
            [self cachePhoto:dataForPhoto withID:photoID];
            
            // Push image to the view.
            [self.imageView setImage: image];
            self.scrollView.contentSize = self.imageView.image.size;
            self.imageView.frame        = CGRectMake(0, 0, self.imageView.image.size.width, self.imageView.image.size.height);
            
            // Color of navigation bar indicates cache state
            if (photoInCache) {
                self.navigationController.navigationBar.tintColor = CACHE_COLOR;
            } else {
                self.navigationController.navigationBar.tintColor = DEFAULT_COLOR;
            }
            
            // zoom to fit the image by whichever dimension is closest to the screen size
            CGFloat imageAspectRatio = self.imageView.image.size.width   / self.imageView.image.size.height;
            CGFloat viewAspectRatio  = self.scrollView.bounds.size.width / self.scrollView.bounds.size.height;
            if (imageAspectRatio < viewAspectRatio) {
                [self.scrollView zoomToRect:CGRectMake(0, 0, self.imageView.image.size.width, self.scrollView.bounds.size.height) animated:YES];
            } else {
                [self.scrollView zoomToRect:CGRectMake(0, 0, self.scrollView.bounds.size.width, self.imageView.image.size.height) animated:YES];
            }
            [self.spinner stopAnimating];
        });
    });
    dispatch_release(photoQueue);
}

// Centers image after zooming instead of hugging upper-left corner
// From Erdemus at http://stackoverflow.com/questions/1316451/center-content-of-uiscrollview-when-smaller
- (void)scrollViewDidZoom:(UIScrollView *)aScrollView {
    CGFloat offsetX = (self.scrollView.bounds.size.width > self.scrollView.contentSize.width)? 
	(self.scrollView.bounds.size.width - self.scrollView.contentSize.width) * 0.5 : 0.0;
    CGFloat offsetY = (self.scrollView.bounds.size.height > self.scrollView.contentSize.height)? 
	(self.scrollView.bounds.size.height - self.scrollView.contentSize.height) * 0.5 : 0.0;
    self.imageView.center = CGPointMake(self.scrollView.contentSize.width  * 0.5 + offsetX, 
                                        self.scrollView.contentSize.height * 0.5 + offsetY);
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
	self.scrollView.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight); // rotate subviews
	self.scrollView.delegate = self;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
	
    if (!self.splitViewController) { // If not iPad
        // reference the calling view controller and set its delegate to self
        NSUInteger viewControllerCount = [self.navigationController.viewControllers count];
        PhotosTableViewController *callingViewController = [self.navigationController.viewControllers objectAtIndex:viewControllerCount - 2];
        [callingViewController setDelegate:self];
        
        // set scrollView's frame to be the same size as the navigation controller's
        self.scrollView.frame = callingViewController.view.frame;
        
        self.spinner.center = self.view.center;
    } else {
        UINavigationController *detailNav = [self.splitViewController.viewControllers lastObject];
        UIViewController *detail = [detailNav.viewControllers lastObject];
        self.scrollView.frame = detail.view.frame;
    }
}

- (void)viewDidUnload
{
    [self setImageView:nil];
    [self setScrollView:nil];
    [self setSpinner:nil];
    [super viewDidUnload];
    // Release any retained subviews of the main view.
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;
}

@end
