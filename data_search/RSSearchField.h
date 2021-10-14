//
//  RSSearchField.h
//  data_search
//
//  Created by u.ochilov on 12.10.2021.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface RSSearchField : NSSearchField

typedef void (^ChangeHandler)(NSString *);

- (void)onChanged:(ChangeHandler)handler;

@end

NS_ASSUME_NONNULL_END
