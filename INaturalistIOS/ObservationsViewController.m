//
//  INaturalistIOSViewController.m
//  INaturalistIOS
//
//  Created by Ken-ichi Ueda on 2/13/12.
//  Copyright (c) 2012 iNaturalist. All rights reserved.
//

#import "ObservationsViewController.h"
#import "LoginViewController.h"
#import "Observation.h"
#import "ObservationPhoto.h"
#import "DejalActivityView.h"
#import "ImageStore.h"

@implementation ObservationsViewController
@synthesize syncButton;
@synthesize observations = _observations;
@synthesize observationsToSyncCount = _observationsToSyncCount;
@synthesize observationPhotosToSyncCount = _observationPhotosToSyncCount;
@synthesize syncToolbarItems = _syncToolbarItems;
@synthesize syncedObservationsCount = _syncedObservationsCount;
@synthesize syncedObservationPhotosCount = _syncedObservationPhotosCount;

- (IBAction)sync:(id)sender {
    [RKObjectManager sharedManager].client.authenticationType = RKRequestAuthenticationTypeHTTPBasic;
    if (self.observationsToSyncCount > 0) {
        [self syncObservations];
    } else {
        [self syncObservationPhotos];
    }
}

- (void)syncObservations
{
    NSArray *observationsToSync = [Observation needingSync];
    
    if (observationsToSync.count == 0) return;
    
    NSLog(@"syncActivityView: %@", syncActivityView);
    NSString *activityMsg = [NSString stringWithFormat:@"Syncing 1 of %d observations", observationsToSync.count];
    if (syncActivityView) {
        [[syncActivityView activityLabel] setText:activityMsg];
    } else {
        syncActivityView = [DejalBezelActivityView activityViewForView:self.navigationController.view
                                                             withLabel:activityMsg];
    }
    
    // manually applying mappings b/c PUT and POST responses return JSON without a root element, 
    // e.g. {foo: 'bar'} instead of observation: {foo: 'bar'}, which RestKit apparently can't 
    // deal with using the name of the model it just posted.
    for (Observation *o in observationsToSync) {
        if (o.syncedAt) {
            [[RKObjectManager sharedManager] putObject:o mapResponseWith:[Observation mapping] delegate:self];
        } else {
            [[RKObjectManager sharedManager] postObject:o mapResponseWith:[Observation mapping] delegate:self];
        }
    }
}

- (void)syncObservationPhotos
{
    NSLog(@"syncObservationPhotos");
    NSArray *observationPhotosToSync = [ObservationPhoto needingSync];
    
    if (observationPhotosToSync.count == 0) return;
    
    NSLog(@"resetting syncActivityView");
    NSString *activityMsg = [NSString stringWithFormat:@"Syncing 1 of %d photos", observationPhotosToSync.count];
    if (syncActivityView) {
        [[syncActivityView activityLabel] setText:activityMsg];
    } else {
        syncActivityView = [DejalBezelActivityView activityViewForView:self.navigationController.view
                                                             withLabel:activityMsg];
    }
    
    for (ObservationPhoto *op in observationPhotosToSync) {
        if (op.syncedAt) {
            [[RKObjectManager sharedManager] putObject:op mapResponseWith:[ObservationPhoto mapping] delegate:self];
        } else {
            [[RKObjectManager sharedManager] postObject:op delegate:self block:^(RKObjectLoader *loader) {
                RKObjectMapping* serializationMapping = [[[RKObjectManager sharedManager] mappingProvider] serializationMappingForClass:[ObservationPhoto class]];
                NSError* error = nil;
                NSDictionary* dictionary = [[RKObjectSerializer serializerWithObject:op mapping:serializationMapping] serializedObject:&error];
                RKParams* params = [RKParams paramsWithDictionary:dictionary];
                [params setFile:[[ImageStore sharedImageStore] pathForKey:op.photoKey 
                                                                  forSize:ImageStoreLargeSize] 
                       forParam:@"file"];
                loader.params = params;
                loader.objectMapping = [ObservationPhoto mapping];
            }];
        }
    }
}

- (IBAction)edit:(id)sender {
    if ([self isEditing]) {
        [sender setTitle:@"Edit"];
        [self setEditing:NO animated:YES];
        [self checkSyncStatus];
    } else {
        [sender setTitle:@"Done"];
        [self setEditing:YES animated:YES];
    }
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        [[self.observations objectAtIndex:indexPath.row] destroy];
        [self.observations removeObjectAtIndex:indexPath.row];
        [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:YES];
    }
}

- (void)loadData
{
    [self setObservations:[[NSMutableArray alloc] initWithArray:[Observation all]]];
    [self setObservationsToSyncCount:0];
// if/when you want to bring back loading existing data, it's pretty easy
//    if (!observations || [observations count] == 0) {
//        [[RKObjectManager sharedManager] loadObjectsAtResourcePath:@"/observations/kueda" 
//                                                     objectMapping:[Observation mapping] 
//                                                          delegate:self];
//    }
    [self checkSyncStatus];
}

- (void)checkSyncStatus
{
    self.observationsToSyncCount = [Observation needingSyncCount];
    self.observationPhotosToSyncCount = [ObservationPhoto needingSyncCount];
    NSMutableString *msg = [NSMutableString stringWithString:@"Sync "];
    if (self.observationsToSyncCount > 0) {
        [msg appendString:[NSString stringWithFormat:@"%d observation", self.observationsToSyncCount]];
        if (self.observationsToSyncCount > 1) [msg appendString:@"s"];
        if (self.observationPhotosToSyncCount > 0) [msg appendString:@", "];
    }
    if (self.observationPhotosToSyncCount > 0) {
        [msg appendString:[NSString stringWithFormat:@"%d photo", self.observationPhotosToSyncCount]];
        if (self.observationPhotosToSyncCount > 1) [msg appendString:@"s"];
    }
    [self.syncButton setTitle:msg];
    if (self.itemsToSyncCount > 0) {
        [self.navigationController setToolbarHidden:NO];
        [self setToolbarItems:self.syncToolbarItems animated:YES];
    } else {
        [self.navigationController setToolbarHidden:YES];
        [self setToolbarItems:nil animated:YES];
    }
    self.syncedObservationsCount = 0;
}

- (int)itemsToSyncCount
{
    if (!self.observationsToSyncCount) self.observationsToSyncCount = 0;
    if (!self.observationPhotosToSyncCount) self.observationPhotosToSyncCount = 0;
    return self.observationsToSyncCount + self.observationPhotosToSyncCount;
}


# pragma mark TableViewController methods
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.observations count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    Observation *o = [self.observations objectAtIndex:[indexPath row]];
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ObservationTableCell"];
    if (o.sortedObservationPhotos.count > 0) {
        ObservationPhoto *op = [o.sortedObservationPhotos objectAtIndex:0];
        UIImage *img = [[ImageStore sharedImageStore] find:op.photoKey forSize:ImageStoreSquareSize];
        [cell.imageView setImage:img];
    } else {
        [cell.imageView setImage:nil];
    }
    if (o.speciesGuess) {
        [cell.textLabel setText:o.speciesGuess];
    } else {
        [cell.textLabel setText:@"Something..."];
    }
    return cell;
}

# pragma mark memory management
- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle
- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    if (!self.observations) {
        [self loadData];
    }
    self.navigationItem.titleView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"header-logo.png"]];
    
    [[[[RKObjectManager sharedManager] client] requestQueue] setDelegate:self]; // TODO, might have to unset this when this view closes?
}

- (void)viewDidUnload
{
    NSLog(@"viewDidUnload");
    [self setTableView:nil];
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [[[self navigationController] toolbar] setBarStyle:UIBarStyleBlack];
    [self setSyncToolbarItems:[NSArray arrayWithObjects:
                               [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil],
                               self.syncButton, 
                               [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil],
                               nil]];
    [self checkSyncStatus];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [self setEditing:NO];
    // TODO update edit button
    [self setToolbarItems:nil animated:YES];
    [self.navigationController setToolbarHidden:YES animated:YES];
	[super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
	[super viewDidDisappear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"AddObservationSegue"]) {
        ObservationDetailViewController *vc = [segue destinationViewController];
        [vc setDelegate:self];
        Observation *o = [Observation object];
        [vc setObservation:o];
    } else if ([segue.identifier isEqualToString:@"EditObservationSegue"]) {
        ObservationDetailViewController *vc = [segue destinationViewController];
        [vc setDelegate:self];
        Observation *o = [self.observations 
                          objectAtIndex:[[self.tableView 
                                          indexPathForSelectedRow] row]];
        [vc setObservation:o];
    } else if ([segue.identifier isEqualToString:@"LoginSegue"]) {
        LoginViewController *vc = (LoginViewController *)[segue.destinationViewController topViewController];
        [vc setDelegate:self];
    }
}

# pragma marl INObservationDetailViewControllerDelegate methods
- (void)observationDetailViewControllerDidSave:(ObservationDetailViewController *)controller
{
    [self dismissViewControllerAnimated:YES completion:nil];
    [[self navigationController] popToViewController:self animated:YES];
    [self loadData];
    [[self tableView] reloadData];
}

- (void)observationDetailViewControllerDidCancel:(ObservationDetailViewController *)controller
{
    [self dismissViewControllerAnimated:YES completion:nil];
    [[self navigationController] popToViewController:self animated:YES];
}

#pragma mark LoginControllerViewDelegate methods
- (void)loginViewControllerDidLogIn:(LoginViewController *)controller
{
    [self sync:nil];
}

#pragma mark RKObjectLoaderDelegate methods
- (void)objectLoader:(RKObjectLoader*)objectLoader didLoadObjects:(NSArray*)objects {
    NSLog(@"objectLoader didLoadObjects");
    if (objects.count == 0) return;
    
    NSDate *now = [NSDate date];
    for (INatModel *o in objects) {
        [o setSyncedAt:now];
    }
    [[[RKObjectManager sharedManager] objectStore] save];
    
    NSString *activityMsg;
    if ([[objects firstObject] isKindOfClass:[Observation class]]) {
        self.syncedObservationsCount += 1;
        activityMsg = [NSString stringWithFormat:@"Syncing %d of %d observations", 
                       self.syncedObservationsCount + 1, 
                       self.observationsToSyncCount];
        if (self.syncedObservationsCount >= self.observationsToSyncCount) {
            [self syncObservationPhotos];
        } else if (syncActivityView) {
            [[syncActivityView activityLabel] setText:activityMsg];
        }
    } else {
        self.syncedObservationPhotosCount += 1;
        activityMsg = [NSString stringWithFormat:@"Syncing %d of %d photos", 
                       self.syncedObservationPhotosCount + 1, 
                       self.observationPhotosToSyncCount];
        if (syncActivityView) {
            [[syncActivityView activityLabel] setText:activityMsg];
        }
    }
}

- (void)objectLoader:(RKObjectLoader *)objectLoader didFailWithError:(NSError *)error {
    NSLog(@"failed with error: %@", error);
    if (syncActivityView) {
        [DejalBezelActivityView removeView];
        syncActivityView = nil;
    }
    
    [[[[RKObjectManager sharedManager] client] requestQueue] cancelAllRequests];
    
    NSString *errorMsg;
    bool jsonParsingError = false, authFailure = false;
    NSLog(@"objectLoader.response.statusCode: %d", objectLoader.response.statusCode);
    switch (objectLoader.response.statusCode) {
        // UNPROCESSABLE ENTITY
        case 422:
            errorMsg = @"Unprocessable entity";
            break;
            
        default:
            // KLUDGE!! RestKit doesn't seem to handle failed auth very well
            jsonParsingError = [error.domain isEqualToString:@"JKErrorDomain"] && error.code == -1;
            authFailure = [error.domain isEqualToString:@"NSURLErrorDomain"] && error.code == -1012;
            errorMsg = error.localizedDescription;
    }
    
    if (jsonParsingError || authFailure) {
        [self performSegueWithIdentifier:@"LoginSegue" sender:self];
    } else {
        UIAlertView *av = [[UIAlertView alloc] initWithTitle:@"Whoops!" 
                                                     message:[NSString stringWithFormat:@"Looks like there was an error: %@", errorMsg]
                                                    delegate:self 
                                           cancelButtonTitle:@"OK" 
                                           otherButtonTitles:nil];
        [av show];
    }
}

- (void)objectLoaderDidLoadUnexpectedResponse:(RKObjectLoader *)objectLoader
{
    UIAlertView *av = [[UIAlertView alloc] initWithTitle:@"Whoops!" 
                                                 message:@"Unknown error! Please report this to help@inaturalist.org"
                                                delegate:self 
                                       cancelButtonTitle:@"OK" 
                                       otherButtonTitles:nil];
    [av show];
}

#pragma mark RKRequestQueueDelegate methods
- (void)requestQueueDidFinishLoading:(RKRequestQueue *)queue
{
    [[self tableView] reloadData];
    [self checkSyncStatus];
    if (syncActivityView) {
        [DejalBezelActivityView removeView];
        syncActivityView = nil;
    }
}

@end
