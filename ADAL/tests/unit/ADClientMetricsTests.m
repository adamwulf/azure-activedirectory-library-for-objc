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
#import "ADClientMetrics.h"

@interface ADClientMetricsTests : XCTestCase

@end

@implementation ADClientMetricsTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testMetrics
{
    ADClientMetrics* metrics = [ADClientMetrics new];
    NSMutableDictionary* header = [NSMutableDictionary new];
    
    NSDate* startTime = [NSDate new];
    [metrics addClientMetrics:header
                     endpoint:@"https://login.windows.net/common/oauth2/token"];
    [metrics endClientMetricsRecord:@"https://login.windows.net/common/oauth2/token"
                          startTime:startTime
                      correlationId:[NSUUID UUID]
                       errorDetails:@"error"];
    XCTAssertEqual([header count], 0);
    
    [metrics addClientMetrics:header
                     endpoint:@"https://login.windows.net/common/oauth2/token"];
    XCTAssertEqual([header count], 4);
}

- (void)testMetricsWithADFSEndpointFollowedByNonADFS
{
    ADClientMetrics* metrics = [ADClientMetrics new];
    NSMutableDictionary* header = [NSMutableDictionary new];
    
    NSDate* startTime = [NSDate new];
    [metrics addClientMetrics:header
                     endpoint:@"https://sts.contoso.com/adfs/oauth2/token"];
    XCTAssertEqual([header count], 0);
    [metrics endClientMetricsRecord:@"https://sts.contoso.com/adfs/oauth2/token"
                          startTime:startTime
                      correlationId:[NSUUID UUID]
                       errorDetails:@"error"];
    
    [metrics addClientMetrics:header
                     endpoint:@"https://login.windows.net/common/oauth2/token"];
    XCTAssertEqual([header count], 0);
    
    [metrics endClientMetricsRecord:@"https://login.windows.net/common/oauth2/token"
                          startTime:startTime
                      correlationId:[NSUUID UUID]
                       errorDetails:@"error"];
    
    [metrics addClientMetrics:header
                     endpoint:@"https://login.windows.net/common/oauth2/token"];
    XCTAssertEqual([header count], 4);
}

@end
