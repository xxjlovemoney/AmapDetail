//
//  ViewController.m
//  高德地图详细测试
//
//  Created by 许小军 on 2017/5/15.
//  Copyright © 2017年 gaga. All rights reserved.
//


//1、导入头文件
//2、创建一个私有地图属性，遵守代理协议
//3、初始化地图
//4、实现地理编码转换，导入头文件 AMapSearchKit/AMapSearchKit.h,在这里面的两个编码转换方法中实现
//5、初始化一个search对象
//6、兴趣点poi搜索  添加一个搜索按钮


#define mapKey @"6fe4747d3b5b452729cd2abdae3986d0"

#import "ViewController.h"
#import <MAMapKit/MAMapKit.h>
#import <AMapFoundationKit/AMapFoundationKit.h>
#import <AMapSearchKit/AMapSearchKit.h>


@interface ViewController ()<MAMapViewDelegate,AMapSearchDelegate,UITableViewDelegate,UITableViewDataSource,UIGestureRecognizerDelegate>
//创建一个私有地图属性
@property(strong,nonatomic)MAMapView * mapView;

@property(strong,nonatomic) AMapSearchAPI * search;
    
//当前位置
@property(strong,nonatomic) CLLocation * currentLocation;
    
    
@property(strong,nonatomic) UITableView * tableView;
//所有的兴趣点
@property(strong,nonatomic) NSArray * pois;
//点击添加大头针记录
@property(strong,nonatomic) NSMutableArray * annotations;
    
//长按手势
@property(strong,nonatomic) UILongPressGestureRecognizer * longPress;

//目的的坐标的
@property(strong,nonatomic) MAPointAnnotation * destinationPoint;
    
//路线数组
@property(strong,nonatomic) NSArray * pathPolylines;

    
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    //1、初始化地图
    [self setUpMapView];
    
    //初始化search
    [self setUpSearch];
    
    //搜索按钮
    [self setUpSearchButton];
    
    //数组初始化
    [self arrayInit];
    
    //tableView初始化
    [self setUpTableView];
    
    //长按手势
    [self longPressGes];
    
    //路径按钮
    [self setUpWayButton];
}
    
-(void)setUpWayButton
{
    UIButton * searchPOIButton = [[UIButton alloc]initWithFrame:CGRectMake(200, 100, 40, 40)];
    searchPOIButton.backgroundColor  = [UIColor greenColor];
    [searchPOIButton setTitle:@"way搜索" forState:UIControlStateNormal];
    [searchPOIButton addTarget:self action:@selector(searchWay) forControlEvents:UIControlEventTouchUpInside];
    [self.mapView addSubview:searchPOIButton];
}
    
#pragma mark --长按手势
-(void)longPressGes
{
    UILongPressGestureRecognizer * longPressGep = [[UILongPressGestureRecognizer alloc]initWithTarget:self action:@selector(longpressClick:)];
    longPressGep.delegate = self;
    [self.mapView addGestureRecognizer:longPressGep];
}

-(void)longpressClick:(UILongPressGestureRecognizer *)gesture
{
    if (gesture.state == UIGestureRecognizerStateBegan) {
        //将相对于view的坐标转化为经纬度坐标
        CLLocationCoordinate2D coordinate = [self.mapView convertPoint:[gesture locationInView:self.mapView] toCoordinateFromView:self.mapView];
        
        //添加标注
        if (self.destinationPoint != nil) {
            //清理
            [self.mapView removeAnnotation:self.destinationPoint];
            self.destinationPoint = nil;
        }
        
        self.destinationPoint = [[MAPointAnnotation alloc]init];
        self.destinationPoint.coordinate = coordinate;
        self.destinationPoint.title = @"目的的";
        
        [self.mapView addAnnotation:self.destinationPoint];
        
    }
}

-(void)searchWay
{
    if (self.destinationPoint == nil || self.currentLocation == nil || self.search == nil) {
        NSLog(@"path search failed");
        return;
    }
    
    AMapRidingRouteSearchRequest * navRide = [[AMapRidingRouteSearchRequest alloc]init];
    navRide.origin = [AMapGeoPoint locationWithLatitude:self.currentLocation.coordinate.latitude longitude:self.currentLocation.coordinate.longitude];
    
    navRide.destination = [AMapGeoPoint locationWithLatitude:self.destinationPoint.coordinate.latitude longitude:self.destinationPoint.coordinate.longitude];
    
    [self.search AMapRidingRouteSearch:navRide];
}
    
/* 路径规划搜索回调. */
- (void)onRouteSearchDone:(AMapRouteSearchBaseRequest *)request response:(AMapRouteSearchResponse *)response
{
    if (response.route > 0)
    {
        [self.mapView removeOverlays:self.pathPolylines];
        self.pathPolylines = nil;
        
        //只显示第一条
        self.pathPolylines = [self polylinesForPath:response.route.paths[0]];
        [self.mapView addOverlays:self.pathPolylines];
        
        //地图显示的范围
        [self.mapView showAnnotations:@[self.destinationPoint,self.mapView.userLocation] animated:YES];
    }
    
    //解析response获取路径信息，具体解析见 Demo
}
    
//字符串解析
-(CLLocationCoordinate2D *)coordinatesForString:(NSString *)string coordinaCount:(NSUInteger *)coordinateCount parseToken:(NSString *)token
{
    if (string == nil) {
        return NULL;
    }
    
    if (token == nil) {
        token = @",";
    }
    
    NSString * str=@"";
    if ([token isEqualToString:@","]) {
        str = [string stringByReplacingOccurrencesOfString:token withString:@","];
    }
    else
    {
        str = [NSString stringWithString:string];
    }
    
    NSArray * components = [str componentsSeparatedByString:@","];
    
    NSUInteger count = components.count / 2;
    
    if (coordinateCount !=NULL) {
        *coordinateCount = count;
    }
    
    CLLocationCoordinate2D * coordinates = (CLLocationCoordinate2D *)malloc(count * sizeof(CLLocationCoordinate2D));
    
    for (int i =0; i<count; i++) {
        coordinates[i] . longitude = [[components objectAtIndex:2 * i] doubleValue];
        coordinates[i].latitude = [[components objectAtIndex:2 *i + 1] doubleValue];
        
    }
    
    return coordinates;
}
    
-(NSArray *)polylinesForPath:(AMapPath *)path
{
    if (path == nil || path.steps.count == 0) {
        return  nil;
    }
    NSMutableArray * polylines = [NSMutableArray array];
    [path.steps enumerateObjectsUsingBlock:^(AMapStep * step, NSUInteger idx, BOOL * _Nonnull stop) {
        NSUInteger count = 0;
        CLLocationCoordinate2D * coordinates = [self coordinatesForString:step.polyline coordinaCount:&count parseToken:@","];
        MAPolyline * polyline = [MAPolyline polylineWithCoordinates:coordinates count:count];
        [polylines addObject:polyline];
        
        free(coordinates), coordinates = NULL;
        
    }];
    
    return polylines;
}
#pragma maek --MAMapViewDelegate
-(MAOverlayView *)mapView:(MAMapView *)mapView rendererForOverlay:(id<MAOverlay>)overlay
{
    if ([overlay isKindOfClass:[MAPolyline class]]) {
        MAPolylineView * polylineView = [[MAPolylineView alloc]initWithPolyline:overlay];
        polylineView.lineWidth = 4;
        polylineView.strokeColor = [UIColor magentaColor];
        return polylineView;
    }
    return  nil;
}
    
    


-(void)arrayInit
{
    self.annotations = [NSMutableArray array];
    self.pois = nil;
}
    
-(void)setUpTableView
{
    self.tableView = [[UITableView alloc]initWithFrame:CGRectMake(0, CGRectGetHeight(self.view.bounds) * 0.5, CGRectGetWidth(self.view.bounds), CGRectGetHeight(self.view.bounds) * 0.5) style:UITableViewStylePlain];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.view addSubview:self.tableView];
}

#pragma mark -- 初始化地图
-(void)setUpMapView
{
    [AMapServices sharedServices].apiKey = mapKey;
    
    self.mapView = [[MAMapView alloc]initWithFrame:CGRectMake(0, 0, CGRectGetWidth(self.view.bounds), CGRectGetHeight(self.view.bounds) * 0.5)];
    self.mapView.delegate = self;
    
    [self.view addSubview:self.mapView];
    
    //定位开启，并显示小蓝点
    self.mapView.showsUserLocation = YES;
    //定位模式
    _mapView.userTrackingMode = MAUserTrackingModeFollowWithHeading;
    
}
    
#pragma mark -- 初始化search
-(void)setUpSearch
{
    self.search = [[AMapSearchAPI alloc]init];
    self.search.delegate = self;

}
    
#pragma mark -- MAMapViewDelegate,实时更新位置刷新
-(void)mapView:(MAMapView *)mapView didUpdateUserLocation:(MAUserLocation *)userLocation updatingLocation:(BOOL)updatingLocation
{
    NSLog(@"userLocation : %@",userLocation.location);
    //获取当前位置
    self.currentLocation = userLocation.location;
}
    
#pragma mark -- MAMapViewDelegate,标记被选中时
//在地图上的标记也就是大头针被选中时，让其显示当前位置的一些信息
//就用到反地理编码
-(void)mapView:(MAMapView *)mapView didSelectAnnotationView:(MAAnnotationView *)view
{
    //选中定位annotationde的时候进行逆地理编码查询
    if ([view.annotation isKindOfClass:[MAUserLocation class]]) {
        [self reGeoAction];
    }
}
    
    
//反地理编码
-(void)reGeoAction
{
    if (self.currentLocation) {
        AMapReGeocodeSearchRequest * request = [[AMapReGeocodeSearchRequest alloc]init];
        request.location = [AMapGeoPoint locationWithLatitude:self.currentLocation.coordinate.latitude longitude:self.currentLocation.coordinate.longitude];
        //开启逆地理编码，同时search也有回调
        [self.search AMapReGoecodeSearch:request];
    }
}

// 逆地理编码查询回调函数
-(void)onReGeocodeSearchDone:(AMapReGeocodeSearchRequest *)request response:(AMapReGeocodeSearchResponse *)response
{
    NSLog(@"response %@",response);
    //市
    NSString * title = response.regeocode.addressComponent.city;
    if (title.length == 0) {
        //省/直辖市
        title = response.regeocode.addressComponent.province;
        
    }
    
    self.mapView.userLocation.title = title;
    //格式化地址
    self.mapView.userLocation.subtitle = response.regeocode.formattedAddress;
}
//逆地理编码查询失败
-(void)AMapSearchRequest:(id)request didFailWithError:(NSError *)error
{
    NSLog(@"request : %@  error: %@",request,error);
}
    
//poi搜索按钮
-(void)setUpSearchButton
{
    UIButton * searchPOIButton = [[UIButton alloc]initWithFrame:CGRectMake(100, 100, 40, 40)];
    searchPOIButton.backgroundColor  = [UIColor redColor];
    [searchPOIButton setTitle:@"POI搜索" forState:UIControlStateNormal];
    [searchPOIButton addTarget:self action:@selector(poiBtn) forControlEvents:UIControlEventTouchUpInside];
    [self.mapView addSubview:searchPOIButton];
}
-(void)poiBtn
{
    if (self.currentLocation == nil || self.search == nil) {
        NSLog(@"搜索失败");
        return;
    }
    //周边搜索
    AMapPOIAroundSearchRequest * request = [[AMapPOIAroundSearchRequest alloc]init];
    //以当前位置为中心
    request.location = [AMapGeoPoint locationWithLatitude:self.currentLocation.coordinate.latitude longitude:self.currentLocation.coordinate.longitude];
    request.keywords = @"餐饮";
    //开始周边搜索
    [self.search AMapPOIAroundSearch:request];
}
 
//搜索结果的回调方法
//搜索失败的回调和上面的逆地理编码失败回调方法是同一个
-(void)onPOISearchDone:(AMapPOISearchBaseRequest *)request response:(AMapPOISearchResponse *)response
{
    NSLog(@"request : %@",request);
    NSLog(@"response : %@",response);
    
    //
    if (response.pois.count > 0) {
        self.pois = response.pois;
        
        [self.tableView reloadData];
        //清空标注(大头针)
        [self.mapView removeAnnotations:self.annotations];
        //获得了回调结果将之前的点击添加的标记删除
        [self.annotations removeAllObjects];
    }
}
    
 
    
-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.pois.count;
}
  
-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString * cellID = @"cellID";
    UITableViewCell * cell = [tableView dequeueReusableCellWithIdentifier:cellID];
    if (cell == nil) {
        cell = [[UITableViewCell alloc]initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellID];
    }
    
    AMapPOI * poi = self.pois[indexPath.row];
    cell.textLabel.text = poi.name;
    cell.detailTextLabel.text = poi.address;
    return cell;
}
    
    
//选中tableView的某一行时 添加大头针
-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    //为点击poi点添加标记
    AMapPOI * poi = self.pois[indexPath.row];
    //添加大头针 之前的MAUserLocation也是大头针，就是小蓝点，还有一个就是下面的MAPointAnnotation
    MAPointAnnotation * annotation = [[MAPointAnnotation alloc]init];
    annotation.coordinate = CLLocationCoordinate2DMake(poi.location.latitude, poi.location.longitude);
    annotation.title = poi.name;
    annotation.subtitle = poi.address;
    
    [self.mapView addAnnotation:annotation];
    //记录一下点击了哪些标记
    [self.annotations addObject:annotation];
    
}

//添加大头真】针对应的地图代理方法实现
//就是地图会询问这个annotation 对应的是哪个annotationView
-(MAAnnotationView *)mapView:(MAMapView *)mapView viewForAnnotation:(id<MAAnnotation>)annotation
{
    if ([annotation isKindOfClass:[MAPointAnnotation class]]) {
        static NSString * annotationID = @"annotationID";
        MAPinAnnotationView * annotationView = (MAPinAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:annotationID];
        if (annotation == nil) {
            annotationView = [[MAPinAnnotationView  alloc]initWithAnnotation:annotation reuseIdentifier:annotationID];
        }
        //可以弹出气泡,自定义的话需要设置为no
        annotationView.canShowCallout = YES;
        
        //自定义大头针图片
//        annotationView.image = [UIImage imageNamed:@"58＊581.png"];
        return annotationView;
    }
    //没有合适的
    return nil;
}
    
    
    
    
    
    
    
@end
