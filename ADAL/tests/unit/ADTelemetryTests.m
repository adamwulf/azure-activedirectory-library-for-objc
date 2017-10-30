// Copyright (c) Microsoft Corporation.
// All rights reserved.
//
// This code is licensed under the MIT License.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files(the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and / or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions :
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import <XCTest/XCTest.h>
#import "ADTelemetry.h"
#import "ADTelemetry+Internal.h"
#import "ADTelemetryDefaultEvent.h"
#import "ADTelemetryAPIEvent.h"
#import "ADTelemetryUIEvent.h"
#import "ADTelemetryHttpEvent.h"
#import "ADTelemetryCacheEvent.h"
#import "ADTelemetryBrokerEvent.h"
#import "ADAuthenticationContext+Internal.h"
#import "ADTestURLSession.h"
#import "XCTestCase+TestHelperMethods.h"
#import "ADTokenCache+Internal.h"
#import "ADTokenCacheItem.h"
#import "ADTelemetryTestDispatcher.h"
#import "ADTelemetryEventStrings.h"

@interface ADTelemetryTests : XCTestCase

@end

@implementation ADTelemetryTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testDefaultEventProperties {
    // new a dispatcher
    ADTelemetryTestDispatcher* dispatcher = [ADTelemetryTestDispatcher new];
    NSMutableArray* receivedEvents = [NSMutableArray new];
    
    // the dispatcher will store the telemetry events it receives
    [dispatcher setTestCallback:^(NSDictionary* event)
    {
        [receivedEvents addObject:event];
    }];
    
    // register the dispatcher
    [[ADTelemetry sharedInstance] addDispatcher:dispatcher aggregationRequired:NO];
    
    // generate telemetry event
    NSString* requestId = [[ADTelemetry sharedInstance] registerNewRequest];
    [[ADTelemetry sharedInstance] startEvent:requestId eventName:@"testEvent"];
    [[ADTelemetry sharedInstance] stopEvent:requestId
                                   event:[[ADTelemetryDefaultEvent alloc] initWithName:@"testEvent"
                                                                             requestId:requestId
                                                                         correlationId:[NSUUID UUID]]];
    
    [[ADTelemetry sharedInstance] flush:requestId];
    
    // there should be 1 telemetry event recorded as we only generated one above
    XCTAssertEqual([receivedEvents count], 1);
    
    // make sure the default properties are recorded in the telemetry event,
    // i.e. sdk_id, sdk_version, device_id, device_name
    NSDictionary* event = [receivedEvents firstObject];
    
    XCTAssertNotNil([event objectForKey:@"Microsoft.ADAL.x_client_sku"]);
    XCTAssertNotNil([event objectForKey:@"Microsoft.ADAL.x_client_ver"]);
    XCTAssertNotNil([event objectForKey:@"Microsoft.ADAL.device_id"]);
    XCTAssertNotNil([event objectForKey:@"Microsoft.ADAL.request_id"]);
    XCTAssertNotNil([event objectForKey:@"Microsoft.ADAL.correlation_id"]);
#if TARGET_OS_IPHONE
    // application_version is only available in unit test framework with host app
    XCTAssertNotNil([event objectForKey:@"Microsoft.ADAL.application_version"]);
#endif
    XCTAssertNotNil([event objectForKey:@"Microsoft.ADAL.application_name"]);
}

- (void)testSequentialEvents {
    // new a dispatcher
    ADTelemetryTestDispatcher* dispatcher = [ADTelemetryTestDispatcher new];
    NSMutableArray* receivedEvents = [NSMutableArray new];
    
    // the dispatcher will store the telemetry events it receives
    [dispatcher setTestCallback:^(NSDictionary* event)
     {
         [receivedEvents addObject:event];
     }];
    
    // register the dispatcher
    [[ADTelemetry sharedInstance] addDispatcher:dispatcher aggregationRequired:NO];
    
    // generate telemetry event 1
    NSString* requestId = [[ADTelemetry sharedInstance] registerNewRequest];
    [[ADTelemetry sharedInstance] startEvent:requestId eventName:@"testEvent1"];
    [[ADTelemetry sharedInstance] stopEvent:requestId
                                   event:[[ADTelemetryDefaultEvent alloc] initWithName:@"testEvent1"
                                                                             requestId:requestId
                                                                         correlationId:nil]];
    
    // generate telemetry event 2
    [[ADTelemetry sharedInstance] startEvent:requestId eventName:@"testEvent2"];
    ADTelemetryDefaultEvent* event2 = [[ADTelemetryDefaultEvent alloc] initWithName:@"testEvent2"
                                                                          requestId:requestId
                                                                      correlationId:nil];
    [event2 setProperty:@"customized_property" value:@"customized_value"];
    [[ADTelemetry sharedInstance] stopEvent:requestId
                                   event:event2];
    
    [[ADTelemetry sharedInstance] flush:requestId];
    
    // there should be 2 telemetry events recorded as we generated two
    XCTAssertEqual([receivedEvents count], 2);
    
    // make sure the 1st event has an event_name, start_time and end_time
    NSDictionary* firstEvent = [receivedEvents firstObject];
    
    XCTAssertEqual([firstEvent objectForKey:@"Microsoft.ADAL.event_name"], @"testEvent1");
    XCTAssertNotNil([firstEvent objectForKey:@"Microsoft.ADAL.start_time"]);
    XCTAssertNotNil([firstEvent objectForKey:@"Microsoft.ADAL.stop_time"]);
    XCTAssertNotNil([firstEvent objectForKey:@"Microsoft.ADAL.response_time"]);

    // make sure the 2nd event has customized_property, event_name, start_time and end_time
    NSDictionary* secondEvent = [receivedEvents objectAtIndex:1];
    
    XCTAssertEqual([secondEvent objectForKey:@"customized_property"], @"customized_value");
    XCTAssertEqual([secondEvent objectForKey:@"Microsoft.ADAL.event_name"], @"testEvent2");
    XCTAssertNotNil([secondEvent objectForKey:@"Microsoft.ADAL.start_time"]);
    XCTAssertNotNil([secondEvent objectForKey:@"Microsoft.ADAL.stop_time"]);
    XCTAssertNotNil([secondEvent objectForKey:@"Microsoft.ADAL.response_time"]);
    
}

- (void)testSequentialEventsWithAggregation {
    // new a dispatcher
    ADTelemetryTestDispatcher* dispatcher = [ADTelemetryTestDispatcher new];
    NSMutableArray* receivedEvents = [NSMutableArray new];
    NSUUID* correlationId = [NSUUID UUID];
    
    // the dispatcher will store the telemetry events it receives
    [dispatcher setTestCallback:^(NSDictionary* event)
     {
         [receivedEvents addObject:event];
     }];
    
    // register the dispatcher with aggregation
    [[ADTelemetry sharedInstance] addDispatcher:dispatcher aggregationRequired:YES];
    
    // generate telemetry event 1
    NSString* requestId = [[ADTelemetry sharedInstance] registerNewRequest];
    [[ADTelemetry sharedInstance] startEvent:requestId eventName:@"testEvent1"];
    [[ADTelemetry sharedInstance] stopEvent:requestId
                                   event:[[ADTelemetryAPIEvent alloc] initWithName:@"testEvent1"
                                                                             requestId:requestId
                                                                         correlationId:correlationId]];
    
    // generate telemetry event 2
    [[ADTelemetry sharedInstance] startEvent:requestId eventName:@"testEvent2"];
    ADTelemetryDefaultEvent* event2 = [[ADTelemetryDefaultEvent alloc] initWithName:@"testEvent2"
                                                                          requestId:requestId
                                                                      correlationId:correlationId];
    [event2 setProperty:@"customized_property" value:@"customized_value"];
    [[ADTelemetry sharedInstance] stopEvent:requestId
                                   event:event2];
    
    [[ADTelemetry sharedInstance] flush:requestId];
    
    // there should be 1 telemetry event recorded as aggregation flag is on
    XCTAssertEqual([receivedEvents count], 1);
    
    // the aggregated event outputs the default properties like correlation_id, request_id, etc.
    NSDictionary* event = [receivedEvents firstObject];
    XCTAssertNotNil([event objectForKey:@"Microsoft.ADAL.correlation_id"]);
    XCTAssertNotNil([event objectForKey:@"Microsoft.ADAL.request_id"]);
    
    // it will also outputs some designated properties like response_time, but not for event_name, etc.
    XCTAssertNotNil([event objectForKey:@"Microsoft.ADAL.response_time"]);
    
    XCTAssertNil([event objectForKey:@"Microsoft.ADAL.event_name"]);
    XCTAssertNil([event objectForKey:@"Microsoft.ADAL.start_time"]);
    XCTAssertNil([event objectForKey:@"Microsoft.ADAL.stop_time"]);
    XCTAssertNil([event objectForKey:@"customized_property"]);
    
}

- (void)testNestedEvents {
    // new a dispatcher
    ADTelemetryTestDispatcher* dispatcher = [ADTelemetryTestDispatcher new];
    NSMutableArray* receivedEvents = [NSMutableArray new];
    
    // the dispatcher will store the telemetry events it receives
    [dispatcher setTestCallback:^(NSDictionary* event)
     {
         [receivedEvents addObject:event];
     }];
    
    // register the dispatcher
    [[ADTelemetry sharedInstance] addDispatcher:dispatcher aggregationRequired:NO];
    
    // generate telemetry event1 nested with event2
    NSString* requestId = [[ADTelemetry sharedInstance] registerNewRequest];
    [[ADTelemetry sharedInstance] startEvent:requestId eventName:@"testEvent1"];
    
    [[ADTelemetry sharedInstance] startEvent:requestId eventName:@"testEvent2"];
    ADTelemetryDefaultEvent* event2 = [[ADTelemetryDefaultEvent alloc] initWithName:@"testEvent2"
                                                                          requestId:requestId
                                                                      correlationId:nil];
    [event2 setProperty:@"customized_property" value:@"customized_value"];
    [[ADTelemetry sharedInstance] stopEvent:requestId
                                   event:event2];
    
    [[ADTelemetry sharedInstance] stopEvent:requestId
                                   event:[[ADTelemetryDefaultEvent alloc] initWithName:@"testEvent1"
                                                                             requestId:requestId
                                                                         correlationId:nil]];
    
    [[ADTelemetry sharedInstance] flush:requestId];
    
    // there should be 2 telemetry events recorded as we generated two
    XCTAssertEqual([receivedEvents count], 2);
    
    // the first event recorded is event2
    // make sure it has customized_property, event_name, start_time and end_time
    NSDictionary* firstEvent = [receivedEvents firstObject];
    XCTAssertEqual([firstEvent objectForKey:@"Microsoft.ADAL.event_name"], @"testEvent2");
    XCTAssertEqual([firstEvent objectForKey:@"customized_property"], @"customized_value");
    XCTAssertNotNil([firstEvent objectForKey:@"Microsoft.ADAL.start_time"]);
    XCTAssertNotNil([firstEvent objectForKey:@"Microsoft.ADAL.stop_time"]);
    
    // the second event recorded is event1
    // make sure it has event_name, start_time and end_time
    NSDictionary* secondEvent = [receivedEvents objectAtIndex:1];
    XCTAssertEqual([secondEvent objectForKey:@"Microsoft.ADAL.event_name"], @"testEvent1");
    XCTAssertNotNil([secondEvent objectForKey:@"Microsoft.ADAL.start_time"]);
    XCTAssertNotNil([secondEvent objectForKey:@"Microsoft.ADAL.stop_time"]);
    
}

- (void)testNestedEventsWithAggregation {
    // new a dispatcher
    ADTelemetryTestDispatcher* dispatcher = [ADTelemetryTestDispatcher new];
    NSMutableArray* receivedEvents = [NSMutableArray new];
    NSUUID* correlationId = [NSUUID UUID];
    
    // the dispatcher will store the telemetry events it receives
    [dispatcher setTestCallback:^(NSDictionary* event)
     {
         [receivedEvents addObject:event];
     }];
    
    // register the dispatcher with aggregation
    [[ADTelemetry sharedInstance] addDispatcher:dispatcher aggregationRequired:YES];
    
    // generate telemetry event1 nested with event2
    NSString* requestId = [[ADTelemetry sharedInstance] registerNewRequest];
    [[ADTelemetry sharedInstance] startEvent:requestId eventName:@"testEvent1"];
    
    [[ADTelemetry sharedInstance] startEvent:requestId eventName:@"testEvent2"];
    ADTelemetryDefaultEvent* event2 = [[ADTelemetryDefaultEvent alloc] initWithName:@"testEvent2"
                                                                          requestId:requestId
                                                                      correlationId:correlationId];
    [event2 setProperty:@"customized_property" value:@"customized_value"];
    [[ADTelemetry sharedInstance] stopEvent:requestId
                                   event:event2];
    
    [[ADTelemetry sharedInstance] stopEvent:requestId
                                   event:[[ADTelemetryAPIEvent alloc] initWithName:@"testEvent1"
                                                                             requestId:requestId
                                                                         correlationId:correlationId]];
    
    [[ADTelemetry sharedInstance] flush:requestId];
    
    // there should be 1 telemetry event recorded as aggregation flag is ON
    XCTAssertEqual([receivedEvents count], 1);
    
    // the aggregated event outputs the default properties like correlation_id, request_id, etc.
    NSDictionary* event = [receivedEvents firstObject];
    XCTAssertNotNil([event objectForKey:@"Microsoft.ADAL.correlation_id"]);
    XCTAssertNotNil([event objectForKey:@"Microsoft.ADAL.request_id"]);
    
    // it will also outputs some designated properties like response_time, but not for event_name, etc.
    XCTAssertNotNil([event objectForKey:@"Microsoft.ADAL.response_time"]);
    
    XCTAssertNil([event objectForKey:@"Microsoft.ADAL.event_name"]);
    XCTAssertNil([event objectForKey:@"Microsoft.ADAL.start_time"]);
    XCTAssertNil([event objectForKey:@"Microsoft.ADAL.stop_time"]);
    XCTAssertNil([event objectForKey:@"customized_property"]);
}

- (void)testComplexEvents {
    // new a dispatcher
    ADTelemetryTestDispatcher* dispatcher = [ADTelemetryTestDispatcher new];
    NSMutableArray* receivedEvents = [NSMutableArray new];
    
    // the dispatcher will store the telemetry events it receives
    [dispatcher setTestCallback:^(NSDictionary* event)
     {
         [receivedEvents addObject:event];
     }];
    
    // register the dispatcher
    [[ADTelemetry sharedInstance] addDispatcher:dispatcher aggregationRequired:NO];
    
    // generate telemetry event1 nested with event2
    NSString* requestId = [[ADTelemetry sharedInstance] registerNewRequest];
    [[ADTelemetry sharedInstance] startEvent:requestId eventName:@"testEvent1"];
    
    [[ADTelemetry sharedInstance] startEvent:requestId eventName:@"testEvent2"];
    
    [[ADTelemetry sharedInstance] startEvent:requestId eventName:@"testEvent3"];
    [[ADTelemetry sharedInstance] stopEvent:requestId
                                   event:[[ADTelemetryDefaultEvent alloc] initWithName:@"testEvent3"
                                                                             requestId:requestId
                                                                         correlationId:nil]];
    
    [[ADTelemetry sharedInstance] stopEvent:requestId
                                   event:[[ADTelemetryDefaultEvent alloc] initWithName:@"testEvent2"
                                                                             requestId:requestId
                                                                         correlationId:nil]];
    
    [[ADTelemetry sharedInstance] stopEvent:requestId
                                   event:[[ADTelemetryDefaultEvent alloc] initWithName:@"testEvent1"
                                                                             requestId:requestId
                                                                         correlationId:nil]];
    
    [[ADTelemetry sharedInstance] startEvent:requestId eventName:@"testEvent4"];
    [[ADTelemetry sharedInstance] stopEvent:requestId
                                   event:[[ADTelemetryDefaultEvent alloc] initWithName:@"testEvent4"
                                                                             requestId:requestId
                                                                         correlationId:nil]];
    
    [[ADTelemetry sharedInstance] flush:requestId];
    
    // there should be 4 telemetry events recorded as we generated four
    XCTAssertEqual([receivedEvents count], 4);
    
    // the first event recorded is event3
    NSDictionary* firstEvent = [receivedEvents firstObject];
    XCTAssertEqual([firstEvent objectForKey:@"Microsoft.ADAL.event_name"], @"testEvent3");
    XCTAssertNotNil([firstEvent objectForKey:@"Microsoft.ADAL.start_time"]);
    XCTAssertNotNil([firstEvent objectForKey:@"Microsoft.ADAL.stop_time"]);
    
    // the second event recorded is event2
    NSDictionary* secondEvent = [receivedEvents objectAtIndex:1];
    XCTAssertEqual([secondEvent objectForKey:@"Microsoft.ADAL.event_name"], @"testEvent2");
    XCTAssertNotNil([secondEvent objectForKey:@"Microsoft.ADAL.start_time"]);
    XCTAssertNotNil([secondEvent objectForKey:@"Microsoft.ADAL.stop_time"]);
    
    // the third event recorded is event1
    NSDictionary* thirdEvent = [receivedEvents objectAtIndex:2];
    XCTAssertEqual([thirdEvent objectForKey:@"Microsoft.ADAL.event_name"], @"testEvent1");
    XCTAssertNotNil([thirdEvent objectForKey:@"Microsoft.ADAL.start_time"]);
    XCTAssertNotNil([thirdEvent objectForKey:@"Microsoft.ADAL.stop_time"]);
    
    // the fourth event recorded is event4
    NSDictionary* fourthEvent = [receivedEvents objectAtIndex:3];
    XCTAssertEqual([fourthEvent objectForKey:@"Microsoft.ADAL.event_name"], @"testEvent4");
    XCTAssertNotNil([fourthEvent objectForKey:@"Microsoft.ADAL.start_time"]);
    XCTAssertNotNil([fourthEvent objectForKey:@"Microsoft.ADAL.stop_time"]);
}

- (void)testComplexEventsWithAggregation {
    // new a dispatcher
    ADTelemetryTestDispatcher* dispatcher = [ADTelemetryTestDispatcher new];
    NSMutableArray* receivedEvents = [NSMutableArray new];
    NSUUID* correlationId = [NSUUID UUID];
    
    // the dispatcher will store the telemetry events it receives
    [dispatcher setTestCallback:^(NSDictionary* event)
     {
         [receivedEvents addObject:event];
     }];
    
    // register the dispatcher
    [[ADTelemetry sharedInstance] addDispatcher:dispatcher aggregationRequired:YES];
    
    // generate telemetry event1 nested with event2
    NSString* requestId = [[ADTelemetry sharedInstance] registerNewRequest];
    [[ADTelemetry sharedInstance] startEvent:requestId eventName:@"testEvent1"];
    
    [[ADTelemetry sharedInstance] startEvent:requestId eventName:@"testEvent2"];
    
    [[ADTelemetry sharedInstance] startEvent:requestId eventName:@"testEvent3"];
    [[ADTelemetry sharedInstance] stopEvent:requestId
                                   event:[[ADTelemetryDefaultEvent alloc] initWithName:@"testEvent3"
                                                                             requestId:requestId
                                                                         correlationId:correlationId]];
    
    [[ADTelemetry sharedInstance] stopEvent:requestId
                                   event:[[ADTelemetryDefaultEvent alloc] initWithName:@"testEvent2"
                                                                             requestId:requestId
                                                                         correlationId:nil]];
    
    [[ADTelemetry sharedInstance] stopEvent:requestId
                                   event:[[ADTelemetryAPIEvent alloc] initWithName:@"testEvent1"
                                                                             requestId:requestId
                                                                         correlationId:correlationId]];
    
    [[ADTelemetry sharedInstance] startEvent:requestId eventName:@"testEvent4"];
    [[ADTelemetry sharedInstance] stopEvent:requestId
                                   event:[[ADTelemetryDefaultEvent alloc] initWithName:@"testEvent4"
                                                                             requestId:requestId
                                                                         correlationId:correlationId]];
    
    [[ADTelemetry sharedInstance] flush:requestId];
    
    // there should be 1 telemetry events recorded as aggregation flag is ON
    XCTAssertEqual([receivedEvents count], 1);
    
    // the aggregated event outputs the default properties like correlation_id, request_id, etc.
    NSDictionary* event = [receivedEvents firstObject];
    
    XCTAssertNotNil([event objectForKey:@"Microsoft.ADAL.correlation_id"]);
    XCTAssertNotNil([event objectForKey:@"Microsoft.ADAL.request_id"]);
    
    // it will also outputs some designated properties like response_time, but not for event_name, etc.
    XCTAssertNotNil([event objectForKey:@"Microsoft.ADAL.response_time"]);
    
    XCTAssertNil([event objectForKey:@"Microsoft.ADAL.event_name"]);
    XCTAssertNil([event objectForKey:@"Microsoft.ADAL.start_time"]);
    XCTAssertNil([event objectForKey:@"Microsoft.ADAL.stop_time"]);
    XCTAssertNil([event objectForKey:@"customized_property"]);
}

@end
