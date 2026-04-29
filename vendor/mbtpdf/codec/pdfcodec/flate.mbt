///|
/// Decode data in FlateDecode.
pub fn PdfCodec::decode_flate(
  _self : PdfCodec,
  data : @pdfio.MutableBytes,
) -> @pdfio.MutableBytes raise CodecError {
  let mut pos = 0
  let input = (buf : @pdfio.MutableBytes) => {
    let remaining = data.length() - pos
    if remaining <= 0 {
      0
    } else {
      let n = if remaining < buf.length() { remaining } else { buf.length() }
      data[pos:pos + n].blit_to(buf)
      pos = pos + n
      n
    }
  }
  let out : @pdfio.MutableBytes = Array::new()
  let output = (buf : @pdfio.MutableBytes, length : Int) => out.append(
    buf[:length],
  )
  try {
    @pdfflate.PdfFlate::new().uncompress(header=true, input, output)
    out
  } catch {
    @pdfflate.FlateError::Error(stage, msg) =>
      raise CodecError::CouldntDecodeStream("\{stage}: \{msg}")
  }
}

///|
/// Encode a PDF stream with an encoding.
pub fn PdfCodec::encode_pdfstream(
  self : PdfCodec,
  pdf : @pdf.Pdf,
  encoding : Encoding,
  obj : @pdf.PdfObject,
  im? : String,
  only_if_smaller? : Bool = false,
  predictor? : Predictor,
  predictor_columns? : Int,
) -> Unit raise CodecError {
  let _ = im
  let predictor_columns = match predictor_columns {
    Some(value) => value
    None => 1
  }
  let encoding_name = match encoding {
    Encoding::ASCIIHex => "/ASCIIHexDecode"
    Encoding::ASCII85 => "/ASCII85Decode"
    Encoding::RunLength => "/RunLengthDecode"
    Encoding::LZW(_) => "/LZWDecode"
    Encoding::Flate => "/FlateDecode"
    Encoding::CCITT(_, _) | Encoding::CCITTG4(_, _) => "/CCITTFaxDecode"
  }
  let encoding_pdf_name = @pdf.PdfName::of_string(encoding_name)
  fn update_filter(dict : @pdf.PdfObject) -> @pdf.PdfObject raise CodecError {
    let filter_obj : @pdf.PdfObject = match pdf.lookup_direct("/Filter", dict) {
      None => Name(encoding_pdf_name)
      Some(Name(name)) =>
        Array([
          @pdf.PdfObject::Name(encoding_pdf_name),
          @pdf.PdfObject::Name(name),
        ])
      Some(Array(filters)) => {
        let updated = Array::new(capacity=filters.length() + 1)
        updated.push(@pdf.PdfObject::Name(encoding_pdf_name))
        for f in filters {
          updated.push(f)
        }
        Array(updated)
      }
      Some(_) => raise CodecError::CouldntDecodeStream("malformed /Filter")
    }
    set_dict_entry(dict, "/Filter", filter_obj)
  }

  fn process_prediction(
    dict : @pdf.PdfObject,
    data : @pdfio.MutableBytes,
  ) -> (@pdf.PdfObject, @pdfio.MutableBytes) raise CodecError {
    match predictor {
      Some(pred) => {
        let (pred_value, colors, bpc) = match pred {
          Predictor::TIFF2 => (2, 1, 8)
          Predictor::PNGNone => (10, 1, 8)
          Predictor::PNGSub => (11, 1, 8)
          Predictor::PNGUp => (12, 1, 8)
          Predictor::PNGAverage => (13, 1, 8)
          Predictor::PNGPaeth => (14, 1, 8)
          Predictor::PNGOptimum => (15, 1, 8)
        }
        let predicted = encode_predictor(
          pred_value, colors, bpc, predictor_columns, data,
        )
        let decodeparms = @pdf.PdfObject::Dictionary([
          ("/Columns", @pdf.PdfObject::Integer(predictor_columns)),
          ("/Predictor", @pdf.PdfObject::Integer(pred_value)),
          ("/Colors", @pdf.PdfObject::Integer(colors)),
          ("/BitsPerComponent", @pdf.PdfObject::Integer(bpc)),
        ])
        let dict_with_parms = set_dict_entry(dict, "/DecodeParms", decodeparms)
        (dict_with_parms, predicted)
      }
      None => (dict, data)
    }
  }

  fn encode_stream(
    dict : @pdf.PdfObject,
    data : @pdfio.MutableBytes,
  ) -> (@pdf.PdfObject, @pdfio.MutableBytes) raise CodecError {
    let (predicted_dict, predicted_data) = process_prediction(dict, data)
    let encoded = match encoding {
      Encoding::ASCIIHex => encode_asciihex(predicted_data)
      Encoding::ASCII85 => encode_ascii85(predicted_data)
      Encoding::RunLength => encode_runlength(predicted_data)
      Encoding::LZW(early) => encode_lzw(early, predicted_data)
      Encoding::Flate => self.encode_flate(predicted_data)
      Encoding::CCITT(columns, rows) =>
        encode_ccitt(columns, rows, predicted_data)
      Encoding::CCITTG4(columns, rows) =>
        encode_ccittg4(columns, rows, predicted_data, im?)
    }
    let dict_with_filter = update_filter(predicted_dict)
    let dict_with_length = set_dict_entry(
      dict_with_filter,
      "/Length",
      @pdf.PdfObject::Integer(@pdfio.bytes_size(encoded)),
    )
    (dict_with_length, encoded)
  }

  match (obj : @pdf.PdfObject) {
    Stream(r) => {
      map_pdf_error("getstream", fn() raise { obj.getstream() })
      let (dict, stream_data) = r.val
      let data = match (stream_data : @pdf.Stream) {
        Got(bytes) => bytes
        _ => raise CodecError::CouldntDecodeStream("stream data not available")
      }
      let (new_dict, new_data) = encode_stream(dict, data)
      if !only_if_smaller ||
        @pdfio.bytes_size(new_data) + 20 < @pdfio.bytes_size(data) {
        r.val = (new_dict, @pdf.Stream::Got(new_data))
      }
    }
    Indirect(i) =>
      self.encode_pdfstream(
        pdf,
        encoding,
        pdf.direct(Indirect(i)),
        im?,
        only_if_smaller~,
        predictor?,
        predictor_columns~,
      )
    _ => raise CodecError::CouldntDecodeStream("malformed stream")
  }
}

///|
/// Decode just one stage of a PDF stream.
pub fn PdfCodec::decode_pdfstream_onestage(
  self : PdfCodec,
  pdf : @pdf.Pdf,
  obj : @pdf.PdfObject,
  jbig2dec? : String,
) -> Unit raise CodecError {
  match (obj : @pdf.PdfObject) {
    Stream(r) => {
      let (dict, _stream) = r.val
      let (filter_key, filter_opt) = match dict.lookup_immediate("/Filter") {
        Some(_) => ("/Filter", pdf.lookup_direct("/Filter", dict))
        None =>
          match dict.lookup_immediate("/F") {
            Some(_) => ("/F", pdf.lookup_direct("/F", dict))
            None => ("/Filter", None)
          }
      }
      let (parms_key, parms) = match dict.lookup_immediate("/DecodeParms") {
        Some(_) => ("/DecodeParms", pdf.lookup_direct("/DecodeParms", dict))
        None =>
          match dict.lookup_immediate("/DP") {
            Some(_) => ("/DP", pdf.lookup_direct("/DP", dict))
            None => ("/DecodeParms", None)
          }
      }
      match filter_opt {
        None => raise CodecError::DecodeNotSupported("no filter")
        Some(filter_obj) => {
          let (filter_name, remaining_filters) : (
            @pdf.PdfName,
            Array[@pdf.PdfObject]?,
          ) = match (filter_obj : @pdf.PdfObject) {
            Name(name) => (name, None)
            Array([]) =>
              raise CodecError::DecodeNotSupported("empty filter array")
            Array([Name(name), .. rest]) => (name, Some(rest.to_array()))
            Array(_) =>
              raise CodecError::DecodeNotSupported("invalid filter entry")
            _ => raise CodecError::DecodeNotSupported("invalid filter")
          }
          map_pdf_error("getstream", fn() raise { obj.getstream() })
          let data = match r.val {
            (_, @pdf.Stream::Got(bytes)) => bytes
            _ =>
              raise CodecError::CouldntDecodeStream("stream data not available")
          }
          let parms_first = match parms {
            Some(Array(arr)) =>
              if arr.length() > 0 {
                Some(arr[0])
              } else {
                None
              }
            Some(Null) => None
            Some(other) => Some(other)
            None => None
          }
          let decoded = PdfFilterNameDecode::decode_stage(
            filter_name, self, pdf, parms_first, data, jbig2dec,
          )
          let mut new_dict = dict
          new_dict = match remaining_filters {
            None =>
              map_pdf_error("remove filter", fn() raise {
                new_dict.remove_entry(filter_key)
              })
            Some(rest) =>
              if rest.length() == 0 {
                map_pdf_error("remove filter", fn() raise {
                  new_dict.remove_entry(filter_key)
                })
              } else {
                map_pdf_error("replace filter", fn() raise {
                  new_dict.replace_entry(
                    filter_key,
                    @pdf.PdfObject::Array(rest),
                  )
                })
              }
          }
          new_dict = match parms {
            None => new_dict
            Some(Array(arr)) =>
              if arr.length() == 0 {
                map_pdf_error("remove decode parms", fn() raise {
                  new_dict.remove_entry(parms_key)
                })
              } else {
                let rest = arr.sub(start=1).to_array()
                if rest.length() == 0 {
                  map_pdf_error("remove decode parms", fn() raise {
                    new_dict.remove_entry(parms_key)
                  })
                } else {
                  map_pdf_error("replace decode parms", fn() raise {
                    new_dict.replace_entry(
                      parms_key,
                      @pdf.PdfObject::Array(rest),
                    )
                  })
                }
              }
            Some(_) =>
              map_pdf_error("remove decode parms", fn() raise {
                new_dict.remove_entry(parms_key)
              })
          }
          new_dict = set_dict_entry(
            new_dict,
            "/Length",
            @pdf.PdfObject::Integer(@pdfio.bytes_size(decoded)),
          )
          r.val = (new_dict, @pdf.Stream::Got(decoded))
        }
      }
    }
    _ => raise CodecError::DecodeNotSupported("not a stream")
  }
}

///|
/// Trait-based filter dispatch.
///
/// This keeps the set of supported filter names and their parameter handling
/// in one place, while leaving higher-level `/Filter` array trimming and
/// dictionary mutation to `decode_pdfstream_onestage`.
pub impl PdfFilterNameDecode for @pdf.PdfName with decode_stage(
  filter_name : @pdf.PdfName,
  ctx : PdfCodec,
  pdf : @pdf.Pdf,
  parms : @pdf.PdfObject?,
  data : @pdfio.MutableBytes,
  jbig2dec : String?,
) -> @pdfio.MutableBytes raise CodecError {
  if filter_name.equal_string_bytes("/FlateDecode") ||
    filter_name.equal_string_bytes("/Fl") {
    let mut decoded = ctx.decode_flate(data)
    match parms {
      Some(Dictionary(_)) => {
        let predictor = get_int_param(pdf, parms, "/Predictor", 1)
        if predictor != 1 {
          let colors = get_int_param(pdf, parms, "/Colors", 1)
          let bpc = get_int_param(pdf, parms, "/BitsPerComponent", 8)
          let columns = get_int_param(pdf, parms, "/Columns", 1)
          decoded = decode_predictor(predictor, colors, bpc, columns, decoded)
        }
      }
      _ => ()
    }
    decoded
  } else if filter_name.equal_string_bytes("/ASCIIHexDecode") ||
    filter_name.equal_string_bytes("/AHx") {
    decode_asciihex(@pdfio.Input::of_bytes(data, source="asciihex"))
  } else if filter_name.equal_string_bytes("/ASCII85Decode") ||
    filter_name.equal_string_bytes("/A85") {
    decode_ascii85(@pdfio.Input::of_bytes(data, source="ascii85"))
  } else if filter_name.equal_string_bytes("/RunLengthDecode") ||
    filter_name.equal_string_bytes("/RL") {
    decode_runlength(@pdfio.Input::of_bytes(data, source="runlength"))
  } else if filter_name.equal_string_bytes("/LZWDecode") ||
    filter_name.equal_string_bytes("/LZW") {
    let early = get_int_param(pdf, parms, "/EarlyChange", 1)
    decode_lzw(early, @pdfio.Input::of_bytes(data, source="lzw"))
  } else if filter_name.equal_string_bytes("/Crypt") {
    data
  } else if filter_name.equal_string_bytes("/JBIG2Decode") {
    let _ = jbig2dec
    raise CodecError::DecodeNotSupported(
      "JBIG2Decode requires decode_pdfstream_async",
    )
  } else if filter_name.equal_string_bytes("/CCITTFaxDecode") ||
    filter_name.equal_string_bytes("/CCF") {
    let k = get_int_param(pdf, parms, "/K", 0)
    let eol = get_bool_param(pdf, parms, "/EndOfLine", false)
    let eba = get_bool_param(pdf, parms, "/EncodedByteAlign", false)
    let columns = get_int_param(pdf, parms, "/Columns", 1728)
    let rows = get_int_param(pdf, parms, "/Rows", 0)
    let eob = get_bool_param(pdf, parms, "/EndOfBlock", true)
    let bone = get_bool_param(pdf, parms, "/BlackIs1", false)
    let dra = get_int_param(pdf, parms, "/DamagedRowsBeforeError", 0)
    decode_ccittfax(
      k,
      eol,
      eba,
      columns,
      rows,
      eob,
      bone,
      dra,
      @pdfio.Input::of_bytes(data, source="ccitt"),
    )
  } else {
    raise CodecError::DecodeNotSupported(
      "filter not supported: \{filter_name.to_string_bytes()}",
    )
  }
}

///|
/// Decode bytes using filters in dict; returns None when decoder unsupported.
pub fn PdfCodec::decode_from_bytes(
  self : PdfCodec,
  bytes : @pdfio.MutableBytes,
  dict : @pdf.PdfObject,
) -> @pdfio.MutableBytes? {
  let pdf = @pdf.Pdf::empty()
  let filter_opt = pdf.lookup_direct_orelse("/F", "/Filter", dict)
  let parms_opt = pdf.lookup_direct_orelse("/DP", "/DecodeParms", dict)
  fn parms_at(index : Int) -> @pdf.PdfObject? {
    match parms_opt {
      Some(Array(arr)) =>
        if index < arr.length() {
          Some(arr[index])
        } else {
          None
        }
      Some(Null) => None
      Some(other) => if index == 0 { Some(other) } else { None }
      None => None
    }
  }

  fn decode_stage(
    bytes : @pdfio.MutableBytes,
    filter_name : @pdf.PdfName,
    parms : @pdf.PdfObject?,
  ) -> @pdfio.MutableBytes? {
    let decoded_result : Result[@pdfio.MutableBytes, Error] = try? PdfFilterNameDecode::decode_stage(
      filter_name,
      self,
      pdf,
      parms,
      bytes,
      None,
    )
    match decoded_result {
      Ok(decoded) => Some(decoded)
      Err(_) => None
    }
  }

  match filter_opt {
    Some(Name(name)) => decode_stage(bytes, name, parms_at(0))
    Some(Array(filters)) => {
      if filters.length() == 0 {
        return None
      }
      let mut current = bytes
      for i in 0..<filters.length() {
        let filter_name = match (filters[i] : @pdf.PdfObject) {
          Name(name) => name
          _ => return None
        }
        match decode_stage(current, filter_name, parms_at(i)) {
          Some(decoded) => current = decoded
          None => return None
        }
      }
      Some(current)
    }
    _ => None
  }
}
