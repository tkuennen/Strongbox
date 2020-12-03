//
//  OpenSafeView.h
//  StrongBox
//
//  Created by Mark McGuill on 06/06/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Model.h"

NS_ASSUME_NONNULL_BEGIN

@interface BrowseSafeView : UITableViewController

@property (nonatomic, strong, nonnull) Model *viewModel;
@property (nonatomic, strong, nonnull) Node *currentGroup;

@end

NS_ASSUME_NONNULL_END
