//
//  OnboardingWelcomeViewController.h
//  MacBox
//
//  Created by Strongbox on 22/11/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "DatabaseMetadata.h"

NS_ASSUME_NONNULL_BEGIN

@interface OnboardingWelcomeViewController : NSViewController

@property DatabaseMetadata* database;
@property (nonatomic, copy) void (^onNext)(void);

@end

NS_ASSUME_NONNULL_END
