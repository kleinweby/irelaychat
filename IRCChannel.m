//
//  IRCChannel.m
//  iRelayChat
//
//  Created by Christian Speich on 17.04.08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "IRCChannel.h"
#import "IRCServer.h"
#import "IRCMessage.h"
#import "IRCUser.h"
#import "IRCUserMode.h"

NSString *IRCUserListHasChanged  = @"iRelayChat-IRCUserListHasChanged";
NSString *IRCNewChannelMessage = @"iRelayChat-IRCNewChannelMessage";
NSString *IRCUserJoinsChannel = @"iRelayChat-IRCUserJoinsChannel";
NSString *IRCUserLeavesChannel = @"iRelayChat-IRCUserLeavesChannel";
NSString *IRCUserHasGotMode = @"iRelayChat-IRCUserHasGotMode";
NSString *IRCUserHasLoseMode = @"iRelayChat-IRCUserHasLoseMode";

NSComparisonResult sortUsers(id first, id second, void *contex) {
	IRCChannel *channel = (IRCChannel*)contex;
	NSLog(@"sort");
	IRCUserMode *firstMode = [first userModeForChannel:channel];
	IRCUserMode *secondMode = [second userModeForChannel:channel];
	
	if ((firstMode.hasOp && secondMode.hasOp) ||
		(firstMode.hasVoice && secondMode.hasVoice))
		return [[first nickname] compare:[second nickname]];
	
	if (firstMode.hasOp && !secondMode.hasOp)
		return NSOrderedAscending;
	
	if (!firstMode.hasOp && secondMode.hasOp)
		return NSOrderedDescending;
	
	if (firstMode.hasVoice && !secondMode.hasVoice)
		return NSOrderedAscending;
	
	if (!firstMode.hasVoice && secondMode.hasVoice)
		return NSOrderedDescending;
	
	return [[first nickname] compare:[second nickname]];
}

@implementation IRCChannel

@synthesize name, server, userList;

- (id) initWithServer:(IRCServer*)_server andName:(NSString*)_name;
{
	self = [super init];
	if (self != nil) {
		name = _name;
		server = _server;
		tmpUserList = nil;
		userList = nil;
		
		NSMutableArray *para = [[NSMutableArray alloc] init];
		[para addObject:@"*"];
		[para addObject:@"*"];
		[para addObject:name];
		
		[server addObserver:self selector:@selector(userList:) message:[[IRCMessage alloc] initWithCommand:@"353" from:nil andPrarameters:para]];
		[para release];
		
		para = [[NSMutableArray alloc] init];
		[para addObject:@"*"];
		[para addObject:name];
		[server addObserver:self selector:@selector(userListEnd:) message:[[IRCMessage alloc] initWithCommand:@"366" from:nil andPrarameters:para]];
		[para release];
		
		para = [[NSMutableArray alloc] init];
		[para addObject:name];
		[server addObserver:self selector:@selector(channelMessage:) message:[[IRCMessage alloc] initWithCommand:@"PRIVMSG" from:nil andPrarameters:para]];
		[para release];
		
		para = [[NSMutableArray alloc] init];
		[para addObject:name];
		[server addObserver:self selector:@selector(userJoin:) message:[[IRCMessage alloc] initWithCommand:@"JOIN" from:nil andPrarameters:para]];
		[para release];
		
		para = [[NSMutableArray alloc] init];
		[para addObject:name];
		[server addObserver:self selector:@selector(userLeave:) message:[[IRCMessage alloc] initWithCommand:@"PART" from:nil andPrarameters:para]];
		[para release];
		
		para = [[NSMutableArray alloc] init];
		[para addObject:name];
		[server addObserver:self selector:@selector(modeChanged:) message:[[IRCMessage alloc] initWithCommand:@"MODE" from:nil andPrarameters:para]];
		[para release];
		
		[server send:[NSString stringWithFormat:@"JOIN %@", name]];
		[[NSNotificationCenter defaultCenter] postNotificationName:IRCJoinChannel object:self];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(userQuits:) name:IRCUserQuit object:self.server];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(userChanged:) name:IRCUserChanged object:nil];
		[NSTimer scheduledTimerWithTimeInterval:120.f target:self selector:@selector(reloadUserList) userInfo:nil repeats:YES];
	}
	return self;
}

- (void) reloadUserList
{
	[server send:[NSString stringWithFormat:@"NAMES %@", name]];
}

- (void) sendMessage:(NSString*)message
{
	if ([message characterAtIndex:0] == '/') {
		
	}
	else {
		[server send:[NSString stringWithFormat:@"PRIVMSG %@ :%@", name, message]];
	}
}

- (void) userList:(IRCMessage*)message
{
	if (!tmpUserList)
		tmpUserList = [[NSMutableArray alloc] init];
	
	NSArray *users = [[message.parameters objectAtIndex:3] componentsSeparatedByString:@" "];
	
	for (NSString *username in users) {
		IRCUser *user = [IRCUser userWithNickname:username onServer:self.server];
		IRCUserMode *mode = [[IRCUserMode alloc] initFromUserString:username];
		[user setUserMode:mode forChannel:self];
		[mode release];
		[tmpUserList addObject:user];
		[user release];
	}
}

- (void) userListEnd:(IRCMessage*)message
{
	[tmpUserList sortUsingFunction:sortUsers context:self];
	if (![userList isEqualToArray:tmpUserList]) {
		NSLog(@"we've loosed some changes!");
		[userList release];
		userList = tmpUserList;
		tmpUserList = nil;
		[[NSNotificationCenter defaultCenter] postNotificationName:IRCUserListHasChanged object:self];
	}
	else {
		[tmpUserList release];
		tmpUserList = nil;
	}

}

- (void) channelMessage:(IRCMessage*)message
{
	NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
	[dict setObject:message.from forKey:@"FROM"];
	[dict setObject:[message.parameters objectAtIndex:1] forKey:@"MESSAGE"];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:IRCNewChannelMessage object:self userInfo:dict];
}

- (void) userJoin:(IRCMessage*)message
{
	NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
	[dict setObject:message.from forKey:@"FROM"];
	[userList addObject:message.from];
	[userList sortUsingFunction:sortUsers context:self];
	[[NSNotificationCenter defaultCenter] postNotificationName:IRCUserJoinsChannel object:self userInfo:dict];
	[[NSNotificationCenter defaultCenter] postNotificationName:IRCUserListHasChanged object:self];
}

- (void) userLeave:(IRCMessage*)message
{
	NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
	[dict setObject:message.from forKey:@"FROM"];
	[userList removeObject:message.from];
	[userList sortUsingFunction:sortUsers context:self];
	[[NSNotificationCenter defaultCenter] postNotificationName:IRCUserLeavesChannel object:self userInfo:dict];
	[[NSNotificationCenter defaultCenter] postNotificationName:IRCUserListHasChanged object:self];
}

- (void) modeChanged:(IRCMessage*)message
{
	IRCUser *user = [IRCUser userWithNickname:[message.parameters objectAtIndex:2] onServer:server];
	IRCUserMode *mode = [user userModeForChannel:self];
	NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
	[dict setObject:user forKey:@"USER"];
	[dict setObject:message.from forKey:@"FROM"];
	
	if ([[message.parameters objectAtIndex:1] isEqualToString:@"+v"]) {
		if (!mode.hasVoice) {
			mode.hasVoice = YES;
			[dict setObject:@"Voice" forKey:@"MODE"];
			[userList sortUsingFunction:sortUsers context:self];
			[[NSNotificationCenter defaultCenter] postNotificationName:IRCUserHasGotMode object:self userInfo:dict];
			[[NSNotificationCenter defaultCenter] postNotificationName:IRCUserListHasChanged object:self];
		}
	}
	else if ([[message.parameters objectAtIndex:1] isEqualToString:@"-v"]) {
		if (mode.hasVoice) {
			mode.hasVoice = NO;
			[userList sortUsingFunction:sortUsers context:self];
			[dict setObject:@"Voice" forKey:@"MODE"];
			[[NSNotificationCenter defaultCenter] postNotificationName:IRCUserHasLoseMode object:self userInfo:dict];
			[[NSNotificationCenter defaultCenter] postNotificationName:IRCUserListHasChanged object:self];
		}
	}
	else if ([[message.parameters objectAtIndex:1] isEqualToString:@"+o"]) {
		if (!mode.hasOp) {
			mode.hasOp = YES;
			[userList sortUsingFunction:sortUsers context:self];
			[dict setObject:@"Op" forKey:@"MODE"];
			[[NSNotificationCenter defaultCenter] postNotificationName:IRCUserHasGotMode object:self userInfo:dict];
			[[NSNotificationCenter defaultCenter] postNotificationName:IRCUserListHasChanged object:self];
		}
	}
	else if ([[message.parameters objectAtIndex:1] isEqualToString:@"-o"]) {
		if (mode.hasOp) {
			mode.hasOp = NO;
			[dict setObject:@"Op" forKey:@"MODE"];
			[[NSNotificationCenter defaultCenter] postNotificationName:IRCUserHasLoseMode object:self userInfo:dict];
			[[NSNotificationCenter defaultCenter] postNotificationName:IRCUserListHasChanged object:self];
		}
	}
	[dict release];
}

- (void) userQuits:(NSNotification*)noti
{
	if ([userList containsObject:[[noti userInfo] objectForKey:@"FROM"]]) {
		[userList removeObject:[[noti userInfo] objectForKey:@"FROM"]];
		[userList sortUsingFunction:sortUsers context:self];
		[[NSNotificationCenter defaultCenter] postNotificationName:IRCUserQuit object:self userInfo:[noti userInfo]];
		[[NSNotificationCenter defaultCenter] postNotificationName:IRCUserListHasChanged object:self];
	}
}

- (void) userChanged:(NSNotification*)noti
{
	[userList sortUsingFunction:sortUsers context:self];
	[[NSNotificationCenter defaultCenter] postNotificationName:IRCUserListHasChanged object:self];
}

@end
