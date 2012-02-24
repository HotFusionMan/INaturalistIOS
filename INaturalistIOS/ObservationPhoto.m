//
//  ObservationPhoto.m
//  INaturalistIOS
//
//  Created by Ken-ichi Ueda on 2/20/12.
//  Copyright (c) 2012 iNaturalist. All rights reserved.
//

#import "ObservationPhoto.h"
#import "Observation.h"
#import "ImageStore.h"

@implementation ObservationPhoto

@dynamic createdAt;
@dynamic largeURL;
@dynamic license_code;
@dynamic localCreatedAt;
@dynamic localUpdatedAt;
@dynamic mediumURL;
@dynamic nativePageURL;
@dynamic nativeRealName;
@dynamic nativeUsername;
@dynamic observationID;
@dynamic originalURL;
@dynamic position;
@dynamic recordID;
@dynamic smallURL;
@dynamic squareURL;
@dynamic syncedAt;
@dynamic thumbURL;
@dynamic updatedAt;
@dynamic observation;
@dynamic photoKey;

@synthesize photoSource = _photoSource;
@synthesize index = _index;
@synthesize size = _size;

- (void)prepareForDeletion
{
    [super prepareForDeletion];
    [[ImageStore sharedImageStore] destroy:self.photoKey];
}

#pragma mark TTPhoto protocol methods
- (NSString *)URLForVersion:(TTPhotoVersion)version
{
    NSString *url;
    if (self.photoKey) {
        switch (version) {
            case TTPhotoVersionThumbnail:
                url = [[ImageStore sharedImageStore] urlStringForKey:self.photoKey forSize:ImageStoreSquareSize];
                break;
            case TTPhotoVersionSmall:
                url = [[ImageStore sharedImageStore] urlStringForKey:self.photoKey forSize:ImageStoreSmallSize];
                break;
            case TTPhotoVersionMedium:
                url = [[ImageStore sharedImageStore] urlStringForKey:self.photoKey forSize:ImageStoreSmallSize];
                break;
            case TTPhotoVersionLarge:
                url = [[ImageStore sharedImageStore] urlStringForKey:self.photoKey forSize:ImageStoreLargeSize];
                break;
            default:
                url = nil;
                break;
        }
    } else {
        switch (version) {
            case TTPhotoVersionThumbnail:
                url = self.squareURL;
                break;
            case TTPhotoVersionSmall:
                url = self.smallURL;
                break;
            case TTPhotoVersionMedium:
                url = self.mediumURL;
                break;
            case TTPhotoVersionLarge:
                url = self.largeURL;
                break;
            default:
                url = nil;
                break;
        }
    }
    return url;
}

- (CGSize)size
{
    // since size is a struct, it sort of already has all its "attributes" in place, 
    // but they have been initialized to zero, so this is the equivalent of a null check
    if (_size.width == 0) {
        UIImage *img = [[ImageStore sharedImageStore] find:self.photoKey forSize:ImageStoreLargeSize];
        if (img) {
            [self setSize:img.size];
        } else {
            [self setSize:UIScreen.mainScreen.bounds.size];
        }
    }
    return _size;

}

- (NSString *)caption
{
    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    [fmt setDateFormat:@"hh:mm aaa MMM d, yyyy"];
    return [NSString stringWithFormat:@"Added at %@", [fmt stringFromDate:self.localCreatedAt]];
}

@end