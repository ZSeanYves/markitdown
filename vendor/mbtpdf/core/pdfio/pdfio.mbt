///|
/// Distinguished value indicating "no more input".
pub let no_more : Int = -1

///|
/// Mutable byte buffer used throughout the port.
pub type MutableBytes = Array[Byte]

///|
/// Immutable core bytes type.
type CoreBytes = Bytes

///|
/// Input abstraction (seekable stream of bytes).
pub struct Input {
  pos_in : () -> Int
  seek_in : (Int) -> Unit
  input_char : () -> Char?
  input_byte : () -> Int
  in_channel_length : Int
  set_offset : (Int) -> Unit
  source : String
}

///|
/// Output abstraction (seekable stream of bytes).
pub struct Output {
  pos_out : () -> Int
  seek_out : (Int) -> Unit
  output_char : (Char) -> Unit
  output_byte : (Int) -> Unit
  output_string : (String) -> Unit
  out_channel_length : () -> Int
  flush : async () -> Unit
}

///|
/// Build bytes with the given size, filled with zero.
pub fn mkbytes(size : Int) -> MutableBytes {
  Array::make(size, (0).to_byte())
}

///|
/// Size of bytes.
pub fn bytes_size(bytes : MutableBytes) -> Int {
  bytes.length()
}

///|
/// Get the value at a position in bytes.
pub fn bget(bytes : MutableBytes, index : Int) -> Int {
  bytes[index].to_int()
}

///|
/// Like bget, but without bounds checking.
pub fn bget_unsafe(bytes : MutableBytes, index : Int) -> Int {
  bytes.unsafe_get(index).to_int()
}

///|
/// Set the value at a position in bytes.
pub fn bset(bytes : MutableBytes, index : Int, value : Int) -> Unit {
  bytes[index] = value.to_byte()
}

///|
/// Like bset, but without bounds checking.
pub fn bset_unsafe(bytes : MutableBytes, index : Int, value : Int) -> Unit {
  bytes.unsafe_set(index, value.to_byte())
}

///|
/// Make bytes from a string by taking the low 8 bits of each character.
pub fn bytes_of_string(s : String) -> MutableBytes {
  let out = Array::new(capacity=s.length())
  for ch in s {
    out.push(ch.to_int().to_byte())
  }
  out
}

///|
/// Make bytes from core bytes.
pub fn bytes_of_caml_bytes(bytes : CoreBytes) -> MutableBytes {
  bytes.to_array()
}

///|
/// Make bytes from an array of integers (each 0..255).
pub fn bytes_of_list(values : Array[Int]) -> MutableBytes {
  let out = Array::new(capacity=values.length())
  for v in values {
    out.push(v.to_byte())
  }
  out
}

///|
/// Make bytes from a character array.
pub fn bytes_of_charlist(values : Array[Char]) -> MutableBytes {
  let out = Array::new(capacity=values.length())
  for v in values {
    out.push(v.to_int().to_byte())
  }
  out
}

///|
/// Make bytes from a list of integer arrays.
pub fn bytes_of_arraylist(values : Array[Array[Int]]) -> MutableBytes {
  let mut total = 0
  for v in values {
    total = total + v.length()
  }
  let out = Array::new(capacity=total)
  for v in values {
    for x in v {
      out.push(x.to_byte())
    }
  }
  out
}

///|
/// Make bytes from an integer array.
pub fn bytes_of_int_array(values : Array[Int]) -> MutableBytes {
  bytes_of_list(values)
}

///|
/// Integer array from bytes.
pub fn int_array_of_bytes(bytes : MutableBytes) -> Array[Int] {
  bytes.map(b => b.to_int())
}

///|
/// Integer array from a string (byte-wise).
pub fn int_array_of_string(s : String) -> Array[Int] {
  bytes_of_string(s).map(b => b.to_int())
}

///|
/// String from a list of integer arrays.
pub fn string_of_int_arrays(values : Array[Array[Int]]) -> String {
  string_of_int_array(values.flatten())
}

///|
/// String from a single int array.
pub fn string_of_int_array(values : Array[Int]) -> String {
  string_of_bytes(bytes_of_list(values))
}

///|
/// Make a string by mapping each byte to a single character.
pub fn string_of_bytes(bytes : MutableBytes) -> String {
  let chars = Array::new(capacity=bytes.length())
  for b in bytes {
    chars.push(b.to_char())
  }
  String::from_array(chars)
}

///|
/// Make a character array from bytes.
pub fn charlist_of_bytes(bytes : MutableBytes) -> Array[Char] {
  bytes.map(b => b.to_char())
}

///|
/// Copy bytes.
pub fn copybytes(bytes : MutableBytes) -> MutableBytes {
  bytes.copy()
}

///|
/// Build an input from bytes.
pub fn Input::of_bytes(
  bytes : MutableBytes,
  source? : String = "bytes",
) -> Input {
  let mut pos = 0
  let mut offset = 0
  let len = bytes.length()
  let input_int = () => {
    let result = if pos > len - 1 { no_more } else { bget_unsafe(bytes, pos) }
    pos = pos + 1
    result
  }
  {
    pos_in: () => pos - offset,
    seek_in: p => pos = p + offset,
    input_char: () => {
      let v = input_int()
      if v == no_more {
        None
      } else {
        Some(v.to_byte().to_char())
      }
    },
    input_byte: input_int,
    in_channel_length: len,
    set_offset: o => if offset == 0 { offset = o },
    source,
  }
}

///|
/// Build an input from a string.
pub fn Input::of_string(s : String, source? : String = "string") -> Input {
  Input::of_bytes(bytes_of_string(s), source~)
}

///|
/// Build an output backed by an external `write_at` function.
///
/// The output uses an internal growable buffer. `flush` writes the full buffer
/// from the beginning (position 0).
pub fn Output::of_write_at(
  write_at : async (BytesView, Int64) -> Unit,
) -> Output {
  let mut pos = 0
  let mut highest_written = -1
  let single : MutableBytes = mkbytes(1)
  let buffer : Ref[MutableBytes] = { val: mkbytes(4096) }
  let output_bytes = (bytes : Bytes) => {
    for b in bytes {
      if pos > buffer.val.length() - 1 {
        let new_len = if pos * 2 > 0 { pos * 2 } else { 1 }
        let new_bytes = mkbytes(new_len)
        buffer.val[:].blit_to(new_bytes)
        buffer.val = new_bytes
      }
      buffer.val.unsafe_set(pos, b)
      pos = pos + 1
    }
    let last = pos - 1
    highest_written = if highest_written > last {
      highest_written
    } else {
      last
    }
  }
  async fn flush_output() -> Unit {
    let out = mkbytes(pos)
    buffer.val[:pos].blit_to(out)
    let bytes = Bytes::from_array(out)
    write_at(bytes[:], 0)
  }

  {
    pos_out: () => pos,
    seek_out: p => pos = p,
    output_char: c => {
      single[0] = c.to_int().to_byte()
      output_bytes(Bytes::from_array(single))
    },
    output_byte: b => {
      single[0] = b.to_byte()
      output_bytes(Bytes::from_array(single))
    },
    output_string: s => output_bytes(Bytes::from_array(bytes_of_string(s))),
    out_channel_length: () => highest_written + 1,
    flush: flush_output,
  }
}

///|
/// Build an input-output, with an initial buffer size.
pub fn Output::of_bytes(size : Int) -> (Output, Ref[MutableBytes]) {
  let data : Ref[MutableBytes] = { val: mkbytes(size) }
  (output_of_bytes(data), data)
}

///|
/// Extract the contents of an input-output in bytes.
pub fn Output::extract_bytes(
  self : Output,
  data : Ref[MutableBytes],
) -> MutableBytes {
  let len = (self.pos_out)()
  let out = mkbytes(len)
  for i in 0..<len {
    bset_unsafe(out, i, bget_unsafe(data.val, i))
  }
  out
}

///|
/// Move forward one byte.
pub fn Input::nudge(self : Input) -> Unit {
  ignore((self.input_byte)())
}

///|
/// Move backward one byte.
pub fn Input::rewind(self : Input) -> Unit {
  let pos = (self.pos_in)()
  if pos <= 0 {
    (self.seek_in)(0)
  } else {
    (self.seek_in)(pos - 1)
  }
}

///|
/// Look at the next character without advancing the pointer.
pub fn Input::peek_char(self : Input) -> Char? {
  let r = (self.input_char)()
  self.rewind()
  r
}

///|
/// Look at the next byte without advancing the pointer.
pub fn Input::peek_byte(self : Input) -> Int {
  let r = (self.input_byte)()
  self.rewind()
  r
}

///|
/// Read the previous character, moving the pointer back one.
pub fn Input::read_char_back(self : Input) -> Char? {
  let pos = (self.pos_in)()
  if pos <= 0 {
    return None
  }
  (self.seek_in)(pos - 1)
  let chr = (self.input_char)()
  (self.seek_in)(pos - 1)
  chr
}

///|
/// Read a line from an input (newline not included).
pub fn Input::read_line(self : Input) -> String raise {
  let sb = StringBuilder::new()
  fn read_more(
    sb : StringBuilder,
    saw_any : Bool,
    input : Input,
  ) -> String raise {
    match (input.input_char)() {
      None => if saw_any { sb.to_string() } else { fail("End_of_file") }
      Some('\n') => sb.to_string()
      Some(ch) => {
        sb.write_char(ch)
        read_more(sb, true, input)
      }
    }
  }

  read_more(sb, false, self)
}

///|
/// Read all lines from an input.
pub fn Input::read_lines(self : Input) -> Array[String] raise {
  let lines = Array::new()
  fn read_all(lines : Array[String], input : Input) -> Array[String] raise {
    match input.peek_char() {
      None => lines
      Some(_) => {
        lines.push(input.read_line())
        read_all(lines, input)
      }
    }
  }

  read_all(lines, self)
}

///|
/// Set bytes o..o+l-1 from input.
pub fn Input::setinit(
  self : Input,
  bytes : MutableBytes,
  offset : Int,
  length : Int,
) -> Unit raise {
  if length == 0 {
    return
  }
  let max = bytes.length() - 1
  let last = offset + length - 1
  if offset > max || offset < 0 || last < 0 || last > max {
    fail("setinit")
  }
  for i = offset; i < offset + length; i = i + 1 {
    bytes[i] = (self.input_byte)().to_byte()
  }
}

///|
/// Bytes with input o..o+l-1.
pub fn Input::bytes_of_input(
  self : Input,
  offset : Int,
  length : Int,
) -> MutableBytes raise {
  (self.seek_in)(offset)
  let out = mkbytes(length)
  self.setinit(out, 0, length)
  out
}

///|
/// String of input contents.
pub fn Input::to_string(self : Input) -> String raise {
  string_of_bytes(self.bytes_of_input(0, self.in_channel_length))
}

///|
/// Write bytes o..o+l-1 to output.
pub fn Output::getinit(
  self : Output,
  bytes : MutableBytes,
  offset : Int,
  length : Int,
) -> Unit raise {
  if length == 0 {
    return
  }
  let max = bytes.length() - 1
  let last = offset + length - 1
  if offset > max || offset < 0 || last < 0 || last > max {
    fail("getinit")
  }
  for i = offset; i < offset + length; i = i + 1 {
    (self.output_byte)(bget_unsafe(bytes, i))
  }
}

///|
/// Most-significant-bit-first bitstream over an Input.
pub struct Bitstream {
  input : Input
  mut curr_byte : Int
  mut bit : Int
  mut bits_read : Int
}

///|
/// Position token for Bitstream; details will evolve during implementation.
pub struct BitstreamPosition {
  pos : Int
  curr_byte : Int
  bit : Int
  bits_read : Int
} derive(Debug)

///|
/// Most-significant-bit-first write bitstream (placeholder).
pub struct BitstreamWrite {
  bytes : MutableBytes
  mut bit : Int
} derive(Debug)

///|
/// Build a bitstream from an input.
pub fn Bitstream::of_input(input : Input) -> Bitstream {
  { input, curr_byte: 0, bit: 0, bits_read: 0 }
}

///|
/// Get the current position of a bitstream.
pub fn Bitstream::position(self : Bitstream) -> BitstreamPosition {
  {
    pos: (self.input.pos_in)(),
    curr_byte: self.curr_byte,
    bit: self.bit,
    bits_read: self.bits_read,
  }
}

///|
/// Seek to a previous bitstream position.
pub fn Bitstream::seek(self : Bitstream, pos : BitstreamPosition) -> Unit {
  (self.input.seek_in)(pos.pos)
  self.curr_byte = pos.curr_byte
  self.bit = pos.bit
  self.bits_read = pos.bits_read
}

///|
/// Read the next bit from a bitstream.
pub fn Bitstream::getbit(self : Bitstream) -> Bool raise {
  if self.bit == 0 {
    let value = (self.input.input_byte)()
    if value == no_more {
      fail("End_of_file")
    }
    self.curr_byte = value
    self.bit = 128
  }
  let result = (self.curr_byte & self.bit) > 0
  self.bits_read = self.bits_read + 1
  self.bit = self.bit / 2
  result
}

///|
/// Read the next bit as an integer, 0 or 1.
pub fn Bitstream::getbitint(self : Bitstream) -> Int raise {
  if self.getbit() {
    1
  } else {
    0
  }
}

///|
/// Align a bitstream to the next byte boundary.
pub fn Bitstream::align(self : Bitstream) -> Unit {
  if self.bit > 0 {
    self.bits_read = (self.bits_read / 8 + 1) * 8
    self.bit = 0
  }
}

///|
/// Make a new write bitstream.
pub fn BitstreamWrite::new() -> BitstreamWrite {
  { bytes: Array::new(), bit: 0 }
}

///|
/// Put a single bit into a write bitstream.
pub fn BitstreamWrite::putbit(self : BitstreamWrite, bit : Int) -> Unit {
  if self.bit == 0 {
    self.bytes.push((0).to_byte())
  }
  let idx = self.bytes.length() - 1
  if bit == 1 {
    let curr = self.bytes[idx].to_int()
    let mask = 1 << (7 - self.bit)
    self.bytes[idx] = (curr | mask).to_byte()
  }
  self.bit = self.bit + 1
  if self.bit == 8 {
    self.bit = 0
  }
}

///|
/// Put a multi-bit value into a write bitstream.
pub fn BitstreamWrite::putval(
  self : BitstreamWrite,
  bits : Int,
  value : Int,
) -> Unit raise {
  if bits < 0 || bits > 32 {
    fail("putval")
  }
  if bits == 0 {
    return
  }
  for i in (bits - 1)>=..0 {
    self.putbit((value >> i) & 1)
  }
}

///|
/// Align a write bitstream to the next byte boundary.
pub fn BitstreamWrite::align(self : BitstreamWrite) -> Unit {
  if self.bit > 0 {
    while self.bit != 0 {
      self.putbit(0)
    }
  }
}

///|
/// Extract bytes from a write bitstream, padding with zeros.
pub fn BitstreamWrite::bytes(self : BitstreamWrite) -> MutableBytes {
  self.align()
  self.bytes.copy()
}

///|
/// Internal output builder over bytes.
fn output_of_bytes(data : Ref[MutableBytes]) -> Output {
  let mut pos = 0
  let mut highest_written = -1
  let output_int = (value : Int) => if pos > data.val.length() - 1 {
    let new_len = if pos * 2 > 0 { pos * 2 } else { 1 }
    let new_bytes = mkbytes(new_len)
    data.val[:].blit_to(new_bytes)
    bset_unsafe(new_bytes, pos, value)
    highest_written = if highest_written > pos { highest_written } else { pos }
    pos = pos + 1
    data.val = new_bytes
  } else {
    highest_written = if highest_written > pos { highest_written } else { pos }
    bset_unsafe(data.val, pos, value)
    pos = pos + 1
  }
  {
    pos_out: () => pos,
    seek_out: p => pos = p,
    output_char: c => output_int(c.to_int()),
    output_string: s => {
      let bytes = bytes_of_string(s)
      for b in bytes {
        output_int(b.to_int())
      }
    },
    output_byte: output_int,
    out_channel_length: () => highest_written + 1,
    flush: noop_flush,
  }
}

///|
/// No-op flush for in-memory outputs.
#warnings("-unused_async")
async fn noop_flush() -> Unit {
  ()
}

///|
fn debug_next_char(input : Input) -> Unit {
  match (input.input_char)() {
    Some(chr) => @pdfe.log("\{chr} = \{chr.to_int()}\n")
    None => ()
  }
}

///|
/// Debug the next `count` characters to the log and rewind.
pub fn debug_next_n_chars(count : Int, input : Input) -> Unit {
  let mut i = 0
  while i < count {
    debug_next_char(input)
    i = i + 1
  }
  @pdfe.log("\n")
  let mut rewind_count = 0
  while rewind_count < count {
    input.rewind()
    rewind_count = rewind_count + 1
  }
}
