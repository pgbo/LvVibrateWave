//
//  ShowWaveGiftHandler.h
//  GalaToy
//
//  Created by guangbo on 15/9/15.
//
//

#import <Foundation/Foundation.h>

/**
 *  震动波形礼物类型
 */
typedef NS_ENUM(NSUInteger, WaveGiftType){
    /**
     *  虚线
     */
    WaveGiftTypeDotDash = 0,
    /**
     *  两条线
     */
    WaveGiftTypeTwoLine,
    /**
     *  一条线
     */
    WaveGiftTypeOneLine,
};

/**
 *  显示震动波形处理器
 */
@interface ShowWaveGiftHandler : NSObject

/**
 *  显示震动波形礼物
 *
 *  @param type   类型
 *  @param quantity
 *  @param isIncomming
 *  @param inView 显示所在视图
 *
 *  @return 用于显示的视图
 */
- (UIView *)showWaveGiftWithType:(WaveGiftType)type
                    giftQuantity:(NSUInteger)quantity
                    isIncomming:(BOOL)isIncomming
                         seconds:(NSTimeInterval)seconds
                          inView:(UIView *)inView;

@end
