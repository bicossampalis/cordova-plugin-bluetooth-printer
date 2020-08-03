//
//  UIWebView+UIImage.h
//  HLBluetoothDemo
//
//  Created by Harvey on 16/5/13.
//  Copyright © 2016年 Halley. All rights reserved.
//

#import "CDVWKWebViewEngine.h"

@interface WKWebView (UIImage)

/**
 *  获取当前加载的网页的截图
 *
 *  @return
 */
- (UIImage *)imageForWebView;

@end
