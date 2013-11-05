//
//  BUSRouteListVCViewController.m
//  BusAwesome
//
//  Created by Gilad Goldberg on 10/29/13.
//  Copyright (c) 2013 Gilad Goldberg. All rights reserved.
//

#import <HexColor.h>
#import "UIViewController+IICNavigator.h"
#import "BUSRouteListVC.h"
#import "BUSGTFSService.h"
#import "BUSRouteListCell.h"
#import "BUSTripVC.h"
#import <MBProgressHUD.h>
#import "BUSRouteListSectionHeader.h"

#define SECTION_HEADER_HEIGHT 42

@interface BUSRouteListVC ()
@property (nonatomic, strong) NSDictionary *tripsByLines;
@property (nonatomic, strong) NSArray *lines;
@property (nonatomic, strong) NSDictionary *agencyColorsById;
@property (nonatomic, weak) UIRefreshControl *refreshControl;

- (NSArray *)getTripsFromSection:(NSInteger)section;
@end

@implementation BUSRouteListVC

- (void)viewDidLoad
{
  [self initAgencyColors];
  self.tableView.dataSource = self;
  self.tableView.delegate = self;
  
  MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
  hud.labelText = @"טוען קווים קרובים...";
  
  [self refresh:nil];
  
  // Doing this way because the property is weak, so we need a local variable to keep
  // it in memory until we add it as a subview, which will retain it
  UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
  [refreshControl addTarget:self action:@selector(refresh:) forControlEvents:UIControlEventValueChanged];
  [self.tableView addSubview:refreshControl];
  
  self.refreshControl = refreshControl;
}

- (void)refresh:(UIRefreshControl *)refreshControl {
  [self.refreshControl beginRefreshing];
  [[BUSLocationService sharedInstance] getCurrentLocation:^(CLLocation  *location) {
    [self updateTrips:location.coordinate];
  } withAccuracy:10.0];
}

-(void)initAgencyColors
{
  NSString *plistPath = [[NSBundle mainBundle] pathForResource:@"agency-colors" ofType:@"plist"];
  self.agencyColorsById = [[NSDictionary alloc] initWithContentsOfFile:plistPath];
}

-(void)updateTrips:(CLLocationCoordinate2D)coordinate
{
  NSNumber *lat =[[NSNumber alloc] initWithDouble:coordinate.latitude];
  NSNumber *lon =  [[NSNumber alloc] initWithDouble:coordinate.longitude];

  [BUSGTFSService findTrips:lat withLongitude:lon withRadiusInMeters:nil withBlock:^(NSArray *trips) {
    self.tripsByLines = _.reduce(trips, [NSMutableDictionary new], ^(NSMutableDictionary *memo, BUSTrip *trip) {
      NSMutableArray *currentElement = [memo objectForKey:trip.route.shortName];
      if (!currentElement) {
        currentElement = [[NSMutableArray alloc] initWithArray:@[trip]];
      } else {
        [currentElement addObject:trip];
      }
      memo[trip.route.shortName] = currentElement;
      return memo;
    });
    self.lines = [_.keys(self.tripsByLines) sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
      NSNumber *first = @([((NSString *)a) integerValue]);
      NSNumber *second = @([((NSString *)b) integerValue]);
      return [first compare:second];
    }];
    [self.tableView reloadData];
    [MBProgressHUD hideAllHUDsForView:self.view animated:NO];
    [self.refreshControl endRefreshing];
  }];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  BUSRouteListCell *cell = (BUSRouteListCell*)[tableView dequeueReusableCellWithIdentifier:@"RouteList" forIndexPath:indexPath];
  NSArray *trips = [self getTripsFromSection:indexPath.section];
  BUSTrip *trip = trips[indexPath.row];
  cell.routeNameLabel.text = [NSString stringWithFormat:@"לכיוון %@", trip.destination];
  return cell;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
  NSArray *trips = [self getTripsFromSection:section];
  BUSTrip *aTrip = trips[0];
  NSString *agencyId = aTrip.route.agency.Id;
  NSString *agencyHexColor = self.agencyColorsById[agencyId];
  UIColor *agencyBGColor = [UIColor colorWithHexString:agencyHexColor alpha:1];
  
  NSString *lineNumberCaption = [NSString stringWithFormat:@"קו %@", aTrip.route.shortName];
  NSString *agencyCaption = aTrip.route.agency.name;
  
  BUSRouteListSectionHeader *sectionHeader = [[BUSRouteListSectionHeader alloc] initWithLineNumber:lineNumberCaption withAgencyName:agencyCaption withBackgroundColor:agencyBGColor];
  return sectionHeader;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
  return SECTION_HEADER_HEIGHT;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  return [self getTripsFromSection:section].count;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
  return self.lines.count;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  NSArray *trips = [self getTripsFromSection:indexPath.section];
  BUSTrip *trip = trips[indexPath.row];
  
  BUSTripVC *vc = (BUSTripVC*)[self viewFrom:@"Trip"];
  vc.tripId = trip.Id;
  
  [self.navigationController pushViewController:vc animated:YES];
}

- (NSArray *)getTripsFromSection:(NSInteger)section
{
  NSString *lineName = self.lines[section];
  return self.tripsByLines[lineName];
}

@end
