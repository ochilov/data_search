//
//  AppDelegate.m
//  data_search
//
//  Created by u.ochilov on 11.10.2021.
//

#import "AppDelegate.h"
#import "RSSearchField.h"

#define KBD_SEARCH_DELAY 300 //ms


// MARK: - SearchOperation
@interface SearchOperation: NSOperation
@property (copy) NSArray *data;
@property (copy) NSString *query;
@property (nonatomic, copy, nullable) void(^completion)(NSArray *);
- (instancetype)initWithData:(NSArray *)data query:(NSString *)query comletion:(void(^)(NSArray *))completion;
@end

@implementation SearchOperation
- (instancetype)initWithData:(NSArray *)data query:(NSString *)query comletion:(void(^)(NSArray *))completion {
	if (self = [super init]) {
		_data = data;
		_query = query;
		_completion = completion;
	}
	return self;
}

- (void)main {
	if (self.isCancelled) {
		NSLog(@"search '%@' Canceled", self.query);
		return;
	}
	NSLog(@"search '%@' Start", self.query);
	
	for (int i = 0; i < 4; i++) {
		if (self.isCancelled) {
			NSLog(@"search '%@' Canceled", self.query);
			return;
		}
		[NSThread sleepForTimeInterval:0.25];
		NSLog(@"search '%@' [%i] ...", self.query, i);
	}
	
	NSMutableArray *findItems = [[NSMutableArray alloc] initWithCapacity:self.data.count];
	
	if (self.isCancelled) {
		NSLog(@"search '%@' Canceled", self.query);
		return;
	}
	
	for (NSString *item in self.data) {
		if ([item rangeOfString:self.query options:NSCaseInsensitiveSearch].location != NSNotFound) {
			[findItems addObject:item];
		}
	}
	
	[NSThread sleepForTimeInterval:0.25];
	NSLog(@"search '%@' Finish", self.query);
	if (self.completion != nil) {
		self.completion(findItems.copy);
	}
}

@end


// MARK: - AppDelegate
@interface AppDelegate () {
	NSOperationQueue *searchFilterQueue;
	NSString *searchQuery;
	
	NSArray *data;
	NSArray *visibleData;
}

@property (strong) IBOutlet NSWindow *window;
@property (weak) IBOutlet RSSearchField *searchField;
@property (weak) IBOutlet NSSegmentedControl *searchOptions;
@property (weak) IBOutlet NSProgressIndicator *searchActivityIndicator;

@property (weak) IBOutlet NSTableView *tableView;
@property (strong) NSTimer *latencyTimer;

@end

@implementation AppDelegate

- (void)applicationWillFinishLaunching:(NSNotification *)notification {
	
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	searchFilterQueue = [[NSOperationQueue alloc] init];
	searchFilterQueue.maxConcurrentOperationCount = 1;
	searchFilterQueue.qualityOfService = NSQualityOfServiceUserInitiated;
	
	data = @[
		@"Data item 1",
		@"Data item 2",
		@"Data item 3",
		@"Data item 4",
		@"Data item 5",
		@"Other item 1",
		@"Other item 2",
		@"Other item 3",
		@"Other item 4",
		@"Other item 5",
		@"Other item 6",
		@"Other item 7",
		@"Other item 8",
		@"Other item 9",
		@"Other item 10",
	];
	visibleData = data;
	
	typeof(self) __weak weakSelf = self;
	[self.searchField onChanged: ^(NSString * text) {
		NSLog(@"text changed to: %@", text);
		[weakSelf updateSearchWithQuery:text];
	}];
	
	self.tableView.dataSource = self;
	self.tableView.delegate = self;
	[self.tableView reloadData];
}

- (void)applicationDidBecomeActive:(NSNotification *)notification {
	[[NSApp mainMenu] update];
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
	// Insert code here to tear down your application
}


- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app {
	return YES;
}


- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
	return YES;
}

- (void)updateSearchWithQuery:(NSString *)query {
	[self.latencyTimer invalidate];
	
	
	typeof(self) __weak weakSelf = self;
	NSBlockOperation *op = [NSBlockOperation blockOperationWithBlock:^{
		[weakSelf performUpdateSearchWithQuery:query];
	}];
	
	
	self.latencyTimer = [NSTimer scheduledTimerWithTimeInterval:KBD_SEARCH_DELAY/1000.0 target:op selector:@selector(main) userInfo:nil repeats:NO];
}

- (void)performUpdateSearchWithQuery:(NSString *)query {
	NSInteger searchVariant =
		self.searchOptions.selectedSegment == 2 ? 1 :
		self.searchOptions.selectedSegment == 1 ? 2 :
		self.searchOptions.selectedSegment == 0 ? 3 : 0 ;

	if (searchVariant == 1) {
		// Variant 1: synchronius
		searchQuery = query;
		[self startProgress];
		typeof(self) __weak weakSelf = self;
		dispatch_async(dispatch_get_main_queue(), ^{
			typeof(self) __strong self = weakSelf;
			if (self == nil) {
				return;
			}
			if (self->searchQuery.length) {
				self->visibleData = [self searchItems:self->data withQuery:query];
			} else {
				self->visibleData = self->data;
			}
			[self updateTableView];
			[self stopProgress];
		});
		
	} else if (searchVariant == 2) {
		// Variant 2: async
		[searchFilterQueue cancelAllOperations];
		searchQuery = query;
		if (!searchQuery.length) {
			self->visibleData = self->data;
			[self updateTableView];
			return;
		}
		
		typeof(self) __weak weakSelf = self;
		__block __weak NSOperation *operation = [NSBlockOperation blockOperationWithBlock:^{
			typeof(self) __strong self = weakSelf;
			if (self == nil) {
				return;
			}
			// search
			if (![self->searchQuery isEqualToString:query]) {
				return;
			}
			self->visibleData = [self searchItems:self->data withQuery:query];
			
			// update view
			if (![self->searchQuery isEqualToString:query]) {
				return;
			}
			[self updateTableView];
			[self stopProgress];
		}];
		[self startProgress];
		[searchFilterQueue addOperation:operation];
	
	
	} else if (searchVariant == 3) {
		// Variant 3: async with cancalable operation
		[searchFilterQueue cancelAllOperations];
		searchQuery = query;
		if (!searchQuery.length) {
			self->visibleData = self->data;
			[self updateTableView];
			return;
		}
		
		typeof(self) __weak weakSelf = self;
		SearchOperation *searchOperation = [[SearchOperation alloc] initWithData: data query:query comletion:^(NSArray *findItems) {
			typeof(self) __strong self = weakSelf;
			if (self == nil) {
				return;
			}
			self->visibleData = findItems;
			[self updateTableView];
			[self stopProgress];
		}];
		[self startProgress];
		[searchFilterQueue addOperation:searchOperation];
	}
}

- (NSArray *)searchItems:(NSArray *)items withQuery:(NSString *)query {
	NSLog(@"search '%@' Start", query);
	
	NSMutableArray *findItems = [[NSMutableArray alloc] initWithCapacity:items.count];
	for (int i = 0; i < 4; i++) {
		[NSThread sleepForTimeInterval:0.25];
		NSLog(@"search '%@' [%i] ...", query, i);
	}
	for (NSString *item in items) {
		if ([item rangeOfString:query options:NSCaseInsensitiveSearch].location != NSNotFound) {
			[findItems addObject:item];
		}
	}
	[NSThread sleepForTimeInterval:0.25];
	NSLog(@"search '%@' Finish", query);
	
	return findItems.copy;
}

- (void)updateTableView {
	NSLog(@"updateTableView");
	typeof(self) __weak weakSelf = self;
	dispatch_async(dispatch_get_main_queue(), ^{
		typeof(self) __strong self = weakSelf;
		if (self == nil) {
			return;
		}
		[self.tableView reloadData];
	});
}

- (void)startProgress {
	if (NSThread.currentThread.isMainThread) {
		[self.searchActivityIndicator startAnimation:self];
	} else {
		dispatch_async(dispatch_get_main_queue(), ^{
			[self.searchActivityIndicator startAnimation:self];
		});
	}
}

- (void)stopProgress {
	if (NSThread.currentThread.isMainThread) {
		[self.searchActivityIndicator stopAnimation:self];
	} else {
		dispatch_async(dispatch_get_main_queue(), ^{
			[self.searchActivityIndicator stopAnimation:self];
		});
	}
}


// MARK: - TableView DataSource
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
	return visibleData.count;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
	NSString * item = visibleData[row];
	NSTableCellView *cell =  [tableView makeViewWithIdentifier:@"TableCell" owner:nil];
	[cell.textField setStringValue:item];
	return cell;
}

@end

