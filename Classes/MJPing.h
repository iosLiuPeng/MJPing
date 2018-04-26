//
//  MJPing.h
//  MJPing
//
//  Created by 刘鹏 on 2018/4/26.
//  Copyright © 2018年 musjoy. All rights reserved.
//  网络延时，可测试网络是否连接

#import <Foundation/Foundation.h>
@class MJPing;

/// 网络请求模式
typedef NS_ENUM(NSUInteger, MJPingMode) {
    MJPingMode_Interval,      ///< 每隔一段时间请求
    MJPingMode_Continuous,    ///< 连续一定次数请求，每次返回平均值
};

@protocol MJPingDelegate <NSObject>
@optional
/// 返回实时延时 （仅限PingMode_Interval模式）
- (void)ping:(MJPing *)ping timeConsuming:(NSInteger)ms;

/// 每次测试后，返回当前的平均网络耗时（单位：毫秒。仅限PingMode_Continuous模式）
- (void)ping:(MJPing *)ping averageConnectConsuming:(NSInteger)ms;

/// 只返回最终的平均网络耗时（单位：毫秒。仅限PingMode_Continuous模式）
- (void)ping:(MJPing *)ping finalConnectConsuming:(NSInteger)ms;
@end

@interface MJPing : NSObject
@property (nonatomic, weak) id<MJPingDelegate> delegate;///< 代理

/**
 模式：连续一定次数请求，每次返回平均值
 
 @param hostAddress 服务器地址
 @param repeatCount 取N次连接结果的平均值
 @return 实例
 */
- (instancetype)initWithHostAddress:(NSString *)hostAddress repeatCount:(NSInteger)repeatCount;

/**
 模式：每隔一段时间请求，每次返回实时延迟
 
 @param hostAddress 服务器地址
 @param interval 请求间隔时间
 @return 实例
 */
- (instancetype)initWithHostAddress:(NSString *)hostAddress interval:(NSTimeInterval)interval;

/// 开始测试网络延迟
- (void)start;
@end
