//
//  HLPrinter.m
//  HLBluetoothDemo
//
//  Created by Harvey on 16/5/3.
//  Copyright © 2016年 Halley. All rights reserved.
//

#import "HLPrinter.h"

#define kHLMargin 20
#define kHLPadding 2
#define kHLPreviewWidth 320

#define KDefault_pageWidth 78
static NSString * const kUD_pringerPageWidth = @"kUD_pringerPageWidth";

#define kDefault_maxLength3Text 16
#define kDefault_maxLength4Text 20

static NSString * const kUD_maxLength3Text = @"kUD_maxLength3Text";
static NSString * const kUD_maxLength4Text = @"kUD_maxLength4Text";

@interface HLPrinter ()

/** 将要打印的排版后的数据 */
@property (strong, nonatomic) NSMutableData *printerData;
@property (strong, nonatomic) MKPageWidthConfig *config;

@end

@implementation HLPrinter

/** 单例 */
static HLPrinter *sharedInstance = nil;
+ (instancetype)sharedInstance {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init{
    self = [super init];
    if (self) {
        [self defaultSetting];
    }
    return self;
}

- (void)defaultSetting{
    _printerData = [[NSMutableData alloc] init];
    
    // 1.初始化打印机
    Byte initBytes[] = {0x1B,0x40};
    [_printerData appendBytes:initBytes length:sizeof(initBytes)];
    // 2.设置行间距为1/6英寸，约34个点
    // 另一种设置行间距的方法看这个 @link{-setLineSpace:}
    Byte lineSpace[] = {0x1B,0x32};
    [_printerData appendBytes:lineSpace length:sizeof(lineSpace)];
    // 3.设置字体:标准0x00，压缩0x01;
    Byte fontBytes[] = {0x1B,0x4D,0x00};
    [_printerData appendBytes:fontBytes length:sizeof(fontBytes)];
    
    _pageWidth = [[NSUserDefaults standardUserDefaults] integerForKey:kUD_pringerPageWidth];
    if (_pageWidth <= 0) {
        _pageWidth = KDefault_pageWidth;
        [[NSUserDefaults standardUserDefaults] setInteger:_pageWidth forKey:kUD_pringerPageWidth];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    
    _config = [[MKPageWidthConfig alloc] init];
    [_config setupConfigWith:_pageWidth];
    
    _maxLength3Text = [[NSUserDefaults standardUserDefaults] integerForKey:kUD_maxLength3Text];
    if (_maxLength3Text <= 0) {
        _maxLength3Text = kDefault_maxLength3Text;
    }
    
    _maxLength4Text = [[NSUserDefaults standardUserDefaults] integerForKey:kUD_maxLength4Text];
    if (_maxLength4Text <= 0) {
        _maxLength4Text = kDefault_maxLength4Text;
    }
}

- (void)setMaxLength3Text:(NSInteger)maxLength3Text{
    if (maxLength3Text > 0) {
        _maxLength3Text = maxLength3Text;
        [[NSUserDefaults standardUserDefaults] setInteger:_maxLength3Text forKey:kUD_maxLength3Text];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

- (void)setMaxLength4Text:(NSInteger)maxLength4Text{
    if (maxLength4Text > 0) {
        _maxLength4Text = maxLength4Text;
        [[NSUserDefaults standardUserDefaults] setInteger:_maxLength4Text forKey:kUD_maxLength4Text];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

#pragma mark - ***** 设置打印机纸张宽度 ******
- (void)setPageWidth:(NSInteger)pageWidth{
    if (pageWidth > 0) {
        _pageWidth = pageWidth;
        [[NSUserDefaults standardUserDefaults] setInteger:_pageWidth forKey:kUD_pringerPageWidth];
        [[NSUserDefaults standardUserDefaults] synchronize];
        [self.config setupConfigWith:_pageWidth];
    }
}


#pragma mark - -------------基本操作----------------
/**
 *  换行
 */
- (void)appendNewLine{
    Byte nextRowBytes[] = {0x0A};
    [_printerData appendBytes:nextRowBytes length:sizeof(nextRowBytes)];
}

/**
 *  回车
 */
- (void)appendReturn{
    Byte returnBytes[] = {0x0D};
    [_printerData appendBytes:returnBytes length:sizeof(returnBytes)];
}

/**
 *  设置对齐方式
 *
 *  @param alignment 对齐方式：居左、居中、居右
 */
- (void)setAlignment:(HLTextAlignment)alignment{
    Byte alignBytes[] = {0x1B,0x61,alignment};
    [_printerData appendBytes:alignBytes length:sizeof(alignBytes)];
}

/**
 *  设置字体大小
 *
 *  @param fontSize 字号
 */
- (void)setFontSize:(HLFontSize)fontSize{
    Byte fontSizeBytes[] = {0x1D,0x21,fontSize};
    [_printerData appendBytes:fontSizeBytes length:sizeof(fontSizeBytes)];
}

/**
 *  添加文字，不换行
 *
 *  @param text 文字内容
 */
- (void)setText:(NSString *)text{
    NSString *str;
    if ([text isKindOfClass:[NSNumber class]]) {
        str = [NSString stringWithFormat:@"%@", str];
    }else{
        str = text;
    }
    
    NSStringEncoding enc = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000);
    NSData *data = [str dataUsingEncoding:enc];
    [_printerData appendData:data];
}

/**
 *  添加文字，不换行
 *
 *  @param text    文字内容
 *  @param maxChar 最多可以允许多少个字节,后面加...
 */
- (void)setText:(NSString *)text maxChar:(int)maxChar{
    NSStringEncoding enc = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000);
    NSData *data = [text dataUsingEncoding:enc];
    if (data.length > maxChar) {
        data = [data subdataWithRange:NSMakeRange(0, maxChar)];
        text = [[NSString alloc] initWithData:data encoding:enc];
        if (!text) {
            data = [data subdataWithRange:NSMakeRange(0, maxChar - 1)];
            text = [[NSString alloc] initWithData:data encoding:enc];
        }
        text = [text stringByAppendingString:@"..."];
    }
    [self setText:text];
}

/**
 *  设置偏移文字
 *
 *  @param text 文字
 */
- (void)setOffsetText:(NSString *)text{
    // 1.计算偏移量,因字体和字号不同，所以计算出来的宽度与实际宽度有误差(小字体与22字体计算值接近)
    NSDictionary *dict = @{NSFontAttributeName:[UIFont systemFontOfSize:22.0]};
    NSAttributedString *valueAttr = [[NSAttributedString alloc] initWithString:text attributes:dict];
    int valueWidth = valueAttr.size.width;
    
    // 2.设置偏移量
    [self setOffset:368 - valueWidth];
    
    // 3.设置文字
    [self setText:text];
}

/**
 *  设置偏移量
 *
 *  @param offset 偏移量
 */
- (void)setOffset:(NSInteger)offset{
    NSInteger remainder = offset % 256;
    NSInteger consult = offset / 256;
    Byte spaceBytes2[] = {0x1B, 0x24, remainder, consult};
    [_printerData appendBytes:spaceBytes2 length:sizeof(spaceBytes2)];
}

/**
 *  设置行间距
 *
 *  @param points 多少个点
 */
- (void)setLineSpace:(NSInteger)points{
    //最后一位，可选 0~255
    Byte lineSpace[] = {0x1B,0x33,points};
    [_printerData appendBytes:lineSpace length:sizeof(lineSpace)];
}

/**
 *  设置二维码模块大小
 *
 *  @param size  1<= size <= 16,二维码的宽高相等
 */
- (void)setQRCodeSize:(NSInteger)size{
    Byte QRSize [] = {0x1D,0x28,0x6B,0x03,0x00,0x31,0x43,size};
//    Byte QRSize [] = {29,40,107,3,0,49,67,size};
    [_printerData appendBytes:QRSize length:sizeof(QRSize)];
}

/**
 *  设置二维码的纠错等级
 *
 *  @param level 48 <= level <= 51
 */
- (void)setQRCodeErrorCorrection:(NSInteger)level{
    Byte levelBytes [] = {0x1D,0x28,0x6B,0x03,0x00,0x31,0x45,level};
//    Byte levelBytes [] = {29,40,107,3,0,49,69,level};
    [_printerData appendBytes:levelBytes length:sizeof(levelBytes)];
}

/**
 *  将二维码数据存储到符号存储区
 * [范围]:  4≤(pL+pH×256)≤7092 (0≤pL≤255,0≤pH≤27) 
 * cn=49  
 * fn=80  
 * m=48
 * k=(pL+pH×256)-3, k就是数据的长度
 *
 *  @param info 二维码数据
 */
- (void)setQRCodeInfo:(NSString *)info{
    NSInteger kLength = info.length + 3;
    NSInteger pL = kLength % 256;
    NSInteger pH = kLength / 256;
    
    Byte dataBytes [] = {0x1D,0x28,0x6B,pL,pH,0x31,0x50,48};
//    Byte dataBytes [] = {29,40,107,pL,pH,49,80,48};
    [_printerData appendBytes:dataBytes length:sizeof(dataBytes)];
    NSData *infoData = [info dataUsingEncoding:NSUTF8StringEncoding];
    [_printerData appendData:infoData];
//    [self setText:info];
}

/**
 *  打印之前存储的二维码信息
 */
- (void)printStoredQRData{
    Byte printBytes [] = {0x1D,0x28,0x6B,0x03,0x00,0x31,0x51,48};
//    Byte printBytes [] = {29,40,107,3,0,49,81,48};
    [_printerData appendBytes:printBytes length:sizeof(printBytes)];
}

#pragma mark - ------------function method ----------------
#pragma mark  文字
- (void)appendText:(NSString *)text alignment:(HLTextAlignment)alignment{
    [self appendText:text alignment:alignment fontSize:HLFontSizeTitleSmalle];
}

- (void)appendText:(NSString *)text alignment:(HLTextAlignment)alignment fontSize:(HLFontSize)fontSize{
    // 1.文字对齐方式
    [self setAlignment:alignment];
    // 2.设置字号
    [self setFontSize:fontSize];
    // 3.设置标题内容
    [self setText:text];
    // 4.换行
    [self appendNewLine];
    if (fontSize != HLFontSizeTitleSmalle) {
        [self appendNewLine];
    }
}

- (void)appendTitle:(NSString *)title value:(NSString *)value{
    [self appendTitle:title value:value fontSize:HLFontSizeTitleSmalle];
}

- (void)appendTitle:(NSString *)title value:(NSString *)value fontSize:(HLFontSize)fontSize{
    // 1.设置对齐方式
    [self setAlignment:HLTextAlignmentLeft];
    // 2.设置字号
    [self setFontSize:fontSize];
    
    NSString *text = [self getPrintString:title tail:value];
    // 3.设置标题内容
    [self setText:text];
    // 4.设置实际值
//    [self setOffsetText:value];
    // 5.换行
    [self appendNewLine];
    if (fontSize != HLFontSizeTitleSmalle) {
        [self appendNewLine];
    }
}

- (NSString *)getPrintString:(NSString *)leader tail:(NSString *)tail{
    int TOTAL = self.config.virtualWidth; //这里是根据你的纸张宽度试验出来的一个合适的总字数
    NSMutableString *printString = [NSMutableString new];
    [printString appendString:leader];
    
    int lenderLen = [self getTextLength:leader];
    
    if (tail) {
        int tailLen = [self getTextLength:tail];
        int detal = (int)(TOTAL - lenderLen - tailLen);
        for (int i = 0; i < detal; i ++) {
            [printString appendString:@" "];
        }
        [printString appendString:tail];
    }else{
        int detal = (int)(TOTAL - lenderLen);
        for (int i = 0; i < detal; i ++) {
            [printString appendString:@" "];
        }
    }
    return printString;
}

- (int)getTextLength:(NSString *)text{
    int strlength = 0;
    char *p = (char*)[text cStringUsingEncoding:NSUnicodeStringEncoding];
    for (int i = 0 ; i < [text lengthOfBytesUsingEncoding:NSUnicodeStringEncoding] ;i++) {
        if (*p) {
            p++;
            strlength++;
        }else {
            p++;
        }
    }
    return strlength;
}

- (void)appendTitle:(NSString *)title value:(NSString *)value valueOffset:(NSInteger)offset{
    [self appendTitle:title value:value valueOffset:offset fontSize:HLFontSizeTitleSmalle];
}

- (void)appendTitle:(NSString *)title value:(NSString *)value valueOffset:(NSInteger)offset fontSize:(HLFontSize)fontSize{
    // 1.设置对齐方式
    [self setAlignment:HLTextAlignmentLeft];
    // 2.设置字号
    [self setFontSize:fontSize];
    // 3.设置标题内容
    [self setText:title];
    // 4.设置内容偏移量
    [self setOffset:offset];
    // 5.设置实际值
    [self setText:value];
    // 6.换行
    [self appendNewLine];
    if (fontSize != HLFontSizeTitleSmalle) {
        [self appendNewLine];
    }
}

- (void)appendLeftText:(NSString *)left middleText:(NSString *)middle rightText:(NSString *)right isTitle:(BOOL)isTitle{
    [self setAlignment:HLTextAlignmentLeft];
    
    NSInteger offset = 0;
    if (!isTitle) {
        offset = 10;
        [self setFontSize:HLFontSizeTitleMiddle];
    }
    
    if (left) {
        [self setText:left maxChar:(int)[HLPrinter sharedInstance].maxLength3Text];
    }
    
    if (middle) {
        [self setOffset:[self.config.offsetAryfor3Text[0] intValue] + offset];
        [self setText:middle];
    }
    
    if (right) {
        [self setOffset:[self.config.offsetAryfor3Text[1] intValue] + offset];
        [self setText:right];
    }
    
    [self appendNewLine];
    
}

- (void)appendTextArray:(NSArray *)texts isTitle:(BOOL)isTitle{
    if (texts.count == 4) {
        [self setAlignment:HLTextAlignmentLeft];
        [self setFontSize:HLFontSizeTitleSmalle];
        
        NSInteger offset = 0;
        if (!isTitle) {
            offset = 5;
        }
        
        if ([texts[0] length] > 0) {
            [self setText:texts[0] maxChar:(int)[HLPrinter sharedInstance].maxLength4Text];
        }
        
        if ([texts[1] length] > 0) {
            [self setOffset:[self.config.offsetAryfor4Text[0] intValue] + offset];
            [self setText:texts[1]];
        }
        if ([texts[2] length] > 0) {
            [self setOffset:[self.config.offsetAryfor4Text[1] intValue] + offset];
            [self setText:texts[2]];
        }
        if ([texts[3] length] > 0) {
            [self setOffset:[self.config.offsetAryfor4Text[2] intValue] + offset];
            [self setText:texts[3]];
        }
        [self appendNewLine];
    }
}

#pragma mark 图片
- (void)appendImage:(UIImage *)image alignment:(HLTextAlignment)alignment maxWidth:(CGFloat)maxWidth{
    if (!image) {
        return;
    }
    // 1.设置图片对齐方式
    [self setAlignment:alignment];
    
    // 2.设置图片
    UIImage *newImage = [image imageWithscaleMaxWidth:250];
//    newImage = [newImage blackAndWhiteImage];
    
    NSData *imageData = [newImage bitmapData];
    [_printerData appendData:imageData];
    
    // 3.换行
    [self appendNewLine];
    [self appendSpaceLine];

    // 4.打印图片后，恢复文字的行间距
    Byte lineSpace[] = {0x1B,0x32};
    [_printerData appendBytes:lineSpace length:sizeof(lineSpace)];
}

- (void)appendBarCodeWithInfo:(NSString *)info{
    [self appendBarCodeWithInfo:info alignment:HLTextAlignmentCenter maxWidth:300];
}

- (void)appendBarCodeWithInfo:(NSString *)info alignment:(HLTextAlignment)alignment maxWidth:(CGFloat)maxWidth{
    UIImage *barImage = [UIImage barCodeImageWithInfo:info];
    [self appendImage:barImage alignment:alignment maxWidth:maxWidth];
}

- (void)appendQRCodeWithInfo:(NSString *)info size:(NSInteger)size{
    [self appendQRCodeWithInfo:info size:size alignment:HLTextAlignmentCenter];
}

- (void)appendQRCodeWithInfo:(NSString *)info size:(NSInteger)size alignment:(HLTextAlignment)alignment{
    [self setAlignment:alignment];
    [self setQRCodeSize:size];
    [self setQRCodeErrorCorrection:48];
    [self setQRCodeInfo:info];
    [self printStoredQRData];
    [self appendNewLine];
}

- (void)appendQRCodeWithInfo:(NSString *)info{
    [self appendQRCodeWithInfo:info centerImage:nil alignment:HLTextAlignmentCenter maxWidth:250];
}

- (void)appendQRCodeWithInfo:(NSString *)info centerImage:(UIImage *)centerImage alignment:(HLTextAlignment)alignment maxWidth:(CGFloat )maxWidth{
    UIImage *QRImage = [UIImage qrCodeImageWithInfo:info centerImage:centerImage width:maxWidth];
    [self appendImage:QRImage alignment:alignment maxWidth:maxWidth];
}

/**
 添加自定义的data
 
 @param data 自定义的data
 */
- (void)appendCustomData:(NSData *)data{
    if (data.length <= 0) {
        return;
    }
    [_printerData appendData:data];
}

#pragma mark 其他
- (void)appendSeperatorLine{
    // 1.设置分割线居中
    [self setAlignment:HLTextAlignmentCenter];
    // 2.设置字号
    [self setFontSize:HLFontSizeTitleSmalle];
    // 3.添加分割线
    NSString *line = self.config.lineStr;
    NSStringEncoding enc = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000);
    NSData *data = [line dataUsingEncoding:enc];
    [_printerData appendData:data];
    // 4.换行
    [self appendNewLine];
}

- (void)appendSpaceLine{
    // 1.设置分割线居中
    [self setAlignment:HLTextAlignmentCenter];
    // 2.设置字号
    [self setFontSize:HLFontSizeTitleSmalle];
    // 3.添加空行
    NSString *line = @"                           ";
    NSStringEncoding enc = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000);
    NSData *data = [line dataUsingEncoding:enc];
    [_printerData appendData:data];
    // 4.换行
    [self appendNewLine];
}

- (void)appendCutPaper{
    Byte bytes[] = {0x1D,0x56,0x41,0x00}; 
    [_printerData appendBytes:bytes length:sizeof(bytes)];
}

- (void)appendFooter:(NSString *)footerInfo{
    if (!footerInfo || footerInfo.length == 0) {
//        footerInfo = @"谢谢惠顾，欢迎下次光临！";
        return;
    }
    [self appendSeperatorLine];
    [self appendText:footerInfo alignment:HLTextAlignmentCenter];
    [self appendNewLine];
}

/** get final data */
- (NSData *)getFinalData{
    return _printerData;
}


#pragma mark - ***** page width auto adjust ******

@end

@implementation MKPageWidthConfig
- (void)setupConfigWith:(NSInteger)width{
    if (width == 58) {
        self.lineStr = @"- - - - - - - - - - - - - - - -";
        self.offsetAryfor3Text = [NSArray arrayWithObjects:@(150), @(300), nil];
        self.offsetAryfor4Text = [NSArray arrayWithObjects:@(140), @(220), @(300), nil];
        self.virtualWidth = 30;
    }else{
        self.lineStr = @"- - - - - - - - - - - - - - - - - - - - - - - -";
        self.offsetAryfor3Text = [NSArray arrayWithObjects:@(240), @(480), nil];
        self.offsetAryfor4Text = [NSArray arrayWithObjects:@(280), @(380), @(470), nil];
        self.virtualWidth = 46;
    }
}

@end
