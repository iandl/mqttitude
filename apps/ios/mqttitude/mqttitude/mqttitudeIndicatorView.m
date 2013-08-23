//
//  mqttitudeIndicatorView.m
//  mqttitude
//
//  Created by Christoph Krey on 23.08.13.
//  Copyright (c) 2013 Christoph Krey. All rights reserved.
//

#import "mqttitudeIndicatorView.h"

@implementation mqttitudeIndicatorView

- (void)drawRect:(CGRect)rect
{    
    UIBezierPath *circle = [UIBezierPath bezierPathWithOvalInRect:self.bounds];
    
    [circle addClip];
    
    self.alpha = 0.5;
    
    [self.color setFill];
    UIRectFill(self.bounds);
    
    [self.color setStroke];
    [circle stroke];
    
    /* to animate, have to use map overlays!!!
    NSTimeInterval duration = 1.0;
    [UIView animateWithDuration:duration
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseInOut |
                                UIViewAnimationOptionAllowUserInteraction |
                                UIViewAnimationOptionAutoreverse |
                                UIViewAnimationOptionBeginFromCurrentState
                     animations:^(void){
                         if (self.alpha) {
                             self.alpha = 0.0;
                         } else {
                             self.alpha = 1.0;
                         }
                     }
                     completion:^(BOOL finished){
                        [self setNeedsDisplay];
                     }];
     */
}
@end
