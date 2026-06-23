///|
fn pdf_wbtest_line(
  text : String,
  x : Double,
  y : Double,
  width? : Double = 120.0,
  height? : Double = 12.0,
  font_size? : Double = 12.0,
) -> PdfNativeTextLine {
  let bbox = make_pdf_bbox(x, y, width, height)
  make_pdf_native_text_line(
    [make_pdf_native_text_span(text, bbox, font_size=Some(font_size))],
    bbox,
  )
}

///|
test "pdf native literal string decoding keeps escapes and balanced parentheses stable" {
  let newline = pdf_parse_literal_token("(Hello\\nWorld)", 0).0
  assert_eq(newline.decoded, "Hello\nWorld")
  assert_true(newline.terminated)

  let parens = pdf_parse_literal_token("(\\(hello\\))", 0).0
  assert_eq(parens.decoded, "(hello)")
  assert_true(parens.terminated)

  let backslash = pdf_parse_literal_token("(a\\\\b)", 0).0
  assert_eq(backslash.decoded, "a\\b")

  let tabbed = pdf_parse_literal_token("(a\\tb)", 0).0
  assert_eq(tabbed.decoded, "a\tb")

  let octal = pdf_parse_literal_token("(\\053)", 0).0
  assert_eq(octal.decoded, "+")

  let octal_wrapped = pdf_parse_literal_token("(\\777)", 0).0
  match octal_wrapped.decoded.get_char(0) {
    Some(ch) => assert_eq(ch.to_int(), 255)
    None => fail("expected octal wrapped char")
  }

  let unknown = pdf_parse_literal_token("(a\\zb)", 0).0
  assert_eq(unknown.decoded, "azb")

  let nested = pdf_parse_literal_token("(outer(inner\\)tail))", 0).0
  assert_eq(nested.decoded, "outer(inner)tail)")
  assert_true(nested.terminated)
}

///|
test "pdf native literal line continuation and malformed boundaries stay conservative" {
  let continued_lf = pdf_parse_literal_token("(Hello\\\nWorld)", 0).0
  assert_eq(continued_lf.decoded, "HelloWorld")
  assert_true(continued_lf.terminated)

  let continued_crlf = pdf_parse_literal_token("(Hello\\\r\nWorld)", 0).0
  assert_eq(continued_crlf.decoded, "HelloWorld")
  assert_true(continued_crlf.terminated)

  let unterminated = pdf_parse_literal_token("(Hello", 0).0
  assert_eq(unterminated.decoded, "Hello")
  assert_true(!unterminated.terminated)

  match pdf_scan_content_tokens("BT (Hello Tj ET") {
    Err(PdfNativeError::ParseFailed(msg)) =>
      assert_true(msg.contains("unterminated PDF literal string"))
    Err(other) =>
      fail("unexpected unterminated literal error: " + other.to_string())
    Ok(_) => fail("expected unterminated literal string to fail")
  }
}

///|
test "pdf native normalization collapses control whitespace without swallowing words" {
  assert_eq(pdf_normalize_pdf_text("a\rb"), "a b")
  assert_eq(pdf_normalize_pdf_text("a\nb"), "a b")
  assert_eq(pdf_normalize_pdf_text("a\tb"), "a b")
  assert_eq(pdf_normalize_pdf_text("a\r\nb"), "a b")
  assert_eq(pdf_normalize_pdf_text("a\u{0008}b"), "a b")
  assert_eq(pdf_normalize_pdf_text("a\u{000C}b"), "a b")
  assert_eq(
    pdf_normalize_pdf_text("The ﬁrst paragraph."),
    "The first paragraph.",
  )
  assert_eq(pdf_normalize_line_fragment_text("  a\t\tb \n c "), "a b c")
  assert_true(
    pdf_line_looks_like_continuation(
      pdf_wbtest_line(" \tcontinued\rhere", 8.0, 8.0),
    ),
  )
}

///|
test "pdf native hex decode and actual text fallback stay stable" {
  assert_eq(pdf_parse_hex_token("<48656c6c6f>", 0).0, "48656c6c6f")
  assert_eq(pdf_parse_hex_token("<48656c6c6f7>", 0).0, "48656c6c6f70")
  assert_true(pdf_hex_to_string("48656c6c6f") == Some("Hello"))
  assert_true(pdf_hex_to_string("48656c6c6f7") == None)
  assert_true(pdf_hex_to_string("FEFF4F60597D") == Some("你好"))

  let operands : Array[PdfNativeContentToken] = [
    PdfNativeContentToken::Dict("<</ActualText (Hello\\nWorld)>>"),
  ]
  assert_true(pdf_actual_text_from_operands(operands) == Some("Hello\nWorld"))

  let utf16_actual_text : Array[PdfNativeContentToken] = [
    PdfNativeContentToken::Dict("<</ActualText (\u{00FE}\u{00FF}O`Y})>>"),
  ]
  assert_true(
    pdf_actual_text_from_operands(utf16_actual_text) == Some("你好"),
  )

  let invalid_actual_text : Array[PdfNativeContentToken] = [
    PdfNativeContentToken::Dict("<</ActualText (\u{00FE}\u{00FF}A)>>"),
  ]
  assert_true(
    pdf_actual_text_from_operands(invalid_actual_text) ==
    Some("\u{00FE}\u{00FF}A"),
  )
}

///|
test "pdf native ToUnicode parser supports bfchar bfrange and codespacerange widths" {
  let cmap = [
    "/CIDInit /ProcSet findresource begin", "12 dict begin", "begincmap", "1 begincodespacerange",
    "<0000> <FFFF>", "endcodespacerange", "1 beginbfchar", "<0001> <4E2D>", "endbfchar",
    "2 beginbfrange", "<0002> <0004> <4E00>", "<0005> <0007> [<4E09> <56DB> <4E94>]",
    "endbfrange", "endcmap", "end", "end",
  ].join("\n")
  let parsed = pdf_parse_tounicode_cmap(cmap)
  assert_true(parsed.0.get("0001") == Some("中"))
  assert_true(parsed.0.get("0002") == Some("一"))
  assert_true(parsed.0.get("0003") == Some("丁"))
  assert_true(parsed.0.get("0004") == Some("丂"))
  assert_true(parsed.0.get("0005") == Some("三"))
  assert_true(parsed.0.get("0006") == Some("四"))
  assert_true(parsed.0.get("0007") == Some("五"))
  assert_true(parsed.1.length() == 1)
  assert_true(parsed.1[0] == 2)
}

///|
test "pdf native hex text decode honors multi-byte font map widths conservatively" {
  let font_info : PdfNativeFontInfo = {
    base_font: Some("PingFangSC-Regular"),
    normalized_base_font: Some("pingfangsc-regular"),
    encoding_name: Some("Identity-H"),
    code_hex_widths: [2],
    unicode_map: Map([("0001", "中"), ("0002", "文"), ("0003", "A")]),
    has_tounicode: true,
    tounicode_decode_failed: false,
  }
  assert_true(
    pdf_decode_hex_pdf_text("00010002", Some(font_info)) == Some("中文"),
  )
  assert_true(
    pdf_decode_hex_pdf_text("00030041", Some(font_info)) == Some("AA"),
  )
}

///|
test "pdf native TJ decoding ignores kerning numbers and decodes mapped hex strings" {
  let font_info : PdfNativeFontInfo = {
    base_font: Some("PingFangSC-Regular"),
    normalized_base_font: Some("pingfangsc-regular"),
    encoding_name: Some("Identity-H"),
    code_hex_widths: [2],
    unicode_map: Map([("0001", "中"), ("0002", "文")]),
    has_tounicode: true,
    tounicode_decode_failed: false,
  }
  let token = PdfNativeContentToken::Array([
    PdfNativeContentToken::HexString("0001"),
    PdfNativeContentToken::Number(-120.0),
    PdfNativeContentToken::HexString("0002"),
  ])
  assert_true(pdf_decode_text_operand(token, Some(font_info)) == Some("中文"))
}

///|
test "pdf native malformed ToUnicode parser stays fail-soft" {
  let parsed = pdf_parse_tounicode_cmap("beginbfchar\n<0001>\nendbfchar")
  assert_eq(parsed.0.length(), 0)
}

///|
test "pdf native cmap stream adapter trims a single trailing eol only when bytes otherwise match" {
  let trimmed = Bytes::from_array([120, 156, 3])
  let declared = Bytes::from_array([120, 156, 3, 10])
  let selected = pdf_cmap_stream_selected_bytes({
    primary_bytes: declared,
    endstream_bytes: trimmed,
    declared_length: Some(4),
  })
  assert_eq(selected, trimmed)

  let different = Bytes::from_array([120, 156, 4, 10])
  let kept = pdf_cmap_stream_selected_bytes({
    primary_bytes: different,
    endstream_bytes: trimmed,
    declared_length: Some(4),
  })
  assert_eq(kept, different)
}

///|
test "pdf native stream slice keeps eol variants out of payload" {
  let lf = pdf_extract_stream_slice(
    @utf8.encode("<< /Length 3 >>\nstream\nabc\nendstream"),
  ).unwrap()
  match lf {
    Some((_dict, slice)) => {
      assert_eq(slice.primary_bytes, b"abc")
      assert_eq(slice.endstream_bytes, b"abc")
      assert_true(slice.declared_length == Some(3))
    }
    None => fail("expected lf stream slice")
  }

  let crlf = pdf_extract_stream_slice(
    @utf8.encode("<< /Length 3 >>\nstream\r\nabc\r\nendstream"),
  ).unwrap()
  match crlf {
    Some((_dict, slice)) => {
      assert_eq(slice.primary_bytes, b"abc")
      assert_eq(slice.endstream_bytes, b"abc")
    }
    None => fail("expected crlf stream slice")
  }

  let cr = pdf_extract_stream_slice(
    @utf8.encode("<< /Length 3 >>\nstream\rabc\rendstream"),
  ).unwrap()
  match cr {
    Some((_dict, slice)) => {
      assert_eq(slice.primary_bytes, b"abc")
      assert_eq(slice.endstream_bytes, b"abc")
    }
    None => fail("expected cr stream slice")
  }
}

///|
test "pdf native cmap stream adapter decodes zlib flated tounicode bytes and fails soft on bad filter states" {
  let ok_object : PdfNativeObject = {
    object_id: 31,
    dict_text: "<< /Filter /FlateDecode /Length 123 >>",
    stream: Some({
      primary_bytes: Bytes::from_array([
        120, 156, 211, 119, 246, 116, 241, 204, 203, 44, 81, 208, 15, 40, 202, 79,
        14, 78, 45, 81, 72, 203, 204, 75, 41, 74, 45, 206, 47, 45, 74, 78, 85, 72,
        74, 77, 207, 204, 227, 50, 52, 82, 72, 201, 76, 46, 129, 242, 192, 100, 114,
        110, 98, 1, 151, 33, 68, 36, 57, 63, 37, 181, 184, 32, 49, 57, 181, 40, 49,
        47, 61, 149, 203, 198, 0, 8, 236, 20, 108, 220, 128, 192, 142, 43, 53, 47,
        5, 77, 30, 170, 43, 41, 45, 57, 35, 177, 8, 172, 218, 16, 168, 218, 192,
        192, 196, 16, 172, 26, 42, 14, 210, 7, 178, 3, 72, 131, 49, 0, 219, 168,
        55, 117,
      ]),
      endstream_bytes: Bytes::from_array([
        120, 156, 211, 119, 246, 116, 241, 204, 203, 44, 81, 208, 15, 40, 202, 79,
        14, 78, 45, 81, 72, 203, 204, 75, 41, 74, 45, 206, 47, 45, 74, 78, 85, 72,
        74, 77, 207, 204, 227, 50, 52, 82, 72, 201, 76, 46, 129, 242, 192, 100, 114,
        110, 98, 1, 151, 33, 68, 36, 57, 63, 37, 181, 184, 32, 49, 57, 181, 40, 49,
        47, 61, 149, 203, 198, 0, 8, 236, 20, 108, 220, 128, 192, 142, 43, 53, 47,
        5, 77, 30, 170, 43, 41, 45, 57, 35, 177, 8, 172, 218, 16, 168, 218, 192,
        192, 196, 16, 172, 26, 42, 14, 210, 7, 178, 3, 72, 131, 49, 0, 219, 168,
        55, 117,
      ]),
      declared_length: Some(123),
    }),
  }
  match pdf_decode_cmap_stream_text(ok_object) {
    Ok(result) => {
      assert_true(result.text.contains("beginbfchar"))
      assert_eq(
        pdf_cmap_stream_decode_strategy_name(result.strategy),
        "ZlibFlateDecode",
      )
      assert_eq(result.diagnostics.zlib_status, "ok")
    }
    Err(err) => fail("expected zlib cmap decode success: " + err.message)
  }

  let compact_filter_object : PdfNativeObject = {
    object_id: 31,
    dict_text: "<</Filter[/FlateDecode]/Length 123>>",
    stream: ok_object.stream,
  }
  match pdf_decode_cmap_stream_text(compact_filter_object) {
    Ok(result) => assert_true(result.text.contains("beginbfchar"))
    Err(err) =>
      fail("expected compact flated cmap decode success: " + err.message)
  }

  let unsupported_filter : PdfNativeObject = {
    object_id: 32,
    dict_text: "<< /Filter /ASCII85Decode /Length 4 >>",
    stream: Some({
      primary_bytes: b"noop",
      endstream_bytes: b"noop",
      declared_length: Some(4),
    }),
  }
  match pdf_decode_cmap_stream_text(unsupported_filter) {
    Err(err) => {
      assert_true(err.message.contains("unsupported CMap stream filter"))
      assert_true(err.diagnostics.filter_name == "ASCII85Decode")
    }
    Ok(_) => fail("expected unsupported cmap filter to fail softly")
  }

  let missing_stream : PdfNativeObject = {
    object_id: 33,
    dict_text: "<< /Filter /FlateDecode >>",
    stream: None,
  }
  match pdf_decode_cmap_stream_text(missing_stream) {
    Err(err) => assert_true(err.message.contains("has no CMap stream"))
    Ok(_) => fail("expected missing cmap stream to fail softly")
  }
}

///|
test "pdf native cmap stream adapter reports checksum mismatch without raw fallback" {
  let corrupted : PdfNativeObject = {
    object_id: 34,
    dict_text: "<< /Filter /FlateDecode /Length 122 >>",
    stream: Some({
      primary_bytes: Bytes::from_array([
        120, 156, 211, 119, 246, 116, 241, 204, 203, 44, 81, 208, 15, 40, 202, 79,
        14, 78, 45, 81, 72, 203, 204, 75, 41, 74, 45, 206, 47, 45, 74, 78, 85, 72,
        74, 77, 207, 204, 227, 50, 52, 82, 72, 201, 76, 46, 129, 242, 192, 100, 114,
        110, 98, 1, 151, 33, 68, 36, 57, 63, 37, 181, 184, 32, 49, 57, 181, 40, 49,
        47, 61, 149, 203, 198, 0, 8, 236, 20, 108, 220, 128, 192, 142, 43, 53, 47,
        5, 77, 30, 170, 43, 41, 45, 57, 35, 177, 8, 172, 218, 16, 168, 218, 192,
        192, 196, 16, 172, 26, 42, 14, 210, 7, 178, 3, 72, 131, 49, 0, 219, 168,
        55, 116,
      ]),
      endstream_bytes: Bytes::from_array([
        120, 156, 211, 119, 246, 116, 241, 204, 203, 44, 81, 208, 15, 40, 202, 79,
        14, 78, 45, 81, 72, 203, 204, 75, 41, 74, 45, 206, 47, 45, 74, 78, 85, 72,
        74, 77, 207, 204, 227, 50, 52, 82, 72, 201, 76, 46, 129, 242, 192, 100, 114,
        110, 98, 1, 151, 33, 68, 36, 57, 63, 37, 181, 184, 32, 49, 57, 181, 40, 49,
        47, 61, 149, 203, 198, 0, 8, 236, 20, 108, 220, 128, 192, 142, 43, 53, 47,
        5, 77, 30, 170, 43, 41, 45, 57, 35, 177, 8, 172, 218, 16, 168, 218, 192,
        192, 196, 16, 172, 26, 42, 14, 210, 7, 178, 3, 72, 131, 49, 0, 219, 168,
        55, 116,
      ]),
      declared_length: Some(122),
    }),
  }
  match pdf_decode_cmap_stream_text(corrupted) {
    Err(err) => {
      assert_true(err.message.contains("ChecksumMismatch"))
      assert_true(err.diagnostics.zlib_status.contains("ChecksumMismatch"))
      match err.diagnostics.raw_fallback {
        Skipped(reason) => assert_eq(reason, "no_raw_flate_evidence")
      }
    }
    Ok(_) => fail("expected checksum mismatch to fail softly")
  }
}

///|
test "pdf native cmap stream adapter fails softly on malformed compressed bytes" {
  let malformed : PdfNativeObject = {
    object_id: 35,
    dict_text: "<< /Filter /FlateDecode /Length 4 >>",
    stream: Some({
      primary_bytes: Bytes::from_array([1, 2, 3, 4]),
      endstream_bytes: Bytes::from_array([1, 2, 3, 4]),
      declared_length: Some(4),
    }),
  }
  match pdf_decode_cmap_stream_text(malformed) {
    Err(err) => {
      assert_true(err.message.contains("flate decode failed"))
      assert_true(err.diagnostics.zlib_status.contains("failed:"))
    }
    Ok(_) => fail("expected malformed cmap bytes to fail softly")
  }
}

///|
test "pdf native font object detection handles compact dictionaries" {
  assert_true(
    pdf_object_is_font({
      object_id: 1,
      dict_text: "<< /Type/Font /Subtype/Type0 /Encoding/Identity-H >>",
      stream: None,
    }),
  )
}

///|
test "pdf native ToUnicode parser drops noncharacter destinations but keeps widths" {
  let cmap = [
    "begincmap", "1 begincodespacerange", "<0000> <FFFF>", "endcodespacerange", "2 beginbfchar",
    "<0001> <FFFF>", "<0002> <0041>", "endbfchar", "endcmap",
  ].join("\n")
  let parsed = pdf_parse_tounicode_cmap(cmap)
  assert_true(parsed.0.get("0001") is None)
  assert_true(parsed.0.get("0002") == Some("A"))
  assert_true(parsed.1.length() == 1)
  assert_true(parsed.1[0] == 2)
}

///|
test "pdf native Identity-H ascii rescue recovers shifted english conservatively" {
  let font_info : PdfNativeFontInfo = {
    base_font: Some("ArialUnicodeMS"),
    normalized_base_font: Some("arialunicodems"),
    encoding_name: Some("Identity-H"),
    code_hex_widths: [2],
    unicode_map: Map([]),
    has_tounicode: false,
    tounicode_decode_failed: false,
  }
  assert_true(
    pdf_decode_hex_pdf_text(
      "00350049004A00540001004A005400010042004F000100220053004A0042004D00010036004F004A00440050004500460001003100250027",
      Some(font_info),
    ) ==
    Some("This is an Arial Unicode PDF"),
  )
}

///|
test "pdf native page font aliases parse compact inline font dictionaries" {
  let page_object : PdfNativeObject = {
    object_id: 1,
    dict_text: "<< /Resources << /Font << /C0_0 35 0 R /F1.7 5 0 R >> >> >>",
    stream: None,
  }
  let aliases = pdf_page_font_aliases(page_object, Map([]))
  assert_true(aliases.get("C0_0") == Some(35))
  assert_true(aliases.get("F1.7") == Some(5))
}

///|
test "pdf native font info collection handles compact type0 font dictionaries" {
  let object_index : Map[Int, PdfNativeObject] = Map([
    (
      5,
      {
        object_id: 5,
        dict_text: "<< /Type/Font /Subtype/Type0 /Encoding /Identity-H /BaseFont /ArialUnicodeMS >>",
        stream: None,
      },
    ),
  ])
  let fonts = pdf_collect_font_infos(object_index).unwrap()
  match fonts.get(5) {
    Some(info) => {
      assert_true(info.base_font == Some("ArialUnicodeMS"))
      assert_true(info.normalized_base_font == Some("arialunicodems"))
      assert_true(info.encoding_name == Some("Identity-H"))
      assert_true(!info.has_tounicode)
    }
    None => fail("expected compact font object to be collected")
  }
}

///|
test "pdf native raw CJK font evidence recognizes escaped and gb2312 font names" {
  let escaped : PdfNativeFontInfo = {
    base_font: Some("#BA#DA#CC#E5"),
    normalized_base_font: pdf_normalized_pdf_font_name(Some("#BA#DA#CC#E5")),
    encoding_name: Some("WinAnsiEncoding"),
    code_hex_widths: [],
    unicode_map: Map([]),
    has_tounicode: false,
    tounicode_decode_failed: false,
  }
  let gb2312_named : PdfNativeFontInfo = {
    base_font: Some("FangSong_GB2312"),
    normalized_base_font: pdf_normalized_pdf_font_name(Some("FangSong_GB2312")),
    encoding_name: Some("WinAnsiEncoding"),
    code_hex_widths: [],
    unicode_map: Map([]),
    has_tounicode: false,
    tounicode_decode_failed: false,
  }
  let latin : PdfNativeFontInfo = {
    base_font: Some("Helvetica"),
    normalized_base_font: Some("helvetica"),
    encoding_name: Some("WinAnsiEncoding"),
    code_hex_widths: [],
    unicode_map: Map([]),
    has_tounicode: false,
    tounicode_decode_failed: false,
  }
  assert_true(pdf_font_has_cjk_name_evidence(escaped))
  assert_true(pdf_font_has_cjk_name_evidence(gb2312_named))
  assert_true(!pdf_font_has_cjk_name_evidence(latin))
}

///|
test "pdf native Identity-H fallback preserves valid ToUnicode mapping before rescue" {
  let font_info : PdfNativeFontInfo = {
    base_font: Some("MinionPro-Regular"),
    normalized_base_font: Some("minionpro-regular"),
    encoding_name: Some("Identity-H"),
    code_hex_widths: [2],
    unicode_map: Map([
      ("0029", "H"),
      ("0046", "e"),
      ("004D", "l"),
      ("0050", "o"),
    ]),
    has_tounicode: true,
    tounicode_decode_failed: false,
  }
  assert_true(
    pdf_decode_hex_pdf_text("00290046004D004D0050", Some(font_info)) ==
    Some("Hello"),
  )
}

///|
test "pdf native multibyte fallback drops control garbage but keeps safe ascii" {
  let font_info : PdfNativeFontInfo = {
    base_font: Some("ArialUnicodeMS"),
    normalized_base_font: Some("arialunicodems"),
    encoding_name: Some("Identity-H"),
    code_hex_widths: [2],
    unicode_map: Map([("0002", "A")]),
    has_tounicode: true,
    tounicode_decode_failed: false,
  }
  assert_true(
    pdf_decode_hex_pdf_text("00020001", Some(font_info)) == Some("A "),
  )
}

///|
test "pdf native failed tounicode state does not masquerade as usable mapping" {
  let font_info : PdfNativeFontInfo = {
    base_font: Some("ArialUnicodeMS"),
    normalized_base_font: Some("arialunicodems"),
    encoding_name: Some("Identity-H"),
    code_hex_widths: [2],
    unicode_map: Map([]),
    has_tounicode: false,
    tounicode_decode_failed: true,
  }
  assert_true(pdf_decode_hex_pdf_text("0001", Some(font_info)) == None)
}

///|
test "pdf native raw GB2312 fallback decodes SimFang bytes conservatively" {
  let font_info : PdfNativeFontInfo = {
    base_font: Some("#BA#DA#CC#E5"),
    normalized_base_font: pdf_normalized_pdf_font_name(Some("#BA#DA#CC#E5")),
    encoding_name: Some("WinAnsiEncoding"),
    code_hex_widths: [],
    unicode_map: Map([]),
    has_tounicode: false,
    tounicode_decode_failed: false,
  }
  assert_true(
    pdf_decode_hex_pdf_text(
      "C8AB20CAC020BDE720CEDEB2FAD5DFA3ACC1AABACFC6F0C0B42041",
      Some(font_info),
    ) ==
    Some("全 世 界 无产者，联合起来 A"),
  )
}

///|
test "pdf native raw GB2312 fallback accepts punctuation-only tokens with strong CJK font evidence" {
  let font_info : PdfNativeFontInfo = {
    base_font: Some("#BA#DA#CC#E5"),
    normalized_base_font: pdf_normalized_pdf_font_name(Some("#BA#DA#CC#E5")),
    encoding_name: Some("WinAnsiEncoding"),
    code_hex_widths: [],
    unicode_map: Map([]),
    has_tounicode: false,
    tounicode_decode_failed: false,
  }
  assert_true(pdf_decode_hex_pdf_text("A3AC", Some(font_info)) == Some("，"))
  assert_true(
    pdf_decode_hex_pdf_text("A1A1A1A1", Some(font_info)) == Some("　　"),
  )
  assert_true(pdf_decode_hex_pdf_text("A3B1", Some(font_info)) == Some("１"))
}

///|
test "pdf native raw GB2312 fallback respects ToUnicode priority" {
  let font_info : PdfNativeFontInfo = {
    base_font: Some("FangSong_GB2312"),
    normalized_base_font: pdf_normalized_pdf_font_name(Some("FangSong_GB2312")),
    encoding_name: Some("WinAnsiEncoding"),
    code_hex_widths: [1],
    unicode_map: Map([("C4", "A"), ("BF", "B")]),
    has_tounicode: true,
    tounicode_decode_failed: false,
  }
  assert_true(pdf_decode_hex_pdf_text("C4BF", Some(font_info)) == Some("AB"))
}

///|
test "pdf native raw GB2312 fallback does not hijack latin WinAnsi fonts" {
  let font_info : PdfNativeFontInfo = {
    base_font: Some("Helvetica"),
    normalized_base_font: Some("helvetica"),
    encoding_name: Some("WinAnsiEncoding"),
    code_hex_widths: [],
    unicode_map: Map([]),
    has_tounicode: false,
    tounicode_decode_failed: false,
  }
  assert_true(
    pdf_decode_hex_pdf_text("48656C6C6F2041", Some(font_info)) ==
    Some("Hello A"),
  )
}

///|
test "pdf native line fragment spacing protects cjk while preserving english gaps" {
  assert_eq(
    pdf_prepare_line_text_fragment("world", Some(8.0), Some(10.0)),
    " world",
  )
  assert_eq(
    pdf_prepare_line_text_fragment("world", Some(2.0), Some(10.0)),
    "world",
  )
  assert_eq(pdf_prepare_line_text_fragment("文", Some(8.0), Some(10.0)), "文")
  assert_eq(pdf_prepare_line_text_fragment("，", Some(8.0), Some(10.0)), "，")
  assert_eq(
    pdf_prepare_line_text_fragment("）续行", Some(8.0), Some(10.0)),
    "）续行",
  )
  assert_eq(
    pdf_prepare_line_text_fragment(
      " am",
      Some(8.0),
      Some(10.0),
      preserve_outer_space=true,
    ),
    " am",
  )
  assert_eq(pdf_normalize_pdf_fragment_text("\t pdf\t"), " pdf  ")
}

///|
test "pdf native TD applies current text scale when placing later text fragments" {
  let source = @input.input_from_bytes_with_format(
    @utf8.encode("%PDF-1.4\n"),
    "scaled-td.pdf",
    Some(@input.DetectedFormat::Pdf),
  )
  let geometry = make_pdf_page_geometry(1, 612.0, 792.0)
  let fonts : Map[Int, PdfNativeFontInfo] = Map([
    (
      1,
      {
        base_font: Some("ArabicCID"),
        normalized_base_font: Some("arabiccid"),
        encoding_name: Some("Identity-H"),
        code_hex_widths: [2],
        unicode_map: Map([
          ("0045", "ﺔ"),
          ("003D", "ﻴ"),
          ("0004", "ﺑ"),
          ("0052", "ﺮ"),
          ("0034", "ﻌ"),
          ("0013", "ﻟ"),
          ("00B1", "ا"),
          ("00C1", "ط"),
          ("0062", "ﻮ"),
          ("0032", "ﻄ"),
          ("0028", "ﳋ"),
          ("00C3", "ع"),
          ("0015", "ﻧ"),
        ]),
        has_tounicode: true,
        tounicode_decode_failed: false,
      },
    ),
    (
      2,
      {
        base_font: Some("SpaceFont"),
        normalized_base_font: Some("spacefont"),
        encoding_name: None,
        code_hex_widths: [],
        unicode_map: Map([]),
        has_tounicode: false,
        tounicode_decode_failed: false,
      },
    ),
  ])
  let aliases : Map[String, Int] = Map([("TT1", 1), ("TT2", 2)])
  let content = [
    "BT", "/TT1 1 Tf", "36 0 0 36 160.26 733 Tm", "<0045003D000400520034001300B1> Tj",
    "/TT2 1 Tf", "3.2622 0 TD", "( ) Tj", "/TT1 1 Tf", "0.2944 0 TD", "<00C100620032002800B1> Tj",
    "/TT2 1 Tf", "3.3603 0 TD", "( ) Tj", "/TT1 1 Tf", "0.2944 0 TD", "<00C300B10062001500B1> Tj",
    "/TT1 1 Tf", "-4.1698 -1.5 TD", "<0045003D000400520034001300B1> Tj", "ET",
  ].join("\n")
  let fragments = pdf_extract_text_fragments_from_stream(
    source, geometry, aliases, fonts, content,
  ).unwrap()
  assert_eq(fragments.length(), 4)
  let lines = pdf_group_text_fragments_into_lines(source, geometry, fragments)
  assert_eq(lines.length(), 2)
  let first_line = pdf_native_line_text(lines[0])
  let second_line = pdf_native_line_text(lines[1])
  assert_true(first_line.contains("ﺔﻴﺑﺮﻌﻟا"))
  assert_true(first_line.contains("طﻮﻄﳋا"))
  assert_true(first_line.contains("عاﻮﻧا"))
  assert_eq(second_line, "ﺔﻴﺑﺮﻌﻟا")
}

///|
test "pdf native conservative grouping matrix keeps merge and split boundaries stable" {
  assert_true(
    pdf_should_merge_line_into_block(
      [pdf_wbtest_line("First sentence", 10.0, 10.0)],
      pdf_wbtest_line("continues here", 12.0, 24.0),
    ),
  )

  assert_true(
    !pdf_should_merge_line_into_block(
      [pdf_wbtest_line("First sentence.", 10.0, 10.0)],
      pdf_wbtest_line("continues here", 12.0, 24.0),
    ),
  )

  assert_true(
    !pdf_should_merge_line_into_block(
      [pdf_wbtest_line("- bullet item", 10.0, 10.0)],
      pdf_wbtest_line("continues here", 12.0, 24.0),
    ),
  )

  assert_true(
    !pdf_should_merge_line_into_block(
      [pdf_wbtest_line("1. numbered item", 10.0, 10.0)],
      pdf_wbtest_line("continues here", 12.0, 24.0),
    ),
  )

  assert_true(
    !pdf_should_merge_line_into_block(
      [pdf_wbtest_line("First sentence", 10.0, 10.0)],
      pdf_wbtest_line("continues here", 12.0, 48.0),
    ),
  )

  assert_true(
    !pdf_should_merge_line_into_block(
      [pdf_wbtest_line("First sentence", 10.0, 10.0)],
      pdf_wbtest_line("continues here", 36.0, 24.0),
    ),
  )

  assert_true(
    !pdf_should_merge_line_into_block(
      [pdf_wbtest_line("Alpha East Open", 10.0, 10.0)],
      pdf_wbtest_line("Beta West Closed", 10.0, 24.0),
    ),
  )
}

///|
test "pdf native literal escapes cover carriage return form feed backspace and escaped delimiters" {
  let carriage = pdf_parse_literal_token("(a\\rb)", 0).0
  assert_eq(carriage.decoded, "a\rb")
  assert_true(carriage.terminated)

  let form_feed = pdf_parse_literal_token("(a\\fb)", 0).0
  assert_eq(form_feed.decoded, "a\u{000C}b")
  assert_true(form_feed.terminated)

  let backspace = pdf_parse_literal_token("(a\\bb)", 0).0
  assert_eq(backspace.decoded, "a\u{0008}b")
  assert_true(backspace.terminated)

  let escaped_close = pdf_parse_literal_token("(a\\)b)", 0).0
  assert_eq(escaped_close.decoded, "a)b")
  assert_true(escaped_close.terminated)
}

///|
test "pdf native token scanning fails explicitly on malformed array boundaries" {
  match pdf_scan_content_tokens("BT [(Hello) (World) Tj ET") {
    Err(PdfNativeError::ParseFailed(msg)) =>
      assert_true(msg.contains("unterminated PDF array token"))
    Err(other) => fail("unexpected malformed array error: " + other.to_string())
    Ok(_) => fail("expected malformed array token to fail")
  }
}

///|
test "pdf native token scanning skips stray delimiters without unbounded growth" {
  match pdf_scan_content_tokens("BT ] EMC ET") {
    Ok(tokens) => {
      assert_true(tokens.length() >= 3)
      match tokens[0] {
        PdfNativeContentToken::Word("BT") => ()
        _ => fail("expected BT token first")
      }
      match tokens[tokens.length() - 1] {
        PdfNativeContentToken::Word("ET") => ()
        _ => fail("expected ET token last")
      }
    }
    Err(err) =>
      fail(
        "expected stray delimiter handling to stay fail-soft: " +
        err.to_string(),
      )
  }
}

///|
test "pdf native literal utf16 strings decode before normalization" {
  assert_eq(pdf_decode_literal_pdf_text("\u{00FE}\u{00FF}O`Y}"), "你好")
  assert_eq(
    pdf_extract_string_after("<< /T (\u{00FE}\u{00FF}O`Y}) >>", "/T").unwrap(),
    "你好",
  )
}

///|
test "pdf native literal strings decode PDFDocEncoding conservatively" {
  assert_eq(pdf_decode_literal_pdf_text("Employee\u{0090}s"), "Employee’s")
  assert_eq(
    pdf_decode_literal_pdf_text("\u{0080}Potato \u{0090}quoted\u{0090}"),
    "•Potato ’quoted’",
  )
}

///|
test "pdf native content literal strings decode WinAnsi bytes with font info" {
  let font_info : PdfNativeFontInfo = {
    base_font: Some("Helvetica"),
    normalized_base_font: Some("helvetica"),
    encoding_name: Some("WinAnsiEncoding"),
    code_hex_widths: [],
    unicode_map: Map([]),
    has_tounicode: false,
    tounicode_decode_failed: false,
  }
  assert_eq(
    pdf_decode_content_literal_pdf_text("Employee\u{0092}s", Some(font_info)),
    "Employee’s",
  )
}

///|
test "pdf native form option arrays flatten nested display pairs conservatively" {
  let options = pdf_extract_string_array_after(
    "<< /Opt [ [(Lorem) (Lorem)] [(Ipsum) (Ipsum)] [(Dolor) (Dolor)] ] >>", "/Opt",
  )
  assert_eq(options.join(","), "Lorem,Ipsum,Dolor")
}

///|
test "pdf native choice form value joins multi-select arrays" {
  let value = pdf_extract_form_value(
    "<< /FT /Ch /V [(Ipsum) (Amet) (Consectetur) (Elit)] >>",
    Some("Ch"),
  )
  assert_true(value == Some("Ipsum, Amet, Consectetur, Elit"))
}

///|
test "pdf native form normalization preserves multiline boundaries conservatively" {
  let value = pdf_extract_form_value(
    "<< /FT /Tx /V (Line one\rLine two\rLine three) >>",
    Some("Tx"),
  )
  assert_true(value == Some("Line one / Line two / Line three"))
}
