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
        NSURL *htmlURL = [[NSBundle bundleWithIdentifier:kPluginBundleId] URLForResource:@"template" withExtension:@"html"];
        NSMutableString *previewHtml = [NSMutableString stringWithContentsOfURL:htmlURL encoding:NSUTF8StringEncoding error:NULL];
        
        NSURL *URL = (__bridge NSURL *)url;
        NSString *name = [[[URL absoluteString] lastPathComponent] stringByRemovingPercentEncoding];
        
        NSString *error;
        NSPropertyListFormat format;
        NSDictionary *contentDict = [NSPropertyListSerialization propertyListWithData:[NSData dataWithContentsOfURL:URL] options:0 format:&format error:&error];
        
        NSMutableDictionary *previewReplacement = [[NSMutableDictionary alloc] init];
        previewReplacement[@"__Name_Value__"] = name;
        previewReplacement[@"__Scopes__"] = @"Scopes";
        previewReplacement[@"__Scopes_Value__"] = [(NSArray *)(contentDict[@"RawQueryDict"][@"SearchScopes"]) componentsJoinedByString:@", "];
        previewReplacement[@"__Query__"] = @"Query";
        previewReplacement[@"__Query_Value__"] = contentDict[@"RawQueryDict"][@"RawQuery"];
        
        NSDictionary *properties = @{(__bridge NSString *)kQLPreviewPropertyTextEncodingNameKey : @"UTF-8",
                                     (__bridge NSString *)kQLPreviewPropertyMIMETypeKey : @"text/html" };

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
