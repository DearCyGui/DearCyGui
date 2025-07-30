#!python
#cython: language_level=3
#cython: boundscheck=False
#cython: wraparound=False
#cython: nonecheck=False
#cython: embedsignature=False
#cython: cdivision=True
#cython: cdivision_warnings=False
#cython: always_allow_keywords=False
#cython: profile=False
#cython: infer_types=False
#cython: initializedcheck=False
#cython: c_line_in_traceback=False
#cython: auto_pickle=False
#cython: freethreading_compatible=True
#distutils: language=c++

cimport cython
from cython.operator cimport dereference
from cpython.ref cimport PyObject

from libc.stdint cimport uint8_t, int32_t, uint32_t, uint64_t
from libc.stdlib cimport malloc, free
from libc.string cimport memcpy, strlen, memset
from libcpp.cmath cimport floor, fmax, fmin
from libcpp.vector cimport vector
from libcpp.string cimport string, to_string
from libcpp.unordered_map cimport unordered_map

from .core cimport uiItem, Context, lock_gil_friendly, Viewport, baseFont, baseItem
from .c_types cimport DCGMutex, unique_lock, Vec2, Vec4, make_Vec2
from .imgui_types cimport unparse_color, parse_color
from .wrapper cimport imgui
from .layout cimport Layout

from .imgui cimport t_draw_line, t_draw_circle, t_draw_star, t_draw_rect

__all__ = ["MarkDownText"]

"""
MD4C Parser Callback Guarantees

The MD4C parser provides the following guarantees for callback sequences:

1. Nesting and Pairing:
   - For each enter_block call, there will be exactly one matching leave_block with the same type
   - For each enter_span call, there will be exactly one matching leave_span with the same type
   - Blocks and spans are properly nested (no overlapping boundaries)
   - All spans within a block are completely closed before the block is closed
   - Child blocks are completely processed before their parent block is closed

2. Order of Operations:
   - The parser processes the document in depth-first order
   - Text callbacks only occur between matching enter_span/leave_span calls or
     directly within a block (not between blocks)
   - When a span contains other spans, inner spans are fully processed before
     the outer span is closed

3. Context Guarantees:
   - Detail structures passed to callbacks are only valid during the callback
   - The parser ensures all text belongs to some block
   - Text is always processed in document order

4. Error Handling:
   - If a callback returns non-zero, parsing is immediately aborted
   - Memory allocation failures will abort parsing with a -1 return
   - If processing completes successfully, all blocks and spans are guaranteed to be closed

5. Other Guarantees:
   - MD_TEXT_BR and MD_TEXT_SOFTBR are not sent from blocks with verbatim output
     (MD_BLOCK_CODE or MD_BLOCK_HTML), where '\n' is part of the text itself
   - The dummy mark at the end ensures all real marks are properly processed

These guarantees make it safe to maintain a stack-based state machine for tracking
the document structure during parsing.

Block Type Nesting Rules:

1. Container Blocks (can contain other blocks):
   - MD_BLOCK_DOC: Can contain any block type (root container)
   - MD_BLOCK_QUOTE: Can contain any block type
   - MD_BLOCK_UL: Can only contain MD_BLOCK_LI blocks
   - MD_BLOCK_OL: Can only contain MD_BLOCK_LI blocks
   - MD_BLOCK_LI: Can contain any block type except another MD_BLOCK_LI directly
   - MD_BLOCK_TABLE: Contains only MD_BLOCK_THEAD and MD_BLOCK_TBODY
   - MD_BLOCK_THEAD/TBODY: Contain only MD_BLOCK_TR
   - MD_BLOCK_TR: Contains only MD_BLOCK_TH or MD_BLOCK_TD

2. Leaf Blocks (cannot contain other blocks):
   - MD_BLOCK_H: Header (both ATX and Setext)
   - MD_BLOCK_CODE: Code block (both indented and fenced)
   - MD_BLOCK_HTML: Raw HTML block
   - MD_BLOCK_P: Paragraph
   - MD_BLOCK_HR: Horizontal rule
   - MD_BLOCK_TH/TD: Table cells (they contain spans, not blocks)

Span Type Nesting Rules:

1. Non-nesting Spans (cannot contain other spans):
   - MD_SPAN_CODE: Code spans marked with backticks
   - MD_SPAN_LATEXMATH: Inline LaTeX math expressions
   - MD_SPAN_LATEXMATH_DISPLAY: Display LaTeX math blocks

2. Container Spans (can contain other spans with restrictions):
   - MD_SPAN_EM: Can contain any span type
   - MD_SPAN_STRONG: Can contain any span type
   - MD_SPAN_A: Can contain any span except another MD_SPAN_A
   - MD_SPAN_IMG: Alt text can contain any span
   - MD_SPAN_DEL: Can contain any span type
   - MD_SPAN_U: Can contain any span type
   - MD_SPAN_WIKILINK: Similar to links, cannot contain another wikilink
"""

# Forward declarations for MD4C structures and functions
cdef extern from "md4c.h" nogil:
    # MD4C block types
    ctypedef enum MD_BLOCKTYPE:
        MD_BLOCK_DOC = 0
        MD_BLOCK_QUOTE
        MD_BLOCK_UL
        MD_BLOCK_OL
        MD_BLOCK_LI
        MD_BLOCK_HR
        MD_BLOCK_H
        MD_BLOCK_CODE
        MD_BLOCK_HTML
        MD_BLOCK_P
        MD_BLOCK_TABLE
        MD_BLOCK_THEAD
        MD_BLOCK_TBODY
        MD_BLOCK_TR
        MD_BLOCK_TH
        MD_BLOCK_TD
    
    # MD4C span types
    ctypedef enum MD_SPANTYPE:
        MD_SPAN_EM = 0
        MD_SPAN_STRONG
        MD_SPAN_A
        MD_SPAN_IMG
        MD_SPAN_CODE
        MD_SPAN_DEL
        MD_SPAN_LATEXMATH
        MD_SPAN_LATEXMATH_DISPLAY
        MD_SPAN_WIKILINK
        MD_SPAN_U
    
    # MD4C text types
    ctypedef enum MD_TEXTTYPE:
        MD_TEXT_NORMAL = 0
        MD_TEXT_NULLCHAR
        MD_TEXT_BR
        MD_TEXT_SOFTBR
        MD_TEXT_ENTITY
        MD_TEXT_CODE
        MD_TEXT_HTML
        MD_TEXT_LATEXMATH

    # Alignment for table cells
    ctypedef enum MD_ALIGN:
        MD_ALIGN_DEFAULT = 0
        MD_ALIGN_LEFT
        MD_ALIGN_CENTER
        MD_ALIGN_RIGHT

    ctypedef unsigned MD_OFFSET
    ctypedef unsigned MD_SIZE
    
    # MD4C structures for block details
    ctypedef struct MD_ATTRIBUTE:
        const char* text
        MD_SIZE size
        const MD_TEXTTYPE* substr_types
        const MD_OFFSET* substr_offsets
    
    ctypedef struct MD_BLOCK_UL_DETAIL:
        int is_tight
        char mark # can be '*', '-', '+'
    
    ctypedef struct MD_BLOCK_OL_DETAIL:
        unsigned start
        int is_tight
        char mark_delimiter # ".", ")", '*', '-', '+'
    
    ctypedef struct MD_BLOCK_LI_DETAIL:
        int is_task
        char task_mark
        size_t task_mark_offset
    
    ctypedef struct MD_BLOCK_H_DETAIL:
        unsigned level
    
    ctypedef struct MD_BLOCK_CODE_DETAIL:
        MD_ATTRIBUTE info
        MD_ATTRIBUTE lang
        char fence_char

    ctypedef struct MD_BLOCK_TABLE_DETAIL:
        unsigned col_count
        unsigned head_row_count
        unsigned body_row_count

    ctypedef struct MD_BLOCK_TD_DETAIL:
        MD_ALIGN align
    
    # MD4C structures for span details
    ctypedef struct MD_SPAN_A_DETAIL:
        MD_ATTRIBUTE href
        MD_ATTRIBUTE title
        int is_autolink
    
    ctypedef struct MD_SPAN_IMG_DETAIL:
        MD_ATTRIBUTE src
        MD_ATTRIBUTE title

    ctypedef struct MD_SPAN_WIKILINK_DETAIL:
        MD_ATTRIBUTE target

    # Parser structure
    ctypedef struct MD_PARSER:
        unsigned abi_version
        unsigned flags
        int (*enter_block)(MD_BLOCKTYPE type, void* detail, void* userdata) noexcept
        int (*leave_block)(MD_BLOCKTYPE type, void* detail, void* userdata) noexcept
        int (*enter_span)(MD_SPANTYPE type, void* detail, void* userdata) noexcept
        int (*leave_span)(MD_SPANTYPE type, void* detail, void* userdata) noexcept
        int (*text)(MD_TEXTTYPE type, const char* text, MD_SIZE size, void* userdata) noexcept
        void (*debug_log)(const char* msg, void* userdata) noexcept
        void (*syntax)() noexcept
    
    # MD4C flags
    int MD_FLAG_COLLAPSEWHITESPACE
    int MD_FLAG_PERMISSIVEATXHEADERS
    int MD_FLAG_PERMISSIVEURLAUTOLINKS
    int MD_FLAG_PERMISSIVEEMAILAUTOLINKS
    int MD_FLAG_NOINDENTEDCODEBLOCKS
    int MD_FLAG_NOHTMLBLOCKS
    int MD_FLAG_NOHTMLSPANS
    int MD_FLAG_TABLES
    int MD_FLAG_STRIKETHROUGH
    int MD_FLAG_PERMISSIVEWWWAUTOLINKS
    int MD_FLAG_TASKLISTS
    int MD_FLAG_LATEXMATHSPANS
    int MD_FLAG_WIKILINKS
    int MD_FLAG_UNDERLINE
    int MD_FLAG_HARD_SOFT_BREAKS
    
    # Dialect constants
    int MD_DIALECT_COMMONMARK
    int MD_DIALECT_GITHUB
    
    # Main parsing function
    int md_parse(const char* text, MD_SIZE size, const MD_PARSER* parser, void* userdata) noexcept

cdef extern from * nogil:
    """
#ifdef __cplusplus
extern "C" {
#endif

#include "../thirdparty/md4c/src/md4c.c"

#ifdef __cplusplus
}
#endif
    """
    pass


# Text styling and layout structures
#---------------------------------

# Markdown Rendering Workflow and Concepts
# ---------------------------------------
# The Markdown rendering process follows these main stages:
#
# 1. PARSING: MD4C parses the raw markdown text into structural elements
#    - Using callback functions for blocks, spans, and text
#    - Building an element tree that represents the document structure
#
# 2. LAYOUT: Layout engine positions all elements with proper sizing
#    - Computing text dimensions and wrapping lines to fit available width
#    - Handling block indentation, spacing, and alignment
#    - Creating a visual hierarchy that reflects the document structure
#
# 3. RENDERING: Renderer draws the laid out content to screen
#    - Only rendering elements visible in the viewport
#    - Applying appropriate styling to each element type
#    - Handling interactive elements like links
#
# KEY CONCEPTS:
#
# - BLOCKS: Container elements that organize content vertically
#   Examples: paragraphs, headings, lists, blockquotes, code blocks
#   Blocks can contain other blocks or spans (MD_BLOCK_* types)
#
# - SPANS: Inline elements that modify text appearance within blocks
#   Examples: bold, italic, links, code, images
#   Spans apply styling to portions of text (MD_SPAN_* types)
#
# - TEXT: The actual content that is displayed
#   Can have different types (normal, line break, code, etc.)
#   Text is always contained within spans (MD_TEXT_* types)

# Parsing:
# We build a tree of elements representing the document structure.
# The goal is that each element has as many info attached such
# that it is easy to determine the layout, sizes, etc after.
#---------------------

cdef enum class MDTextType:
    MD_TEXT_NORMAL = 0
    MD_TEXT_EMPH = 1
    MD_TEXT_STRONG = 2
    MD_TEXT_STRIKETHROUGH = 4
    MD_TEXT_UNDERLINE = 8
    MD_TEXT_CODE = 16
    MD_TEXT_LINK = 32 # text with a link style
    MD_TEXT_MATH = 64 # LaTeX math style
    MD_TEXT_IMAGE = 128 # alt text style
    MD_TEXT_WIKILINK = 256 # Wiki link style
    MD_TEXT_HARD_BREAK = 512 # Hard line break after this text
    MD_TEXT_SOFT_BREAK = 1024 # Soft line break after this text

# A word in Markdown text
cdef struct MDParsedWord:
    string text            # The actual text content
    MDTextType type        # Type of text (normal, code, etc.)
    int level              # Heading level (1-6) if applicable

# Clone of some of the detail structures from MD4C
# We need to clone them as the MD_ATTRIBUTE structure
# references values which are freed after each callback call.

cdef struct MD_BLOCK_CODE_DETAIL_EXT:
    #string info            # Info string (language, etc.)   -> attr1
    #string lang            # Language for syntax highlighting -> attr2
    char fence_char        # Character used for fenced code blocks

cdef struct MD_SPAN_A_DETAIL_EXT:
    #string href            # Link URL -> attr1
    #string title           # Link title (tooltip text) -> attr2
    bint is_autolink

#cdef struct MD_SPAN_IMG_DETAIL_EXT:
#    string src            # Image source URL -> attr1
#    string title          # Image title (tooltip) -> attr2

#cdef struct MD_SPAN_WIKILINK_EXT:
#    string target -> attr1

cdef enum class MD_BLOCKTYPE_EXT:
    MD_BLOCK_DOC = MD_BLOCKTYPE.MD_BLOCK_DOC
    MD_BLOCK_QUOTE = MD_BLOCKTYPE.MD_BLOCK_QUOTE
    MD_BLOCK_UL = MD_BLOCKTYPE.MD_BLOCK_UL
    MD_BLOCK_OL = MD_BLOCKTYPE.MD_BLOCK_OL
    MD_BLOCK_LI = MD_BLOCKTYPE.MD_BLOCK_LI
    MD_BLOCK_HR = MD_BLOCKTYPE.MD_BLOCK_HR
    MD_BLOCK_H = MD_BLOCKTYPE.MD_BLOCK_H
    MD_BLOCK_CODE = MD_BLOCKTYPE.MD_BLOCK_CODE
    MD_BLOCK_HTML = MD_BLOCKTYPE.MD_BLOCK_HTML
    MD_BLOCK_P = MD_BLOCKTYPE.MD_BLOCK_P
    MD_BLOCK_TABLE = MD_BLOCKTYPE.MD_BLOCK_TABLE
    MD_BLOCK_THEAD = MD_BLOCKTYPE.MD_BLOCK_THEAD
    MD_BLOCK_TBODY = MD_BLOCKTYPE.MD_BLOCK_TBODY
    MD_BLOCK_TR = MD_BLOCKTYPE.MD_BLOCK_TR
    MD_BLOCK_TH = MD_BLOCKTYPE.MD_BLOCK_TH
    MD_BLOCK_TD = MD_BLOCKTYPE.MD_BLOCK_TD
    MD_TEXT # Just text
    MD_TEXT_URL # Text with an URL behind
    MD_IMAGE # Image block, with alternate text and title
    MD_WIKILINK # Wiki link block, with target
    MD_LATEX # Latex math block (not inline)


cdef union MDParsedBlockDetail:
    # Union to hold details for different block types
    MD_BLOCK_UL_DETAIL ul_detail
    MD_BLOCK_OL_DETAIL ol_detail
    MD_BLOCK_LI_DETAIL li_detail
    MD_BLOCK_H_DETAIL h_detail
    MD_BLOCK_CODE_DETAIL_EXT code_detail
    MD_BLOCK_TABLE_DETAIL table_detail
    MD_BLOCK_TD_DETAIL td_detail
    MD_SPAN_A_DETAIL_EXT link_detail

cdef struct MDParsedBlock:
    MD_BLOCKTYPE_EXT type       # Type of block (paragraph, heading, etc.)
    MDParsedBlockDetail detail  # Details for this block type
    # We store the strings of some of the details
    # into these to now have them in the union.
    string attr1  # Additional attribute 1 (e.g., language for code)
    string attr2  # Additional attribute 2 (e.g., title for links)
    # Either children is empty or words is empty.
    # in others words: words ? => no children
    # children ? => no words
    # This is to avoid ambiguity in the parser.
    # This is why we introduce the MD_TEXT type.
    vector[MDParsedBlock] children # Children in this block
    vector[MDParsedWord] words  # Words in this block. ONLY for MD_TEXT

# Parser state information
cdef struct MDParserInfo:
    vector[MDParsedBlock*] block_stack     # Stack of blocks being parsed
    MDTextType text_type                   # Current text type being parsed
    int current_heading_level              # Current heading level (1-6)
    vector[int] heading_stack              # Stack of heading levels
    vector[MDParsedWord] words        # Accumulated text that will be moved into a MD_TEXT
    bint last_had_break

cdef struct MDParser:
    MDParserInfo cur
    MDParsedBlock content  # Parsed content structure
    MDParsedBlock tmp_block # block for temporary storage

# Helper function to create a new MDParsedBlock
cdef void initialize_tmp_block(MDParser* parser, MD_BLOCKTYPE_EXT type) noexcept nogil:
    parser.tmp_block.children.clear()
    parser.tmp_block.words.clear()
    parser.tmp_block.attr1.clear()
    parser.tmp_block.attr2.clear()

    parser.tmp_block.type = type
    # Initialize details to 0
    memset(&parser.tmp_block.detail, 0, sizeof(MDParsedBlockDetail))

cdef int flush_text_buffer(MDParser* parser) noexcept nogil:
    """Create a text block from accumulated words if any exist"""
    # If there are no words, nothing to do
    if parser.cur.words.empty():
        return 0

    # Create a new text block
    initialize_tmp_block(parser, MD_BLOCKTYPE_EXT.MD_TEXT)

    # Move all words from the parser buffer to the text block
    # We use swap for efficiency to avoid copying each word
    parser.tmp_block.words.swap(parser.cur.words)

    # Add the text block to the current parent block
    cdef MDParsedBlock* parent
    if not parser.cur.block_stack.empty():
        parent = parser.cur.block_stack.back()
        parent.children.push_back(parser.tmp_block)
    else:
        # Add to root
        parser.content.children.push_back(parser.tmp_block)

    return 0

# Helper function to add the block to the stack
cdef int push_tmp_block(MDParser* parser) noexcept nogil:
    """Push tmp_block to the current block stack"""

    cdef MDParsedBlock* parent
    # Add this block to the appropriate parent
    if parser.cur.block_stack.empty():
        # This is a top-level block, add it to the content
        parser.content.children.push_back(parser.tmp_block)
        # Push the address of the newly added block to the stack
        parser.cur.block_stack.push_back(&parser.content.children.back())
    else:
        # Add as child of current block
        parent = parser.cur.block_stack.back()
        parent.children.push_back(parser.tmp_block)
        # Push the address of the newly added block to the stack
        parser.cur.block_stack.push_back(&parent.children.back())
    
    return 0

# Helper function to remove the current block from the stack
cdef int end_block(MDParser* parser) noexcept nogil:
    """Handle end of a block element"""
    assert not parser.cur.block_stack.empty() # md4c guarantees this

    if parser.cur.block_stack.back().type not in [MD_BLOCKTYPE_EXT.MD_TEXT, MD_BLOCKTYPE_EXT.MD_TEXT_URL, MD_BLOCKTYPE_EXT.MD_IMAGE, MD_BLOCKTYPE_EXT.MD_WIKILINK, MD_BLOCKTYPE_EXT.MD_LATEX]:
        parser.cur.last_had_break = True

    # Flush any accumulated text before leaving the block
    flush_text_buffer(parser)

    parser.cur.block_stack.pop_back()
    return 0

# MD4C callback handlers
cdef int enter_block(MD_BLOCKTYPE type, void* detail, void* userdata) noexcept nogil:
    """Handle start of a block element"""
    cdef MDParser* parser = <MDParser*>userdata

    # Add accumulated text to current block before entering a new block
    flush_text_buffer(parser)

    initialize_tmp_block(parser, <MD_BLOCKTYPE_EXT>type)
    cdef MD_BLOCK_CODE_DETAIL* code_detail

    # Copy details based on block type
    if type == MD_BLOCK_UL and detail != NULL:
        parser.tmp_block.detail.ul_detail = dereference(<MD_BLOCK_UL_DETAIL*>detail)
        
    elif type == MD_BLOCK_OL and detail != NULL:
        parser.tmp_block.detail.ol_detail = dereference(<MD_BLOCK_OL_DETAIL*>detail)

    elif type == MD_BLOCK_LI and detail != NULL:
        parser.tmp_block.detail.li_detail = dereference(<MD_BLOCK_LI_DETAIL*>detail)

    elif type == MD_BLOCK_H and detail != NULL:
        parser.tmp_block.detail.h_detail = dereference(<MD_BLOCK_H_DETAIL*>detail)
        parser.cur.current_heading_level = parser.tmp_block.detail.h_detail.level
        parser.cur.heading_stack.push_back(parser.tmp_block.detail.h_detail.level)

    elif type == MD_BLOCK_CODE and detail != NULL:
        code_detail = <MD_BLOCK_CODE_DETAIL*>detail
        if code_detail.info.size > 0:
            parser.tmp_block.attr1 = string(code_detail.info.text, code_detail.info.size)

        if code_detail.lang.size > 0:
            parser.tmp_block.attr2 = string(code_detail.lang.text, code_detail.lang.size)

        parser.tmp_block.detail.code_detail.fence_char = code_detail.fence_char

    elif type == MD_BLOCK_TABLE and detail != NULL:
        parser.tmp_block.detail.table_detail = dereference(<MD_BLOCK_TABLE_DETAIL*>detail)

    elif type == MD_BLOCK_TD or type == MD_BLOCK_TH and detail != NULL:
        parser.tmp_block.detail.td_detail = dereference(<MD_BLOCK_TD_DETAIL*>detail)

    push_tmp_block(parser)

    return 0


cdef int leave_block(MD_BLOCKTYPE type, void* detail, void* userdata) noexcept nogil:
    """Handle end of a block element"""
    cdef MDParser* parser = <MDParser*>userdata
    end_block(parser)
    
    # Update heading level tracking if leaving a heading
    if type == MD_BLOCK_H:
        assert not parser.cur.heading_stack.empty() # md4c guarantees this
        parser.cur.heading_stack.pop_back()
        if parser.cur.heading_stack.empty():
            parser.cur.current_heading_level = 0
        else:
            parser.cur.current_heading_level = parser.cur.heading_stack.back()
    
    return 0

cdef int enter_span(MD_SPANTYPE type, void* detail, void* userdata) noexcept nogil:
    """Handle start of a span element"""
    cdef MDParser* parser = <MDParser*>userdata
    cdef MD_SPAN_A_DETAIL *a_detail
    cdef MD_SPAN_IMG_DETAIL *img_detail
    cdef MD_SPAN_WIKILINK_DETAIL *wikilink_detail

    # Update text style based on span type
    if type == MD_SPAN_EM:
        parser.cur.text_type = <MDTextType>(<int32_t>parser.cur.text_type | <int32_t>MDTextType.MD_TEXT_EMPH)
    elif type == MD_SPAN_STRONG:
        parser.cur.text_type = <MDTextType>(<int32_t>parser.cur.text_type | <int32_t>MDTextType.MD_TEXT_STRONG)
    elif type == MD_SPAN_CODE:
        parser.cur.text_type = <MDTextType>(<int32_t>parser.cur.text_type | <int32_t>MDTextType.MD_TEXT_CODE)
    elif type == MD_SPAN_DEL:
        parser.cur.text_type = <MDTextType>(<int32_t>parser.cur.text_type | <int32_t>MDTextType.MD_TEXT_STRIKETHROUGH)
    elif type == MD_SPAN_U:
        parser.cur.text_type = <MDTextType>(<int32_t>parser.cur.text_type | <int32_t>MDTextType.MD_TEXT_UNDERLINE)
    elif type == MD_SPAN_LATEXMATH: # Inline LaTeX math
        parser.cur.text_type = <MDTextType>(<int32_t>parser.cur.text_type | <int32_t>MDTextType.MD_TEXT_MATH)

    # For the remaining span types, we create special blocks
    elif type == MD_SPAN_A:
        parser.cur.text_type = <MDTextType>(<int32_t>parser.cur.text_type | <int32_t>MDTextType.MD_TEXT_LINK)
        assert detail != NULL
        
        a_detail = <MD_SPAN_A_DETAIL*>detail
        initialize_tmp_block(parser, MD_BLOCKTYPE_EXT.MD_TEXT_URL)
        if a_detail.href.size > 0:
            parser.tmp_block.attr1 = string(a_detail.href.text, a_detail.href.size)

        if a_detail.title.size > 0:
            parser.tmp_block.attr2 = string(a_detail.title.text, a_detail.title.size)

        parser.tmp_block.detail.link_detail.is_autolink = a_detail.is_autolink
        # Add the link block to the current block stack
        push_tmp_block(parser)
    elif type == MD_SPAN_IMG:
        parser.cur.text_type = <MDTextType>(<int32_t>parser.cur.text_type | <int32_t>MDTextType.MD_TEXT_IMAGE)
        assert detail != NULL
        
        img_detail = <MD_SPAN_IMG_DETAIL*>detail
        initialize_tmp_block(parser, MD_BLOCKTYPE_EXT.MD_IMAGE)
        if img_detail.src.size > 0:
            parser.tmp_block.attr1 = string(img_detail.src.text, img_detail.src.size)

        if img_detail.title.size > 0:
            parser.tmp_block.attr2 = string(img_detail.title.text, img_detail.title.size)

        # Add the image block to the current block stack
        push_tmp_block(parser)
    elif type == MD_SPAN_WIKILINK:
        parser.cur.text_type = <MDTextType>(<int32_t>parser.cur.text_type | <int32_t>MDTextType.MD_TEXT_WIKILINK)
        assert detail != NULL
        
        wikilink_detail = <MD_SPAN_WIKILINK_DETAIL*>detail
        initialize_tmp_block(parser, MD_BLOCKTYPE_EXT.MD_WIKILINK)
        if wikilink_detail.target.size > 0:
            parser.tmp_block.attr1 = string(wikilink_detail.target.text, wikilink_detail.target.size)

        # Add the wikilink block to the current block stack
        push_tmp_block(parser)    
    elif type == MD_SPAN_LATEXMATH_DISPLAY:
        parser.cur.text_type = <MDTextType>(<int32_t>parser.cur.text_type | <int32_t>MDTextType.MD_TEXT_MATH)
        # Display LaTeX math is treated like a block
        initialize_tmp_block(parser, MD_BLOCKTYPE_EXT.MD_LATEX)
        # Add the LaTeX block to the current block stack
        push_tmp_block(parser)

    else:
        assert False, "Unknown span type in enter_span"
    return 0

cdef int leave_span(MD_SPANTYPE type, void* detail, void* userdata) noexcept nogil:
    """Handle end of a span element"""
    cdef MDParser* parser = <MDParser*>userdata

    if not parser.cur.words.empty():
        parser.cur.last_had_break = (<int32_t>parser.cur.words.back().type & (<int32_t>MDTextType.MD_TEXT_HARD_BREAK | <int32_t>MDTextType.MD_TEXT_SOFT_BREAK)) != 0

    # Update text style based on span type being left
    if type == MD_SPAN_EM:
        parser.cur.text_type = <MDTextType>(<int32_t>parser.cur.text_type & ~<int32_t>MDTextType.MD_TEXT_EMPH)
    elif type == MD_SPAN_STRONG:
        parser.cur.text_type = <MDTextType>(<int32_t>parser.cur.text_type & ~<int32_t>MDTextType.MD_TEXT_STRONG)
    elif type == MD_SPAN_CODE:
        parser.cur.text_type = <MDTextType>(<int32_t>parser.cur.text_type & ~<int32_t>MDTextType.MD_TEXT_CODE)
    elif type == MD_SPAN_DEL:
        parser.cur.text_type = <MDTextType>(<int32_t>parser.cur.text_type & ~<int32_t>MDTextType.MD_TEXT_STRIKETHROUGH)
    elif type == MD_SPAN_U:
        parser.cur.text_type = <MDTextType>(<int32_t>parser.cur.text_type & ~<int32_t>MDTextType.MD_TEXT_UNDERLINE)
    elif type == MD_SPAN_LATEXMATH: # Inline LaTeX math
        parser.cur.text_type = <MDTextType>(<int32_t>parser.cur.text_type & ~<int32_t>MDTextType.MD_TEXT_MATH)

    # For the remaining span types, we pop the special block if it exists
    else:
        assert type in [MD_SPAN_A, MD_SPAN_IMG, MD_SPAN_LATEXMATH_DISPLAY, MD_SPAN_WIKILINK]
        end_block(parser)
        if type == MD_SPAN_A:
            parser.cur.text_type = <MDTextType>(<int32_t>parser.cur.text_type & ~<int32_t>MDTextType.MD_TEXT_LINK)
        elif type == MD_SPAN_IMG:
            parser.cur.text_type = <MDTextType>(<int32_t>parser.cur.text_type & ~<int32_t>MDTextType.MD_TEXT_IMAGE)
        elif type == MD_SPAN_LATEXMATH_DISPLAY:
            parser.cur.text_type = <MDTextType>(<int32_t>parser.cur.text_type & ~<int32_t>MDTextType.MD_TEXT_MATH)
        elif type == MD_SPAN_WIKILINK:
            parser.cur.text_type = <MDTextType>(<int32_t>parser.cur.text_type & ~<int32_t>MDTextType.MD_TEXT_WIKILINK)

    return 0

cdef int handle_text(MD_TEXTTYPE type, const char* text, MD_SIZE size, void* userdata) noexcept nogil:
    """Handle text content by breaking it into words and accumulating in the parser context"""
    cdef MDParser* parser = <MDParser*>userdata
    cdef MDParsedWord word
    cdef MD_OFFSET off = 0
    cdef MD_OFFSET word_start = 0
    
    # Handle special text types directly
    if type == MD_TEXTTYPE.MD_TEXT_NULLCHAR:
        # Ignore
        return 0
        
    elif type == MD_TEXTTYPE.MD_TEXT_BR:
        # Hard break / line jump / \n
        # Not generated for MD_TEXT_CODE and MD_TEXT_LATEXMATH
        if not parser.cur.words.empty() and \
           (<int32_t>parser.cur.words.back().type & <int32_t>MDTextType.MD_TEXT_HARD_BREAK) == 0:
            # Add the flag to the last word if it doesn't have the flag already
            parser.cur.words.back().type = <MDTextType>(<int32_t>parser.cur.words.back().type | 
                                                        <int32_t>MDTextType.MD_TEXT_HARD_BREAK)
        else:
            # create an empty word with this flag
            word.text.clear()
            word.type = <MDTextType>(<int32_t>parser.cur.text_type | <int32_t>MDTextType.MD_TEXT_HARD_BREAK)
            word.level = parser.cur.current_heading_level
            parser.cur.words.push_back(word)

        return 0
        
    elif type == MD_TEXTTYPE.MD_TEXT_SOFTBR:
        # Soft break / line continuation / space
        if parser.cur.words.empty():
            # create an empty word with this flag
            word.text.clear()
            word.type = <MDTextType>(<int32_t>parser.cur.text_type |
                                     <int32_t>MDTextType.MD_TEXT_SOFT_BREAK)
            word.level = parser.cur.current_heading_level
            parser.cur.words.push_back(word)
        else:
            # Add the flag to the last word
            parser.cur.words.back().type = <MDTextType>(<int32_t>parser.cur.words.back().type | 
                                                        <int32_t>MDTextType.MD_TEXT_SOFT_BREAK)
        return 0

    elif type & MD_TEXTTYPE.MD_TEXT_CODE:
        # for verbatim code text. Split at newlines
        off = 0
        word_start = 0

        while off < size:
            if text[off] == '\n':
                if off == word_start:
                    # Add an empty word for the newline
                    word.text.clear()
                elif off > word_start:
                    word.text.assign(text + word_start, off - word_start)
                word.type = <MDTextType>(<int32_t>MDTextType.MD_TEXT_CODE |
                                         <int32_t>MDTextType.MD_TEXT_HARD_BREAK)
                word.level = parser.cur.current_heading_level
                parser.cur.words.push_back(word)
                word_start = off + 1
            off += 1

        if word_start < size:
            # Add any remaining text after the last newline
            word.text.assign(text + word_start, size - word_start)
            word.type = MDTextType.MD_TEXT_CODE
            word.level = parser.cur.current_heading_level
            parser.cur.words.push_back(word)
        return 0

    elif type & MD_TEXTTYPE.MD_TEXT_LATEXMATH:
        # Same as MD_TEXT_CODE
        off = 0
        word_start = 0
        
        while off < size:
            if text[off] == '\n':
                if off == word_start:
                    # Add an empty word for the newline
                    word.text.clear()
                    word.type = <MDTextType>(<int32_t>MDTextType.MD_TEXT_MATH |
                                             <int32_t>MDTextType.MD_TEXT_HARD_BREAK)
                    word.level = parser.cur.current_heading_level
                    parser.cur.words.push_back(word)
                elif off > word_start:
                    word.text.assign(text + word_start, off - word_start)
                    word.type = <MDTextType>(<int32_t>MDTextType.MD_TEXT_MATH |
                                             <int32_t>MDTextType.MD_TEXT_HARD_BREAK)
                    word.level = parser.cur.current_heading_level
                    parser.cur.words.push_back(word)
                word_start = off + 1
            off += 1
        
        if word_start < size:
            # Add any remaining text after the last newline
            word.text.assign(text + word_start, size - word_start)
            word.type = MDTextType.MD_TEXT_MATH
            word.level = parser.cur.current_heading_level
            parser.cur.words.push_back(word)
        return 0

    # Process regular text by splitting into words
    off = 0
    word_start = 0

    # Special handling: beginning with a space
    if size > 0 and text[0] == ' ':
        # Add a soft break to the prevous word if it exists
        if not parser.cur.words.empty():
            parser.cur.words.back().type = <MDTextType>(<int32_t>parser.cur.words.back().type | 
                                                        <int32_t>MDTextType.MD_TEXT_SOFT_BREAK)
        elif not parser.cur.last_had_break:
            # In most of the cases, the previous block had a line break, but not always.
            word.text.clear()
            word.type = <MDTextType>(<int32_t>parser.cur.text_type |
                                     <int32_t>MDTextType.MD_TEXT_SOFT_BREAK)
            word.level = parser.cur.current_heading_level
            parser.cur.words.push_back(word)

        word_start = 1
        off = 1

    if <int32_t>parser.cur.text_type & <int32_t>MDTextType.MD_TEXT_LINK:
        # Do not split links (current limitation)
        # We assume the text is a single link, so we create a single word
        if word_start >= size:
            # No text to process
            return 0
        if word_start < size - 1 and text[size - 1] == ' ':
            # Remove trailing space if it exists
            size -= 1
            word.type = <MDTextType>(<int32_t>parser.cur.text_type | <int32_t>MDTextType.MD_TEXT_LINK | <int32_t>MDTextType.MD_TEXT_SOFT_BREAK)
        else:
            word.type = <MDTextType>(<int32_t>parser.cur.text_type | <int32_t>MDTextType.MD_TEXT_LINK)
        word.text.assign(text+word_start, size-word_start)
        word.level = parser.cur.current_heading_level
        parser.cur.words.push_back(word)
        return 0

    while off < size:
        if text[off] == ' ': # NOTE: we cannot get '\n', '\r', '\t' or extra spaces are they are handled by md4c
            # End of a word
            if word_start < off:
                word.text.assign(text + word_start, off - word_start)
                word.type = <MDTextType>(<int32_t>parser.cur.text_type |
                                         <int32_t>MDTextType.MD_TEXT_SOFT_BREAK)
                word.level = parser.cur.current_heading_level
                parser.cur.words.push_back(word)
            word_start = off + 1
        off += 1
    
    # Add the last word if any
    if word_start < off: # we have met at least one non-space character
        word.text.assign(text + word_start, off - word_start)
        word.type = parser.cur.text_type
        word.level = parser.cur.current_heading_level
        parser.cur.words.push_back(word)
    elif word_start == size: # Last element was a space
        # Append the soft break flag to the previous word
        if not parser.cur.words.empty():
            parser.cur.words.back().type = <MDTextType>(<int32_t>parser.cur.words.back().type | 
                                                        <int32_t>MDTextType.MD_TEXT_SOFT_BREAK)
        else:
            # No words (just a space). Create an empty word
            word.text.clear()
            word.type = <MDTextType>(<int32_t>parser.cur.text_type |
                                     <int32_t>MDTextType.MD_TEXT_SOFT_BREAK)
            word.level = parser.cur.current_heading_level
            parser.cur.words.push_back(word)
    return 0


# Layout and rendering.
# ---------------------
# After the parsing is done, we have a tree of blocks, with
# MD_TEXT blocks as leaves, containing words or text (code, math).
# For a given available width, and items to insert (image), we
# compute a set of lines to render.
# Then during rendering, we can skip lines that are not visible.


# using inline CPP to make it a real C++ type
cdef extern from * nogil:
    """
    enum class TextColorIndex {
        DEFAULT = 0,
        HEADING_1 = 1,
        HEADING_2 = 2,
        HEADING_3 = 3,
        HEADING_4 = 4,
        HEADING_5 = 5,
        HEADING_6 = 6,
        EMPH = 7,
        STRONG = 8,
        STRIKETHROUGH = 9,
        UNDERLINE = 10,
        CODE = 11,
        CODE_BACKGROUND = 12,
        LINK = 13,
        COUNT = 14  // Number of color indices
    };
    """
    enum class TextColorIndex:
        DEFAULT = 0
        HEADING_1 = 1
        HEADING_2 = 2
        HEADING_3 = 3
        HEADING_4 = 4
        HEADING_5 = 5
        HEADING_6 = 6
        EMPH = 7
        STRONG = 8
        STRIKETHROUGH = 9
        UNDERLINE = 10
        CODE = 11
        CODE_BACKGROUND = 12
        LINK = 13
        COUNT = 14 # Number of color indices

cdef inline TextColorIndex color_for_text_type(MDTextType type, int level) noexcept nogil:
    """
    Get the color index for a given text type.
    This is used to map text types to colors for rendering.
    """
    if level == 0:
        if <int32_t>type & <int32_t>MDTextType.MD_TEXT_LINK:
            return TextColorIndex.LINK
        if <int32_t>type & (<int32_t>MDTextType.MD_TEXT_CODE | <int32_t>MDTextType.MD_TEXT_MATH):
            return TextColorIndex.CODE
        if <int32_t>type & <int32_t>MDTextType.MD_TEXT_UNDERLINE:
            return TextColorIndex.UNDERLINE
        if <int32_t>type & <int32_t>MDTextType.MD_TEXT_STRIKETHROUGH:
            return TextColorIndex.STRIKETHROUGH
        if <int32_t>type & <int32_t>MDTextType.MD_TEXT_STRONG:
            return TextColorIndex.STRONG
        if <int32_t>type & <int32_t>MDTextType.MD_TEXT_EMPH:
            return TextColorIndex.EMPH
    elif level == 1:
        return TextColorIndex.HEADING_1
    elif level == 2:
        return TextColorIndex.HEADING_2
    elif level == 3:
        return TextColorIndex.HEADING_3
    elif level == 4:
        return TextColorIndex.HEADING_4
    elif level == 5:
        return TextColorIndex.HEADING_5
    elif level == 6:
        return TextColorIndex.HEADING_6

    return TextColorIndex.DEFAULT


cdef struct MDProcessedItem:
    # Words
    string text         # Processed text content
    MDTextType text_type
    float font_scale    # Font scale factor
    TextColorIndex color_index # Color index
    # Other items
    uint64_t uuid       # Item unique identifier. Can be index of attribute
    # Common properties
    int32_t item_type   # 0: words, 1: bullet (list item), 2: words (not justified), 3: horizontal rule, 4: uuid
    float x             # x offset relative to the left of the MarkDown item
    float width         # Cached width measurement
    float height        # Cached height measurement


# A line of text composed of items
cdef struct MDProcessedLine:
    vector[MDProcessedItem] items     # Text spans in this line
    float height                      # Line height (max of all spans)
    float y                             # Start y position (top) in layout

# only for the main blocks
cdef struct MDProcessedBlock:
    MD_BLOCKTYPE_EXT type  # Type of block (paragraph, heading, etc.)
    float x
    float ymin
    float ymax

cdef struct MDProcessedBlockDetail:
    MD_BLOCKTYPE_EXT type       # Type of block (paragraph, heading, etc.)
    MDParsedBlockDetail detail  # Details for this block type
    string attr1
    string attr2

cdef const uint32_t codepoint_A = ord('A')
cdef const uint32_t codepoint_Z = ord('Z')
cdef const uint32_t codepoint_a = ord('a')
cdef const uint32_t codepoint_z = ord('z')
cdef const uint32_t codepoint_0 = ord('0')
cdef const uint32_t codepoint_9 = ord('9')

cdef const uint32_t codepoint_A_bold = ord("\U0001D5D4")
cdef const uint32_t codepoint_a_bold = ord("\U0001D5EE")
cdef const uint32_t codepoint_0_bold = ord("\U0001D7CE")

cdef const uint32_t codepoint_A_italic = ord("\U0001D434")
cdef const uint32_t codepoint_a_italic = ord("\U0001D44E")

cdef const uint32_t codepoint_A_bitalic = ord("\U0001D468")
cdef const uint32_t codepoint_a_bitalic = ord("\U0001D482")

cdef const uint32_t codepoint_A_mono = ord("\U0001D670")
cdef const uint32_t codepoint_a_mono = ord("\U0001D68A")
cdef const uint32_t codepoint_0_mono = ord("\U0001D7F6")
cdef const uint32_t codepoint_basic_pua = ord("\U0000E000")  # See font.pyx

cdef bint[255] in_pua_table
_mono_symbols = " ()[]{}<>|\\`~!@#$%^&*_-+=:;\"'?,./"
cdef int i_pua
for i_pua in range(255):
    if chr(i_pua) in _mono_symbols:
        in_pua_table[i_pua] = True

cdef inline bint in_pua(uint32_t codepoint) nogil:
    if codepoint >= 255:
        return False
    return in_pua_table[codepoint]


# Main Markdown Text component
#--------------------------
cdef class MarkDownText(uiItem):
    """
    Markdown text component that renders formatted markdown content
    
    This component parses Markdown text using md4c, computes the layout,
    and renders it efficiently with caching to avoid unnecessary recomputation.

    * Experimental. API and rendering results may change in future minor versions. *
    """

    # Content
    cdef string _text
    cdef MDParser _parser
    cdef uint32_t[<int32_t>TextColorIndex.COUNT] _color_table # requested colors from the user. value of 1 means "use default color"
    
    # Layout
    cdef float _last_width
    cdef Vec2 _rect_size
    cdef vector[MDProcessedLine] _lines  # Processed lines for rendering, in order of increasing y position
    cdef vector[MDProcessedBlock] _blocks  # Processed blocks for rendering, in a topological order
    cdef vector[MDProcessedBlockDetail] _block_details # Details for selected blocks needed for rendering
    cdef PyObject *_applicable_font # font used for layout, baseFont
    cdef bint _last_is_soft_break # temporary data

    # Style configuration
    cdef float[7] _heading_scales  # Scale factors for h1-h6, h0 used for normal text

    # Inline items
    cdef unordered_map[uint64_t, PyObject*] _uuid_map  # Map of UUIDs to DCG objects (uiItem) for links, images, etc.
    cdef dict _uuid_dict # Same as above, but holds the Python reference. We split to avoid gil during rendering.

    def __cinit__(self, Context context, **kwargs):
        """Initialize the markdown component"""
        self.can_have_widget_child = True        # Children are shown if referenced by uuid in the markdown text
        self.state.cap.has_content_region = True # For children
        self.state.cap.can_be_clicked = True
        self.state.cap.can_be_hovered = True
        self.state.cap.can_be_dragged = True
        self._heading_scales = [1.0, 2.0, 1.75, 1.5, 1.375, 1.25, 1.125]
        self._color_table = [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]
        self._last_width = -1.0  # Initial width, will be set on first layout
    
    # Properties
    @property
    def heading_scales(self):
        """Get scaling factors for headings (h1-h6)"""
        return [self._heading_scales[1+i] for i in range(6)]
    
    @heading_scales.setter
    def heading_scales(self, scales):
        """Set scaling factors for headings"""
        cdef int32_t i
        if len(scales) > 6:
            raise ValueError("heading_scales must have maximum 6 elements (for h1-h6)")
        for i in range(6):
            self._heading_scales[1+i] = 1.
        for i in range(min(6, len(scales))):
            self._heading_scales[1+i] = float(scales[i])
        self._last_width = -1.0

    @property
    def color_headings(self):
        """
        Override colors for headings (h1-h6). None or missing items = auto
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        cdef uint32_t[6] heading_colors
        heading_colors[0] = self._color_table[<int32_t>TextColorIndex.HEADING_1]
        heading_colors[1] = self._color_table[<int32_t>TextColorIndex.HEADING_2]
        heading_colors[2] = self._color_table[<int32_t>TextColorIndex.HEADING_3]
        heading_colors[3] = self._color_table[<int32_t>TextColorIndex.HEADING_4]
        heading_colors[4] = self._color_table[<int32_t>TextColorIndex.HEADING_5]
        heading_colors[5] = self._color_table[<int32_t>TextColorIndex.HEADING_6]

        colors = []
        for i in range(6):
            if heading_colors[i] == 1:
                colors.append(None)  # Use default color
            else:
                colors.append(heading_colors[i])
        return colors

    @color_headings.setter
    def color_headings(self, colors):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        cdef uint32_t new_colors[6]
        cdef int32_t i
        for i in range(6):
            new_colors[i] = 1
        if colors is not None:
            if len(colors) > 6:
                raise ValueError("color_headings must have maximum 6 elements (for h1-h6)")
            for i in range(len(colors)):
                if colors[i] is None:
                    new_colors[i] = 1  # Use default color
                else:
                    new_colors[i] = parse_color(colors[i])
        self._color_table[<int32_t>TextColorIndex.HEADING_1] = new_colors[0]
        self._color_table[<int32_t>TextColorIndex.HEADING_2] = new_colors[1]
        self._color_table[<int32_t>TextColorIndex.HEADING_3] = new_colors[2]
        self._color_table[<int32_t>TextColorIndex.HEADING_4] = new_colors[3]
        self._color_table[<int32_t>TextColorIndex.HEADING_5] = new_colors[4]
        self._color_table[<int32_t>TextColorIndex.HEADING_6] = new_colors[5]

    @property
    def color_emph(self):
        """
        Override color for emphasized text (italics). None = auto
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)

        if self._color_table[<int32_t>TextColorIndex.EMPH] == 1:
            return None  # Use default color
        return <int>self._color_table[<int32_t>TextColorIndex.EMPH]

    @color_emph.setter
    def color_emph(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if value is None:
            self._color_table[<int32_t>TextColorIndex.EMPH] = 1  # default color
            return
        self._color_table[<int32_t>TextColorIndex.EMPH] = parse_color(value)

    @property
    def color_strong(self):
        """
        Override color for strong text (bold italics). None = auto
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)

        if self._color_table[<int32_t>TextColorIndex.STRONG] == 1:
            return None  # Use default color
        return <int>self._color_table[<int32_t>TextColorIndex.STRONG]

    @color_strong.setter
    def color_strong(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if value is None:
            self._color_table[<int32_t>TextColorIndex.STRONG] = 1  # default color
            return
        self._color_table[<int32_t>TextColorIndex.STRONG] = parse_color(value)

    @property
    def color_code(self):
        """
        Override color for code text (inline code and code blocks). None = auto
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)

        if self._color_table[<int32_t>TextColorIndex.CODE] == 1:
            return None  # Use default color
        return <int>self._color_table[<int32_t>TextColorIndex.CODE]

    @color_code.setter
    def color_code(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if value is None:
            self._color_table[<int32_t>TextColorIndex.CODE] = 1  # default code
            return
        self._color_table[<int32_t>TextColorIndex.CODE] = parse_color(value)

    @property
    def color_code_bg(self):
        """
        Override background color for code blocks. None = auto
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)

        if self._color_table[<int32_t>TextColorIndex.CODE_BACKGROUND] == 1:
            return None  # Use default color
        return <int>self._color_table[<int32_t>TextColorIndex.CODE_BACKGROUND]

    @color_code_bg.setter
    def color_code_bg(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if value is None:
            self._color_table[<int32_t>TextColorIndex.CODE_BACKGROUND] = 1  # default code
            return
        self._color_table[<int32_t>TextColorIndex.CODE_BACKGROUND] = parse_color(value)

    @property
    def color_strikethrough(self):
        """
        Override color for strikethrough. None = auto
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if self._color_table[<int32_t>TextColorIndex.STRIKETHROUGH] == 1:
            return None  # Use default color
        return <int>self._color_table[<int32_t>TextColorIndex.STRIKETHROUGH]

    @color_strikethrough.setter
    def color_strikethrough(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if value is None:
            self._color_table[<int32_t>TextColorIndex.STRIKETHROUGH] = 1  # default code
            return
        self._color_table[<int32_t>TextColorIndex.STRIKETHROUGH] = parse_color(value)

    @property
    def color_underline(self):
        """
        Override color for underline. None = auto
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if self._color_table[<int32_t>TextColorIndex.UNDERLINE] == 1:
            return None  # Use default color
        return <int>self._color_table[<int32_t>TextColorIndex.UNDERLINE]

    @color_underline.setter
    def color_underline(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if value is None:
            self._color_table[<int32_t>TextColorIndex.UNDERLINE] = 1  # default code
            return
        self._color_table[<int32_t>TextColorIndex.UNDERLINE] = parse_color(value)

    @property
    def value(self):
        """Get the markdown text content"""
        return self._text.decode('utf8')
    
    @value.setter
    def value(self, text): # TODO: SharedStr
        """Set markdown text and mark for reparsing"""
        if not isinstance(text, str):
            raise TypeError("value must be a string")
        new_value = text.encode('utf8')
        if <int32_t>self._text.size() == <int32_t>len(new_value) and bytes(self._text) == new_value:
            return  # No change, no need to reparse
        self._text = new_value
        # Reset parser state
        self._parser.cur.block_stack.clear()
        self._parser.cur.text_type = MDTextType.MD_TEXT_NORMAL
        self._parser.cur.current_heading_level = 0
        self._parser.cur.heading_stack.clear()
        self._parser.cur.words.clear()
        self._parser.cur.last_had_break = True
        self._parser.content.type = MD_BLOCKTYPE_EXT.MD_BLOCK_DOC
        self._parser.content.attr1.clear()
        self._parser.content.attr2.clear()
        self._parser.content.children.clear()
        self._parser.content.words.clear()
        # Reset layout state
        self._last_width = -1.0
        # Start parsing
        cdef MD_PARSER parser
        parser.abi_version = 0
        # not yet supported:
        # MD_FLAG_TASKLISTS | MD_FLAG_WIKILINKS | MD_FLAG_TABLES | MD_FLAG_LATEXMATHSPANS
        parser.flags = (MD_FLAG_COLLAPSEWHITESPACE | MD_FLAG_PERMISSIVEATXHEADERS |
                        MD_FLAG_PERMISSIVEURLAUTOLINKS | MD_FLAG_PERMISSIVEEMAILAUTOLINKS |
                        MD_FLAG_NOHTMLBLOCKS | MD_FLAG_NOHTMLSPANS |
                        MD_FLAG_STRIKETHROUGH |
                        MD_FLAG_PERMISSIVEWWWAUTOLINKS |
                        MD_FLAG_UNDERLINE)
        parser.enter_block = &enter_block
        parser.leave_block = &leave_block
        parser.enter_span = &enter_span
        parser.leave_span = &leave_span
        parser.text = &handle_text
        parser.debug_log = NULL  # No debug logging
        parser.syntax = NULL
        if md_parse(self._text.c_str(), self._text.size(), &parser, <void*>&self._parser) != 0:
            # Reset parser state
            self._parser.cur.block_stack.clear()
            self._parser.cur.text_type = MDTextType.MD_TEXT_NORMAL
            self._parser.cur.current_heading_level = 0
            self._parser.cur.heading_stack.clear()
            self._parser.cur.words.clear()
            self._parser.content.type = MD_BLOCKTYPE_EXT.MD_BLOCK_DOC
            self._parser.content.attr1.clear()
            self._parser.content.attr2.clear()
            self._parser.content.children.clear()
            self._parser.content.words.clear()
            raise RuntimeError("Failed to parse markdown text")
        # Free temporary parser state
        self._parser.cur.block_stack.clear()
        self._parser.cur.heading_stack.clear()
        self._parser.cur.words.clear()
        #self.debug_parser()

    cdef void debug_parser(self):
        """Print the complete status of the MDParser including the whole parse tree."""
        print("=== MDParser Debug Output ===")
        self._print_parser_state()
        print("\n=== Parse Tree ===")
        self._print_block(&self._parser.content, 0)
        print("=========================")

    cdef void _print_parser_state(self):
        """Print the current state of the parser."""
        print(f"Current text type: {self._parser.cur.text_type}")
        print(f"Current heading level: {self._parser.cur.current_heading_level}")
        print(f"Block stack size: {self._parser.cur.block_stack.size()}")
        print(f"Heading stack size: {self._parser.cur.heading_stack.size()}")
        print(f"Pending words: {self._parser.cur.words.size()}")

    cdef void _print_block(self, MDParsedBlock* block, int depth):
        """Recursively print a block and its children."""
        indent = "  " * depth
        block_type = self._get_block_type_name(block.type)
        print(f"{indent}Block: {block_type}")
        
        # Print block details based on type
        if block.type == MD_BLOCKTYPE_EXT.MD_BLOCK_H:
            print(f"{indent}  Level: {block.detail.h_detail.level}")
        elif block.type == MD_BLOCKTYPE_EXT.MD_BLOCK_UL:
            print(f"{indent}  Is tight: {block.detail.ul_detail.is_tight}")
            print(f"{indent}  Mark: {chr(block.detail.ul_detail.mark)}")
        elif block.type == MD_BLOCKTYPE_EXT.MD_BLOCK_OL:
            print(f"{indent}  Start: {block.detail.ol_detail.start}")
            print(f"{indent}  Is tight: {block.detail.ol_detail.is_tight}")
            print(f"{indent}  Mark delimiter: {chr(block.detail.ol_detail.mark_delimiter)}")
        elif block.type == MD_BLOCKTYPE_EXT.MD_BLOCK_CODE:
            print(f"{indent}  Fence char: {chr(block.detail.code_detail.fence_char)}")
        elif block.type == MD_BLOCKTYPE_EXT.MD_TEXT_URL:
            print(f"{indent}  Is autolink: {block.detail.link_detail.is_autolink}")
        
        # Print attributes if present
        if not block.attr1.empty():
            print(f"{indent}  Attr1: {block.attr1.decode('utf-8', errors='replace')}")
        if not block.attr2.empty():
            print(f"{indent}  Attr2: {block.attr2.decode('utf-8', errors='replace')}")
        
        # Print words if this is a text block
        if block.words.size() > 0:
            print(f"{indent}  Words:")
            for i in range(block.words.size()):
                word_text = block.words[i].text.decode('utf-8', errors='replace')
                word_type = self._get_text_type_name(block.words[i].type)
                print(f"{indent}    '{word_text}' (Type: {word_type}, Level: {block.words[i].level})")
        
        # Print children recursively
        if block.children.size() > 0:
            print(f"{indent}  Children: {block.children.size()}")
            for i in range(block.children.size()):
                self._print_block(&block.children[i], depth + 2)

    def _get_block_type_name(self, MD_BLOCKTYPE_EXT type):
        """Convert block type enum to string representation."""
        type_names = {
            MD_BLOCKTYPE_EXT.MD_BLOCK_DOC: "DOC",
            MD_BLOCKTYPE_EXT.MD_BLOCK_QUOTE: "QUOTE",
            MD_BLOCKTYPE_EXT.MD_BLOCK_UL: "UL",
            MD_BLOCKTYPE_EXT.MD_BLOCK_OL: "OL",
            MD_BLOCKTYPE_EXT.MD_BLOCK_LI: "LI",
            MD_BLOCKTYPE_EXT.MD_BLOCK_HR: "HR",
            MD_BLOCKTYPE_EXT.MD_BLOCK_H: "H",
            MD_BLOCKTYPE_EXT.MD_BLOCK_CODE: "CODE",
            MD_BLOCKTYPE_EXT.MD_BLOCK_HTML: "HTML",
            MD_BLOCKTYPE_EXT.MD_BLOCK_P: "P",
            MD_BLOCKTYPE_EXT.MD_BLOCK_TABLE: "TABLE",
            MD_BLOCKTYPE_EXT.MD_BLOCK_THEAD: "THEAD",
            MD_BLOCKTYPE_EXT.MD_BLOCK_TBODY: "TBODY",
            MD_BLOCKTYPE_EXT.MD_BLOCK_TR: "TR",
            MD_BLOCKTYPE_EXT.MD_BLOCK_TH: "TH",
            MD_BLOCKTYPE_EXT.MD_BLOCK_TD: "TD",
            MD_BLOCKTYPE_EXT.MD_TEXT: "TEXT",
            MD_BLOCKTYPE_EXT.MD_TEXT_URL: "URL",
            MD_BLOCKTYPE_EXT.MD_IMAGE: "IMAGE",
            MD_BLOCKTYPE_EXT.MD_WIKILINK: "WIKILINK",
            MD_BLOCKTYPE_EXT.MD_LATEX: "LATEX",
        }
        return type_names.get(type, f"UNKNOWN({int(type)})")

    def _get_text_type_name(self, MDTextType type):
        """Convert text type enum to string representation."""
        type_values = []
        if <int32_t>type & <int32_t>MDTextType.MD_TEXT_EMPH:
            type_values.append("EMPH")
        if <int32_t>type & <int32_t>MDTextType.MD_TEXT_STRONG:
            type_values.append("STRONG")
        if <int32_t>type & <int32_t>MDTextType.MD_TEXT_STRIKETHROUGH:
            type_values.append("STRIKETHROUGH")
        if <int32_t>type & <int32_t>MDTextType.MD_TEXT_UNDERLINE:
            type_values.append("UNDERLINE")
        if <int32_t>type & <int32_t>MDTextType.MD_TEXT_CODE:
            type_values.append("CODE")
        if <int32_t>type & <int32_t>MDTextType.MD_TEXT_LINK:
            type_values.append("LINK")
        if <int32_t>type & <int32_t>MDTextType.MD_TEXT_MATH:
            type_values.append("MATH")
        if <int32_t>type & <int32_t>MDTextType.MD_TEXT_IMAGE:
            type_values.append("IMAGE")
        if <int32_t>type & <int32_t>MDTextType.MD_TEXT_WIKILINK:
            type_values.append("WIKILINK")
        if <int32_t>type & <int32_t>MDTextType.MD_TEXT_HARD_BREAK:
            type_values.append("HB")
        if <int32_t>type & <int32_t>MDTextType.MD_TEXT_SOFT_BREAK:
            type_values.append("SB")
        if not type_values:
            return "NORMAL"
        return "+".join(type_values)

    # Utf-8
    @cython.final
    cdef string _apply_text_styling(self, MDParsedWord* word, int32_t style_mask) noexcept nogil:
        """Apply styling to text based on text type and available glyphs."""
        cdef string result = string()
        
        # If no styling needed, return the original text
        if style_mask == 0:
            return word.text
            
        # UTF-8 decoding variables
        cdef size_t utf8_pos = 0
        cdef uint8_t utf8_byte
        cdef uint32_t utf8_codepoint
        cdef int remaining_bytes
        
        # Process each UTF-8 codepoint properly
        while utf8_pos < word.text.size():
            # Decode UTF-8 sequence
            utf8_byte = <uint8_t>word.text[utf8_pos]
            
            # Determine UTF-8 sequence length from first byte
            if (utf8_byte & 0x80) == 0:
                # ASCII character (0xxxxxxx)
                utf8_codepoint = utf8_byte
                remaining_bytes = 0
            elif (utf8_byte & 0xE0) == 0xC0:
                # 2-byte sequence (110xxxxx)
                utf8_codepoint = utf8_byte & 0x1F
                remaining_bytes = 1
            elif (utf8_byte & 0xF0) == 0xE0:
                # 3-byte sequence (1110xxxx)
                utf8_codepoint = utf8_byte & 0x0F
                remaining_bytes = 2
            elif (utf8_byte & 0xF8) == 0xF0:
                # 4-byte sequence (11110xxx)
                utf8_codepoint = utf8_byte & 0x07
                remaining_bytes = 3
            else:
                # Invalid UTF-8 sequence, skip this byte
                utf8_pos += 1
                continue
            
            # Read continuation bytes (10xxxxxx)
            utf8_pos += 1
            while remaining_bytes > 0 and utf8_pos < word.text.size():
                utf8_byte = <uint8_t>word.text[utf8_pos]
                if (utf8_byte & 0xC0) != 0x80:
                    # Invalid continuation byte
                    break
                utf8_codepoint = (utf8_codepoint << 6) | (utf8_byte & 0x3F)
                remaining_bytes -= 1
                utf8_pos += 1
            
            # Skip if we didn't read all continuation bytes
            if remaining_bytes > 0:
                continue
            
            # Now utf8_codepoint contains the full Unicode codepoint
            # Apply font style transformations based on the codepoint range
            self._append_styled_codepoint(&result, utf8_codepoint, style_mask)
        
        return result

    @cython.final
    cdef void _append_styled_codepoint(self, string* result, uint32_t codepoint, int32_t style_mask) noexcept nogil:
        """Apply styling to a single codepoint and append to the result string."""
        cdef uint32_t styled_codepoint = codepoint
        
        # Apply styles based on codepoint range
        if codepoint >= codepoint_A and codepoint <= codepoint_Z:
            if style_mask == <int32_t>(MDTextType.MD_TEXT_STRONG):
                styled_codepoint = codepoint - codepoint_A + codepoint_A_bold
                if imgui.GetFont().FindGlyph(styled_codepoint) != NULL:
                    self._append_utf8_codepoint(result, styled_codepoint)
                    return
            if style_mask == <int32_t>(MDTextType.MD_TEXT_EMPH):
                styled_codepoint = codepoint - codepoint_A + codepoint_A_italic
                if imgui.GetFont().FindGlyph(styled_codepoint) != NULL:
                    self._append_utf8_codepoint(result, styled_codepoint)
                    return
            if style_mask == <int32_t>MDTextType.MD_TEXT_STRONG | <int32_t>MDTextType.MD_TEXT_EMPH:
                styled_codepoint = codepoint - codepoint_A + codepoint_A_bitalic
                if imgui.GetFont().FindGlyph(styled_codepoint) != NULL:
                    self._append_utf8_codepoint(result, styled_codepoint)
                    return
            if style_mask & <int32_t>(MDTextType.MD_TEXT_CODE):
                styled_codepoint = codepoint - codepoint_A + codepoint_A_mono
                if imgui.GetFont().FindGlyph(styled_codepoint) != NULL:
                    self._append_utf8_codepoint(result, styled_codepoint)
                    return
        elif codepoint >= codepoint_a and codepoint <= codepoint_z:
            if style_mask == <int32_t>(MDTextType.MD_TEXT_STRONG):
                styled_codepoint = codepoint - codepoint_a + codepoint_a_bold
                if imgui.GetFont().FindGlyph(styled_codepoint) != NULL:
                    self._append_utf8_codepoint(result, styled_codepoint)
                    return
            if style_mask == <int32_t>(MDTextType.MD_TEXT_EMPH):
                styled_codepoint = codepoint - codepoint_a + codepoint_a_italic
                if imgui.GetFont().FindGlyph(styled_codepoint) != NULL:
                    self._append_utf8_codepoint(result, styled_codepoint)
                    return
            if style_mask == <int32_t>MDTextType.MD_TEXT_STRONG | <int32_t>MDTextType.MD_TEXT_EMPH:
                styled_codepoint = codepoint - codepoint_a + codepoint_a_bitalic
                if imgui.GetFont().FindGlyph(styled_codepoint) != NULL:
                    self._append_utf8_codepoint(result, styled_codepoint)
                    return
            if style_mask & <int32_t>(MDTextType.MD_TEXT_CODE):
                styled_codepoint = codepoint - codepoint_a + codepoint_a_mono
                if imgui.GetFont().FindGlyph(styled_codepoint) != NULL:
                    self._append_utf8_codepoint(result, styled_codepoint)
                    return
        elif style_mask == <int32_t>MDTextType.MD_TEXT_STRONG and codepoint >= codepoint_0 and codepoint <= codepoint_9:
            # Bold digits
            styled_codepoint = codepoint - codepoint_0 + codepoint_0_bold
            if imgui.GetFont().FindGlyph(styled_codepoint) != NULL:
                self._append_utf8_codepoint(result, styled_codepoint)
                return
        elif style_mask & <int32_t>(MDTextType.MD_TEXT_CODE):
            # code font has extended character set
            if codepoint >= codepoint_0 and codepoint <= codepoint_9:
                styled_codepoint = codepoint - codepoint_0 + codepoint_0_mono
                if imgui.GetFont().FindGlyph(styled_codepoint) != NULL:
                    self._append_utf8_codepoint(result, styled_codepoint)
                    return
            elif in_pua(codepoint):
                # If it's a PUA character and we are in code style, use the PUA mapping
                styled_codepoint = codepoint + codepoint_basic_pua
                if imgui.GetFont().FindGlyph(styled_codepoint) != NULL:
                    self._append_utf8_codepoint(result, styled_codepoint)
                    return

        # If no special glyph found or not in range for styling, use the original codepoint
        self._append_utf8_codepoint(result, codepoint)

    @cython.final
    cdef void _append_utf8_codepoint(self, string* result, uint32_t codepoint) noexcept nogil:
        """Append a Unicode codepoint to a string as UTF-8 bytes."""
        if codepoint <= 0x7F:
            # 1-byte sequence
            result[0] += <char>(codepoint & 0x7F)
        elif codepoint <= 0x7FF:
            # 2-byte sequence
            result[0] += <char>(0xC0 | ((codepoint >> 6) & 0x1F))
            result[0] += <char>(0x80 | (codepoint & 0x3F))
        elif codepoint <= 0xFFFF:
            # 3-byte sequence
            result[0] += <char>(0xE0 | ((codepoint >> 12) & 0x0F))
            result[0] += <char>(0x80 | ((codepoint >> 6) & 0x3F))
            result[0] += <char>(0x80 | (codepoint & 0x3F))
        else:
            # 4-byte sequence
            result[0] += <char>(0xF0 | ((codepoint >> 18) & 0x07))
            result[0] += <char>(0x80 | ((codepoint >> 12) & 0x3F))
            result[0] += <char>(0x80 | ((codepoint >> 6) & 0x3F))
            result[0] += <char>(0x80 | (codepoint & 0x3F))

    @cython.final
    cdef float _get_indentation(self, MDParsedBlock* block) noexcept nogil:
        """Get indentation for a block based on its type"""
        if block.type == MD_BLOCKTYPE_EXT.MD_BLOCK_CODE:
            return imgui.GetStyle().IndentSpacing
        elif block.type == MD_BLOCKTYPE_EXT.MD_BLOCK_QUOTE:
            return imgui.GetStyle().IndentSpacing
        elif block.type == MD_BLOCKTYPE_EXT.MD_BLOCK_UL or block.type == MD_BLOCKTYPE_EXT.MD_BLOCK_OL:
            return imgui.GetStyle().IndentSpacing
        return 0

    @cython.final
    cdef float _get_pre_vertical_spacing(self, MDParsedBlock* block) noexcept nogil:
        """Get vertical spacing before a block based on its type"""
        if block.type == MD_BLOCKTYPE_EXT.MD_BLOCK_P: # paragraph
            return 0.5 * imgui.GetTextLineHeight() # jump a line (half a line top and bottom)
        elif block.type == MD_BLOCKTYPE_EXT.MD_BLOCK_H: # heading
            return 0.5 * imgui.GetTextLineHeight()
        elif block.type == MD_BLOCKTYPE_EXT.MD_BLOCK_CODE: # code block
            return 0.5 * imgui.GetTextLineHeight()
        elif block.type == MD_BLOCKTYPE_EXT.MD_BLOCK_QUOTE: # quote block
            return 0.5 * imgui.GetTextLineHeight()
        elif block.type == MD_BLOCKTYPE_EXT.MD_BLOCK_UL or block.type == MD_BLOCKTYPE_EXT.MD_BLOCK_OL: # unordered or ordered list
            return 0.5 * imgui.GetTextLineHeight() #imgui.GetStyle().ItemSpacing.y
        elif block.type == MD_BLOCKTYPE_EXT.MD_BLOCK_HR: # horizontal rule
            return 0.5 * imgui.GetTextLineHeight()
        return 0

    @cython.final
    cdef float _get_post_vertical_spacing(self, MDParsedBlock* block) noexcept nogil:
        """Get vertical spacing after a block based on its type"""
        if block.type == MD_BLOCKTYPE_EXT.MD_BLOCK_P:
            return 0.5 * imgui.GetTextLineHeight() # jump a line (half a line top and bottom)
        elif block.type == MD_BLOCKTYPE_EXT.MD_BLOCK_H:
            return 0.5 * imgui.GetTextLineHeight()
        elif block.type == MD_BLOCKTYPE_EXT.MD_BLOCK_CODE:
            return 0.5 * imgui.GetTextLineHeight()
        elif block.type == MD_BLOCKTYPE_EXT.MD_BLOCK_QUOTE:
            return 0.5 * imgui.GetTextLineHeight()
        elif block.type == MD_BLOCKTYPE_EXT.MD_BLOCK_UL or block.type == MD_BLOCKTYPE_EXT.MD_BLOCK_OL:
            return 0.5 * imgui.GetTextLineHeight() #imgui.GetStyle().ItemSpacing.y
        elif block.type == MD_BLOCKTYPE_EXT.MD_BLOCK_HR:
            return 0.5 * imgui.GetTextLineHeight()
        return 0

    @cython.final
    cdef bint _block_should_end_line_before(self, MDParsedBlock* block) noexcept nogil:
        """Get if a block should end the current line before it."""
        if (block.type == MD_BLOCKTYPE_EXT.MD_BLOCK_CODE     # code
            or block.type == MD_BLOCKTYPE_EXT.MD_BLOCK_H     # heading
            or block.type == MD_BLOCKTYPE_EXT.MD_BLOCK_HR    # horizontal rule
            #or block.type == MD_BLOCKTYPE_EXT.MD_BLOCK_LI    # list item -> no because it has the marker before it on the same line
            or block.type == MD_BLOCKTYPE_EXT.MD_BLOCK_OL    # ordered list
            or block.type == MD_BLOCKTYPE_EXT.MD_BLOCK_P     # paragraph
            or block.type == MD_BLOCKTYPE_EXT.MD_BLOCK_QUOTE # quote
            or block.type == MD_BLOCKTYPE_EXT.MD_BLOCK_TABLE # table
            or block.type == MD_BLOCKTYPE_EXT.MD_BLOCK_UL):  # unordered list
            return True
        return False

    @cython.final
    cdef bint _block_should_end_line_after(self, MDParsedBlock* block) noexcept nogil:
        """Get if a block should end the current line when it is ended."""
        if (block.type == MD_BLOCKTYPE_EXT.MD_BLOCK_CODE     # code
            or block.type == MD_BLOCKTYPE_EXT.MD_BLOCK_H     # heading
            or block.type == MD_BLOCKTYPE_EXT.MD_BLOCK_HR    # horizontal rule
            or block.type == MD_BLOCKTYPE_EXT.MD_BLOCK_LI    # list item
            or block.type == MD_BLOCKTYPE_EXT.MD_BLOCK_OL    # ordered list
            or block.type == MD_BLOCKTYPE_EXT.MD_BLOCK_P     # paragraph
            or block.type == MD_BLOCKTYPE_EXT.MD_BLOCK_QUOTE # quote
            or block.type == MD_BLOCKTYPE_EXT.MD_BLOCK_TABLE # table
            or block.type == MD_BLOCKTYPE_EXT.MD_BLOCK_UL):  # unordered list
            return True
        return False

    @cython.final
    cdef bint _block_position_should_be_stored(self, MDParsedBlock* block) noexcept nogil:
        """Get if a block should be added to the blocks array."""
        if (block.type == MD_BLOCKTYPE_EXT.MD_BLOCK_CODE     # code
            or block.type == MD_BLOCKTYPE_EXT.MD_BLOCK_H     # heading
            or block.type == MD_BLOCKTYPE_EXT.MD_BLOCK_HR    # horizontal rule
            or block.type == MD_BLOCKTYPE_EXT.MD_BLOCK_QUOTE):  # quote
            return True
        return False

    ''' TODO: soft breaks, hyphenation, etc
    @cython.final
    cdef void _justify_line(self, MDProcessedLine* line) noexcept nogil:
        """Justify the current line by adjusting item positions."""
        cdef float available_width = self._last_width
        cdef int start_item = 0
        cdef float start_x = 0
        cdef int i
        
        if available_width <= 0 or line.items.size() <= 1:
            return  # Nothing to justify

        # Find first item to justify
        for i in range(<int>line.items.size()):
            # Only justify the section starting with words and items with UUID  
            if line.items[i].item_type in [0, 4]:
                start_item = i
                start_x = line.items[i].x
                break
        else:
            return  # No items to justify

        available_width = available_width - start_x
        cdef float current_width = line.items.back().x + line.items.back().width - start_x
        
        # Calculate extra space to distribute
        cdef float extra_space = available_width - current_width
        if extra_space <= 0:
            return  # No extra space to distribute

        # Calculate space per item
        cdef float space_per_item = floor(extra_space / (line.items.size() - 1))

        # Adjust item positions
        for i in range(start_item, <int>line.items.size() - 1):
            line.items[i].x += space_per_item * (i - start_item)
        # Distribute any remaining space to the last item
        if <int>line.items.size() > start_item:
            line.items.back().x = available_width - line.items.back().width
    '''

    @cython.final
    cdef void _finish_line(self, float extra_height, bint justify) noexcept nogil:
        """Finish the current line and move to the next one."""
        cdef float y = 0.
        cdef int32_t i

        if not self._lines.empty():
            # Compute line height
            for i in range(<int>self._lines.back().items.size()):
                self._lines.back().height = max(self._lines.back().height, self._lines.back().items[i].height)
            # Move y cursor for next line
            y = self._lines.back().y + self._lines.back().height
            # if the line is empty, skip it (but use its y)
            if self._lines.back().items.empty():
                self._lines.pop_back()
            #elif justify:
            #    # Apply justification
            #    self._justify_line(&self._lines.back())

        y += extra_height # extra height is not accounted for in the line height (it is spacing)
        # Start new line
        self._lines.resize(self._lines.size() + 1)
        self._lines.back().y = y
        self._lines.back().height = 0
        self._last_is_soft_break = False  # Reset soft break state

    @cython.final
    cdef void _process_text(self, MDParsedBlock* block, float indent) noexcept nogil:
        """Process text content within a block."""
        cdef float global_scale = self.context.viewport.global_scale

        cdef const imgui.ImFontGlyph* space_glyph
        cdef float space_advance_x = 0.0
        cdef float prev_font_scale = global_scale, font_scale
        cdef PyObject *font_to_pop = NULL
        cdef int32_t style_font_mask = <int32_t>MDTextType.MD_TEXT_EMPH \
            | <int32_t>MDTextType.MD_TEXT_STRONG | <int32_t>MDTextType.MD_TEXT_CODE
        cdef int32_t cur_style_mask = 0
        cdef uint32_t codepoint

        cdef MDProcessedItem *item
        cdef MDParsedWord *word
        cdef int i, j

        cdef imgui.ImVec2 word_size
        cdef float x
        cdef string text = string()

        # Make sure we have a line to work with
        if self._lines.empty():
            self._finish_line(0, False)

        space_glyph = imgui.GetFont().FindGlyph(32)
        if space_glyph is not NULL:
            space_advance_x = space_glyph.AdvanceX  # Add space width if available
        else:
            space_advance_x = imgui.GetStyle().ItemSpacing.x  # Use default spacing if no glyph found

        for i in range(<int>block.words.size()):
            word = &block.words[i]

            # Compute font characteristics
            #cur_bi_mask = <int32_t>(word.type) & bi_mask
            font_scale = self._heading_scales[word.level] * global_scale

            if font_scale != prev_font_scale: # cur_bi_mask != last_bi_mask
                self.context.viewport.global_scale = font_scale
                prev_font_scale = font_scale
                if font_to_pop != NULL:
                    (<baseFont>font_to_pop).pop()
                    font_to_pop = NULL
                # Currently we need to reapply a font for the global scale change
                if <object>self._applicable_font is not None:
                    font_to_pop = self._applicable_font
                    (<baseFont>font_to_pop).push()
                    space_glyph = imgui.GetFont().FindGlyph(32)
                    if space_glyph is not NULL:
                        space_advance_x = space_glyph.AdvanceX  # Add space width if available
                    else:
                        space_advance_x = imgui.GetStyle().ItemSpacing.x  # Use default spacing if no glyph found
            assert word.level >= 0 and word.level <= 6, "Heading level must be between 0 and 6"

            # apply font style
            text = self._apply_text_styling(word, <int32_t>(word.type) & style_font_mask)

            if not text.empty():
                word_size = imgui.CalcTextSize(text.c_str(), text.c_str() + text.size(), False, -1)
                word_size.y = imgui.GetTextLineHeight() # We care about the default height, not the height for the specific text
            else:
                word_size = imgui.ImVec2(0, imgui.GetTextLineHeight())

            # Check if it fits in the current line
            if self._lines.back().items.size() > 0:
                x = self._lines.back().items.back().x + self._lines.back().items.back().width

                if self._last_is_soft_break:
                    x += space_advance_x  # Add space after soft break

                # Check if word fits on current line
                if x + word_size.x > self._last_width:
                    # Word doesn't fit, start new line
                    self._finish_line(0, True) # imgui.GetStyle().ItemSpacing.y
                    x = indent  # Reset x to indentation for the new line
            else:
                # Start at indentation for the first item in the line
                x = indent

            if not text.empty():
                # Create a new item for the word
                self._lines.back().items.resize(self._lines.back().items.size() + 1)
                item = &self._lines.back().items.back()
                item.text = text
                item.text_type = word.type
                item.font_scale = font_scale
                item.color_index = color_for_text_type(item.text_type, word.level)
                if <int32_t>word.type & <int32_t>MDTextType.MD_TEXT_LINK\
                   and self._block_details.size() > 0\
                   and self._block_details.back().type == MD_BLOCKTYPE_EXT.MD_TEXT_URL:
                    # Link to the detail
                    item.uuid = 1 + (self._block_details.size() - 1) # 0 means no detail / error
                else:
                    item.uuid = 0  # No UUID for regular text
                item.item_type = 0  # Regular text item
                item.x = x
                item.width = word_size.x
                item.height = word_size.y

             # Check for breaks after this word
            if <int32_t>word.type & <int32_t>MDTextType.MD_TEXT_HARD_BREAK:
                # Hard break - finish the line
                if not self._lines.back().items.empty():
                    self._finish_line(0, True)
                else:
                    self._finish_line(word_size.y, True)
            elif <int32_t>word.type & <int32_t>MDTextType.MD_TEXT_SOFT_BREAK:
                # Soft break - add space but don't start a new line
                # To do so, we cheat by increasing the width of the item
                # (And thus if we are at the start of the line, no space is added)
                self._last_is_soft_break = True
            else:
                self._last_is_soft_break = False

        # Restore state
        self.context.viewport.global_scale = global_scale
        if font_to_pop != NULL:
            (<baseFont>font_to_pop).pop()
            font_to_pop = NULL

    @cython.final
    cdef void _process_block(self, MDParsedBlock* block, float indent, bint no_end_line) noexcept nogil:
        """Process a markdown block recursively.
        
        indent: indentation level to accumulate
        """
        cdef int i
        cdef float init_x = indent
        cdef float init_y = 0.
        indent += self._get_indentation(block)
        cdef int cur_line_index = self._lines.size() - 1
        cdef MDProcessedItem *new_item
        cdef float extra_width
        cdef string tmp

        if self._block_should_end_line_before(block) and not no_end_line:
            # End the current line if needed
            self._finish_line(0, True)
            init_y = self._lines.back().y
            self._finish_line(self._get_pre_vertical_spacing(block), True)

        # Save detail if important block type
        if block.type == MD_BLOCKTYPE_EXT.MD_TEXT_URL:
            self._block_details.resize(self._block_details.size() + 1)
            self._block_details.back().type = block.type
            self._block_details.back().detail.link_detail = block.detail.link_detail
            self._block_details.back().attr1 = block.attr1
            self._block_details.back().attr2 = block.attr2

        # Render content
        if block.type == MD_BLOCKTYPE_EXT.MD_BLOCK_HR:
            self._lines.back().items.resize(1)
            self._lines.back().items[0].uuid = 0
            self._lines.back().items[0].item_type = 3  # Horizontal rule
            self._lines.back().items[0].x = indent
            self._lines.back().items[0].width = self._last_width - indent
            self._lines.back().items[0].height = imgui.GetFrameHeight() # vertical rule height
            self._lines.back().height = self._lines.back().items[0].height
        elif block.type == MD_BLOCKTYPE_EXT.MD_BLOCK_UL:
            for i in range(<int>block.children.size()):
                # Process the marker
                # Assume bullet takes GetTextLineHeight of width
                self._lines.back().items.resize(self._lines.back().items.size() + 1)
                new_item = &self._lines.back().items.back()
                new_item.item_type = 1  # List item marker
                new_item.uuid = 0
                new_item.text += block.detail.ul_detail.mark
                new_item.font_scale = self.context.viewport.global_scale
                new_item.x = indent
                new_item.width = imgui.GetTextLineHeight()  # Width of the marker
                new_item.height = imgui.GetTextLineHeight()  # Height of the marker
                # Add extra spacing after marker
                new_item.width += imgui.GetStyle().ItemSpacing.x
                # Process the content of the list
                self._process_block(&block.children[i], indent + new_item.width, True)
                # Add extra spacing for loose lists
                #if not block.detail.ol_detail.is_tight:
                #    self._finish_line(imgui.GetStyle().ItemSpacing.y, True)
                #else:
                #    # Tight lists do not add extra spacing
                #    self._finish_line(0, True)
                # loose list insert a paragraph which already adds spacing
                self._finish_line(0, True)
        elif block.type == MD_BLOCKTYPE_EXT.MD_BLOCK_OL:
            # compute maximize size for the numerical values
            extra_width = 0.
            for i in range(<int>block.children.size()):
                # Calculate the width of the numerical value
                tmp = to_string(block.detail.ol_detail.start + i)
                extra_width = fmax(extra_width, imgui.CalcTextSize(tmp.c_str(), tmp.c_str() + tmp.size(), False, -1).x)
            for i in range(<int>block.children.size()):
                # Process the numerical value
                self._lines.back().items.resize(self._lines.back().items.size() + 1)
                new_item = &self._lines.back().items.back()
                new_item.item_type = 2 # text item (not justified)
                new_item.x = indent
                new_item.text = to_string(block.detail.ol_detail.start + i)
                new_item.text_type = MDTextType.MD_TEXT_NORMAL
                new_item.font_scale = self.context.viewport.global_scale
                new_item.color_index = color_for_text_type(new_item.text_type, 0)
                new_item.width = extra_width
                new_item.height = imgui.GetTextLineHeight()  # Height of the marker
                new_item.uuid = 0  # No UUID for regular text
                # Add the marker
                self._lines.back().items.resize(self._lines.back().items.size() + 1)
                new_item = &self._lines.back().items.back()
                new_item.item_type = 1 # List item marker
                new_item.text += block.detail.ol_detail.mark_delimiter
                new_item.x += extra_width + indent
                new_item.font_scale = self.context.viewport.global_scale
                new_item.width = imgui.GetTextLineHeight()  # Width of the marker
                new_item.height = imgui.GetTextLineHeight()  # Height of the marker
                new_item.uuid = 0
                # Add extra spacing after marker
                new_item.width += imgui.GetStyle().ItemSpacing.x
                # Process the content of the list
                self._process_block(&block.children[i], new_item.x + new_item.width, True)
                # Add extra spacing for loose lists
                #if not block.detail.ol_detail.is_tight:
                #    self._finish_line(imgui.GetStyle().ItemSpacing.y, True)
                #else:
                #    # Tight lists do not add extra spacing
                #    self._finish_line(0, True)
                # loose list insert a paragraph which already adds spacing
                self._finish_line(0, True)
        elif block.type == MD_BLOCKTYPE_EXT.MD_TEXT:
            self._process_text(block, indent) 
        else:
            # Process all children for container blocks
            for i in range(<int>block.children.size()):
                self._process_block(&block.children[i], indent, no_end_line and i == 0)

        # End line if needed
        if self._block_should_end_line_after(block):
            self._finish_line(self._get_post_vertical_spacing(block), True)

        cdef float final_y = 0.
        if self._block_position_should_be_stored(block):
            final_y = self._lines.back().y # assumes there is a least one line
            self._blocks.resize(self._blocks.size() + 1)
            self._blocks.back().type = block.type
            self._blocks.back().x = init_x
            self._blocks.back().ymin = init_y
            self._blocks.back().ymax = final_y

    # Processing of the parsed content
    cdef void _process(self, float available_width) noexcept nogil:
        """Process the whole document tree to compute layout"""
        cdef PyObject *applicable_font = <PyObject *>self._font
        cdef PyObject *parent_item = <PyObject *>self.parent

        # Retrieve applicable font
        if self._font is None:
            # Find the font in the parent tree
            while <object>parent_item is not None:
                # Important Note: assume that all parents are uiItem except the viewport
                if <baseItem>parent_item is self.context.viewport:
                    # Reached the viewport, use its font
                    applicable_font = <PyObject*>self.context.viewport._font
                    break
                else:
                    # Use the parent's font
                    applicable_font = <PyObject*>(<uiItem>parent_item)._font
                    if <object>applicable_font is not None:
                        break
                # Move to the parent item
                parent_item = <PyObject*>(<baseItem>parent_item).parent

        # Skip if width or font hasn't changed TODO: also on global scale change
        if self._last_width == available_width\
           and self._applicable_font == applicable_font:
            self.state.cur.rect_size = self._rect_size
            return

        # Reset layout state
        self._lines.clear()
        self._blocks.clear()
        self._block_details.clear()
        self._applicable_font = applicable_font
        self._last_width = available_width

        # Process the document tree recursively
        self._process_block(&self._parser.content, 0, False)

        cdef int i
        # We build blocks in a reverse order, we need
        # to reverse them to have a topological order (will not be top to bottom)
        cdef MDProcessedBlock tmp_p_block
        for i in range(<int>self._blocks.size() // 2):
            tmp_p_block = self._blocks[i]
            self._blocks[i] = self._blocks[self._blocks.size() - 1 - i]
            self._blocks[self._blocks.size() - 1 - i] = tmp_p_block

        # Compute the size
        self.state.cur.rect_size.x = 0
        self.state.cur.rect_size.y = 0

        for i in range(<int>self._lines.size()):
            if self._lines[i].items.empty():
                continue  # Skip empty lines
            self.state.cur.rect_size.x = fmax(self.state.cur.rect_size.x, self._lines[i].items.back().x + self._lines[i].items.back().width)
        if self._lines.size() > 0:
            self.state.cur.rect_size.y = self._lines.back().y + self._lines.back().height
        for i in range(<int>self._blocks.size()):
            self.state.cur.rect_size.y = fmax(self.state.cur.rect_size.y, self._blocks[i].ymax)

        self._rect_size = self.state.cur.rect_size

    # Rendering
    cdef bint draw_item(self) noexcept nogil:
        """Draw the markdown content"""
        cdef Vec2 full_content_area = self.context.viewport.parent_size
        cdef Vec2 cur_content_area, requested_size

        full_content_area.x -= self.state.cur.pos_to_parent.x

        requested_size = self.get_requested_size()

        if requested_size.x == 0:
            cur_content_area.x = full_content_area.x
        elif requested_size.x < 0:
            cur_content_area.x = full_content_area.x + requested_size.x
        else:
            cur_content_area.x = requested_size.x

        cur_content_area.x = max(0, cur_content_area.x)

        self._process(cur_content_area.x) # fills rect_size

        cdef imgui.ImVec2 initial_pos_backup = imgui.GetCursorScreenPos()

        imgui.Dummy(imgui.ImVec2(self.state.cur.rect_size.x, self.state.cur.rect_size.y))

        self.update_current_state()

        if not self.state.cur.rendered:
            # Entirely clipped
            return False

        cdef imgui.ImVec2 final_pos_backup = imgui.GetCursorScreenPos() # to reset it later

        # Move to the first visible line
        imgui.SetCursorScreenPos(initial_pos_backup)

        cdef imgui.ImDrawList* draw_list = imgui.GetWindowDrawList()

        cdef float global_scale = self.context.viewport.global_scale

        cdef const imgui.ImFontGlyph* space_glyph
        cdef const imgui.ImFontGlyph* A_glyph
        cdef const imgui.ImFontGlyph* o_glyph
        cdef float space_advance_x = 0.0, A_center = 0.0, A_height = 0.0, o_center = 0.0, o_height = 0.0
        space_glyph = imgui.GetFont().FindGlyph(32)
        if space_glyph is not NULL:
            space_advance_x = space_glyph.AdvanceX  # Add space width if available
        else:
            space_advance_x = imgui.GetStyle().ItemSpacing.x  # Use default spacing if no glyph found
        A_glyph = imgui.GetFont().FindGlyph(65)  # 'A' glyph for height
        if A_glyph is not NULL:
            A_center = (A_glyph.Y0 + A_glyph.Y1) * 0.5
            A_height = A_glyph.Y1 - A_glyph.Y0
        else:
            A_center = imgui.GetTextLineHeight() * 0.5 # Default height if no glyph found
            A_height = imgui.GetTextLineHeight()
        o_glyph = imgui.GetFont().FindGlyph(111)  # 'o' glyph for height
        if o_glyph is not NULL:
            o_center = (o_glyph.Y0 + o_glyph.Y1) * 0.5
            o_height = o_glyph.Y1 - o_glyph.Y0
        else:
            o_center = imgui.GetTextLineHeight() * 0.5 # Default height if no glyph found
            o_height = imgui.GetTextLineHeight()

        cdef float prev_font_scale = global_scale, font_scale
        cdef PyObject *font_to_pop = NULL
        cdef uint32_t codepoint

        cdef int i, j
        cdef MDProcessedLine *line
        cdef MDProcessedItem *item
        cdef bint last_strikethrough, last_underline
        cdef float last_x, x, y
        cdef imgui.ImVec2 item_pos, item_size
        cdef float max_available_x = self.context.viewport.parent_pos.x + self.context.viewport.parent_size.x

        cdef uint32_t[<int32_t>TextColorIndex.COUNT] color_table = self._color_table
        if color_table[<int32_t>TextColorIndex.DEFAULT] == 1:
            color_table[<int32_t>TextColorIndex.DEFAULT] = imgui.GetColorU32(imgui.GetStyleColorVec4(imgui.ImGuiCol_Text))
        if color_table[<int32_t>TextColorIndex.HEADING_1] == 1:
            color_table[<int32_t>TextColorIndex.HEADING_1] = color_table[<int32_t>TextColorIndex.DEFAULT]
        if color_table[<int32_t>TextColorIndex.HEADING_2] == 1:
            color_table[<int32_t>TextColorIndex.HEADING_2] = color_table[<int32_t>TextColorIndex.HEADING_1]
        if color_table[<int32_t>TextColorIndex.HEADING_3] == 1:
            color_table[<int32_t>TextColorIndex.HEADING_3] = color_table[<int32_t>TextColorIndex.HEADING_2]
        if color_table[<int32_t>TextColorIndex.HEADING_4] == 1:
            color_table[<int32_t>TextColorIndex.HEADING_4] = color_table[<int32_t>TextColorIndex.HEADING_3]
        if color_table[<int32_t>TextColorIndex.HEADING_5] == 1:
            color_table[<int32_t>TextColorIndex.HEADING_5] = color_table[<int32_t>TextColorIndex.HEADING_4]
        if color_table[<int32_t>TextColorIndex.HEADING_6] == 1:
            color_table[<int32_t>TextColorIndex.HEADING_6] = color_table[<int32_t>TextColorIndex.HEADING_5]
        if color_table[<int32_t>TextColorIndex.EMPH] == 1:
            color_table[<int32_t>TextColorIndex.EMPH] = 0xFF00FF00  # Default green color
        if color_table[<int32_t>TextColorIndex.STRONG] == 1:
            color_table[<int32_t>TextColorIndex.STRONG] = 0xFF0000FF  # Default red color
        if color_table[<int32_t>TextColorIndex.STRIKETHROUGH] == 1:
            color_table[<int32_t>TextColorIndex.STRIKETHROUGH] = imgui.GetColorU32(imgui.GetStyleColorVec4(imgui.ImGuiCol_TextDisabled))
        if color_table[<int32_t>TextColorIndex.UNDERLINE] == 1:
            color_table[<int32_t>TextColorIndex.UNDERLINE] = color_table[<int32_t>TextColorIndex.DEFAULT]
        if color_table[<int32_t>TextColorIndex.CODE] == 1:
            color_table[<int32_t>TextColorIndex.CODE] = 0xFFFFFF00  # Default cyan color
        if color_table[<int32_t>TextColorIndex.CODE_BACKGROUND] == 1:
            color_table[<int32_t>TextColorIndex.CODE_BACKGROUND] = imgui.GetColorU32(imgui.GetStyleColorVec4(imgui.ImGuiCol_ChildBg))
        if color_table[<int32_t>TextColorIndex.LINK] == 1:
            color_table[<int32_t>TextColorIndex.LINK] = imgui.ColorConvertFloat4ToU32(imgui.GetStyleColorVec4(imgui.ImGuiCol_TextLink))
        imgui.PushStyleColor(imgui.ImGuiCol_TextLink, imgui.ColorConvertU32ToFloat4(color_table[<int32_t>TextColorIndex.LINK]))
        cdef uint32_t border_color = imgui.GetColorU32(imgui.GetStyleColorVec4(imgui.ImGuiCol_Border))
        cdef float border_size = imgui.GetStyle().ChildBorderSize

        # Before rendering the text (lines), render the background
        for i in range(<int>self._blocks.size()):
            item_pos.x = initial_pos_backup.x + self._blocks[i].x
            item_pos.y = initial_pos_backup.y + self._blocks[i].ymin
            if not imgui.IsRectVisible(item_pos,
                                       imgui.ImVec2(max_available_x,
                                                    initial_pos_backup.y + self._blocks[i].ymax)):
                continue  # Skip invisible blocks
            if self._blocks[i].type == MD_BLOCKTYPE_EXT.MD_BLOCK_CODE:
                # Draw code block background
                t_draw_rect(self.context, draw_list,
                            item_pos.x + 0.5 * border_size, item_pos.y + 0.5 * border_size,
                            max_available_x - 0.5 * border_size, initial_pos_backup.y + self._blocks[i].ymax - 0.5 * border_size,
                            None, border_color,
                            color_table[<int32_t>TextColorIndex.CODE_BACKGROUND],
                            border_size, 0)
            elif self._blocks[i].type == MD_BLOCKTYPE_EXT.MD_BLOCK_QUOTE:
                # Draw quote block background
                t_draw_line(self.context, draw_list,
                            item_pos.x + 0.5 * global_scale * imgui.GetStyle().SeparatorTextBorderSize,
                            item_pos.y + 0.5 * global_scale * imgui.GetStyle().SeparatorTextBorderSize,
                            item_pos.x + 0.5 * global_scale * imgui.GetStyle().SeparatorTextBorderSize,
                            initial_pos_backup.y + self._blocks[i].ymax - 0.5 * global_scale * imgui.GetStyle().SeparatorTextBorderSize,
                            None, border_color,
                            global_scale * imgui.GetStyle().SeparatorTextBorderSize)


        for i in range(<int>self._lines.size()):
            line = &self._lines[i]
            if line.items.empty():
                continue  # Skip empty lines
            
            item_pos.y = initial_pos_backup.y + line.y
            item_pos.x = initial_pos_backup.x + line.items[0].x

            # Skip invisible lines
            if not imgui.IsRectVisible(item_pos, imgui.ImVec2(item_pos.x + self.state.cur.rect_size.x, item_pos.y + line.height)):
                continue

            last_strikethrough = False
            last_underline = False
            last_x = item_pos.x

            for j in range(<int>line.items.size()):
                item = &line.items[j]
                item_pos.x = initial_pos_backup.x + item.x
                item_pos.y = initial_pos_backup.y + line.y
                item_size.x = item.width
                item_size.y = item.height

                font_scale = item.font_scale

                # Update the font if the scale is different
                if font_scale != prev_font_scale:
                    self.context.viewport.global_scale = font_scale
                    prev_font_scale = font_scale
                    if font_to_pop != NULL:
                        (<baseFont>font_to_pop).pop()
                        font_to_pop = NULL
                    # Currently we need to reapply a font for the global scale change
                    if <object>self._applicable_font is not None:
                        font_to_pop = self._applicable_font
                        (<baseFont>font_to_pop).push()
                    space_glyph = imgui.GetFont().FindGlyph(32)
                    if space_glyph is not NULL:
                        space_advance_x = space_glyph.AdvanceX  # Add space width if available
                    else:
                        space_advance_x = imgui.GetStyle().ItemSpacing.x  # Use default spacing if no glyph found
                    A_glyph = imgui.GetFont().FindGlyph(65)  # 'A' glyph for height
                    if A_glyph is not NULL:
                        A_center = (A_glyph.Y0 + A_glyph.Y1) * 0.5
                        A_height = A_glyph.Y1 - A_glyph.Y0
                    else:
                        A_center = imgui.GetTextLineHeight() * 0.5
                        A_height = imgui.GetTextLineHeight()
                    o_glyph = imgui.GetFont().FindGlyph(111)  # 'o' glyph for height
                    if o_glyph is not NULL:
                        o_center = (o_glyph.Y0 + o_glyph.Y1) * 0.5
                        o_height = o_glyph.Y1 - o_glyph.Y0
                    else:
                        o_center = imgui.GetTextLineHeight() * 0.5
                        o_height = imgui.GetTextLineHeight()

                # Draw the item based on its type
                if item.item_type == 0 or item.item_type == 2:  # Regular text
                    if <int32_t>item.text_type & <int32_t>MDTextType.MD_TEXT_LINK:
                        # Use imgui link feature. Assumes the size is the same as AddText.
                        imgui.SetCursorScreenPos(item_pos)
                        imgui.TextLinkOpenURL(item.text.c_str(), <const char*> NULL if item.uuid == 0 or self._block_details[item.uuid - 1].attr1.size() == 0 else self._block_details[item.uuid - 1].attr1.c_str())
                        last_x = item_pos.x + item_size.x
                        continue
                    # Draw the text with the appropriate font and color
                    draw_list.AddText(item_pos, color_table[<int32_t>item.color_index], item.text.c_str(), item.text.c_str() + item.text.size())
                elif item.item_type == 1:  # marker (list item). Can be ')', '.', '*', '+' or '-'
                    imgui.SetCursorScreenPos(item_pos)
                    if item.text[0] == r"*":
                        t_draw_star(self.context, draw_list,
                                    item_pos.x + item_size.x * 0.5,
                                    item_pos.y + o_center - 0.5,
                                    o_height * 0.5,
                                    o_height * 0.3,
                                    0.5*3.1415, 5, None, 0,
                                    color_table[<int32_t>item.color_index], 0.)
                    elif item.text == r"-":
                        t_draw_line(self.context, draw_list,
                                    item_pos.x,
                                    item_pos.y + A_center,
                                    item_pos.x + space_advance_x,
                                    item_pos.y + A_center,
                                    None,
                                    color_table[<int32_t>item.color_index],
                                    self.context.viewport.global_scale)
                    elif item.text == r"." or item.text == r")":
                        # Draw a left-aligned small point
                        t_draw_circle(self.context, draw_list,
                                      item_pos.x + o_height * 0.5,
                                      item_pos.y + o_center + 0.25 * o_height,
                                      o_height * 0.2,
                                      None, 0,
                                      color_table[<int32_t>item.color_index], 0., 12)
                    else: # item.text == r"+":
                        # Fallback to bullet
                        t_draw_circle(self.context, draw_list,
                                      item_pos.x + item_size.x * 0.5,
                                      item_pos.y + o_center,
                                      o_height * 0.45,
                                      None, 0,
                                      color_table[<int32_t>item.color_index], 0., 12)
                elif item.item_type == 3:  # Horizontal rule
                    imgui.SetCursorScreenPos(item_pos)
                    imgui.Separator()
                elif item.item_type == 4:  # UUID-based items (links, images, tables)
                    pass # TODO
                    #if <object>self._uuid_map.get(item.uuid) is not None:
                    #    (<uiItem>self._uuid_map[item.uuid]).draw() # Draw the linked UI item

                if (<int32_t>item.text_type & <int32_t>MDTextType.MD_TEXT_UNDERLINE):
                    x = last_x if last_underline else item_pos.x
                    last_underline = True
                    y = item_pos.y + item_size.y + 0.2 * imgui.GetFont().Descent * imgui.GetFont().Scale
                    draw_list.AddLine(imgui.ImVec2(x, y),
                                      imgui.ImVec2(item_pos.x + item_size.x, y),
                                      color_table[<int32_t>TextColorIndex.UNDERLINE],
                                      self.context.viewport.global_scale)
                else:
                    last_underline = False

                if (<int32_t>item.text_type & <int32_t>MDTextType.MD_TEXT_STRIKETHROUGH):
                    x = last_x if last_strikethrough else item_pos.x
                    last_strikethrough = True
                    y = item_pos.y + 0.5 * imgui.GetFont().FontSize * imgui.GetFont().Scale
                    draw_list.AddLine(imgui.ImVec2(x, y),
                                      imgui.ImVec2(item_pos.x + item_size.x, y),
                                      color_table[<int32_t>TextColorIndex.STRIKETHROUGH],
                                      self.context.viewport.global_scale)
                else:
                    last_strikethrough = False

                last_x = item_pos.x + item_size.x

        if font_to_pop != NULL:
            (<baseFont>font_to_pop).pop()
            font_to_pop = NULL

        # Restore cursor for the next item
        imgui.SetCursorScreenPos(final_pos_backup)

        imgui.PopStyleColor(1)  # Pop the text link color

        return False