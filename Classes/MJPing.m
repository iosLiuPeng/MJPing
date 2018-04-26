//
//  MJPing.m
//  MJPing
//
//  Created by 刘鹏 on 2018/4/26.
//  Copyright © 2018年 musjoy. All rights reserved.
//  

#import "MJPing.h"
#import "SimplePing.h"

@interface MJPing () <SimplePingDelegate>
@property (nonatomic, assign) MJPingMode pingMode;        ///< 请求模式
@property (nonatomic, strong) SimplePing *pinger;       ///< 请求类
@property (nonatomic, strong) NSDate *startDate;        ///< 每次请求开始时间

/* MJPingMode_Interval 每隔一段时间请求值 */
@property (nonatomic, assign) NSTimeInterval interval;  ///< 请求间隔时间
@property (nonatomic, assign) uint16_t sequenceNumber;  ///< 每次请求的编号
@property (nonatomic, strong) NSTimer *timer;           ///< 定时器
@property (nonatomic, assign) NSTimeInterval consuming; ///< 最近一次得到的延时
@property (nonatomic, assign) BOOL firstRequest;        ///< 是否第一次请求

/* MJPingMode_Continuous 连续一定次数请求，每次返回平均值 */
@property (nonatomic, assign) NSInteger repeatCount;    ///< 请求次数。取N次连接结果的平均值
@property (nonatomic, strong) NSMutableArray *arrTimeConsuming;///< 存储每次耗时
@end

@implementation MJPing
#pragma mark - Life Cycle
/**
 模式：连续一定次数请求，每次返回平均值
 
 @param hostAddress 服务器地址
 @param repeatCount 取N次连接结果的平均值
 @return 实例
 */
- (instancetype)initWithHostAddress:(NSString *)hostAddress repeatCount:(NSInteger)repeatCount
{
    self = [super init];
    if (self) {
        _pingMode = MJPingMode_Continuous;
        
        _pinger = [[SimplePing alloc] initWithHostName:hostAddress];
        _pinger.delegate = self;
        
        if (repeatCount <= 0) {
            _repeatCount = 1;
        } else {
            _repeatCount = repeatCount;
        }
        
        _arrTimeConsuming = [[NSMutableArray alloc] init];
    }
    return self;
}

/**
 模式：每隔一段时间请求，每次返回实时延迟
 
 @param hostAddress 服务器地址
 @param interval 请求间隔时间
 @return 实例
 */
- (instancetype)initWithHostAddress:(NSString *)hostAddress interval:(NSTimeInterval)interval
{
    self = [super init];
    if (self) {
        _pingMode = MJPingMode_Interval;
        
        _pinger = [[SimplePing alloc] initWithHostName:hostAddress];
        _pinger.delegate = self;
        
        if (interval <= 0) {
            _interval = 1;
        } else {
            _interval = interval;
        }
    }
    return self;
}

- (void)dealloc
{
    [self cleanTimer];
}

#pragma mark - Private
- (void)cleanTimer
{
    if (_timer) {
        [_timer invalidate];
        _timer = nil;
    }
}

#pragma mark - Public
/// 开始测试网络延迟
- (void)start
{
    switch (_pingMode) {
        case MJPingMode_Interval:     // 每隔一段时间请求
        {
            _firstRequest = YES;
            _sequenceNumber = 0;
            _consuming = 0;
            
            [self cleanTimer];
            _timer = [NSTimer scheduledTimerWithTimeInterval:_interval target:self selector:@selector(continueNextRequest) userInfo:nil repeats:YES];
            
            [_pinger start];
        }
            break;
        case MJPingMode_Continuous:   // 连续一定次数请求，每次返回平均值
        {
            [_arrTimeConsuming removeAllObjects];
            [self continuousModeStart];
        }
            break;
        default:
            break;
    }
}

/// 连续一定次数模式，开始请求方法
- (void)continuousModeStart
{
    [_pinger start];
    
    [self cleanTimer];
    _timer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(failed) userInfo:nil repeats:YES];
}

/// 停止
- (void)stop
{
    [_pinger stop];
}

/// 失败
- (void)failed
{
    [_pinger stop];
    
    switch (_pingMode) {
        case MJPingMode_Continuous:
            [self cleanTimer];
            _consuming = 1000;
            [self continueNextRequest];
            break;
        default:
            break;
    }
}

/// 继续下次请求
- (void)continueNextRequest
{
    switch (_pingMode) {
        case MJPingMode_Interval:     // 每隔一段时间请求
        {
            [_pinger stop];
            
            if (_firstRequest) {
                _firstRequest = NO;
                
                // 首次在规定时间内也未收到回调
                if (_consuming == 0) {
                    _consuming = 1000;
                    if ([_delegate respondsToSelector:@selector(ping:timeConsuming:)]) {
                        [_delegate ping:self timeConsuming:_consuming];
                    }
                }
            } else {
                // 返回最近一次的请求结果
                if (_consuming == 0) {
                    _consuming = 1000;
                }
                
                if ([_delegate respondsToSelector:@selector(ping:timeConsuming:)]) {
                    [_delegate ping:self timeConsuming:_consuming];
                }
            }
            
            //开始下次请求
            [_pinger start];
        }
            break;
        case MJPingMode_Continuous:   // 连续一定次数请求，每次返回平均值
        {
            [_arrTimeConsuming addObject:[NSNumber numberWithDouble:_consuming]];
            
            // 传出平均耗时
            double totalConsuming = 0;
            for (NSNumber *time in _arrTimeConsuming) {
                //                // 只记入有效延时
                //                if ([time doubleValue] < 1000) {
                totalConsuming += [time doubleValue];
                //                }
            }
            NSInteger averageValue = 0;
            if (totalConsuming == 0) {
                averageValue = 1000;
            } else {
                averageValue = floor(totalConsuming / _arrTimeConsuming.count);
            }
            
            if ([_delegate respondsToSelector:@selector(ping:averageConnectConsuming:)]) {
                [_delegate ping:self averageConnectConsuming:averageValue];
            }
            
            // 判断是否继续请求
            if (_arrTimeConsuming.count < _repeatCount) {
                [self continuousModeStart];
            } else {
                // 返回最终结果
                if ([_delegate respondsToSelector:@selector(ping:finalConnectConsuming:)]) {
                    [_delegate ping:self finalConnectConsuming:averageValue];
                }
            }
        }
            break;
        default:
            break;
    }
    
}

#pragma mark - SimplePingDelegate
- (void)simplePing:(SimplePing *)pinger didStartWithAddress:(NSData *)address
{
    [pinger sendPingWithData:nil];
}

- (void)simplePing:(SimplePing *)pinger didFailWithError:(NSError *)error
{
    [self failed];
}

- (void)simplePing:(SimplePing *)pinger didSendPacket:(NSData *)packet sequenceNumber:(uint16_t)sequenceNumber
{
    _startDate = [NSDate date];
    _consuming = 0;
    _sequenceNumber = sequenceNumber;
}

- (void)simplePing:(SimplePing *)pinger didFailToSendPacket:(NSData *)packet sequenceNumber:(uint16_t)sequenceNumber error:(NSError *)error
{
    if (_sequenceNumber == sequenceNumber) {
        [self failed];
    }
}

- (void)simplePing:(SimplePing *)pinger didReceivePingResponsePacket:(NSData *)packet sequenceNumber:(uint16_t)sequenceNumber
{
    // 计算耗时
    NSDate *now = [NSDate date];
    NSTimeInterval consuming = [now timeIntervalSinceDate:_startDate];
    consuming = floor(consuming * 1000);
    
    // 如果请求编号一致
    if (sequenceNumber == _sequenceNumber) {
        [_pinger stop];
        
        switch (_pingMode) {
            case MJPingMode_Interval:     // 每隔一段时间请求
            {
                if (_firstRequest) {
                    // 首次请求，实时返回
                    _consuming = consuming;
                    
                    if ([_delegate respondsToSelector:@selector(ping:timeConsuming:)]) {
                        [_delegate ping:self timeConsuming:consuming];
                    }
                } else {
                    //剩余请求，先记录，延时统一返回
                    _consuming = consuming;
                }
            }
                break;
            case MJPingMode_Continuous:   // 连续一定次数请求，每次返回平均值
            {
                _consuming = consuming;
                [self cleanTimer];
                [self continueNextRequest];
            }
                break;
            default:
                break;
        }
    }
}

- (void)simplePing:(SimplePing *)pinger didReceiveUnexpectedPacket:(NSData *)packet
{
    
}

@end
