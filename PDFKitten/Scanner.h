#import <Foundation/Foundation.h>
#import "StringDetector.h"
#import "FontCollection.h"
#import "RenderingState.h"
#import "Selection.h"

@interface Scanner : NSObject <StringDetectorDelegate> {
	NSURL *documentURL;
	NSString *keyword;
	CGPDFDocumentRef pdfDocument;
	CGPDFOperatorTableRef operatorTable;
	StringDetector *stringDetector;
	FontCollection *fontCollection;
	RenderingStateStack *renderingStateStack;
	Selection *currentSelection;
	NSMutableArray *selections;
	NSMutableString **rawTextContent;
    CGPoint documentPoint;
    BOOL findsPoint;
    void(^positiveHitTestBlock)(Selection *selection);
}

/* Initialize with a file path */
- (id)initWithContentsOfFile:(NSString *)path;

/* Initialize with a PDF document */
- (id)initWithDocument:(CGPDFDocumentRef)document;

/* Start scanning (synchronous) */
- (void)scanDocumentPage:(NSUInteger)pageNumber;

/* Start scanning a particular page */
- (void)scanPage:(CGPDFPageRef)page;

- (void)setHitTestPoint:(CGPoint)hitTestPoint;

@property (nonatomic, retain) NSMutableArray *selections;
@property (nonatomic, retain) RenderingStateStack *renderingStateStack;
@property (nonatomic, retain) FontCollection *fontCollection;
@property (nonatomic, retain) StringDetector *stringDetector;
@property (nonatomic, retain) NSString *keyword;
@property (nonatomic, assign) NSMutableString **rawTextContent;
@property (nonatomic, copy) void(^positiveHitTestBlock)(Selection *selection);
@end
