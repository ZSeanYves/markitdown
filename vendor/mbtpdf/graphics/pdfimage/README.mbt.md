# @bobzhang/mbtpdf/graphics/pdfimage

Image extraction and decoding for PDF documents.

## Overview

This package extracts images from PDF documents, handling various image formats (JPEG, JPEG2000, JBIG2) and color space conversions to produce 24-bit RGB output.

## Types

### Image

Extracted image data.

```moonbit nocheck
///|
pub(all) enum Image {
  JPEG(@pdfio.MutableBytes, Array[Double]?)
  JPEG2000(@pdfio.MutableBytes, Array[Double]?)
  JBIG2(@pdfio.MutableBytes, Array[Double]?, Int?)
  Raw(Int, Int, PixelLayout, @pdfio.MutableBytes)
}
```

- `JPEG`: JPEG data with optional decode array
- `JPEG2000`: JPEG2000 data with optional decode array
- `JBIG2`: JBIG2 data, decode array, globals stream reference
- `Raw`: Width, height, pixel layout, raw pixel data

### PixelLayout

Pixel format of raw images.

```moonbit nocheck
///|
pub(all) enum PixelLayout {
  BPP1
  BPP8
  BPP24
  BPP48
}
```

- `BPP1`: 1 bit per pixel (monochrome)
- `BPP8`: 8 bits per pixel (grayscale)
- `BPP24`: 24 bits per pixel (RGB)
- `BPP48`: 48 bits per pixel (16-bit RGB)

## Functions

### Image::get_image_24bpp

Extract an image and convert to 24-bit RGB format.

```moonbit nocheck
pub fn Image::get_image_24bpp(
  pdf : @pdf.Pdf,
  dict : @pdf.PdfObject,
  stream : @pdf.PdfObject
) -> Image raise
```

- `dict`: Image dictionary
- `stream`: Image stream

### Image::colspace

Determine the color space of an image.

```moonbit nocheck
pub fn Image::colspace(
  pdf : @pdf.Pdf,
  dict : @pdf.PdfObject,
  resources : @pdf.PdfObject
) -> @pdfspace.ColourSpace raise
```

- `dict`: Image dictionary
- `resources`: Page resources

### Image::bpc

Get the bits-per-component value from an image dictionary.

```moonbit nocheck
pub fn Image::bpc(pdf : @pdf.Pdf, dict : @pdf.PdfObject) -> @pdf.PdfObject?
```

## Supported Image Types

- **JPEG (DCTDecode)**: Returned as raw JPEG bytes for external decoding
- **JPEG2000 (JPXDecode)**: Returned as raw JP2 bytes
- **JBIG2 (JBIG2Decode)**: Returned with optional globals stream reference
- **Raw images**: Decoded and converted to 24-bit RGB

## Color Space Handling

The package handles color space conversions including:
- DeviceGray to RGB
- DeviceCMYK to RGB
- Indexed (palette) colors
- Calibrated color spaces (CalGray, CalRGB, Lab)
- ICC-based color spaces
