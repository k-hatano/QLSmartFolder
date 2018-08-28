#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>
#include <QuickLook/QuickLook.h>

#include "Shared.h"

OSStatus GeneratePreviewForURL(void *thisInterface, QLPreviewRequestRef preview, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options);
void CancelPreviewGeneration(void *thisInterface, QLPreviewRequestRef preview);

/* -----------------------------------------------------------------------------
   Generate a preview for file

   This function's job is to create preview for designated file
   ----------------------------------------------------------------------------- */

OSStatus GeneratePreviewForURL(void *thisInterface, QLPreviewRequestRef preview, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options)
{
    @autoreleasepool {
        NSURL *imgURL = [[NSBundle bundleWithIdentifier:kPluginBundleId] URLForResource:@"smartFolderIcon" withExtension:@"png"];
        
        NSURL *htmlURL = [[NSBundle bundleWithIdentifier:kPluginBundleId] URLForResource:@"template" withExtension:@"html"];
        NSMutableString *previewHtml = [NSMutableString stringWithContentsOfURL:htmlURL encoding:NSUTF8StringEncoding error:NULL];
        
        NSURL *URL = (__bridge NSURL *)url;
        NSString *name = [[[URL absoluteString] lastPathComponent] stringByRemovingPercentEncoding];
        
        NSDictionary *urlAttributes = [URL resourceValuesForKeys:@[NSURLContentAccessDateKey] error:NULL];
        NSDate *lastAccessDate = urlAttributes[NSURLContentAccessDateKey];
        
        NSString *error;
        NSPropertyListFormat format;
        NSDictionary *contentDict = [NSPropertyListSerialization propertyListWithData:[NSData dataWithContentsOfURL:URL] options:0 format:&format error:&error];
        
        NSString *rawQueryString = contentDict[@"RawQueryDict"][@"RawQuery"];
        
        NSMutableString *queryString = [[NSMutableString alloc] init];
        
        NSArray *criteriaSlices = contentDict[@"SearchCriteria"][@"FXCriteriaSlices"];
        for (NSDictionary *criteriaSlice in criteriaSlices) {
            if ([queryString length] > 0) {
                [queryString appendString:@"&nbsp;&amp;&nbsp;"];
            }
            NSArray *displayValuesArray = (criteriaSlice[@"displayValues"]);
            NSString *displayValues = [displayValuesArray componentsJoinedByString:@" "];
            [queryString appendString:displayValues];
        }
        
        NSDictionary *scopesReplacement = @{ @"kMDQueryScopeHome": @"Home",
                                             @"kMDQueryScopeComputer": @"Computer",
                                             @"kMDQueryScopeNetwork": @"Network",
                                             @"kMDQueryScopeAllIndexed": @"All Indexed",
                                             @"kMDQueryScopeComputerIndexed": @"Computer Indexed",
                                             @"kMDQueryScopeNetworkIndexed": @"Network Indexed"
                                             };
        
        NSMutableArray *scopes = contentDict[@"RawQueryDict"][@"SearchScopes"];
        for (NSInteger i = 0; i < [scopes count]; i++) {
            for (NSString *key in scopesReplacement) {
                if ([scopes[i] isEqualToString:key]) {
                    scopes[i] = scopesReplacement[key];
                }
            }
        }
        
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"yyyy/MM/dd HH:mm:ss"];
        [formatter setTimeZone:[NSTimeZone systemTimeZone]];
        
        NSMutableDictionary *previewReplacement = [[NSMutableDictionary alloc] init];
        previewReplacement[@"__Name_Value__"] = name;
        previewReplacement[@"__Last_Access_Date__"] = @"Last Access Date";
        previewReplacement[@"__Last_Access_Date_Value__"] = [formatter stringFromDate:lastAccessDate];
        previewReplacement[@"__Scopes__"] = @"Scopes";
        previewReplacement[@"__Scopes_Value__"] = [scopes componentsJoinedByString:@", "];
        previewReplacement[@"__Query__"] = @"Query";
        previewReplacement[@"__Query_Value__"] = queryString;
        previewReplacement[@"__Raw_Query__"] = @"Raw&nbsp;Query";
        previewReplacement[@"__Raw_Query_Value__"] = rawQueryString;
        
        [previewHtml appendString:@"</table>"];
        
        NSData *imgData = [[NSData alloc] initWithContentsOfURL:imgURL];
        
        NSDictionary *properties = @{(__bridge NSString *)kQLPreviewPropertyTextEncodingNameKey : @"UTF-8",
                                     (__bridge NSString *)kQLPreviewPropertyMIMETypeKey : @"text/html",
                                     (__bridge NSString *)kQLPreviewPropertyAttachmentsKey : @{
                                             @"icon" : @{
                                                     (__bridge NSString*)kQLPreviewPropertyMIMETypeKey : @"image/png",
                                                     (__bridge NSString*)kQLPreviewPropertyAttachmentDataKey: imgData,
                                                     }
                                             }
                                     };

        for (NSString *key in previewReplacement) {
            [previewHtml replaceOccurrencesOfString:key
                                         withString:previewReplacement[key]
                                            options:0
                                              range:NSMakeRange(0, [previewHtml length])];
        }
        
        QLPreviewRequestSetDataRepresentation(preview, (__bridge CFDataRef)[previewHtml dataUsingEncoding:NSUTF8StringEncoding], kUTTypeHTML, (__bridge CFDictionaryRef)properties);
    }
    
    return noErr;
}

void CancelPreviewGeneration(void *thisInterface, QLPreviewRequestRef preview)
{
    // Implement only if supported
}
