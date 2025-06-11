# Themes

## ThemeColor and ThemeStyle

**ImGui** is the main library used to render items. The appearance of many items,
as well as the style, and various spacing behaviours can be tuned using themes.
**ImPlot** is used to render plots.

- `ThemeColorImGui` enables to change the color of most objects
- `ThemeColorImPlot` enables to change the color of plot items
- `ThemeStyleImGui` enables to change the style and spacing of most items
- `ThemeStyleImPlot` enables to change the style and spacing of plots

By default all values passed, as well as default values, are scaled by the global scale, and rounded to an
integer when it makes sense. This can be disabled using `no_scaling` and `no_rounding`.

Values set in a theme instance are meant to replace any previous value currently set in the rendering tree.
When a theme is attached to an item, the values are replayed when the item is rendered, and the item,
as well as all its children will use these theme values (unless another theme is applied).

```python
my_theme = dcg.ThemeStyleImGui(frame_padding=(0, 0))
...
item.theme = my_theme
...
my_theme.window_rounding = 1 # adding a new setting in the theme
...
my_theme.window_rounding = None # Removing a setting from the theme
```

***

# Fonts

## The default font

The default font uses the Latex Latin Modern font at size 17, scaled by the global scale.
It combines several fonts in order to provide in a single font `bold`, *italics* and **bold-italics**.
The advantage of combining fonts into one is to benefit from text wrapping, as it is not needed
to issue several Text() calls. In addition combining fonts needs special centering and sizing.

## The default font at different sizes

New instances of the default font can be created using `AutoFont`.
```python
my_new_font = dcg.AutoFont(C, base_size=new_size)
```
The default base size is 17.

## Simplest and fastest way of loading a font

To load a non-default font, the simplest is to use `AutoFont`
```python
my_new_font = dcg.AutoFont(C,
                           base_size=my_target_size,
                           main_font_path=path)
```

`AutoFont` does the following for you:
- Load the font, render the `GlyphSet`, and load it in a `FontTexture`
- Detect scales at which the font is used in practice (viewport dpi scaling, etc), and compile in the background new versions of the font to be sharp at the target scale.
- Load the best compiled font for the target scale when used, in order to have sharp rendering

By default it uses `make_extended_latin_font` to build a `GlyphSet`, which corresponds to a set of renderer glyphs and their size information.
This function builds an extended latin set of characters, with bold/bold-italics and italics. The helpers `make_bold`, `make_bold_italic` and `make_italic` can be used to generate text that uses the characters that will render in these modes.

If one wants to load a different set of characters, AutoFont takes a `font_creator` argument to replace `make_extended_latin`. This function should take as argument the target size, and optional arguments that are forwarded by AutoFont. It should return a `GlyphSet` (see below how to build one).

## Alternative way

The second simplest way is to use a `FontTexture` directly:
```python

font_texture = dcg.FontTexture(C)
font_texture.add_font_file(path, size=size)
font_texture.build()
my_new_font = font_texture[0]
```

This is simple and fast (it uses **ImGui** directly), but it has its share
of imperfections. It is not the recommended way.

## An improved alternative way

```python

# Prepare the font texture
font_texture = dcg.FontTexture(C)
# Load the font
font_renderer = FontRenderer(path)
# render the glyphs (GlyphSet)
# see the docstring for various modes that impact
# how the glyphs are rendered.
glyph_set = font_renderer.render_glyph_set(target_size=size)
# Note a GlyphSet can be built manually by adding
# manually the image of each glyph with GlyphSet's `add_glyph`.
# This enables to load custom bitmap fonts, using any character mapping.
# Characters can also be added to an already built GlyphSet.
# See GlyphSet methods for how to alter the size and positioning
# of the loaded glyphs.
# Center the font on a target character (optional)
glyph_set.center_on_glyph(target_unicode=ord("B"))
# Load into a font texture
font_texture.add_custom_font(glyph_set)
font_texture.build()
my_new_font = font_texture[0]
```

Note however that both alternative methods will give blurry rendering whenever the display's dpi scale is not 1. `AutoFont` handles building at the correct scale for you. Alternatively a simple way to handle scaling is to do:

```python
# Scale the size during glyph rendering
global_scale = C.viewport.dpi * C.viewport.scale
# Render at a bigger size
glyph_set = font_renderer.render_glyph_set(target_size=round(size*global_scale))
...
# The font is already scaled
# Thus we make it so after being scaled
# by global_scale, the resulting scale is 1.
my_new_font.scale = 1./global_scale
```

As long as `global_scale` is not changed after the font is created, this method will give good results.
