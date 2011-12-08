#import <CoreText/CoreText.h>
#import "PDFCoreTextParser.h"

#pragma mark 

@interface PDFCoreTextParser ()

#pragma mark - Text showing

// Text-showing operators
void PDFCoreTextParser_Tj(CGPDFScannerRef scanner, void *info);
void PDFCoreTextParser_quot(CGPDFScannerRef scanner, void *info);
void PDFCoreTextParser_doubleQuot(CGPDFScannerRef scanner, void *info);
void PDFCoreTextParser_TJ(CGPDFScannerRef scanner, void *info);

#pragma mark Text positioning

// Text-positioning operators
void PDFCoreTextParser_Td(CGPDFScannerRef scanner, void *info);
void PDFCoreTextParser_TD(CGPDFScannerRef scanner, void *info);
void PDFCoreTextParser_Tm(CGPDFScannerRef scanner, void *info);
void PDFCoreTextParser_TStar(CGPDFScannerRef scanner, void *info);

#pragma mark Text state

// Text state operators
void PDFCoreTextParser_BT(CGPDFScannerRef scanner, void *info);
void PDFCoreTextParser_Tc(CGPDFScannerRef scanner, void *info);
void PDFCoreTextParser_Tw(CGPDFScannerRef scanner, void *info);
void PDFCoreTextParser_Tz(CGPDFScannerRef scanner, void *info);
void PDFCoreTextParser_TL(CGPDFScannerRef scanner, void *info);
void PDFCoreTextParser_Tf(CGPDFScannerRef scanner, void *info);
void PDFCoreTextParser_Ts(CGPDFScannerRef scanner, void *info);

#pragma mark Graphics state

// Special graphics state operators
void PDFCoreTextParser_q(CGPDFScannerRef scanner, void *info);
void PDFCoreTextParser_Q(CGPDFScannerRef scanner, void *info);
void PDFCoreTextParser_cm(CGPDFScannerRef scanner, void *info);

@property (nonatomic, retain) Selection *currentSelection;
@property (nonatomic, readonly) RenderingState *currentRenderingState;
@property (nonatomic, readonly) Font *currentFont;
@property (nonatomic, readonly) CGPDFDocumentRef pdfDocument;
@property (nonatomic, copy) NSURL *documentURL;

/* Returts the operator callbacks table for scanning page stream */
@property (nonatomic, readonly) CGPDFOperatorTableRef operatorTable;

@end

#pragma mark

@implementation PDFCoreTextParser

#pragma mark - Initialization

- (id)initWithDocument:(CGPDFDocumentRef)document
{
	if ((self = [super init]))
	{
		pdfDocument = CGPDFDocumentRetain(document);
	}
	return self;
}

- (id)initWithContentsOfFile:(NSString *)path
{
	if ((self = [super init]))
	{
		self.documentURL = [NSURL fileURLWithPath:path];
	}
	return self;
}

#pragma mark Scanner state accessors

- (RenderingState *)currentRenderingState
{
	return [self.renderingStateStack topRenderingState];
}

- (Font *)currentFont
{
	return self.currentRenderingState.font;
}

- (CGPDFDocumentRef)pdfDocument
{
	if (!pdfDocument)
	{
		pdfDocument = CGPDFDocumentCreateWithURL((CFURLRef)self.documentURL);
	}
	return pdfDocument;
}

/* The operator table used for scanning PDF pages */
- (CGPDFOperatorTableRef)operatorTable
{
	if (operatorTable)
	{
		return operatorTable;
	}
	
	operatorTable = CGPDFOperatorTableCreate();

	// Text-showing operators
	CGPDFOperatorTableSetCallback(operatorTable, "Tj", PDFCoreTextParser_Tj);
	CGPDFOperatorTableSetCallback(operatorTable, "\'", PDFCoreTextParser_quot);
	CGPDFOperatorTableSetCallback(operatorTable, "\"", PDFCoreTextParser_doubleQuot);
	CGPDFOperatorTableSetCallback(operatorTable, "TJ", PDFCoreTextParser_TJ);
	
	// Text-positioning operators
	CGPDFOperatorTableSetCallback(operatorTable, "Tm", PDFCoreTextParser_Tm);
	CGPDFOperatorTableSetCallback(operatorTable, "Td", PDFCoreTextParser_Td);		
	CGPDFOperatorTableSetCallback(operatorTable, "TD", PDFCoreTextParser_TD);
	CGPDFOperatorTableSetCallback(operatorTable, "T*", PDFCoreTextParser_TStar);
	
	// Text state operators
	CGPDFOperatorTableSetCallback(operatorTable, "Tw", PDFCoreTextParser_Tw);
	CGPDFOperatorTableSetCallback(operatorTable, "Tc", PDFCoreTextParser_Tc);
	CGPDFOperatorTableSetCallback(operatorTable, "TL", PDFCoreTextParser_TL);
	CGPDFOperatorTableSetCallback(operatorTable, "Tz", PDFCoreTextParser_Tz);
	CGPDFOperatorTableSetCallback(operatorTable, "Ts", PDFCoreTextParser_Ts);
	CGPDFOperatorTableSetCallback(operatorTable, "Tf", PDFCoreTextParser_Tf);
	
	// Graphics state operators
	CGPDFOperatorTableSetCallback(operatorTable, "cm", PDFCoreTextParser_cm);
	CGPDFOperatorTableSetCallback(operatorTable, "q", PDFCoreTextParser_q);
	CGPDFOperatorTableSetCallback(operatorTable, "Q", PDFCoreTextParser_Q);
	
	CGPDFOperatorTableSetCallback(operatorTable, "BT", PDFCoreTextParser_BT);
	
	return operatorTable;
}

/* Create a font dictionary given a PDF page */
- (FontCollection *)fontCollectionWithPage:(CGPDFPageRef)page
{
	CGPDFDictionaryRef dict = CGPDFPageGetDictionary(page);
	if (!dict)
	{
		NSLog(@"Scanner: fontCollectionWithPage: page dictionary missing");
		return nil;
	}
	CGPDFDictionaryRef resources;
	if (!CGPDFDictionaryGetDictionary(dict, "Resources", &resources))
	{
		NSLog(@"Scanner: fontCollectionWithPage: page dictionary missing Resources dictionary");
		return nil;	
	}
	CGPDFDictionaryRef fonts;
	if (!CGPDFDictionaryGetDictionary(resources, "Font", &fonts)) return nil;
	FontCollection *collection = [[FontCollection alloc] initWithFontDictionary:fonts];
	return [collection autorelease];
}

/* Scan the given page of the current document */
- (void)scanDocumentPage:(NSUInteger)pageNumber
{
	CGPDFPageRef page = CGPDFDocumentGetPage(self.pdfDocument, pageNumber);
    [self scanPage:page];
}

#pragma mark Start scanning

- (void)scanPage:(CGPDFPageRef)page
{
	// Return immediately if no keyword set
	if (!keyword) return;
    
    [self.stringDetector reset];
    self.stringDetector.keyword = self.keyword;

    // Initialize font collection (per page)
	self.fontCollection = [self fontCollectionWithPage:page];
    
	CGPDFContentStreamRef content = CGPDFContentStreamCreateWithPage(page);
	CGPDFScannerRef scanner = CGPDFScannerCreate(content, self.operatorTable, self);
	CGPDFScannerScan(scanner);
	CGPDFScannerRelease(scanner); scanner = nil;
	CGPDFContentStreamRelease(content); content = nil;
}


#pragma mark StringDetectorDelegate

- (void)detector:(StringDetector *)detector didScanCharacter:(unichar)character
{
	RenderingState *state = [self currentRenderingState];
	CGFloat width = [self.currentFont widthOfCharacter:character withFontSize:state.fontSize];
	width /= 1000;
	width += state.characterSpacing;
	if (character == 32)
	{
		width += state.wordSpacing;
	}
	[state translateTextPosition:CGSizeMake(width, 0)];
}

- (void)detector:(StringDetector *)detector didStartMatchingString:(NSString *)string
{
	Selection *sel = [[Selection alloc] initWithStartState:self.currentRenderingState];
	self.currentSelection = sel;
	[sel release];
}

- (void)detector:(StringDetector *)detector foundString:(NSString *)needle
{	
	RenderingState *state = [[self renderingStateStack] topRenderingState];
	[self.currentSelection finalizeWithState:state];

	if (self.currentSelection)
	{
		[self.selections addObject:self.currentSelection];
		self.currentSelection = nil;
	}
}

#pragma mark - Scanner callbacks

void PDFCoreTextParser_BT(CGPDFScannerRef scanner, void *info)
{
	[[(PDFCoreTextParser *)info currentRenderingState] setTextMatrix:CGAffineTransformIdentity replaceLineMatrix:YES];
}

/* Pops the requested number of values, and returns the number of values popped */
// !!!: Make sure this is correct, then use it
int PDFCoreTextParser_popIntegers(CGPDFScannerRef scanner, CGPDFInteger *buffer, size_t length)
{
    bzero(buffer, length);
    CGPDFInteger value;
    int i = 0;
    while (i < length)
    {
        if (!CGPDFScannerPopInteger(scanner, &value)) break;
        buffer[i] = value;
        i++;
    }
    return i;
}

#pragma mark Text showing operators

void PDFCoreTextParser_didScanSpace(float value, PDFCoreTextParser *scanner)
{
    float width = [scanner.currentRenderingState convertToUserSpace:value];
    [scanner.currentRenderingState translateTextPosition:CGSizeMake(-width, 0)];
    if (abs(value) >= [scanner.currentRenderingState.font widthOfSpace])
    {
		if (scanner.rawTextContent)
		{
			[*scanner.rawTextContent appendString:@" "];
		}
        [scanner.stringDetector reset];
    }
}

/* Called any time the scanner scans a string */
void PDFCoreTextParser_didScanString(CGPDFStringRef pdfString, PDFCoreTextParser *scanner)
{
	NSString *string = [[scanner stringDetector] appendPDFString:pdfString withFont:[scanner currentFont]];
	
	if (scanner.rawTextContent)
	{
		[*scanner.rawTextContent appendString:string];
	}
}

/* Show a string */
void PDFCoreTextParser_Tj(CGPDFScannerRef scanner, void *info)
{
	CGPDFStringRef pdfString = nil;
	if (!CGPDFScannerPopString(scanner, &pdfString)) return;
	PDFCoreTextParser_didScanString(pdfString, info);
}

/* Equivalent to operator sequence [T*, Tj] */
void PDFCoreTextParser_quot(CGPDFScannerRef scanner, void *info)
{
	PDFCoreTextParser_TStar(scanner, info);
	PDFCoreTextParser_Tj(scanner, info);
}

/* Equivalent to the operator sequence [Tw, Tc, '] */
void PDFCoreTextParser_doubleQuot(CGPDFScannerRef scanner, void *info)
{
	PDFCoreTextParser_Tw(scanner, info);
	PDFCoreTextParser_Tc(scanner, info);
	PDFCoreTextParser_quot(scanner, info);
}

/* Array of strings and spacings */
void PDFCoreTextParser_TJ(CGPDFScannerRef scanner, void *info)
{
	CGPDFArrayRef array = nil;
	CGPDFScannerPopArray(scanner, &array);
    size_t count = CGPDFArrayGetCount(array);
    
	for (int i = 0; i < count; i++)
	{
		CGPDFObjectRef object = nil;
		CGPDFArrayGetObject(array, i, &object);
		CGPDFObjectType type = CGPDFObjectGetType(object);

        switch (type)
        {
            case kCGPDFObjectTypeString:
            {
                CGPDFStringRef pdfString = nil;
                CGPDFObjectGetValue(object, kCGPDFObjectTypeString, &pdfString);
                PDFCoreTextParser_didScanString(pdfString, info);
                break;
            }
            case kCGPDFObjectTypeReal:
            {
                CGPDFReal tx = 0.0f;
                CGPDFObjectGetValue(object, kCGPDFObjectTypeReal, &tx);
                PDFCoreTextParser_didScanSpace(tx, info);
                break;
            }
            case kCGPDFObjectTypeInteger:
            {
                CGPDFInteger tx = 0L;
                CGPDFObjectGetValue(object, kCGPDFObjectTypeInteger, &tx);
                PDFCoreTextParser_didScanSpace(tx, info);
                break;
            }
            default:
                NSLog(@"Scanner: TJ: Unsupported type: %d", type);
                break;
        }
	}
}

#pragma mark Text positioning operators

/* Move to start of next line */
void PDFCoreTextParser_Td(CGPDFScannerRef scanner, void *info)
{
	CGPDFReal tx = 0, ty = 0;
	CGPDFScannerPopNumber(scanner, &ty);
	CGPDFScannerPopNumber(scanner, &tx);
	[[(PDFCoreTextParser *)info currentRenderingState] newLineWithLeading:-ty indent:tx save:NO];
}

/* Move to start of next line, and set leading */
void PDFCoreTextParser_TD(CGPDFScannerRef scanner, void *info)
{
	CGPDFReal tx, ty;
	if (!CGPDFScannerPopNumber(scanner, &ty)) return;
	if (!CGPDFScannerPopNumber(scanner, &tx)) return;
	[[(PDFCoreTextParser *)info currentRenderingState] newLineWithLeading:-ty indent:tx save:YES];
}

/* Set line and text matrixes */
void PDFCoreTextParser_Tm(CGPDFScannerRef scanner, void *info)
{
	CGPDFReal a, b, c, d, tx, ty;
	if (!CGPDFScannerPopNumber(scanner, &ty)) return;
	if (!CGPDFScannerPopNumber(scanner, &tx)) return;
	if (!CGPDFScannerPopNumber(scanner, &d)) return;
	if (!CGPDFScannerPopNumber(scanner, &c)) return;
	if (!CGPDFScannerPopNumber(scanner, &b)) return;
	if (!CGPDFScannerPopNumber(scanner, &a)) return;
	CGAffineTransform t = CGAffineTransformMake(a, b, c, d, tx, ty);
	[[(PDFCoreTextParser *)info currentRenderingState] setTextMatrix:t replaceLineMatrix:YES];
}

/* Go to start of new line, using stored text leading */
void PDFCoreTextParser_TStar(CGPDFScannerRef scanner, void *info)
{
	[[(PDFCoreTextParser *)info currentRenderingState] newLine];
}

#pragma mark Text State operators

/* Set character spacing */
void PDFCoreTextParser_Tc(CGPDFScannerRef scanner, void *info)
{
	CGPDFReal charSpace;
	if (!CGPDFScannerPopNumber(scanner, &charSpace)) return;
	[[(PDFCoreTextParser *)info currentRenderingState] setCharacterSpacing:charSpace];
}

/* Set word spacing */
void PDFCoreTextParser_Tw(CGPDFScannerRef scanner, void *info)
{
	CGPDFReal wordSpace;
	if (!CGPDFScannerPopNumber(scanner, &wordSpace)) return;
	[[(PDFCoreTextParser *)info currentRenderingState] setWordSpacing:wordSpace];
}

/* Set horizontal scale factor */
void PDFCoreTextParser_Tz(CGPDFScannerRef scanner, void *info)
{
	CGPDFReal hScale;
	if (!CGPDFScannerPopNumber(scanner, &hScale)) return;
	[[(PDFCoreTextParser *)info currentRenderingState] setHorizontalScaling:hScale];
}

/* Set text leading */
void PDFCoreTextParser_TL(CGPDFScannerRef scanner, void *info)
{
	CGPDFReal leading;
	if (!CGPDFScannerPopNumber(scanner, &leading)) return;
	[[(PDFCoreTextParser *)info currentRenderingState] setLeadning:leading];
}

/* Font and font size */
void PDFCoreTextParser_Tf(CGPDFScannerRef scanner, void *info)
{
	CGPDFReal fontSize;
	const char *fontName;
	if (!CGPDFScannerPopNumber(scanner, &fontSize)) return;
	if (!CGPDFScannerPopName(scanner, &fontName)) return;
	
	RenderingState *state = [(PDFCoreTextParser *)info currentRenderingState];
	Font *font = [[(PDFCoreTextParser *)info fontCollection] fontNamed:[NSString stringWithUTF8String:fontName]];
	[state setFont:font];
	[state setFontSize:fontSize];
}

/* Set text rise */
void PDFCoreTextParser_Ts(CGPDFScannerRef scanner, void *info)
{
	CGPDFReal rise;
	if (!CGPDFScannerPopNumber(scanner, &rise)) return;
	[[(PDFCoreTextParser *)info currentRenderingState] setTextRise:rise];
}


#pragma mark Graphics state operators

/* Push a copy of current rendering state */
void PDFCoreTextParser_q(CGPDFScannerRef scanner, void *info)
{
	RenderingStateStack *stack = [(PDFCoreTextParser *)info renderingStateStack];
	RenderingState *state = [[(PDFCoreTextParser *)info currentRenderingState] copy];
	[stack pushRenderingState:state];
	[state release];
}

/* Pop current rendering state */
void PDFCoreTextParser_Q(CGPDFScannerRef scanner, void *info)
{
	[[(PDFCoreTextParser *)info renderingStateStack] popRenderingState];
}

/* Update CTM */
void PDFCoreTextParser_cm(CGPDFScannerRef scanner, void *info)
{
	CGPDFReal a, b, c, d, tx, ty;
	if (!CGPDFScannerPopNumber(scanner, &ty)) return;
	if (!CGPDFScannerPopNumber(scanner, &tx)) return;
	if (!CGPDFScannerPopNumber(scanner, &d)) return;
	if (!CGPDFScannerPopNumber(scanner, &c)) return;
	if (!CGPDFScannerPopNumber(scanner, &b)) return;
	if (!CGPDFScannerPopNumber(scanner, &a)) return;
	
	RenderingState *state = [(PDFCoreTextParser *)info currentRenderingState];
	CGAffineTransform t = CGAffineTransformMake(a, b, c, d, tx, ty);
	state.ctm = CGAffineTransformConcat(state.ctm, t);
}


#pragma mark -
#pragma mark Memory management

- (RenderingStateStack *)renderingStateStack
{
	if (!renderingStateStack)
	{
		renderingStateStack = [[RenderingStateStack alloc] init];
	}
	return renderingStateStack;
}

- (StringDetector *)stringDetector
{
	if (!stringDetector)
	{
		stringDetector = [[StringDetector alloc] initWithKeyword:self.keyword];
		stringDetector.delegate = self;
	}
	return stringDetector;
}

- (NSMutableArray *)selections
{
	if (!selections)
	{
		selections = [[NSMutableArray alloc] init];
	}
	return selections;
}

- (void)dealloc
{
	CGPDFOperatorTableRelease(operatorTable);
	[currentSelection release];
	[fontCollection release];
	[renderingStateStack release];
	[keyword release]; keyword = nil;
	[stringDetector release];
	[documentURL release]; documentURL = nil;
	CGPDFDocumentRelease(pdfDocument); pdfDocument = nil;
	[super dealloc];
}

@synthesize documentURL, keyword, stringDetector, fontCollection, renderingStateStack, currentSelection, selections, rawTextContent;
@end
