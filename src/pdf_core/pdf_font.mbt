///|
pub struct PdfFontRef {
  resource_name : String
  obj_num : Int
  gen : Int
  to_unicode_obj : Int?
  to_unicode_gen : Int?
}

///|
fn as_dict(v : PdfValue, ctx : String) -> Map[String, PdfValue] raise {
  match v {
    PdfValue::Dict(dict) => dict
    _ => raise TypeMismatch(ctx + " must be dictionary")
  }
}

///|
fn lookup_page_resources_dict(
  doc : PdfDocument,
  page_obj : Int,
  page_gen : Int,
) -> Map[String, PdfValue]? raise {
  let mut cur_obj = page_obj
  let mut cur_gen = page_gen

  while true {
    let node = get_indirect_object(doc, cur_obj, cur_gen)
    let dict = as_dict(node.value, "page tree node")

    match dict.get("Resources") {
      Some(PdfValue::Dict(res)) => return Some(res)
      Some(PdfValue::Ref(obj, gen)) => {
        let res_obj = get_indirect_object(doc, obj, gen)
        return Some(as_dict(res_obj.value, "resources"))
      }
      Some(_) => raise TypeMismatch("/Resources must be dict or ref")
      None => ()
    }

    match dict.get("Parent") {
      Some(PdfValue::Ref(obj, gen)) => {
        cur_obj = obj
        cur_gen = gen
      }
      _ => return None
    }
  } nobreak {
    None
  }
}

///|
pub fn resolve_page_fonts(
  doc : PdfDocument,
  page_obj : Int,
  page_gen : Int,
) -> Map[String, PdfFontRef] raise {
  let out : Map[String, PdfFontRef] = Map::new()
  let resources_opt = lookup_page_resources_dict(doc, page_obj, page_gen)
  let resources = match resources_opt {
    Some(v) => v
    None => return out
  }

  let font_map = match resources.get("Font") {
    Some(PdfValue::Dict(d)) => d
    Some(PdfValue::Ref(obj, gen)) => {
      let font_obj = get_indirect_object(doc, obj, gen)
      as_dict(font_obj.value, "font resources")
    }
    _ => return out
  }

  let candidate_names = [
    "F0", "F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "TT0", "TT1",
  ]
  for name in candidate_names {
    match font_map.get(name) {
      Some(PdfValue::Ref(obj, gen)) => {
        let mut to_unicode_obj : Int? = None
        let mut to_unicode_gen : Int? = None
        let font_obj = get_indirect_object(doc, obj, gen)
        match font_obj.value {
          PdfValue::Dict(fd) =>
            match fd.get("ToUnicode") {
              Some(PdfValue::Ref(cobj, cgen)) => {
                to_unicode_obj = Some(cobj)
                to_unicode_gen = Some(cgen)
              }
              _ => ()
            }
          _ => ()
        }
        out.set(name, {
          resource_name: name,
          obj_num: obj,
          gen,
          to_unicode_obj,
          to_unicode_gen,
        })
      }
      _ => ()
    }
  }

  out
}
