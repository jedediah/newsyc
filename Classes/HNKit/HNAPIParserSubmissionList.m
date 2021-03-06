//
//  HNParserSubmissionList.m
//  newsyc
//
//  Created by Grant Paul on 3/12/11.
//  Copyright 2011 Xuzz Productions, LLC. All rights reserved.
//

#import "HNAPIParserSubmissionList.h"

#import "HNKit.h"
#import "XMLDocument.h"

@implementation HNAPIParserSubmissionList

- (id)parseString:(NSString *)string options:(NSDictionary *)options {
    XMLDocument *document = [[XMLDocument alloc] initWithHTMLData:[string dataUsingEncoding:NSUTF8StringEncoding]];
    NSMutableArray *result = [NSMutableArray array];
    
    // The first row is the HN header, which also uses a nested table.
    // Hardcoding around it is required to prevent crashing.
    // XXX: can this be done in a more change-friendly way?
    NSArray *submissions = [document elementsMatchingPath:@"//table//tr[position()>1]//td//table//tr"];
    
    // Token for the next page of items.
    NSString *more = nil;
    
    // Three rows are used per submission.
    for (int i = 0; i + 1 < [submissions count]; i += 3) {
        XMLElement *first = [submissions objectAtIndex:i];
        XMLElement *second = [submissions objectAtIndex:i + 1];
        
        // These have a number of edge cases (e.g. "discuss"),
        // so use sane default values in case of one of those.
        NSNumber *points = [NSNumber numberWithInt:0];
        NSNumber *comments = [NSNumber numberWithInt:0];
        
        NSString *title = nil;
        NSString *user = nil;
        NSNumber *identifier = nil;
        NSString *date = nil;
        NSString *href = nil;
        
        for (XMLElement *element in [first children]) {
            if ([[element attributeWithName:@"class"] isEqual:@"title"]) {
                for (XMLElement *element2 in [element children]) {
                    if ([[element2 tagName] isEqual:@"a"]) {
                        title = [element2 content];
                        href = [element2 attributeWithName:@"href"];
                        
                        // In "ask HN" posts, we need to extract the id (and fix the URL) here.
                        if ([href hasPrefix:@"item?id="]) {
                            identifier = [NSNumber numberWithInt:[[href substringFromIndex:[@"item?id=" length]] intValue]];
                            href = [NSString stringWithFormat:@"http://%@/%@", kHNWebsiteHost, href];
                        }
                    }
                }
            }
        }
        
        for (XMLElement *element in [second children]) {
            if ([[element attributeWithName:@"class"] isEqual:@"subtext"]) {
                NSString *content = [element content];
                
                // XXX: is there any better way of doing this?
                int start = [content rangeOfString:@"</a> "].location;
                if (start != NSNotFound) content = [content substringFromIndex:start + [@"</a> " length]];
                int end = [content rangeOfString:@" ago"].location;
                if (end != NSNotFound) date = [content substringToIndex:end];
                
                for (XMLElement *element2 in [element children]) {
                    NSString *content = [element2 content];
                    NSString *tag = [element2 tagName];
                    
                    if ([tag isEqual:@"a"]) {
                        if ([[element2 attributeWithName:@"href"] hasPrefix:@"user?id="]) {
                            user = content;
                        } else if ([[element2 attributeWithName:@"href"] hasPrefix:@"item?id="]) {
                            int end = [content rangeOfString:@" "].location;
                            if (end != NSNotFound) comments = [NSNumber numberWithInt:[[content substringToIndex:end] intValue]];
                            
                            identifier = [NSNumber numberWithInt:[[[element2 attributeWithName:@"href"] substringFromIndex:[@"item?id=" length]] intValue]];
                        }
                    } else if ([tag isEqual:@"span"]) {
                        int end = [content rangeOfString:@" "].location;
                        if (end != NSNotFound) points = [NSNumber numberWithInt:[[content substringToIndex:end] intValue]];
                    }
                }
            } else if ([[element attributeWithName:@"class"] isEqual:@"title"] && [[element content] isEqual:@"More"]) {
                more = [[element attributeWithName:@"href"] substringFromIndex:[@"x?fnid=" length]];
            }
        }
        
        // XXX: better sanity checks?
        if (user != nil && title != nil && identifier != nil) {
            NSMutableDictionary *item = [NSMutableDictionary dictionary];
            [item setObject:user forKey:@"user"];
            [item setObject:points forKey:@"points"];
            [item setObject:title forKey:@"title"];
            [item setObject:comments forKey:@"numchildren"];
            [item setObject:href forKey:@"url"];
            [item setObject:date forKey:@"date"];
            [item setObject:identifier forKey:@"identifier"];
            [result addObject:item];
        } else {
            NSLog(@"Bug: Ignoring unparsable submission (more link?).");
        }
    }
    
    [document release];
    
    NSMutableDictionary *item = [NSMutableDictionary dictionary];
    [item setObject:result forKey:@"children"];
    if (more != nil) [item setObject:more forKey:@"more"];
    return item;
}

@end
