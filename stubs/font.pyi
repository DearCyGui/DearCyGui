from typing import Iterator, overload

class GlyphSet:
    height: int
    origin_y: int
    images: dict[int, Array]
    positioning: dict[int, tuple[float, float, float]]
    
    def __init__(self, height: int, origin_y: int) -> None:
        """Initialize empty GlyphSet with specified dimensions
        
        Args:
            height: fixed vertical space reserved to render text.
                A good value would be the size needed to render
                all glyphs loaded with proper alignment,
                but in some cases some rarely used glyphs can be
                very large. Thus you might want to use only a subset
                of the glyphs to fit this space.
                All y coordinates (dy in add_glyph and origin_y),
                take as origin (y=0) the top of this reserved
                vertical space, and use a top down coordinate system.
            origin_y: Y coordinate of the baseline (bottom of 'A'
                character) from the top of the reserved vertical space
                (in a top down coordinate system).
        """
        ...
    
    def add_glyph(self, 
                 unicode_key: int, 
                 image: Array, 
                 dy: float, 
                 dx: float, 
                 advance: float) -> None:
        """insert a glyph into the set
        
        Args:
            unicode_key: UTF-8 code for the character
            image: Array containing glyph bitmap (h,w,c)
            dy: Y offset from cursor to glyph top (top down axis)
            dx: X offset from cursor to glyph left
            advance: Horizontal advance to next character
        """
        ...
    
    @overload
    def __getitem__(self, key: int) -> tuple[Array, float, float, float]:
        """Returns the information stored for a given character.
        The output Format is (image, dy, dx, advance)"""
        ...
    
    @overload
    def __getitem__(self, key: str) -> tuple[Array, float, float, float]:
        """Returns the information stored for a given character.
        The output Format is (image, dy, dx, advance)"""
        ...
    
    def __iter__(self) -> Iterator[tuple[int, Array, float, float, float]]:
        """Iterate over all glyphs.

        Elements are of signature (unicode_key, image, dy, dx, advance)
        """
        ...
    
    def insert_padding(self, 
                      top: int = 0, 
                      bottom: int = 0, 
                      left: int = 0, 
                      right: int = 0) -> None:
        """
        Shift all characters from their top-left origin
        by adding empty areas.
        Note the character images are untouched. Only the positioning
        information and the reserved height may change.
        """
        ...
    
    def fit_to_new_height(self, target_height: int) -> None:
        """
        Update the height, by inserting equal padding
        at the top and bottom.
        """
        ...
    
    @overload
    def center_on_glyph(self, target_unicode: int) -> None:
        """
        Center the glyphs on the target glyph (B if not given).

        This function adds the relevant padding in needed to ensure
        when rendering in widgets the glyphs, the target character
        is properly centered.
        """
        ...
    
    @overload
    def center_on_glyph(self, target_unicode: str = "B") -> None:
        """
        Center the glyphs on the target glyph (B if not given).

        This function adds the relevant padding in needed to ensure
        when rendering in widgets the glyphs, the target character
        is properly centered.
        """
        ...
    
    def remap(self,
             src_codes: list[int] | list[str],
             dst_codes: list[int] | list[str]) -> None:
        """
        Provide the set of dst_codes unicode codes by
        using the glyphs from src_codes
        """
        ...
    
    @classmethod
    def fit_glyph_sets(cls, glyphs: list['GlyphSet']) -> None:
        """
        Given list of GlyphSets, update the positioning
        information of the glyphs such that the glyphs of
        all sets take the same reserved height, and their
        baseline are aligned.

        This is only useful for merging GlyphSet in a single
        font, as else the text rendering should already handle
        this alignment.
        """
        ...
    
    @classmethod
    def merge_glyph_sets(cls, glyphs: list['GlyphSet']) -> 'GlyphSet':
        """
        Merge together a list of GlyphSet-s into a single
        GlyphSet.

        The new GlyphSet essentially:
        - Homogeneizes the GlyphSets origins and vertical
            spacing by calling `fit_glyph_sets`
        - Merge the character codes. In case of character
            duplication, the first character seen takes
            priority.

        *WARNING* Since `fit_glyph_sets` is called, the original
        glyphsets are modified.
        """
        ...

class FontRenderer:
    """
    A class that manages font loading,
    glyph rendering and text rendering.
    """
    
    def __init__(self, path: str) -> None:
        """
        Initialize a FontRenderer with a font file path.
        
        Args:
            path: Path to the font file
        
        Raises:
            ValueError: If the font file does not exist or cannot be opened
        """
        ...
    
    def render_text_to_array(self, 
                           text: str,
                           target_size: int,
                           align_to_pixels: bool = True,
                           enable_kerning: bool = True,
                           hinter: str = "light",
                           allow_color: bool = True) -> tuple[memoryview, int]:
        """
        Render text string to an array and return the array and bitmap_top.
        
        Args:
            text: The text to render
            target_size: Target pixel size of the text
            align_to_pixels: Whether to align characters to pixel boundaries
            enable_kerning: Whether to apply kerning between characters
            hinter: Hinting strategy ("none", "font", "light", "strong", "monochrome")
            allow_color: Whether to render color glyphs if available
        
        Returns:
            tuple of (image memoryview, bitmap_top)
        """
        ...
    
    def estimate_text_dimensions(self, 
                               text: str, 
                               load_flags: int, 
                               align_to_pixels: bool, 
                               enable_kerning: bool) -> tuple[float, float, float, float]:
        """
        Calculate the dimensions needed for the text.
        
        Args:
            text: The text to measure
            load_flags: FreeType load flags
            align_to_pixels: Whether to align characters to pixel boundaries
            enable_kerning: Whether to apply kerning between characters
        
        Returns:
            tuple of (width, height, max_top, max_bottom)
        """
        ...
    
    def render_glyph_set(self,
                       target_pixel_height: float | None = None,
                       target_size: int = 0,
                       hinter: str = "light",
                       restrict_to: set[int] | None = None,
                       allow_color: bool = True) -> GlyphSet:
        """
        Render the glyphs of the font at the target scale,
        in order to them load them in a Font object.

        Args:
            target_pixel_height: if set, scale the characters to match
                this height in pixels. The height here, refers to the
                distance between the maximum top of a character,
                and the minimum bottom of the character, when properly
                aligned.
            target_size: if set, scale the characters to match the
                font 'size' by scaling the pixel size at the 'nominal'
                value (default size of the font).
            hinter: "font", "none", "light", "strong" or "monochrome".
                The hinter is the rendering algorithm that
                impacts a lot the aspect of the characters,
                especially at low scales, to make them
                more readable.
            restrict_to: set of ints that contains the unicode characters
                that should be loaded. If None, load all the characters
                available.
            allow_color: If the font contains colored glyphs, this enables
                to render them in color.

        Returns:
            GlyphSet object containing the rendered characters.
        """
        ...