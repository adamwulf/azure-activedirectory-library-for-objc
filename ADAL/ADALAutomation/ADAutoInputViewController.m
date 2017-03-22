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

#import "ADAutoInputViewController.h"
#import "ADAutoTextAndButtonView.h"

@interface ADAutoInputViewController ()

@end

@implementation ADAutoInputViewController
{
    ADAutoParamBlock _completionBlock;
    ADAutoTextAndButtonView* _textAndButtonView;
}

- (id)initWithCompletionBlock:(ADAutoParamBlock)completionBlock
{
    if (!(self = [super init]))
    {
        return nil;
    }
    
    _completionBlock = completionBlock;
    
    return self;
}

- (void)loadView
{
    UIView* contentView = [[UIView alloc] initWithFrame:UIScreen.mainScreen.bounds];
    contentView.backgroundColor = UIColor.whiteColor;
    self.view = contentView;
    _textAndButtonView = [[ADAutoTextAndButtonView alloc] initWithFrame:UIScreen.mainScreen.bounds];
    [contentView addSubview:_textAndButtonView];
    [_textAndButtonView.actionButton addTarget:self
                                        action:@selector(go:)
                              forControlEvents:UIControlEventTouchUpInside];
    
    NSDictionary* views = @{ @"textAndButtonView" : _textAndButtonView,
                             @"topLayoutGuide" : self.topLayoutGuide,
                             @"bottomLayoutGuide" : self.bottomLayoutGuide };
    
    NSArray* verticalConstraints =
    [NSLayoutConstraint constraintsWithVisualFormat:@"V:[topLayoutGuide]-[textAndButtonView]-[bottomLayoutGuide]"
                                            options:0
                                            metrics:nil
                                              views:views];
    
    NSArray* horizontalConstraints =
    [NSLayoutConstraint constraintsWithVisualFormat:@"H:|-[textAndButtonView]-|"
                                            options:0
                                            metrics:nil
                                              views:views];
    
    [self.view addConstraints:verticalConstraints];
    [self.view addConstraints:horizontalConstraints];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)go:(id)sender
{
    (void)sender;
    
    @synchronized (self)
    {
        NSString* text = _textAndButtonView.textView.text;
        NSError* error = nil;
        NSDictionary* params = [NSJSONSerialization JSONObjectWithData:[text dataUsingEncoding:NSUTF8StringEncoding] options:0 error:&error];
        if (!params)
        {
            params = @{ @"error" : error };
        }
        
        _completionBlock(params);
    }
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
