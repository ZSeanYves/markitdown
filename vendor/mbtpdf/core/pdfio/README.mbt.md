# pdfio

Low-level I/O primitives for reading and writing PDF byte streams.

## Overview

The `pdfio` package provides the fundamental I/O abstractions used throughout the PDF library. It defines:

- **MutableBytes**: The primary byte buffer type
- **Input**: Seekable input stream abstraction
- **Output**: Seekable output stream abstraction
- **Bitstream**: MSB-first bit-level reading and writing

## Byte Buffer Types

```mbt nocheck
///|
pub type MutableBytes = Array[Byte]

///|
pub type CoreBytes = Bytes

///|
pub type RawBytes = MutableBytes
```

### Creating Buffers

```mbt check
///|
test "mkbytes creates zero-filled buffer" {
  let bytes = @pdfio.mkbytes(10)
  inspect(bytes.length(), content="10")
  inspect(@pdfio.bget(bytes, 0), content="0")
}
```

### Byte Access

```mbt check
///|
test "bget and bset" {
  let bytes = @pdfio.mkbytes(4)
  @pdfio.bset(bytes, 0, 65)
  @pdfio.bset(bytes, 1, 66)
  inspect(@pdfio.bget(bytes, 0), content="65")
  inspect(@pdfio.bget(bytes, 1), content="66")
}
```

### Conversions

```mbt check
///|
test "bytes_of_string and string_of_bytes" {
  let bytes = @pdfio.bytes_of_string("ABC")
  inspect(@pdfio.bytes_size(bytes), content="3")
  let s = @pdfio.string_of_bytes(bytes)
  inspect(s, content="ABC")
}
```

```mbt check
///|
test "bytes_of_list" {
  let bytes = @pdfio.bytes_of_list([65, 66, 67])
  inspect(@pdfio.string_of_bytes(bytes), content="ABC")
}
```

```mbt check
///|
test "int_array_of_bytes" {
  let bytes = @pdfio.bytes_of_string("Hi")
  let ints = @pdfio.int_array_of_bytes(bytes)
  inspect(ints, content="[72, 105]")
}
```

### Copying

```mbt check
///|
test "copybytes creates independent copy" {
  let original = @pdfio.bytes_of_string("test")
  let copy = @pdfio.copybytes(original)
  @pdfio.bset(copy, 0, 88)
  inspect(@pdfio.bget(original, 0), content="116") // unchanged
  inspect(@pdfio.bget(copy, 0), content="88")
}
```

## Input Streams

The `Input` struct provides a seekable byte stream:

```mbt nocheck
///|
pub struct Input {
  pos_in : () -> Int // Current position
  seek_in : (Int) -> Unit // Seek to position
  input_char : () -> Char? // Read next char
  input_byte : () -> Int // Read next byte
  in_channel_length : Int // Total length
  set_offset : (Int) -> Unit // Set base offset
  source : String // Source description
}
```

### Creating Input from Bytes

```mbt check
///|
test "input_of_bytes" {
  let bytes = @pdfio.bytes_of_string("Hello")
  let input = @pdfio.Input::of_bytes(bytes)
  inspect(input.in_channel_length, content="5")
  inspect((input.input_byte)(), content="72") // 'H'
  inspect((input.input_byte)(), content="101") // 'e'
}
```

### Creating Input from String

```mbt check
///|
test "input_of_string" {
  let input = @pdfio.Input::of_string("ABC")
  inspect((input.input_char)(), content="Some('A')")
  inspect((input.input_char)(), content="Some('B')")
}
```

### Peeking and Rewinding

```mbt check
///|
test "peek_byte does not advance" {
  let input = @pdfio.Input::of_string("XY")
  let first = input.peek_byte()
  let second = input.peek_byte()
  inspect(first, content="88") // 'X'
  inspect(second, content="88") // still 'X'
}
```

### Reading Lines

```mbt check
///|
test "read_line" {
  let input = @pdfio.Input::of_string("line1\nline2\n")
  inspect(input.read_line(), content="line1")
  inspect(input.read_line(), content="line2")
}
```

### Extracting Bytes from Input

```mbt check
///|
test "bytes_of_input extracts range" {
  let input = @pdfio.Input::of_string("Hello World")
  let bytes = input.bytes_of_input(0, 5)
  inspect(@pdfio.string_of_bytes(bytes), content="Hello")
}
```

## Output Streams

The `Output` struct provides a seekable output stream:

```mbt nocheck
///|
pub struct Output {
  pos_out : () -> Int // Current position
  seek_out : (Int) -> Unit // Seek to position
  output_char : (Char) -> Unit // Write char
  output_byte : (Int) -> Unit // Write byte
  output_string : (String) -> Unit // Write string
  out_channel_length : () -> Int // Written length
  flush : async () -> Unit // Flush buffer
}
```

### Creating Output Buffers

```mbt check
///|
test "input_output_of_bytes" {
  let (output, data) = @pdfio.Output::of_bytes(16)
  (output.output_string)("test")
  let bytes = output.extract_bytes(data)
  inspect(@pdfio.string_of_bytes(bytes), content="test")
}
```

## Native File/Channel IO

`core/pdfio` is intentionally focused on in-memory `Input`/`Output` and byte
utilities.

For native `@fs.File` helpers (read whole file/channel into memory, or create an
`Output` backed by a channel), use `io/pdfiofs`.

## Bitstreams

For reading data at the bit level (MSB-first order).

### Creating a Bitstream

```mbt nocheck
///|
test "bitstream reading" {
  // Byte 0xA5 = 10100101 in binary
  let input = @pdfio.Input::of_bytes(@pdfio.bytes_of_list([0xA5]))
  let bits = @pdfio.Bitstream::of_input(input)

  // Read first 4 bits: 1010 = 10
  let val = getval_32(bits, 4) // internal function
  inspect(val, content="10")
}
```

### Bit-Level Reading

```mbt check
///|
test "getbit reads individual bits" {
  let input = @pdfio.Input::of_bytes(@pdfio.bytes_of_list([0x80])) // 10000000
  let bits = @pdfio.Bitstream::of_input(input)
  inspect(bits.getbit(), content="true") // bit 7
  inspect(bits.getbit(), content="false") // bit 6
}
```

### Bitstream Position

```mbt nocheck
///|
test "bitstream save and restore" {
  let input = @pdfio.Input::of_bytes(@pdfio.bytes_of_list([0xFF, 0x00]))
  let bits = @pdfio.Bitstream::of_input(input)
  let pos = bits.position()
  ignore(getval_32(bits, 8)) // read 8 bits (internal function)
  bits.seek(pos) // rewind
  inspect(getval_32(bits, 8), content="255") // read again
}
```

### Alignment

```mbt nocheck
///|
test "align skips to next byte" {
  let input = @pdfio.Input::of_bytes(@pdfio.bytes_of_list([0xFF, 0xAB]))
  let bits = @pdfio.Bitstream::of_input(input)
  ignore(bits.getbit()) // read 1 bit
  bits.align() // skip to byte boundary
  inspect(getval_32(bits, 8), content="171") // 0xAB (internal function)
}
```

### Write Bitstreams

```mbt check
///|
test "write bitstream" {
  let b = @pdfio.BitstreamWrite::new()
  b.putval(4, 0b1010) // write 4 bits: 1010
  b.putval(4, 0b0101) // write 4 bits: 0101
  let bytes = b.bytes()
  inspect(@pdfio.bget(bytes, 0), content="165") // 0xA5
}
```

## Constants

```mbt nocheck
///|
pub let no_more : Int = -1 // Indicates end of input
```

## Utility Functions

### Transform Bytes In-Place (Internal)

```mbt nocheck
///|
test "bytes_selfmap transforms each byte" {
  let bytes = @pdfio.bytes_of_list([1, 2, 3])
  bytes_selfmap(fn(x) { x * 2 }, bytes) // internal function
  inspect(@pdfio.int_array_of_bytes(bytes), content="[2, 4, 6]")
}
```

### Fill Bytes (Internal)

```mbt nocheck
///|
test "fillbytes sets all bytes" {
  let bytes = @pdfio.mkbytes(3)
  fillbytes(42, bytes) // internal function
  inspect(@pdfio.int_array_of_bytes(bytes), content="[42, 42, 42]")
}
```
