///|
pub fn filter_noise_blocks(
  pages : Array[PdfConvertPage],
) -> Array[PdfConvertPage] {
  let repeated = collect_repeated_short_lines(pages)

  let out = Array::new()
  for page in pages {
    let kept = Array::new()
    for b in page.blocks {
      if should_drop_noise_block(b, repeated) {
        kept.push({
          page_index: b.page_index,
          kind: PdfConvertBlockKind::Noise,
          text: b.text,
          heading_level: b.heading_level,
          line_count: b.line_count,
        })
      } else {
        kept.push(b)
      }
    }
    out.push({ page_index: page.page_index, lines: page.lines, blocks: kept })
  }

  out
}

///|
fn should_drop_noise_block(
  b : PdfConvertBlock,
  repeated : Array[String],
) -> Bool {
  if b.kind == PdfConvertBlockKind::Noise {
    return true
  }
  let t = b.text.trim().to_string()
  if t == "" {
    return true
  }

  for r in repeated {
    if t == r {
      return true
    }
  }

  false
}

///|
fn collect_repeated_short_lines(pages : Array[PdfConvertPage]) -> Array[String] {
  let all = Array::new()

  for page in pages {
    for line in page.lines {
      let t = line.text.trim().to_string()
      if t != "" && t.to_array().length() <= 40 {
        all.push(t)
      }
    }
  }

  let repeated = Array::new()
  for i = 0; i < all.length(); i = i + 1 {
    let s = all[i]
    if seen_in(repeated, s) {
      continue
    }

    let mut count = 1
    for j = i + 1; j < all.length(); j = j + 1 {
      if all[j] == s {
        count = count + 1
      }
    }

    if count >= 3 {
      repeated.push(s)
    }
  }

  repeated
}

///|
fn seen_in(xs : Array[String], target : String) -> Bool {
  for x in xs {
    if x == target {
      return true
    }
  }
  false
}
