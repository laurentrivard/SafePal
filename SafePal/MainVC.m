//
//  ViewController.m
//  SafePal
//
//  Created by Laurent Rivard on 11/2/13.
//  Copyright (c) 2013 Rivard.Laurent. All rights reserved.
//

#import "mainVC.h"
#import "AFNetworking.h"
#import <CoreLocation/CoreLocation.h>
#import "CrimeBreakdownVC.h"

#define METERS_PER_MILE 1609.344

@interface MainVC ()
@property BOOL isNightTime, _isOnWifi;
@property (strong, nonatomic) NSTimer *timer;
@property (strong, nonatomic) NSString *zipCode;
@property (strong, nonatomic) NSArray *crimeCategories;
@property CLLocationCoordinate2D userLoc;
@property (strong, nonatomic) NSDictionary *crimeDic;
@property (strong, nonatomic) NSArray *crimesArray;
@end

@implementation MainVC
@synthesize mapView=_mapView;
@synthesize locationManager=_locationManager;
@synthesize location=_location;
@synthesize isNightTime=_isNightTime, _isOnWifi=_isOnWifi;
@synthesize  timer=_timer;
@synthesize zipCode=_zipCode;
@synthesize crimeCategories=_crimeCategories;
@synthesize userLoc=_userLoc;
@synthesize crimeDic=_crimeDic;
@synthesize crimesArray=_crimesArray;
@synthesize breakdownLabel=_breakdownLabel;
@synthesize breakdownView=_breakdownView;

- (void)viewDidLoad
{
    [super viewDidLoad];
	// setting night time to false to start out
    _isNightTime = NO;
    _isOnWifi = NO;

    _crimeCategories = [[NSArray alloc] initWithObjects:@"Arrest", @"Arson", @"Assault", @"Burglary", @"Robbery", @"Shooting", @"Theft", @"Vandalism", @"Other", nil];

    
    //initialize location manager
    if (!_locationManager) {
        _locationManager = [[CLLocationManager alloc]init];
        _locationManager.desiredAccuracy = kCLLocationAccuracyBest;
        _locationManager.delegate = self;
    }
    [_locationManager startUpdatingLocation];
    
    //tells the app to keep things running in background -->??
    UIBackgroundTaskIdentifier bgTask =0;
    UIApplication  *app = [UIApplication sharedApplication];
    bgTask = [app beginBackgroundTaskWithExpirationHandler:^{
        [app endBackgroundTask:bgTask];
    }];
    

    [self schedule8PMAnd6AMTimer];

}
-(void) schedule8PMAnd6AMTimer {
    //the hour right now
    int hour = [self getHour];
    NSDate *date = [NSDate date];
    NSCalendar *calendar = [NSCalendar autoupdatingCurrentCalendar];
    NSUInteger preservedComponents = (NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit);
    date = [calendar dateFromComponents:[calendar components:preservedComponents fromDate:date]];
    NSDate *morning = date;
    if(hour < 20) //if it's not 8PM today yet
        date = [date dateByAddingTimeInterval:60*60*20]; //set the date to today at 8PM
    else
        date = [date dateByAddingTimeInterval:60*60*44]; //set the date to tomorrow at 8PM
    
    NSTimer *timer8PM = [NSTimer scheduledTimerWithTimeInterval:[date timeIntervalSinceNow] target:self selector:@selector(startTracking:) userInfo:nil repeats:NO];
    if(hour > 6)
        morning = [morning dateByAddingTimeInterval:60*60*30]; //set the date to tomorrow morning at 6AM
    else
        morning = [morning dateByAddingTimeInterval:60*60*6]; //set the date to today at 6AM
    
        NSTimer *timer6AM = [NSTimer scheduledTimerWithTimeInterval:[date timeIntervalSinceNow] target:self selector:@selector(stopTracking:) userInfo:nil repeats:NO];
}
-(void) startTracking: (NSTimer *) timer {
    _timer = [NSTimer scheduledTimerWithTimeInterval:15 target:self selector:@selector(fireTimer:) userInfo:nil repeats:YES];
    
}
-(void) stopTracking: (NSTimer *) timer {
    [_timer invalidate];
}
-(void) fireTimer: (NSTimer *) timer {

    
    UIApplicationState state = [[UIApplication sharedApplication] applicationState];

    int hour = [self getHour];
    
    //check if it's nighttime --> run in background
    if(hour >=20 || hour <= 4) {
        if (state == UIApplicationStateBackground || state == UIApplicationStateInactive)
        {
            [_locationManager startUpdatingLocation];
            NSLog(@"updated location");
        }
    }
//
//    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(networkChanged:) name:kReachabilityChangedNotification object:nil];
//    
//    reachability = [Reachability reachabilityForInternetConnection];
//    [reachability startNotifier];
//    
    
    //check what time it is
    //get location
    //query crimes
    //show marker on map if app is in foreground
    //
}


//- (void)networkChanged:(NSNotification *)notification
//{
//    
//    NetworkStatus remoteHostStatus = [reachability currentReachabilityStatus];
//    
//    if(remoteHostStatus == NotReachable) { NSLog(@"not reachable");}
//    else if (remoteHostStatus == ReachableViaWiFiNetwork) { NSLog(@"wifi"); }
//    else if (remoteHostStatus == ReachableViaCarrierDataNetwork) { NSLog(@"carrier"); }
//}
-(int) getHour {
    //need to check if it's night time (8PM-4AM)
    NSDate *now = [NSDate date];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    //24 hour clock
    NSLocale* formatterLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_GB"];
    [formatter setLocale:formatterLocale];
    [formatter setDateFormat:@"HH"];
    NSString *hourStr = [formatter stringFromDate:now];
    
    return [hourStr intValue];
}
- (void)locationManager:(CLLocationManager *)manager
    didUpdateToLocation:(CLLocation *)newLocation
           fromLocation:(CLLocation *)oldLocation{
    
    CLLocationCoordinate2D mapLocation;
    mapLocation.latitude = newLocation.coordinate.latitude;
    mapLocation.longitude = newLocation.coordinate.longitude;
    
    _userLoc.latitude = newLocation.coordinate.latitude;
    _userLoc.longitude = newLocation.coordinate.longitude;
    MKCoordinateRegion viewRegion = MKCoordinateRegionMakeWithDistance(mapLocation,METERS_PER_MILE,METERS_PER_MILE);

    MKReverseGeocoder *geocoder = [[MKReverseGeocoder alloc] initWithCoordinate:mapLocation];
	[geocoder setDelegate:self];
	[geocoder start];

    [_mapView setRegion:viewRegion animated:YES];
    
    //stop location manager
    [_locationManager stopUpdatingLocation];
    
}
- (void)reverseGeocoder:(MKReverseGeocoder *)geocoder didFailWithError:(NSError *)error {
    UIAlertView *err = [[UIAlertView alloc] initWithTitle:@"Error" message:[error localizedDescription] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil];
    
    [err show];
}
- (void)reverseGeocoder:(MKReverseGeocoder *)geocoder didFindPlacemark:(MKPlacemark *)placemark
{
    //gets the zipcode of user location
    _zipCode = [[placemark addressDictionary] objectForKey:@"ZIP"];

    
    [self getCrimeDataWithLatitude:_userLoc.latitude andLongitude:_userLoc.longitude andZipCode:_zipCode andCity:@"lkajsdflkjasdf"];

}
- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    NSLog(@"ERROR UPDATING LOCATION: %@", [error localizedDescription]);
}
- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void) getCrimeDataWithLatitude:(double) latitude andLongitude:(double) longitude andZipCode:(NSString *) zipCode andCity:(NSString *) city {
    NSURL *url = [NSURL URLWithString:@"http://safepal.herokuapp.com/"];
    AFHTTPClient *httpClient = [[AFHTTPClient alloc] initWithBaseURL:url];
    NSNumber *lat = [NSNumber numberWithDouble:latitude];
    NSNumber *lng = [NSNumber numberWithDouble:longitude];

    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            lat , @"lat",
                            lng, @"lon",
                            nil];
    [httpClient getPath:@"/api" parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
        _crimeDic = [NSJSONSerialization JSONObjectWithData:responseObject options:0 error:nil];
        BOOL dangerous = [[[_crimeDic objectForKey:@"metadata"] objectForKey:@"sendAlert"] boolValue];
        NSLog(@"dangerous: %@", [[_crimeDic objectForKey:@"metadata"] objectForKey:@"sendAlert"] );
        NSString *reason = [[_crimeDic objectForKey:@"metadata"] objectForKey:@"reason"];
        //if app is backgrounded just send notification
        UIApplicationState state = [[UIApplication sharedApplication] applicationState];
        if (state == UIApplicationStateBackground || state == UIApplicationStateInactive)
        {
            if(dangerous)
                [self sendLocalNotification];
        }
        else if(state == UIApplicationStateActive) {
            [self showAnnotationsAndData];
            [self updateViewWithReason:reason andDangerousBool:dangerous];
        }

    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"[HTTPClient Error]: %@", error.localizedDescription);
    }];
}
-(void) showAnnotationsAndData {
    _crimesArray = [_crimeDic objectForKey:@"data"];
    NSLog(@"count: %d", [_crimesArray count]);
    
    for(NSDictionary *dic in _crimesArray) {
        MKPointAnnotation *ann = [[MKPointAnnotation alloc] init];
        [ann setCoordinate:CLLocationCoordinate2DMake([[dic objectForKey:@"lat"] doubleValue], [[dic objectForKey:@"lon"] doubleValue])];
        [ann setTitle:[dic objectForKey:@"type"]];
        [_mapView addAnnotation:ann];
    }
}

-(void) sendLocalNotification {
    UILocalNotification* localNotification = [[UILocalNotification alloc] init];
    localNotification.fireDate = [NSDate dateWithTimeIntervalSinceNow:0];
    localNotification.alertBody = @"Be careful!";
    [[UIApplication sharedApplication] scheduleLocalNotification:localNotification];
    NSLog(@"notification is scheduled");

}
//call 911 if panic button is pressed
-(IBAction)panicBtnPressed:(id)sender {
    NSString *phNo = @"911";
    NSURL *phoneUrl = [NSURL URLWithString:[NSString  stringWithFormat:@"telprompt:%@",phNo]];
    
    if ([[UIApplication sharedApplication] canOpenURL:phoneUrl])
        [[UIApplication sharedApplication] openURL:phoneUrl];
}
-(IBAction)breakdownBtnPressed:(id)sender{
    [self performSegueWithIdentifier:@"breakdownSegue" sender:self];
}
//update bottom view when alarm changes
-(void) updateViewWithReason: (NSString *) reason andDangerousBool: (BOOL) dangerous {
    NSLog(@"reason: %@, dnagerous : %c", reason, dangerous);
    
    if(dangerous) {
        _breakdownView.backgroundColor = [UIColor redColor];
    }
    else {
        _breakdownView.backgroundColor = [UIColor blueColor];
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Make sure your segue name in storyboard is the same as this line
    if ([[segue identifier] isEqualToString:@"breakdownSegue"])
    {
        // Get reference to the destination view controller
        CrimeBreakdownVC *vc = [segue destinationViewController];
        vc.crimeData = _crimesArray;
        CLLocation *loc = [[CLLocation alloc] initWithLatitude:_userLoc.latitude longitude:_userLoc.longitude];
        vc.userLocation = loc;
    }
}
@end

//TODO
    // check for wifi
    //change safe/unsafe label
    //choose colors
    //get icons for crime types
    //sort tableviews by crime type
    //display text in bottom view


