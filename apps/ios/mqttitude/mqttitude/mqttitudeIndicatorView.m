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
}
@end
