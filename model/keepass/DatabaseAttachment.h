//
//  Attachment.h
//  Strongbox
//
//  Created by Mark on 01/11/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DatabaseAttachment : NSObject

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithStream:(NSInputStream *)stream protectedInMemory:(BOOL)protectedInMemory compressed:(BOOL)compressed;
- (instancetype)initWithStream:(NSInputStream*)stream length:(NSUInteger)length protectedInMemory:(BOOL)protectedInMemory;
- (instancetype)initWithStream:(NSInputStream *)stream length:(NSUInteger)length protectedInMemory:(BOOL)protectedInMemory compressed:(BOOL)compressed;
- (instancetype)initForStreamWriting:(BOOL)protectedInMemory compressed:(BOOL)compressed;

- (NSInteger)writeStreamWithB64Text:(NSString*)text;
- (void)closeWriteStream;

@property (readonly) NSUInteger estimatedStorageBytes;
@property (readonly) NSUInteger length;
@property (readonly) NSString* digestHash; 

@property BOOL compressed; 
@property BOOL protectedInMemory; 

- (NSInputStream*)getPlainTextInputStream;



- (instancetype)initWithData:(NSData*)data compressed:(BOOL)compressed protectedInMemory:(BOOL)protectedInMemory; 
@property (readonly) NSData* unitTestDataOnly;

@end

NS_ASSUME_NONNULL_END
