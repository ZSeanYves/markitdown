# PDF Format Tutorial: From File to Memory

A beginner's guide to understanding how PDF documents are encoded on disk and represented in memory.

## Table of Contents

1. [What is a PDF?](#what-is-a-pdf)
2. [PDF File Structure](#pdf-file-structure)
3. [The Eight PDF Object Types](#the-eight-pdf-object-types)
4. [How Objects Are Written in PDF Files](#how-objects-are-written-in-pdf-files)
5. [Indirect Objects and References](#indirect-objects-and-references)
6. [Streams: Binary Data in PDF](#streams-binary-data-in-pdf)
7. [Document Structure](#document-structure)
8. [In-Memory Representation](#in-memory-representation)
9. [Putting It All Together](#putting-it-all-together)

---

## What is a PDF?

PDF (Portable Document Format) is a file format designed to present documents consistently across different platforms. At its core, a PDF is:

- A **collection of objects** (numbers, strings, arrays, dictionaries, etc.)
- Organized into a **tree structure** rooted at a "document catalog"
- With **binary streams** for images, fonts, and page content
- And **cross-reference tables** to locate objects within the file

Think of a PDF as a database of numbered objects, where some objects reference others by number.

---

## PDF File Structure

A PDF file has four main parts:

```
+------------------+
|     Header       |  <- "%PDF-1.7" or "%PDF-2.0"
+------------------+
|                  |
|      Body        |  <- All the objects (pages, fonts, images, etc.)
|                  |
+------------------+
|  Cross-Reference |  <- Index: "object 5 is at byte 1234"
|      Table       |
+------------------+
|     Trailer      |  <- Points to the root object and xref
+------------------+
```

### Header

The first line identifies the PDF version:

```
%PDF-1.7
```

Often followed by a comment with binary bytes to signal that the file contains binary data:

```
%âãÏÓ
```

### Body

Contains all the objects in the document. Each object has a number and can be referenced by other objects.

### Cross-Reference Table (xref)

An index that maps object numbers to byte offsets in the file:

```
xref
0 6
0000000000 65535 f
0000000015 00000 n
0000000074 00000 n
0000000182 00000 n
0000000281 00000 n
0000000432 00000 n
```

This says: "Object 1 starts at byte 15, Object 2 at byte 74, etc."

### Trailer

Points to the root of the document and the cross-reference table:

```
trailer
<<
  /Size 6
  /Root 1 0 R
>>
startxref
553
%%EOF
```

---

## The Eight PDF Object Types

PDF has exactly **eight** fundamental object types. Here's each one with its file syntax and in-memory representation:

### 1. Null

Represents "nothing" or an undefined value.

**File syntax:**
```
null
```

**In memory (MoonBit):**
```mbt
PdfObject::Null
```

### 2. Boolean

True or false values.

**File syntax:**
```
true
false
```

**In memory:**
```mbt
PdfObject::Boolean(true)
PdfObject::Boolean(false)
```

### 3. Integer

Whole numbers (positive or negative).

**File syntax:**
```
42
-17
0
```

**In memory:**
```mbt
PdfObject::Integer(42)
PdfObject::Integer(-17)
```

### 4. Real

Floating-point numbers.

**File syntax:**
```
3.14159
-0.5
.25
```

**In memory:**
```mbt
PdfObject::Real(3.14159)
PdfObject::Real(-0.5)
```

### 5. String

Text data, written in two ways:

**Literal strings** (parentheses):
```
(Hello, World!)
(Line one\nLine two)
(Parens \( must \) be escaped)
```

**Hexadecimal strings** (angle brackets):
```
<48656C6C6F>
```
This is "Hello" encoded as hex bytes.

**In memory:**
```mbt
PdfObject::String("Hello, World!")
```

Note: The in-memory representation doesn't distinguish between literal and hex strings.

### 6. Name

Identifiers that start with `/`. Used as dictionary keys and type identifiers.

**File syntax:**
```
/Type
/Page
/Font
/Hello#20World
```

The `#20` is a hex escape for space. Names can contain any character via `#XX` escaping.

**In memory:**
```mbt
PdfObject::Name("/Type")
PdfObject::Name("/Page")
```

### 7. Array

Ordered sequences of objects, enclosed in square brackets.

**File syntax:**
```
[1 2 3]
[/Name (string) 42 true]
[[1 2] [3 4]]
```

**In memory:**
```mbt
PdfObject::Array([
  PdfObject::Integer(1),
  PdfObject::Integer(2),
  PdfObject::Integer(3),
])
```

### 8. Dictionary

Key-value mappings where keys are always Names. Enclosed in `<<` and `>>`.

**File syntax:**
```
<<
  /Type /Page
  /MediaBox [0 0 612 792]
  /Contents 5 0 R
>>
```

**In memory:**
```mbt
PdfObject::Dictionary([
  ("/Type", PdfObject::Name("/Page")),
  ("/MediaBox", PdfObject::Array([
    PdfObject::Integer(0),
    PdfObject::Integer(0),
    PdfObject::Integer(612),
    PdfObject::Integer(792),
  ])),
  ("/Contents", PdfObject::Indirect(5)),
])
```

Note: Dictionary entries are stored as an array of `(String, PdfObject)` pairs, preserving order.

---

## How Objects Are Written in PDF Files

In a PDF file, objects can appear in two ways:

### Direct Objects

Objects written inline, exactly as shown above:

```
[1 2 3]
```

### Indirect Objects

Objects with an assigned number, written with `obj` and `endobj`:

```
5 0 obj
<< /Type /Page /MediaBox [0 0 612 792] >>
endobj
```

The `5 0` means "object number 5, generation 0" (generation is for incremental updates).

---

## Indirect Objects and References

The key to PDF's structure is **indirect references**. Instead of embedding an object directly, you can reference it by number:

```
5 0 R
```

This means "look up object 5" (the `R` stands for Reference).

### Example: A Page Referencing Its Content

```
% Object 3: A page
3 0 obj
<<
  /Type /Page
  /MediaBox [0 0 612 792]
  /Contents 4 0 R
>>
endobj

% Object 4: The page's content stream
4 0 obj
<< /Length 44 >>
stream
BT /F1 12 Tf 100 700 Td (Hello World) Tj ET
endstream
endobj
```

Here, the page (object 3) doesn't contain its content directly. Instead, it has `/Contents 4 0 R`, which points to object 4.

**In memory:**

```mbt
// Object 3 (page) contains an indirect reference
PdfObject::Dictionary([
  ("/Type", PdfObject::Name("/Page")),
  ("/MediaBox", PdfObject::Array([...])),
  ("/Contents", PdfObject::Indirect(4)),  // Points to object 4
])
```

When you need the actual content, you "follow" the indirect reference:

```mbt
// pdf.direct() follows indirect references
let content = pdf.direct(page_dict.lookup_immediate("/Contents").unwrap())
```

---

## Streams: Binary Data in PDF

A **stream** is a dictionary followed by arbitrary binary data. Streams are used for:

- Page content (drawing commands)
- Images
- Fonts
- Compressed data

### File Syntax

```
7 0 obj
<<
  /Length 1024
  /Filter /FlateDecode
>>
stream
...binary data here...
endstream
endobj
```

Key dictionary entries:
- `/Length`: Number of bytes between `stream` and `endstream`
- `/Filter`: Compression/encoding applied (e.g., `/FlateDecode` for zlib)

### In Memory

Streams are represented specially to support **lazy loading**:

```mbt
pub(all) enum Stream {
  Got(@pdfio.MutableBytes)  // Data loaded in memory
  ToGet(ToGet)              // Data still on disk (deferred)
}

// A stream object pairs a dictionary with stream data
PdfObject::Stream(Ref[(PdfObject, Stream)])
```

The `ToGet` variant stores the file position and length, allowing the data to be read only when needed:

```mbt
pub(all) struct ToGet {
  input : @pdfio.Input   // The source file
  position : Int         // Byte offset in file
  length : Int           // Number of bytes
  crypt : ToGetCrypt     // Encryption info if applicable
}
```

To get the stream data:

```mbt
// Force loading the stream data
stream_obj.getstream!()

// Extract the bytes
let bytes = stream_obj.bigarray_of_stream!()
```

---

## Document Structure

PDF documents have a hierarchical structure rooted at the **document catalog**:

```
Document Catalog (/Type /Catalog)
  |
  +-- Pages Tree (/Type /Pages)
  |     |
  |     +-- Page 1 (/Type /Page)
  |     +-- Page 2 (/Type /Page)
  |     +-- ...
  |
  +-- Outlines (bookmarks)
  +-- Names (name trees)
  +-- ...
```

### The Trailer and Root

The trailer dictionary points to the root:

```
trailer
<<
  /Size 42
  /Root 1 0 R    <- Object 1 is the catalog
  /Info 2 0 R    <- Optional: document info
>>
```

### Document Catalog (Object 1)

```
1 0 obj
<<
  /Type /Catalog
  /Pages 3 0 R
>>
endobj
```

### Pages Tree (Object 3)

```
3 0 obj
<<
  /Type /Pages
  /Kids [4 0 R 5 0 R]   <- References to page objects
  /Count 2              <- Total number of pages
>>
endobj
```

### A Page (Object 4)

```
4 0 obj
<<
  /Type /Page
  /Parent 3 0 R
  /MediaBox [0 0 612 792]   <- Page size in points (8.5" x 11")
  /Contents 6 0 R           <- Drawing commands
  /Resources <<
    /Font << /F1 7 0 R >>
  >>
>>
endobj
```

---

## In-Memory Representation

The `Pdf` struct holds the entire document:

```mbt
pub(all) struct Pdf {
  major : Int              // PDF version major (e.g., 2)
  minor : Int              // PDF version minor (e.g., 0)
  root : Int               // Object number of document catalog
  objects : PdfObjects     // All objects in the document
  mut trailerdict : PdfObject
  was_linearized : Bool
  mut saved_encryption : SavedEncryption?
}
```

### The Object Store

All objects live in a map from object number to object data:

```mbt
pub type PdfObjMap = Map[Int, (Ref[ObjectData], Int)]
//                        ^     ^                ^
//                        |     |                generation number
//                        |     object data (with lazy parsing support)
//                        object number
```

Objects can be in different states:

```mbt
pub(all) enum ObjectData {
  Parsed(PdfObject)                // Already parsed
  ParsedAlreadyDecrypted(PdfObject)
  ToParse                          // Not yet parsed (lazy)
  ToParseFromObjectStream(...)     // In a compressed object stream
}
```

### Looking Up Objects

```mbt
// Get an object by number (parses if needed)
let obj = pdf.lookup_obj(5)

// Follow indirect references
let resolved = pdf.direct(obj)

// Look up a key in a dictionary, following indirects
match pdf.lookup_direct("/Type", some_dict) {
  Some(Name("/Page")) => println("It's a page!")
  _ => ()
}
```

### Adding Objects

```mbt
// Add an object, get its number
let objnum = pdf.addobj(
  PdfObject::Dictionary([
    ("/Type", PdfObject::Name("/Page")),
  ])
)

// Add with a specific number
pdf.addobj_given_num((42, PdfObject::Integer(100)))
```

---

## Putting It All Together

Here's a minimal PDF file and its in-memory representation:

### The File

```
%PDF-2.0
1 0 obj
<< /Type /Catalog /Pages 2 0 R >>
endobj
2 0 obj
<< /Type /Pages /Kids [3 0 R] /Count 1 >>
endobj
3 0 obj
<<
  /Type /Page
  /Parent 2 0 R
  /MediaBox [0 0 612 792]
  /Contents 4 0 R
>>
endobj
4 0 obj
<< /Length 44 >>
stream
BT /F1 12 Tf 100 700 Td (Hello World) Tj ET
endstream
endobj
xref
0 5
0000000000 65535 f
0000000009 00000 n
0000000058 00000 n
0000000115 00000 n
0000000214 00000 n
trailer
<< /Size 5 /Root 1 0 R >>
startxref
308
%%EOF
```

### In Memory

```mbt
let pdf : Pdf = {
  major: 2,
  minor: 0,
  root: 1,  // Object 1 is the catalog
  objects: /* contains: */
    // Object 1: Catalog
    // Object 2: Pages tree
    // Object 3: Page
    // Object 4: Content stream
  trailerdict: Dictionary([
    ("/Size", Integer(5)),
    ("/Root", Indirect(1)),
  ]),
  was_linearized: false,
  saved_encryption: None,
}

// Navigating the structure:
let catalog = pdf.lookup_obj(1)
// => Dictionary([("/Type", Name("/Catalog")), ("/Pages", Indirect(2))])

let pages = pdf.lookup_direct("/Pages", catalog)
// => Some(Dictionary([("/Type", Name("/Pages")), ...]))

let page_refs = pdf.lookup_direct("/Kids", pages.unwrap())
// => Some(Array([Indirect(3)]))
```

### Creating a PDF from Scratch

```mbt
// Create empty PDF
let pdf = Pdf::empty()

// Add a page dictionary
let page_num = pdf.addobj(Dictionary([
  ("/Type", Name("/Page")),
  ("/MediaBox", Array([Real(0), Real(0), Real(612), Real(792)])),
]))

// Add pages tree
let pages_num = pdf.addobj(Dictionary([
  ("/Type", Name("/Pages")),
  ("/Kids", Array([Indirect(page_num)])),
  ("/Count", Integer(1)),
]))

// Add catalog and set as root
let catalog_num = pdf.addobj(Dictionary([
  ("/Type", Name("/Catalog")),
  ("/Pages", Indirect(pages_num)),
]))
pdf.root = catalog_num
```

---

## Summary

| Concept | File Syntax | In-Memory Type |
|---------|-------------|----------------|
| Null | `null` | `PdfObject::Null` |
| Boolean | `true`, `false` | `PdfObject::Boolean(Bool)` |
| Integer | `42` | `PdfObject::Integer(Int)` |
| Real | `3.14` | `PdfObject::Real(Double)` |
| String | `(hello)`, `<48656C6C6F>` | `PdfObject::String(String)` |
| Name | `/Type` | `PdfObject::Name(String)` |
| Array | `[1 2 3]` | `PdfObject::Array(Array[PdfObject])` |
| Dictionary | `<< /Key value >>` | `PdfObject::Dictionary(Array[(String, PdfObject)])` |
| Stream | dictionary + `stream...endstream` | `PdfObject::Stream(Ref[(PdfObject, Stream)])` |
| Reference | `5 0 R` | `PdfObject::Indirect(Int)` |

Key operations:
- `pdf.lookup_obj(n)` - Get object by number
- `pdf.direct(obj)` - Follow indirect references
- `pdf.lookup_direct(key, dict)` - Look up dictionary key
- `pdf.addobj(obj)` - Add new object
- `stream.getstream!()` - Load stream data from disk

For more details, see:
- `core/pdf/pdf.mbt` - Core types and operations
- `core/pdf/README.mbt.md` - API reference with examples
- `docs/architecture.md` - Overall system architecture
