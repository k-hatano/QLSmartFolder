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
        
        NSString *queryString = [((NSString *)contentDict[@"RawQueryDict"][@"RawQuery"]) stringByReplacingOccurrencesOfString:@"kMDItem" withString:@""];
        
        NSArray *criteriaSlices = contentDict[@"SearchCriteria"][@"FXCriteriaSlices"];
        NSMutableArray *attributes = [[NSMutableArray alloc] init];
        NSMutableDictionary *criteriaTable = [[NSMutableDictionary alloc] init];
        for (NSDictionary *criteriaSlice in criteriaSlices) {
            NSArray *criteriaArray = (criteriaSlice[@"criteria"]);
            NSString *originalCriteria = [((NSString *)criteriaArray[0]) stringByReplacingOccurrencesOfString:@"kMDItem" withString:@""];
            NSString *newCriteria = [[[originalCriteria substringToIndex:1] lowercaseString] stringByAppendingString:[originalCriteria substringFromIndex:1]];
            [attributes addObject:newCriteria];
            
            criteriaTable[originalCriteria] = newCriteria;
        }
        
        for (NSString *key in criteriaTable) {
            queryString = [queryString stringByReplacingOccurrencesOfString:key withString:criteriaTable[key]];
        }
        
        NSMutableDictionary *previewReplacement = [[NSMutableDictionary alloc] init];
        previewReplacement[@"__Name_Value__"] = name;
        previewReplacement[@"__Scopes__"] = @"Scopes";
        previewReplacement[@"__Scopes_Value__"] = [(NSArray *)(contentDict[@"RawQueryDict"][@"SearchScopes"]) componentsJoinedByString:@", "];
        previewReplacement[@"__Query__"] = @"Query";
        previewReplacement[@"__Query_Value__"] = queryString;
        
        __block NSMutableArray *foundItems = [[NSMutableArray alloc] init];
        __block NSString *errorString = @"";
        __block BOOL searchFinished = NO;
        
        CSSearchQuery *query = [[CSSearchQuery alloc] initWithQueryString:queryString attributes:attributes];
        query.foundItemsHandler = ^(NSArray<CSSearchableItem *> * _Nonnull items) {
            [foundItems addObjectsFromArray:items];
        };
        query.completionHandler = ^(NSError * _Nullable error) {
            errorString = [error description] ?: @"";
            searchFinished = YES;
        };
        [query start];
        
        NSInteger i = 0;
        while ([query foundItemCount] < 10 && i < 100 && ![query isCancelled] && !searchFinished) {
            [NSThread sleepForTimeInterval:0.1f];
            i++;
        }
        
        [previewHtml appendFormat:@"<table><tr><th>%ld Files</th></tr>", (long)[query foundItemCount]];
        for (CSSearchableItem *item in foundItems) {
            [previewHtml appendFormat:@"<table><tr><td>%@</td></tr>", [item uniqueIdentifier]];
        }
        [previewHtml appendString:@"</table>"];
        [previewHtml appendString:errorString];
        
        NSDictionary *properties = @{(__bridge NSString *)kQLPreviewPropertyTextEncodingNameKey : @"UTF-8",
                                     (__bridge NSString *)kQLPreviewPropertyMIMETypeKey : @"text/html" };

        for (NSString *key in previewReplacement) {
            [previewHtml replaceOccurrencesOfString:key
                                         withString:previewReplacement[key]
                                            options:0
                                              range:NSMakeRange(0, [previewHtml length])];
        }
        
        [query cancel];
        
        QLPreviewRequestSetDataRepresentation(preview, (__bridge CFDataRef)[previewHtml dataUsingEncoding:NSUTF8StringEncoding], kUTTypeHTML, (__bridge CFDictionaryRef)properties);
    }
    
    return noErr;
}

void CancelPreviewGeneration(void *thisInterface, QLPreviewRequestRef preview)
{
    // Implement only if supported
}
