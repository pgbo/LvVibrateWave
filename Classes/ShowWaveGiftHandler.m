//
//  ShowWaveGiftHandler.m
//  GalaToy
//
//  Created by guangbo on 15/9/15.
//
//

#import "ShowWaveGiftHandler.h"
#import "LvCurveWaveView.h"
#import "LvCurveWaveYieller.h"

@protocol CurveWaveAnimation <NSObject>

- (void)startAnimation;
- (void)stopAnimation;

@end

static const NSTimeInterval waveMoveTimeInterval = 0.01;

@interface CurveWaveAnimationImpl : NSObject <CurveWaveAnimation>
{
    LvCurveWaveView *curveWaveView;
    
    CAShapeLayer *waveShapeLayer;
    
    NSTimer *waveAnimTimer;
    CurveWavePath *currentCurveWavePath;
}

@property (nonatomic, readonly) CGFloat animationScopeHeight;
@property (nonatomic, readonly) NSArray *horizonContactPoints;
@property (nonatomic, readonly) UIView *hostView;

@property (nonatomic) UIColor *lineColor;
@property (nonatomic) CGFloat lineWidth;
@property (nonatomic) BOOL isDash;
@property (nonatomic) NSUInteger moveLengthPerSecond; /** 移动的速度 */

- (instancetype)initWithAnimationScopeHeight:(CGFloat)animationScopeHeight
                        horizonContactPoints:(NSArray *)horizonContactPoints
                                    hostView:(UIView *)hostView;

@end

@implementation CurveWaveAnimationImpl

- (instancetype)initWithAnimationScopeHeight:(CGFloat)animationScopeHeight
                        horizonContactPoints:(NSArray *)horizonContactPoints
                                    hostView:(UIView *)hostView
{
    if (self = [super init]) {
        _animationScopeHeight = animationScopeHeight;
        _horizonContactPoints = horizonContactPoints;
        _hostView = hostView;
        
        [self setupCurveWaveAnimationImpl];
    }
    return self;
}

- (void)setupCurveWaveAnimationImpl
{
    curveWaveView = [[LvCurveWaveView alloc]initWithFrame:CGRectMake(0,
                                                                     (CGRectGetHeight(self.hostView.bounds) - self.animationScopeHeight)/2,
                                                                     CGRectGetWidth(self.hostView.bounds),
                                                                     self.animationScopeHeight)];
    [self.hostView addSubview:curveWaveView];
    
    curveWaveView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    curveWaveView.backgroundColor = [UIColor clearColor];
    
    self.lineColor = [UIColor whiteColor];
    self.isDash = NO;
    self.lineWidth = 3.f;
    self.moveLengthPerSecond = 600.f;
}

+ (NSUInteger)calculateCurveWaveRepeatCountWithContactPoints:(NSArray *)contactPoints animAreaWidthScope:(CGFloat)animAreaWidthScope
{
    if (contactPoints.count < 2)
        return 1;
    
    NSUInteger repeatCount = 0;
    
    CGPoint firstPoint = ((NSValue *)contactPoints.firstObject).CGPointValue;
    CGPoint lastPoint = ((NSValue *)contactPoints.lastObject).CGPointValue;
    
    CGFloat maxPointGap = fabsf(lastPoint.x - firstPoint.x);
    if (maxPointGap == 0) {
        repeatCount = 1;
    } else {
        repeatCount = ceilf(animAreaWidthScope/maxPointGap);
    }
    
    return repeatCount;
}

- (CurveWavePath *)createWavePathByContactPoints:(NSArray *)contactPoints repeatCount:(NSUInteger)repeatCount
{
    LvBasicCurveWaveYieller *yieller = [[LvBasicCurveWaveYieller alloc]init];
    yieller.horizonContactPoints = contactPoints;
    yieller.repeatCount = repeatCount;
    
    return [yieller yielCurvePath];
}

#pragma mark - CurveWaveAnimation

- (void)startAnimation
{
    [self stopAnimation];
    
    [waveShapeLayer removeFromSuperlayer];
    
    curveWaveView.lineColor = self.lineColor;
    curveWaveView.lineStyle = self.isDash?LvCurveWaveLineStyleDot:LvCurveWaveLineStyleSolid;
    curveWaveView.lineWidth = self.lineWidth;
    
    waveShapeLayer = [CAShapeLayer layer];
    waveShapeLayer.frame = curveWaveView.bounds;
    
    NSUInteger waveCurveRepeatCount = [[self class]calculateCurveWaveRepeatCountWithContactPoints:self.horizonContactPoints animAreaWidthScope:CGRectGetWidth(curveWaveView.bounds)];
    
    CurveWavePath *waveShapeLayerPath = [self createWavePathByContactPoints:self.horizonContactPoints repeatCount:waveCurveRepeatCount];
    waveShapeLayer.path = waveShapeLayerPath.curvePath.CGPath;
    waveShapeLayer.strokeColor = curveWaveView.lineColor.CGColor;
    waveShapeLayer.fillColor = [UIColor clearColor].CGColor;
    waveShapeLayer.lineWidth = curveWaveView.lineWidth;
    if (self.isDash) {
        waveShapeLayer.lineCap = kCALineCapRound;
        waveShapeLayer.lineDashPattern = @[@(curveWaveView.lineWidth/2), @(2*curveWaveView.lineWidth)];
    } else {
        waveShapeLayer.lineCap = kCALineCapButt;
    }
    
    [curveWaveView.layer addSublayer:waveShapeLayer];
    
    CABasicAnimation *bAnim = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
    bAnim.duration = 3;
    bAnim.delegate = self;
    bAnim.fromValue = @(0.f);
    bAnim.toValue = @(1.f);
    
    [waveShapeLayer addAnimation:bAnim forKey:nil];
}

- (void)stopAnimation
{
    [waveShapeLayer removeAllAnimations];
    [waveAnimTimer invalidate];
}

#pragma mark - CAAnimationDelegate

- (void)animationDidStop:(CAAnimation *)anim finished:(BOOL)flag
{
    waveShapeLayer.strokeEnd = 0;
    [waveShapeLayer removeFromSuperlayer];
    waveAnimTimer = [NSTimer scheduledTimerWithTimeInterval:waveMoveTimeInterval
                                                     target:self
                                                   selector:@selector(waveAnimTimerFire:)
                                                   userInfo:nil
                                                    repeats:YES];
}

- (void)waveAnimTimerFire:(NSTimer *)timer
{
    if (!currentCurveWavePath) {
        
        NSUInteger waveCurveRepeatCount = [[self class]calculateCurveWaveRepeatCountWithContactPoints:self.horizonContactPoints animAreaWidthScope:CGRectGetWidth(curveWaveView.bounds)];
        
        CurveWavePath *path = [self createWavePathByContactPoints:self.horizonContactPoints repeatCount:waveCurveRepeatCount];
        currentCurveWavePath = [self createWavePathByContactPoints:[[self class] extendContactPointsAtLeft:path.horizonContactPoints] repeatCount:1];
        
    } else {
        
        CGPoint curveWavePathFirstPoint = ((NSValue *)currentCurveWavePath.horizonContactPoints.firstObject).CGPointValue;
        
        if (curveWavePathFirstPoint.x > 0) {
            CGPoint firstPoint = ((NSValue *)self.horizonContactPoints.firstObject).CGPointValue;
            CGPoint lastPoint = ((NSValue *)self.horizonContactPoints.lastObject).CGPointValue;
            currentCurveWavePath = [currentCurveWavePath nextCurveWavePathWithHorizonMoveLength:- fabs(lastPoint.x - firstPoint.x)];
        } else {
            currentCurveWavePath = [currentCurveWavePath nextCurveWavePathWithHorizonMoveLength:self.moveLengthPerSecond*waveMoveTimeInterval];
        }
    }
    
    curveWaveView.curvePath = currentCurveWavePath.curvePath;
}


+ (NSArray *)extendContactPointsAtLeft:(NSArray *)contactPoints
{
    if (contactPoints.count >= 2) {
        CGPoint firstPoint = ((NSValue *)contactPoints[0]).CGPointValue;
        CGPoint lastPoint = ((NSValue *)contactPoints[contactPoints.count - 1]).CGPointValue;
        CGPoint secondLastPoint = ((NSValue *)contactPoints[contactPoints.count - 2]).CGPointValue;
        CGFloat gap = lastPoint.x - secondLastPoint.x;
        
        NSMutableArray *newArray = [NSMutableArray arrayWithArray:contactPoints];
        
        NSArray *subArray = [contactPoints subarrayWithRange:NSMakeRange(0, contactPoints.count - 1)];
        for (NSInteger i = subArray.count - 1; i >=0; i --) {
            CGPoint newPoint = ((NSValue *)subArray[i]).CGPointValue;
            if (i == subArray.count - 1) {
                newPoint.x = firstPoint.x - gap;
            } else {
                CGPoint upperPoint = ((NSValue *)subArray[i + 1]).CGPointValue;
                CGPoint newFirstPoint = ((NSValue *)newArray[0]).CGPointValue;
                newPoint.x = newFirstPoint.x - (upperPoint.x - newPoint.x);
            }
            [newArray insertObject:[NSValue valueWithCGPoint:newPoint] atIndex:0];
        }
        return newArray;
    } else {
        return contactPoints;
    }
}

@end


@interface ShowWaveGiftHandler ()

@property (nonatomic) UIView *view;

@property (nonatomic) UIView *curveWaveAnimTopHostView;

@property (nonatomic) UILabel *animationDurationLabel;
@property (nonatomic) NSTimer *animationDurationTimer;
@property (nonatomic) NSTimeInterval animationTotalDuration;
@property (nonatomic) NSUInteger animationPlayedDuration;

@property (nonatomic) NSArray *curveWaveAnimations;

@end

@implementation ShowWaveGiftHandler

- (UIView *)showWaveGiftWithType:(WaveGiftType)type
                    giftQuantity:(NSUInteger)quantity
                     isIncomming:(BOOL)isIncomming
                         seconds:(NSTimeInterval)seconds
                          inView:(UIView *)inView
{
    if (!inView)
        return nil;
    
    self.view = inView;
    
    UIView *animHostView = nil;
    
    // 添加礼物赠送视图
    if ([UIDevice currentDevice].systemVersion.floatValue < 8) {
        // 普通视图
        UIView *commonView = [[UIView alloc]initWithFrame:self.view.bounds];
        [self.view addSubview:commonView];
        
        commonView.autoresizingMask = UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleWidth;
        commonView.backgroundColor = [UIColor colorWithRed:35/255.f green:31/255.f blue:39/255.f alpha:0.9];
        
        self.curveWaveAnimTopHostView = animHostView = commonView;
        
    } else {
        
        // 毛玻璃效果视图
        
        UIVisualEffectView *blurView = [[UIVisualEffectView alloc]initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
        [self.view addSubview:blurView];
        
        blurView.frame = self.view.bounds;
        blurView.autoresizingMask = UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleWidth;
        
        animHostView = blurView.contentView;
        self.curveWaveAnimTopHostView = blurView;
    }
    
    CGFloat animationScopeHeight = 0;
    
    switch (type) {
        case WaveGiftTypeDotDash: {
            
            animationScopeHeight = 80;
            
            NSArray *waveShapeContactPoints = @[[NSValue valueWithCGPoint:CGPointMake(0, 40)],
                                                [NSValue valueWithCGPoint:CGPointMake(90, 44)],
                                                [NSValue valueWithCGPoint:CGPointMake(190, 10)],
                                                [NSValue valueWithCGPoint:CGPointMake(290, 48)],
                                                [NSValue valueWithCGPoint:CGPointMake(360, 38)],
                                                [NSValue valueWithCGPoint:CGPointMake(400, 40)]];
            
            CurveWaveAnimationImpl *curveWaveAnimation = [[CurveWaveAnimationImpl alloc]initWithAnimationScopeHeight:animationScopeHeight horizonContactPoints:waveShapeContactPoints hostView:animHostView];
            
            curveWaveAnimation.lineColor = [UIColor colorWithRed:248.f/255.f green:25.f/255.f blue:78.f/255.f alpha:1];
            curveWaveAnimation.isDash = YES;
            curveWaveAnimation.lineWidth = 3.f;
            curveWaveAnimation.moveLengthPerSecond = 600.f;
            
            [curveWaveAnimation startAnimation];
            
            self.curveWaveAnimations = @[curveWaveAnimation];
            
            // seconds 秒后删除视图
            [self performSelector:@selector(removeAnimateView) withObject:nil afterDelay:seconds];
            
            break;
        }
        case WaveGiftTypeTwoLine: {
            
            animationScopeHeight = 80;
            
            NSArray *waveShape1ContactPoints = @[[NSValue valueWithCGPoint:CGPointMake(0, 40)],
                                                 [NSValue valueWithCGPoint:CGPointMake(90, 44)],
                                                 [NSValue valueWithCGPoint:CGPointMake(190, 10)],
                                                 [NSValue valueWithCGPoint:CGPointMake(290, 48)],
                                                 [NSValue valueWithCGPoint:CGPointMake(360, 38)],
                                                 [NSValue valueWithCGPoint:CGPointMake(400, 40)]];
            
            NSArray *waveShape2ContactPoints = @[[NSValue valueWithCGPoint:CGPointMake(0, 40)],
                                                 [NSValue valueWithCGPoint:CGPointMake(90, 38)],
                                                 [NSValue valueWithCGPoint:CGPointMake(190, 50)],
                                                 [NSValue valueWithCGPoint:CGPointMake(290, 34)],
                                                 [NSValue valueWithCGPoint:CGPointMake(360, 42)],
                                                 [NSValue valueWithCGPoint:CGPointMake(400, 40)]];
            
            CurveWaveAnimationImpl *curveWave1Animation = [[CurveWaveAnimationImpl alloc]initWithAnimationScopeHeight:animationScopeHeight horizonContactPoints:waveShape1ContactPoints hostView:animHostView];
            
            CurveWaveAnimationImpl *curveWave2Animation = [[CurveWaveAnimationImpl alloc]initWithAnimationScopeHeight:animationScopeHeight horizonContactPoints:waveShape2ContactPoints hostView:animHostView];
            
            curveWave1Animation.lineColor = [UIColor colorWithRed:205.f/255.f green:179.f/255.f blue:8.f/255.f alpha:1];
            curveWave1Animation.isDash = NO;
            curveWave1Animation.lineWidth = 3.f;
            curveWave1Animation.moveLengthPerSecond = 400.f;
            
            curveWave2Animation.lineColor = [UIColor colorWithRed:205.f/255.f green:179.f/255.f blue:8.f/255.f alpha:0.4];
            curveWave2Animation.isDash = NO;
            curveWave2Animation.lineWidth = 1.f;
            curveWave2Animation.moveLengthPerSecond = 400.f;
            
            self.curveWaveAnimations = @[curveWave1Animation, curveWave2Animation];
            
            [curveWave1Animation startAnimation];
            [curveWave2Animation startAnimation];
            
            // 5 秒后删除视图
            [self performSelector:@selector(removeAnimateView) withObject:nil afterDelay:seconds];
            
            break;
        }
        case WaveGiftTypeOneLine: {
            
            animationScopeHeight = 80;
            
            NSArray *waveShapeContactPoints = @[[NSValue valueWithCGPoint:CGPointMake(0, 40)],
                                                [NSValue valueWithCGPoint:CGPointMake(90, 44)],
                                                [NSValue valueWithCGPoint:CGPointMake(190, 10)],
                                                [NSValue valueWithCGPoint:CGPointMake(290, 48)],
                                                [NSValue valueWithCGPoint:CGPointMake(360, 38)],
                                                [NSValue valueWithCGPoint:CGPointMake(400, 40)]];
            
            CurveWaveAnimationImpl *curveWaveAnimation = [[CurveWaveAnimationImpl alloc]initWithAnimationScopeHeight:animationScopeHeight horizonContactPoints:waveShapeContactPoints hostView:animHostView];
            
            curveWaveAnimation.lineColor = [UIColor colorWithRed:36.f/255.f green:104.f/255.f blue:176.f/255.f alpha:1];
            curveWaveAnimation.isDash = NO;
            curveWaveAnimation.lineWidth = 3.f;
            curveWaveAnimation.moveLengthPerSecond = 300.f;
            
            [curveWaveAnimation startAnimation];
            
            self.curveWaveAnimations = @[curveWaveAnimation];
            
            // 5 秒后删除视图
            [self performSelector:@selector(removeAnimateView) withObject:nil afterDelay:seconds];
            
            break;
        }
    }
    
    UILabel *quantityLabel = [[UILabel alloc]init];
    quantityLabel.backgroundColor = [UIColor clearColor];
    quantityLabel.textAlignment = NSTextAlignmentCenter;
    quantityLabel.numberOfLines = 1;
    quantityLabel.textColor = [UIColor whiteColor];
    quantityLabel.font = [UIFont systemFontOfSize:17];
    NSUInteger nQ = quantity;
    if (nQ == 0)
        nQ = 1;
    quantityLabel.text = [NSString stringWithFormat:isIncomming?@"收到 %@ 个礼物":@"赠送出 %@ 个礼物", @(nQ)];
    
    quantityLabel.frame = CGRectMake(0, 72, CGRectGetWidth(animHostView.bounds), 22.f);
    [animHostView addSubview:quantityLabel];
    
    self.animationDurationLabel = [[UILabel alloc]initWithFrame:CGRectMake(0, (CGRectGetHeight(animHostView.bounds) + animationScopeHeight)/2.f + 8.f, CGRectGetWidth(animHostView.bounds), 22.f)];
    self.animationDurationLabel.backgroundColor = [UIColor clearColor];
    self.animationDurationLabel.textColor = [UIColor whiteColor];
    self.animationDurationLabel.textAlignment = NSTextAlignmentCenter;
    
    [animHostView addSubview:self.animationDurationLabel];
    
    
    
    [self.animationDurationTimer invalidate];
    self.animationTotalDuration = seconds;
    self.animationPlayedDuration = 0;
    
    self.animationDurationTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(durationTimerFire:) userInfo:nil repeats:YES];
    
    return self.curveWaveAnimTopHostView;
}

- (void)removeAnimateView
{
    for (CurveWaveAnimationImpl *curveWaveAnimation in self.curveWaveAnimations) {
        [curveWaveAnimation stopAnimation];
    }
    [self.curveWaveAnimTopHostView removeFromSuperview];
}

- (void)durationTimerFire:(NSTimer *)timer
{
    if (self.animationPlayedDuration >= self.animationTotalDuration) {
        [self.animationDurationTimer invalidate];
        
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(removeAnimateView) object:nil];
        [self removeAnimateView];
        
        return;
    }
    
    self.animationPlayedDuration ++;
    self.animationDurationLabel.text = [NSString stringWithFormat:@"%@ / %@ s",
                                        @(self.animationPlayedDuration),
                                        @(self.animationTotalDuration)];
}

@end
