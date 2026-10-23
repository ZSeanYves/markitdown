// Vendored from moonbit-community/flate@0.8.5, revision
// 3cbcb5c8bde0b34117fd7980b9f41719f2b8f3d7. Apache-2.0.
// See LICENSE, NOTICE and UPSTREAM.md for exact source hashes and local changes.

// Streaming, suspendable DEFLATE decoder (RFC 1951)
//
// Suspension model:
//  - Input: each block header and each literal/match "unit" is decoded
//    atomically. A bit read past the end of the current input raises the
//    internal `NeedInput`; the decoder rewinds that unit and owns its bounded
//    byte tail, so `step` can accept non-overlapping chunks and resume once more
//    input arrives.
//  - Output: a unit needs room for only its first byte; a match longer than the
//    remaining output is copied in pieces, with `copy_remaining`/`copy_dist`
//    carrying the rest to the next `step`. Match and stored data are moved in
//    contiguous window segments, then drained to the caller's output view.
//  - Back-references read from a 32 KB circular history window.

///|
/// Stable classification for failures raised by the raw DEFLATE APIs.
pub(all) enum InflateErrorKind {
  /// Physical input ended before a complete raw DEFLATE stream.
  Truncated
  /// The raw stream violates RFC 1951 structure or coding rules.
  Corrupt
  /// Exact decoding reached a valid final block before the input boundary.
  TrailingData
  /// Decoded output would exceed the caller-supplied safety limit.
  OutputLimitExceeded
  /// A caller-supplied cancellation callback requested an early stop.
  Cancelled
} derive(Eq, Debug)

///|
pub extend InflateErrorKind with Eq::{not_equal, equal}

///|
pub extend InflateErrorKind with Debug::{to_repr}

///|
/// Error raised while decoding a raw DEFLATE stream.
pub suberror InflateError {
  InflateError(InflateErrorKind, String)
}

///|
/// Internal control-flow signal: the current input view was exhausted mid-unit.
priv suberror NeedInput

///|
/// Total classification of every error that can cross one atomic streaming
/// decode boundary. Unknown future error kinds become the stable public
/// corruption diagnostic instead of leaking through `Inflater::step`.
priv enum DecoderErrorClass {
  DecoderInputExhausted
  DecoderFailure(InflateErrorKind, String)
}

///|
#coverage.skip
fn classify_decoder_error(err : Error) -> DecoderErrorClass {
  match err {
    NeedInput => DecoderInputExhausted
    InflateError(kind, message) => DecoderFailure(kind, message)
    _ => DecoderFailure(Corrupt, "corrupt: unexpected decoder error")
  }
}

///|
priv enum Mode {
  AtBlock // about to read the next block header
  InStored // copying a stored block (stored_remaining bytes left)
  InHuffman // decoding literal/match units with hl/hd
  Done
}

///|
/// Streaming DEFLATE decompressor (RFC 1951): a push-based, suspendable state
/// machine. All cross-call state lives here, so it pauses on
/// `NeedMoreInput`/`NeedMoreOutput` and resumes on the next `step`.  Supports stored, fixed- and dynamic-Huffman
/// blocks. `step` makes progress with as little as one byte of output room
/// (the `output` view): a match too large for the buffer is copied in
/// pieces across calls.
pub struct Inflater {
  priv mut mode : Mode
  priv mut bitbuf : Int32 // LSB-first bit accumulator
  priv mut bit_count : Int32
  priv mut final_block : Bool
  priv mut stored_remaining : Int32
  priv mut hl : HuffmanDecoder? // literal/length table (None until a block sets it)
  priv mut hd : HuffmanDecoder? // distance table (None => fixed 5-bit distances)
  priv mut hd_fixed : Bool
  priv window : FixedArray[Byte] // 32 KB circular history
  priv mut wpos : Int32 // total bytes ever written; window index = wpos & 32767
  priv mut filled : Bool // window has held >= 32 KB, so any distance <= 32768 is valid
  priv dyn_litlen : HuffmanDecoder // dynamic literal/length (and code-length) table
  priv dyn_dist : HuffmanDecoder // dynamic distance table
  priv clbits : FixedArray[Int32]
  priv codebits : FixedArray[Int32]
  // A match copy in progress, suspended because the output filled mid-copy.
  // `copy_remaining` bytes are still owed at back-distance `copy_dist`; the
  // next `step` drains them before decoding any new unit. This is what lets
  // the decoder make progress into an output buffer as small as one byte.
  priv mut copy_remaining : Int32
  priv mut copy_dist : Int32
  // Bytes belonging to one incomplete atomic unit. Owning this bounded tail
  // lets callers drop every byte reported as consumed instead of re-presenting
  // a growing view on NeedMoreInput.
  priv mut staged_input : Array[Byte]
  priv mut staged_pos : Int32
  priv mut ending : Bool // physical EOF has been declared by the caller
  priv mut failure_kind : InflateErrorKind? // stable terminal error
  priv mut failure_message : String
  priv mut step_consumed : Int32 // latest step's input position, including failure
  priv mut step_produced : Int32 // output written by the latest step, including failure
  // Step-local cursors (reset on each `step`).
  priv mut view : BytesView
  priv mut in_pos : Int32
  priv mut out_pos : Int32
  priv mut out : MutArrayView[Byte]
  priv mut fixed_out : FixedArray[Byte]?
  priv mut out_end : Int32 // one past the last writable index in `out`
  priv empty_out : FixedArray[Byte]
}

///|
/// Create a fresh decompressor positioned at the start of a DEFLATE stream.
/// If supplied, `dictionary` preloads the history window with its final 32 KiB.
pub fn Inflater::Inflater(dictionary? : BytesView) -> Inflater {
  let empty_out = FixedArray::make(0, b'\x00')
  let inflater : Inflater = {
    mode: AtBlock,
    bitbuf: 0,
    bit_count: 0,
    final_block: false,
    stored_remaining: 0,
    hl: None,
    hd: None,
    hd_fixed: false,
    window: FixedArray::make(WINDOW_SIZE, b'\x00'),
    wpos: 0,
    filled: false,
    dyn_litlen: HuffmanDecoder(),
    dyn_dist: HuffmanDecoder(),
    clbits: FixedArray::make(MAX_NUM_LIT + MAX_NUM_DIST, 0),
    codebits: FixedArray::make(NUM_CODES, 0),
    copy_remaining: 0,
    copy_dist: 0,
    staged_input: [],
    staged_pos: 0,
    ending: false,
    failure_kind: None,
    failure_message: "",
    step_consumed: 0,
    step_produced: 0,
    view: b""[:],
    in_pos: 0,
    out_pos: 0,
    out: empty_out.mut_view(),
    fixed_out: None,
    out_end: 0,
    empty_out,
  }
  if dictionary is Some(dict) {
    inflater.preload_dictionary(dict)
  }
  inflater
}

///|
/// Whether the end of the DEFLATE stream has been reached.
pub fn Inflater::is_finished(self : Inflater) -> Bool {
  self.mode is Done
}

///|
/// Input position of the latest step before cleanup, including a failing
/// call. Zero initially, after reset, and for a repeated terminal failure.
pub fn Inflater::last_consumed(self : Inflater) -> Int32 {
  self.step_consumed
}

///|
/// Number of bytes physically written by the latest step, including a
/// failing call. Failed output is unvalidated and must never be delivered.
/// Zero initially, after reset, and for a repeated terminal failure.
pub fn Inflater::last_produced(self : Inflater) -> Int32 {
  self.step_produced
}

///|
/// Preload the history window with the final 32 KiB of a preset dictionary.
fn Inflater::preload_dictionary(self : Inflater, dict : BytesView) -> Unit {
  let start = (dict.length() - WINDOW_SIZE).max(0)
  // Construction and reset both start with an empty history window.
  self.window.blit_from_bytesview(0, dict[start:])
  self.wpos = dict.length() - start
  self.filled = self.wpos == WINDOW_SIZE
}

///|
/// Reset to the start of a fresh DEFLATE stream, reusing allocations (the
/// 32 KB window and Huffman table storage) across many streams (e.g. ZIP
/// entries). The stale window contents are unreachable afterwards: any
/// distance reaching past the new stream's start is rejected (`dist > wpos`).
/// Pass `dictionary` to preload the fresh stream's history window.
pub fn Inflater::reset(self : Inflater, dictionary? : BytesView) -> Unit {
  self.mode = AtBlock
  self.bitbuf = 0
  self.bit_count = 0
  self.final_block = false
  self.stored_remaining = 0
  self.hl = None
  self.hd = None
  self.hd_fixed = false
  self.wpos = 0
  self.filled = false
  self.copy_remaining = 0
  self.copy_dist = 0
  self.staged_input.clear()
  self.staged_pos = 0
  self.ending = false
  self.failure_kind = None
  self.failure_message = ""
  self.step_consumed = 0
  self.step_produced = 0
  self.view = b""[:]
  self.in_pos = 0
  self.out_pos = 0
  self.out = self.empty_out.mut_view()
  self.fixed_out = None
  self.out_end = 0
  if dictionary is Some(dict) {
    self.preload_dictionary(dict)
  }
}

// ---- bit reader (raises NeedInput when the current view is exhausted) ----

///|
/// Take the next byte from the staged atomic tail or the external view.
fn Inflater::next_fill_byte(self : Inflater) -> Byte? {
  if self.staged_pos < self.staged_input.length() {
    let byte = self.staged_input[self.staged_pos]
    self.staged_pos = self.staged_pos + 1
    Some(byte)
  } else if self.in_pos < self.view.length() {
    let byte = self.view[self.in_pos]
    self.in_pos = self.in_pos + 1
    Some(byte)
  } else {
    None
  }
}

///|
fn Inflater::fill(self : Inflater, n : Int32) -> Unit raise NeedInput {
  while self.bit_count < n {
    guard self.next_fill_byte() is Some(b) else { raise NeedInput }
    self.bitbuf = self.bitbuf | (b.to_int() << self.bit_count)
    self.bit_count = self.bit_count + 8
  }
}

///|
fn Inflater::read_bits(self : Inflater, n : Int32) -> Int32 raise NeedInput {
  self.fill(n)
  let v = self.bitbuf & ((1 << n) - 1)
  self.bitbuf = self.bitbuf >> n
  self.bit_count = self.bit_count - n
  v
}

///|
fn Inflater::huff_sym(self : Inflater, h : HuffmanDecoder) -> Int32 raise {
  let mut n = h.min
  for ;; {
    self.fill(n)
    let mut chunk = h.chunks[self.bitbuf & 0x1FF]
    n = (chunk & 0xF).reinterpret_as_int()
    if n > HUFFMAN_CHUNK_BITS {
      let link = ((self.bitbuf >> HUFFMAN_CHUNK_BITS).reinterpret_as_uint() &
      h.link_mask).reinterpret_as_int()
      chunk = h.links[(chunk >> HUFFMAN_VALUE_SHIFT).reinterpret_as_int() + link]
      n = (chunk & 0xF).reinterpret_as_int()
    }
    if n <= self.bit_count {
      if n == 0 {
        raise InflateError(Corrupt, "corrupt: bad Huffman code")
      }
      self.bitbuf = self.bitbuf >> n
      self.bit_count = self.bit_count - n
      return (chunk >> HUFFMAN_VALUE_SHIFT).reinterpret_as_int()
    }
  }
}

// ---- output + window ----

///|
/// Emit one decoded byte to the output buffer and the history window. The
/// caller guarantees output room before starting a unit / each stored byte.
fn Inflater::emit(self : Inflater, b : Byte) -> Unit {
  // The caller checks `out_pos < out_end` before every emit.
  self.out.unsafe_set(self.out_pos, b)
  self.out_pos = self.out_pos + 1
  self.window[self.wpos & (WINDOW_SIZE - 1)] = b
  self.wpos = self.wpos + 1
  if !self.filled && self.wpos >= WINDOW_SIZE {
    self.filled = true
  }
}

// ---- block handling ----

///|
/// Translate an error raised by the streaming decoder's bit reader inside the
/// shared dynamic header decoder into the uniform `InflateError` it requires.
/// `NeedInput` becomes `Truncated` so the caller can recognize the suspension
/// at its own boundary.
#coverage.skip
fn streaming_header_error(err : Error) -> InflateError {
  match err {
    NeedInput => InflateError(Truncated, "unexpected end of input")
    InflateError(kind, message) => InflateError(kind, message)
    _ => InflateError(Corrupt, "corrupt: unexpected decoder error")
  }
}

///|
fn Inflater::read_dynamic(self : Inflater) -> Unit raise {
  let (nlit, ndist) = decode_dynamic_header(
    n => {
      self.read_bits(n) catch {
        NeedInput => raise InflateError(Truncated, "unexpected end of input")
      }
    },
    () => {
      self.huff_sym(self.dyn_litlen) catch {
        err => raise streaming_header_error(err)
      }
    },
    self.dyn_litlen,
    self.codebits,
    self.clbits,
  ) catch {
    // A truncated dynamic header is a suspension, not a failure, in the
    // streaming decoder: rewind to the block start and wait for more input.
    InflateError(Truncated, _) => raise NeedInput
    InflateError(kind, message) => raise InflateError(kind, message)
  }
  guard self.dyn_litlen.initialize(self.clbits[0:nlit]) else {
    raise InflateError(Corrupt, "corrupt: bad literal/length tree")
  }
  guard self.dyn_dist.initialize(self.clbits[nlit:nlit + ndist]) else {
    raise InflateError(Corrupt, "corrupt: bad distance tree")
  }
}

///|
/// Install the Huffman tables for a fixed or dynamic block.
fn Inflater::enter_huffman_mode(
  self : Inflater,
  hl : HuffmanDecoder,
  hd : HuffmanDecoder?,
  fixed : Bool,
) -> Unit {
  self.hl = Some(hl)
  self.hd = hd
  self.hd_fixed = fixed
  self.mode = InHuffman
}

///|
/// Read the next block's header (and, for dynamic blocks, its Huffman tables).
/// Atomic w.r.t. input: raises `NeedInput` to be retried from the block start.
fn Inflater::parse_block_header(self : Inflater) -> Unit raise {
  self.fill(3)
  self.final_block = (self.bitbuf & 1) == 1
  let btype = (self.bitbuf >> 1) & 3
  self.bitbuf = self.bitbuf >> 3
  self.bit_count = self.bit_count - 3
  match btype {
    0 => {
      let drop = self.bit_count & 7
      self.bitbuf = self.bitbuf >> drop
      self.bit_count = self.bit_count - drop
      let len = self.read_bits(16)
      let nlen = self.read_bits(16)
      validate_stored_length(len, nlen)
      self.stored_remaining = len
      self.mode = InStored
    }
    1 => self.enter_huffman_mode(fixed_huffman_decoder, None, true)
    2 => {
      self.read_dynamic()
      self.enter_huffman_mode(self.dyn_litlen, Some(self.dyn_dist), false)
    }
    _ => raise InflateError(Corrupt, "corrupt: reserved block type")
  }
}

///|
/// Take the next stored-block byte once byte-aligned: drain the accumulator
/// first, then the staged tail or input view. Returns None when input is
/// exhausted.
fn Inflater::next_stored_byte(self : Inflater) -> Byte? {
  if self.bit_count >= 8 {
    let b = (self.bitbuf & 0xFF).to_byte()
    self.bitbuf = self.bitbuf >> 8
    self.bit_count = self.bit_count - 8
    Some(b)
  } else {
    self.next_fill_byte()
  }
}

///|
/// Preserve the unconsumed tail of an incomplete atomic unit. Every byte from
/// the external view is then either permanently decoded or owned here, so the
/// public call may report that complete view as consumed.
fn Inflater::stage_incomplete_input(self : Inflater) -> Unit {
  let kept = self.staged_input[self.staged_pos:].to_owned()
  kept.push_iter(self.view[self.in_pos:].iter())
  self.staged_input = kept
  self.staged_pos = 0
}

///|
/// Drop bytes permanently consumed from the staged atomic tail while retaining
/// an unconsumed suffix across output backpressure.
fn Inflater::compact_staged_input(self : Inflater) -> Unit {
  guard self.staged_pos != 0 else { return }
  guard self.staged_pos < self.staged_input.length() else {
    self.staged_input.clear()
    self.staged_pos = 0
    return
  }
  self.staged_input = self.staged_input[self.staged_pos:].to_owned()
  self.staged_pos = 0
}

///|
/// Release call-owned views after every success or error so a suspended engine
/// never pins the caller's network input or mutable output buffer.
fn Inflater::release_step_views(self : Inflater) -> Unit {
  // Local accounting fix: failed steps can write bytes before raising. Save
  // both positions before releasing views; finish_step keeps normal semantics.
  self.step_consumed = self.in_pos
  self.step_produced = self.out_pos
  self.view = b""[:]
  self.in_pos = 0
  self.out_pos = 0
  self.out = self.empty_out.mut_view()
  self.fixed_out = None
  self.out_end = 0
}

///|
/// Advance the absolute window cursor after a bounded batch write.
#inline
fn Inflater::advance_window(self : Inflater, count : Int32) -> Unit {
  self.wpos = self.wpos + count
  if !self.filled && self.wpos >= WINDOW_SIZE {
    self.filled = true
  }
}

///|
/// Drain a contiguous window segment into the caller's output view. The caller
/// proves both ranges fit. Fixed-array callers use a bulk copy; arbitrary
/// mutable views retain the scalar fallback because core exposes no view blit.
#inline
fn Inflater::write_window_to_output(
  self : Inflater,
  start : Int32,
  length : Int32,
) -> Unit {
  if self.fixed_out is Some(output) {
    FixedArray::unsafe_blit(output, self.out_pos, self.window, start, length)
  } else {
    for i in 0..<length {
      self.out.unsafe_set(self.out_pos + i, self.window[start + i])
    }
  }
  self.out_pos = self.out_pos + length
}

///|
/// Copy a logical source range in the circular window to the current window
/// cursor. Both ranges are split at their physical wrap points, so each blit is
/// a valid fixed-array operation. Callers pass non-overlapping logical ranges;
/// `drain_match` limits each logical copy to one distance window so overlapping
/// DEFLATE matches retain their forward-copy semantics.
#inline
fn Inflater::copy_window_segment(
  self : Inflater,
  source : Int32,
  length : Int32,
) -> Unit {
  let mut source = source
  let mut remaining = length
  while remaining > 0 {
    let src = source & (WINDOW_SIZE - 1)
    let dst = self.wpos & (WINDOW_SIZE - 1)
    let chunk = remaining.min(WINDOW_SIZE - src).min(WINDOW_SIZE - dst)
    FixedArray::unsafe_blit(self.window, dst, self.window, src, chunk)
    self.write_window_to_output(dst, chunk)
    self.advance_window(chunk)
    source = source + chunk
    remaining = remaining - chunk
  }
}

///|
/// Copy as many bytes of the in-progress match as fit before `out_end`, leaving
/// the remainder in `copy_remaining` for the next `step`. The window is updated
/// with fixed-array blits (or a fill for distance one), while output writes are
/// performed once per contiguous segment.
fn Inflater::drain_match(self : Inflater) -> Unit {
  let total = self.copy_remaining.min(self.out_end - self.out_pos)
  guard total > 0 else { return }
  if self.copy_dist == 1 {
    let repeated = self.window[(self.wpos - 1) & (WINDOW_SIZE - 1)]
    let mut remaining = total
    while remaining > 0 {
      let dst = self.wpos & (WINDOW_SIZE - 1)
      let chunk = remaining.min(WINDOW_SIZE - dst)
      self.window.fill(repeated, start=dst, end=dst + chunk)
      self.write_window_to_output(dst, chunk)
      self.advance_window(chunk)
      remaining = remaining - chunk
    }
  } else {
    // Copy at most one distance window per blit. This is the largest logical
    // range that is non-overlapping, so memmove semantics remain equivalent to
    // DEFLATE's forward byte-at-a-time expansion even across output steps.
    let mut remaining = total
    while remaining > 0 {
      let chunk = remaining.min(self.copy_dist)
      self.copy_window_segment(self.wpos - self.copy_dist, chunk)
      remaining = remaining - chunk
    }
  }
  self.copy_remaining = self.copy_remaining - total
}

///|
/// Copy a byte-aligned stored-block range directly from the current input view
/// into the circular window, then drain it to output in contiguous segments.
/// Staged input and bit-buffer bytes are handled by the caller's scalar fallback.
fn Inflater::copy_stored_view(
  self : Inflater,
  source : Int32,
  length : Int32,
) -> Unit {
  let mut source = source
  let mut remaining = length
  while remaining > 0 {
    let dst = self.wpos & (WINDOW_SIZE - 1)
    let chunk = remaining.min(WINDOW_SIZE - dst)
    self.window.blit_from_bytesview(dst, self.view[source:source + chunk])
    self.write_window_to_output(dst, chunk)
    self.advance_window(chunk)
    source = source + chunk
    remaining = remaining - chunk
  }
}

///|
/// Decode one literal or match into output + window. Returns true at end-of-block.
/// Atomic w.r.t. input via `NeedInput`; the caller guarantees room for at least
/// one byte before calling, and a match too large for the output suspends with
/// `copy_remaining` set (drained by `drain_match` on the next `step`).
fn Inflater::decode_unit(self : Inflater) -> Bool raise {
  let v = self.huff_sym(self.hl.unwrap())
  guard v >= 256 else {
    self.emit(v.to_byte())
    return false
  }
  guard v != 256 else { return true }
  guard v < 286 else {
    raise InflateError(Corrupt, "corrupt: invalid literal/length code")
  }
  let length_info = length_code_info_table[v - 257]
  let length = (length_info >> 3) + self.read_bits(length_info & 0x7)
  let dsym = if self.hd_fixed {
    fixed_distance_symbol(self.read_bits(5))
  } else {
    self.huff_sym(self.hd.unwrap())
  }
  guard dsym.reinterpret_as_uint() < MAX_NUM_DIST.reinterpret_as_uint() else {
    raise InflateError(Corrupt, "corrupt: invalid distance code")
  }
  let distance_info = distance_code_info_table[dsym]
  // `read_bits(0)` reads nothing and returns 0, so the base serves as the
  // distance when the code carries no extra bits.
  let dist = (distance_info >> 4) + self.read_bits(distance_info & 0xF)
  guard self.filled || back_reference_distance_is_valid(dist, self.wpos) else {
    raise InflateError(Corrupt, "corrupt: distance too far back")
  }
  // All input reads are done; set up the (possibly suspendable) copy. Because
  // copy state is established only here, a `NeedInput` raised above leaves
  // `copy_remaining == 0` and the unit re-runs cleanly.
  self.copy_remaining = length
  self.copy_dist = dist
  self.drain_match()
  false
}

///|
/// Snapshot of the input cursor taken before one atomic unit. Rewinding to a
/// mark lets a `NeedInput`-suspended unit re-run verbatim once more input
/// arrives, instead of resuming mid-unit.
#valtype
priv struct CursorMark {
  bitbuf : Int32
  bit_count : Int32
  staged_pos : Int32
  in_pos : Int32
}

///|
#inline
fn Inflater::mark_cursor(self : Inflater) -> CursorMark {
  {
    bitbuf: self.bitbuf,
    bit_count: self.bit_count,
    staged_pos: self.staged_pos,
    in_pos: self.in_pos,
  }
}

///|
#inline
fn Inflater::rewind_cursor(self : Inflater, mark : CursorMark) -> Unit {
  self.bitbuf = mark.bitbuf
  self.bit_count = mark.bit_count
  self.staged_pos = mark.staged_pos
  self.in_pos = mark.in_pos
}

///|
/// Translate an error raised by the streaming decoder's bit reader inside one
/// atomic unit. An exhausted view rewinds to `mark` and suspends; any other
/// failure becomes the stable `InflateError` it already is.
fn Inflater::retry_or_raise(
  self : Inflater,
  mark : CursorMark,
  err : Error,
) -> Status raise InflateError {
  match classify_decoder_error(err) {
    DecoderInputExhausted => {
      self.rewind_cursor(mark)
      NeedMoreInput
    }
    DecoderFailure(kind, message) => raise InflateError(kind, message)
  }
}

///|
/// Drive the decoder over the currently installed step-local views.
/// The step-local input/output cursors already live on `self`, so returning
/// only `Status` avoids allocating an internal three-tuple that `step` would
/// immediately unpack and discard.
fn Inflater::run_step(self : Inflater) -> Status raise InflateError {
  for ;; {
    match self.mode {
      Done => return Done
      AtBlock => {
        let mark = self.mark_cursor()
        self.parse_block_header() catch {
          err => return self.retry_or_raise(mark, err)
        }
      }
      InStored => {
        while self.stored_remaining > 0 {
          guard self.out_pos < self.out_end else { return NeedMoreOutput }
          // Once the bit buffer and staged tail are empty, move the available
          // external input in window-sized segments instead of pulling bytes
          // through the scalar `next_stored_byte` path.
          if self.bit_count == 0 &&
            self.staged_pos == self.staged_input.length() &&
            self.in_pos < self.view.length() {
            let output_room = self.out_end - self.out_pos
            let input_room = self.view.length() - self.in_pos
            let chunk = self.stored_remaining.min(output_room).min(input_room)
            self.copy_stored_view(self.in_pos, chunk)
            self.in_pos = self.in_pos + chunk
            self.stored_remaining = self.stored_remaining - chunk
          } else {
            guard self.next_stored_byte() is Some(b) else {
              return NeedMoreInput
            }
            self.emit(b)
            self.stored_remaining = self.stored_remaining - 1
          }
        }
        self.mode = if self.final_block { Done } else { AtBlock }
      }
      InHuffman => {
        // Finish any match copy suspended by a full output buffer last step.
        if self.copy_remaining > 0 {
          self.drain_match()
          guard self.copy_remaining == 0 else { return NeedMoreOutput }
        }
        // A unit needs room for at least its first byte; the rest of a match
        // suspends via `copy_remaining` rather than requiring 258 bytes upfront.
        guard self.out_pos < self.out_end else { return NeedMoreOutput }
        let mark = self.mark_cursor()
        let eob = self.decode_unit() catch {
          err => return self.retry_or_raise(mark, err)
        }
        if eob {
          self.mode = if self.final_block { Done } else { AtBlock }
        }
      }
    }
  }
}

///|
/// Commit the counters for one normally returning public step.
fn Inflater::finish_step(
  self : Inflater,
  status : Status,
  consumed : Int32,
  produced : Int32,
) -> Status {
  self.step_consumed = consumed
  self.step_produced = produced
  status
}

///|
/// Run one decompression step. Reads from `input`, writes into `output`, and
/// returns the status. After a normal return, read `last_consumed()` and
/// `last_produced()` for this call's counts, and drop exactly
/// `input[:last_consumed()]`. An empty output makes no progress
/// (`NeedMoreOutput`, zero produced); one output byte always suffices to
/// advance. Both counts are cleared before every call. The local accounting
/// fix preserves failing-call positions before cleanup; output from a failing
/// call remains invalid and must not be delivered.
///
/// Headers and Huffman symbols remain atomic internally, but an incomplete
/// unit's small tail is retained by the engine. Therefore callers may feed
/// ordinary non-overlapping chunks: on `NeedMoreInput` the complete supplied
/// view has been accepted and need not be re-presented. Pass `end=true` with
/// the physical final input view; the signal is sticky across output
/// backpressure, and an incomplete stream then raises `InflateError` instead of
/// returning `NeedMoreInput` forever. Once any error is raised, later calls
/// stably raise the same error until `reset()`.
pub fn Inflater::step(
  self : Inflater,
  input : BytesView,
  output : MutArrayView[Byte],
  end~ : Bool = false,
) -> Status raise InflateError {
  self.step_output(input, output, None, end~)
}

///|
/// Advance the streaming decoder into a complete fixed output array. This has
/// the same consumption, backpressure and EOF semantics as `step`, with bulk
/// window copies. The array is borrowed only for this call; inspect
/// `last_consumed` and `last_produced` after a successful step.
pub fn Inflater::step_into(
  self : Inflater,
  input : BytesView,
  output : FixedArray[Byte],
  end~ : Bool = false,
) -> Status raise InflateError {
  self.step_output(input, output.mut_view(), Some(output), end~)
}

///|
fn Inflater::step_output(
  self : Inflater,
  input : BytesView,
  output : MutArrayView[Byte],
  fixed_output : FixedArray[Byte]?,
  end~ : Bool,
) -> Status raise InflateError {
  self.step_consumed = 0
  self.step_produced = 0
  if self.failure_kind is Some(kind) {
    raise InflateError(kind, self.failure_message)
  }
  if end {
    self.ending = true
  }
  self.view = input
  self.in_pos = 0
  self.out_pos = 0
  self.out = output
  self.fixed_out = fixed_output
  self.out_end = output.length()
  let status = self.run_step() catch {
    InflateError(kind, message) => {
      self.failure_kind = Some(kind)
      self.failure_message = message
      self.staged_input.clear()
      self.staged_pos = 0
      self.release_step_views()
      raise InflateError(kind, message)
    }
  }
  let decoded_input = self.in_pos
  let produced = self.out_pos
  let consumed = if status is NeedMoreInput {
    self.stage_incomplete_input()
    guard !self.ending else {
      let message = "unexpected end of input"
      self.failure_kind = Some(Truncated)
      self.failure_message = message
      self.staged_input.clear()
      self.staged_pos = 0
      self.release_step_views()
      raise InflateError(Truncated, message)
    }
    input.length()
  } else {
    self.compact_staged_input()
    decoded_input
  }
  self.release_step_views()
  self.finish_step(status, consumed, produced)
}
