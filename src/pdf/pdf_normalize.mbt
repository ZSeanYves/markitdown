///|
/// PDF 分段：
pub fn split_paragraphs_smart(page : String) -> Array[String] {
  let s = page
    .replace(old="\r\n", new="\n")
    .replace(old="\r", new="\n")
    .replace(old="\u00A0", new=" ")
    .replace(old="\t", new=" ")

  // 先把行收集起来，方便做“空行前后 lookahead”
  let lines : Array[String] = []
  for sv in s.split("\n") {
    lines.push(sv.to_string())
  }

  let paras : Array[String] = []
  let mut buf = ""

  let n = lines.length()
  let mut i = 0
  while i < n {
    let cur = lines[i].trim().to_string()

    if cur == "" {
      // 数空行
      let mut k = i
      while k < n && lines[k].trim() == "" {
        k = k + 1
      }

      // 找下一个非空行（用于判断是否真分段）
      if buf != "" && k < n {
        let next = lines[k].trim().to_string()

        if is_short(buf) || is_short(next) {

        } else {
          // 真分段
          let p = finalize_paragraph(buf)
          if p != "" {
            paras.push(p)
          }
          buf = ""
        }
      } else if buf != "" && k >= n {
        // 文件结束，收尾
        let p = finalize_paragraph(buf)
        if p != "" {
          paras.push(p)
        }
        buf = ""
      }

      i = k
      continue
    }

    // 非空行：追加进 buf
    if buf == "" {
      buf = cur
    } else {
      buf = buf + glue_between(buf, cur) + cur
    }

    i = i + 1
  }

  if buf != "" {
    let p = finalize_paragraph(buf)
    if p != "" {
      paras.push(p)
    }
  }

  paras
}

///|
/// 段落最后做一次清理：多空格折叠 + trim（字符级，不走 bytes）
fn finalize_paragraph(s : String) -> String {
  let t = s.trim()
  if t == "" {
    return ""
  }

  let mut out = ""
  let mut prev_space = false
  for c in t.to_array() {
    if c == ' ' {
      if !prev_space {
        out = out + " "
        prev_space = true
      }
    } else {
      out = out + c.to_string()
      prev_space = false
    }
  }

  remove_cjk_inner_spaces(out.trim().to_string())
}

///|
/// 去掉中文/全角符号之间的“字间空格”
fn remove_cjk_inner_spaces(s : String) -> String {
  let cs = s.to_array()
  let n = cs.length()
  if n == 0 {
    return s
  }

  let mut out = ""
  let mut i = 0
  while i < n {
    let c = cs[i]

    if c == ' ' {
      if i > 0 && i + 1 < n {
        let prev = cs[i - 1]
        let next = cs[i + 1]
        if is_cjkish(prev) && is_cjkish(next) {
          i = i + 1
          continue
        }
      }
      out = out + " "
      i = i + 1
      continue
    }

    out = out + c.to_string()
    i = i + 1
  }

  out
}

///|
/// 粗略判断“中文相关字符”：CJK 汉字,全角区（含中文标点）,常见中文标点
fn is_cjkish(c : Char) -> Bool {
  let x = c.to_int()
  (x >= 0x4E00 && x <= 0x9FFF) || // CJK Unified
  (x >= 0x3400 && x <= 0x4DBF) || // Extension A
  (x >= 0xF900 && x <= 0xFAFF) || // Compatibility
  (x >= 0xFF00 && x <= 0xFFEF) || // Half/Full width
  c == '，' ||
  c == '。' ||
  c == '；' ||
  c == '：' ||
  c == '！' ||
  c == '？'
}

///|
/// “短行”判断：<=2 个字符（对付中文被切成单字/两字的情况）
pub fn is_short(s : String) -> Bool {
  let t = s.trim()
  if t == "" {
    return true
  }
  t.to_array().length() <= 2
}

///|
/// 决定拼接时加不加空格：
/// - CJK + CJK：不加空格（中文不应该被强行加空格）
/// - 其他情况：加一个空格
pub fn glue_between(left : String, right : String) -> String {
  let lc = last_char(left)
  let rc = first_char(right)
  match (lc, rc) {
    (Some(a), Some(b)) => if is_cjk(a) && is_cjk(b) { "" } else { " " }
    _ => " "
  }
}

///|
fn first_char(s : String) -> Char? {
  let arr = s.trim().to_array()
  if arr.length() == 0 {
    None
  } else {
    Some(arr[0])
  }
}

///|
fn last_char(s : String) -> Char? {
  let arr = s.trim().to_array()
  let n = arr.length()
  if n == 0 {
    None
  } else {
    Some(arr[n - 1])
  }
}

///|
/// 粗略 CJK 判定（足够 MVP）
/// 覆盖：CJK Unified / Extensions / 常用全角符号区
fn is_cjk(c : Char) -> Bool {
  let x = c.to_int()
  (x >= 0x4E00 && x <= 0x9FFF) ||
  (x >= 0x3400 && x <= 0x4DBF) ||
  (x >= 0xF900 && x <= 0xFAFF) ||
  (x >= 0xFF00 && x <= 0xFFEF)
}
