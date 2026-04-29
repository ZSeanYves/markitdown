# @bobzhang/mbtpdf/font/pdffont

PDF font and encoding types.

## Overview

This package defines the core types for representing PDF fonts, including simple fonts (Type 1, TrueType, Type 3), CID-keyed composite fonts, and the 14 standard PDF fonts. It also handles font encodings and character mappings.

## Types

### Font

The main font type encompassing all PDF font types.

```moonbit nocheck
///|
pub(all) enum Font {
  StandardFont(StandardFont, Encoding)
  SimpleFont(SimpleFont)
  CIDKeyedFont(String, CompositeCIDFont, CMapEncoding)
}
```

### StandardFont

The 14 standard PDF fonts.

```moonbit nocheck
///|
pub(all) enum StandardFont {
  TimesRoman
  TimesBold
  TimesItalic
  TimesBoldItalic
  Helvetica
  HelveticaBold
  HelveticaOblique
  HelveticaBoldOblique
  Courier
  CourierBold
  CourierOblique
  CourierBoldOblique
  Symbol
  ZapfDingbats
}
```

### SimpleFont

Simple (non-composite) font structure.

```moonbit nocheck
///|
pub(all) struct SimpleFont {
  fonttype : SimpleFontType
  basefont : String
  firstchar : Int
  lastchar : Int
  widths : Array[Int]
  fontdescriptor : FontDescriptor?
  fontmetrics : FontMetrics?
  encoding : Encoding
}
```

### SimpleFontType

Types of simple fonts.

```moonbit nocheck
///|
pub(all) enum SimpleFontType {
  Type1 // PostScript Type 1
  MMType1 // Multiple Master Type 1
  Type3(Type3Glyphs) // User-defined glyphs
  Truetype // TrueType/OpenType
}
```

### Encoding

Font encoding schemes.

```moonbit nocheck
///|
pub(all) enum Encoding {
  ImplicitInFontFile
  StandardEncoding
  MacRomanEncoding
  WinAnsiEncoding
  MacExpertEncoding
  CustomEncoding(Encoding, Differences)
  FillUndefinedWithStandard(Encoding)
}
```

### FontDescriptor

Font metrics and properties.

```moonbit nocheck
///|
pub(all) struct FontDescriptor {
  ascent : Double
  descent : Double
  avgwidth : Double
  maxwidth : Double
  flags : Int
  fontbbox : (Double, Double, Double, Double)
  italicangle : Double
  capheight : Double
  xheight : Double
  stemv : Double
  fontfile : FontFile?
  charset : Array[String]?
  tounicode : Map[Int, String]?
  tounicode_bytes : Map[String, String]?
}
```

### CMapEncoding

CMap encoding for CID fonts.

```moonbit nocheck
///|
pub(all) enum CMapEncoding {
  Predefined(String) // Named CMap (e.g., "/Identity-H")
  CMap(Int) // Embedded CMap stream object number
}
```

## Functions

### StandardFont::to_string

Get the PDF name for a standard font.

```moonbit nocheck
pub fn StandardFont::to_string(self : StandardFont) -> String
```

### Encoding::to_string

Get a debug string for an encoding.

```moonbit nocheck
pub fn Encoding::to_string(self : Encoding) -> String
```

### Font::to_string

Get a debug string for a font.

```moonbit nocheck
pub fn Font::to_string(self : Font) -> String
```
