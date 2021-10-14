//
//  RSSearchField.m
//  data_search
//
//  Created by u.ochilov on 12.10.2021.
//

#import "RSSearchField.h"

@interface RSSearchField() {
	NSMutableArray *onChangeHandlers;
}
@end

@implementation RSSearchField
- (void)textDidChange:(NSNotification *)notification {
	NSString *text = self.stringValue.copy;
	if ([onChangeHandlers count]) {
		for (ChangeHandler handler in onChangeHandlers) {
			handler(text);
		}
	}
}

- (void)onChanged:(ChangeHandler)handler {
	if (onChangeHandlers == nil) {
		onChangeHandlers = [[NSMutableArray alloc] init];
	}
	[onChangeHandlers addObject:handler];
}

@end
