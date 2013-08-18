//
//  Location.m
//  Longitude
//
//  Created by Christoph Krey on 13.07.13.
//  Copyright (c) 2013 Christoph Krey. All rights reserved.
//

#import "Location.h"

@interface Location() <MKAnnotation>
@property (nonatomic, readwrite) CLLocationCoordinate2D coordinate;
@end

@implementation Location
- (NSString *)description {
    return [NSString stringWithFormat:@"%@ %@", self.title, self.subtitle];
}

- (NSString *)title {
    return [NSDateFormatter localizedStringFromDate:self.timeStamp
                                          dateStyle:NSDateFormatterShortStyle
                                          timeStyle:NSDateFormatterMediumStyle];
}

- (NSString *)subtitle {
    NSString *string = [NSString stringWithFormat:@"%f %f",
                        self.coordinate.latitude,
                        self.coordinate.longitude];

    return string;
}

- (void)setCoordinate:(CLLocationCoordinate2D)newCoordinate {
    _coordinate = newCoordinate;    
}

@end
