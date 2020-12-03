//
//  TagsViewTableViewCell.m
//  Strongbox
//
//  Created by Mark on 27/03/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "TagsViewTableViewCell.h"
#import "ItemDetailsViewController.h"
#import "FontManager.h"

#ifndef IS_APP_EXTENSION
#import "Strongbox-Swift.h"
#else
#import "Strongbox_Auto_Fill-Swift.h"
#endif

@interface TagsViewTableViewCell () <UITextFieldDelegate>

@property (weak, nonatomic) IBOutlet WSTagsField *tagsField;
@property (weak, nonatomic) IBOutlet UILabel *labelTags;

@end

@implementation TagsViewTableViewCell

- (void)awakeFromNib {
    [super awakeFromNib];

    self.tagsField.onDidChangeHeightTo = ^(WSTagsField * _Nonnull field, CGFloat size) {
        [self notifyCellHeightChanged];
    };
    
    self.labelTags.text = 
    self.tagsField.placeholder = NSLocalizedString(@"item_details_username_field_tags", @"Tags");

    self.tagsField.numberOfLines = 0;
    self.tagsField.spaceBetweenLines = 8.0f;
    self.tagsField.spaceBetweenTags = 8.0f;

    self.tagsField.contentInset = UIEdgeInsetsMake(2, 2, 2, 2);
    self.tagsField.layoutMargins = UIEdgeInsetsMake(2, 6, 2, 6);
    
    self.tagsField.textDelegate = self;
}

- (void)textFieldDidEndEditing:(UITextField *)textField {

    [self.tagsField acceptCurrentTextAsTag];
}

- (void)notifyCellHeightChanged {
    [[NSNotificationCenter defaultCenter] postNotificationName:CellHeightsChangedNotification object:self];
}

- (void)prepareForReuse {
    [super prepareForReuse];

    self.tagsField.onDidAddTag = nil;
    self.tagsField.onDidRemoveTag = nil;
    [self.tagsField removeTags];
}

- (void)setModel:(BOOL)readOnly
            tags:(NSArray<NSString*>*)tags
 useEasyReadFont:(BOOL)useEasyReadFont
           onAdd:(void(^)(NSString* tag))onAdd
           onRemove:(void(^)(NSString* tag))onRemove {
    self.tagsField.readOnly = readOnly;
    self.tagsField.font = useEasyReadFont ? FontManager.sharedInstance.easyReadFont : FontManager.sharedInstance.regularFont;
    if (@available(iOS 13.0, *)) {
        self.tagsField.fieldTextColor = UIColor.labelColor;
    }
    
    [self.tagsField addTags:tags];

    self.tagsField.onDidAddTag = ^(WSTagsField * _Nonnull field, NSString * _Nonnull text) {
        NSLog(@"Added Tag: %@", text);
        onAdd(text);
    };
    self.tagsField.onDidRemoveTag = ^(WSTagsField * _Nonnull field, NSString * _Nonnull text) {
        NSLog(@"Removed Tag: %@", text);
        onRemove(text);
    };
}

@end
