//
//  MyDocument.m
//  iRelayChat
//
//  Created by Christian Speich on 17.04.08.
//  Copyright __MyCompanyName__ 2008 . All rights reserved.
//

#import "MyDocument.h"
#import "IRCServer.h"
#import "ChannelView.h"

@implementation MyDocument

- (id)init
{
    self = [super init];
    if (self) {
		servers = [[NSMutableArray alloc] init];
		IRCServer *server = [[IRCServer alloc] initWithHost:@"localhost" andPort:@"6667"];
		[server connect];
		[server joinChannel:@"#Apachefriends"];
		[servers addObject:server];
		[server release];
    }
    return self;
}

- (NSString *)windowNibName
{
    return @"MyDocument";
}

- (void)windowControllerDidLoadNib:(NSWindowController *) aController
{
    [super windowControllerDidLoadNib:aController];
	ChannelView *channelView = [[ChannelView alloc] initWithChannel:[[[servers objectAtIndex:0] channels] objectAtIndex:0]];
	[channelView.view setFrame:[contentView bounds]];
	channelView.inputField = inputField;
	[inputField setTarget:channelView];
	[inputField setAction:@selector(sendMessage)];
	[contentView addSubview:channelView.view];
	[[aController window] setAutorecalculatesContentBorderThickness:YES forEdge:NSMinYEdge];
	[[aController window] setContentBorderThickness:35 forEdge:NSMinYEdge];
	[channelView performSelector:@selector(splitViewDidResizeSubviews:) withObject:nil];
	[self performSelector:@selector(splitViewDidResizeSubviews:) withObject:nil];
}

- (int)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
	if (item == nil) {
		return [servers count];
	}
	else if ([item isKindOfClass:[IRCServer class]]) {
		return [[item channels] count];
	}
	
    return 0;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
	if ([item isKindOfClass:[IRCServer class]]) {
		return YES;
	}
	return NO;
}

- (id)outlineView:(NSOutlineView *)outlineView
			child:(int)index
		   ofItem:(id)item
{
    if (item == nil) {
		return [servers objectAtIndex:index];
	}
	else {
		return [[item channels] objectAtIndex:index];
	}

	return nil;
}

- (id)outlineView:(NSOutlineView *)outlineView
objectValueForTableColumn:(NSTableColumn *)tableColumn
		   byItem:(id)item
{
	if ([[tableColumn identifier] isEqualToString:@"TitleColumn"]) {
		if ([item isKindOfClass:[IRCServer class]]) {
			return [item serverName];
		}
		else {
			return [item name];
		}
	}
	else {
		return @"";
	}
}

-(BOOL)outlineView:(NSOutlineView*)outlineView isGroupItem:(id)item
{
	if ([item isKindOfClass:[IRCServer class]]) {
		return YES;
	}
	return NO;
}

- (void)splitView:(NSSplitView*)sender resizeSubviewsWithOldSize:(NSSize)oldSize
{
	NSRect newFrame = [sender frame];
	NSView *left = [[sender subviews] objectAtIndex:0];
	NSRect leftFrame = [left frame];
	NSView *right = [[sender subviews] objectAtIndex:1];
	NSRect rightFrame = [right frame];
	
	CGFloat dividerThickness = [sender dividerThickness];
	
	leftFrame.size.height = newFrame.size.height;
	
	rightFrame.size.width = newFrame.size.width - leftFrame.size.width 
	- dividerThickness;
	rightFrame.size.height = newFrame.size.height;
	rightFrame.origin.x = leftFrame.size.width + dividerThickness;
	
	[left setFrame:leftFrame];
	[right setFrame:rightFrame];
}

- (void)splitViewDidResizeSubviews:(NSNotification *)aNotification
{
	NSRect oldInputFrame = [inputField frame];
	oldInputFrame.origin.x = [channelList frame].size.width + [channelList frame].origin.x + 8.f;
	[inputField setFrame:oldInputFrame];
}

@end