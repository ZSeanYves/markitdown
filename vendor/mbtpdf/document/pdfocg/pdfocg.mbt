///|
/// Placeholder for optional content group usage dictionaries.
pub(all) enum OcgUsage {
  Placeholder
} derive(Debug)

///|
pub struct PdfOcg {
  pdf : @pdf.Pdf
}

///|
type PdfObject = @pdf.PdfObject

///|
pub fn PdfOcg::new(pdf : @pdf.Pdf) -> PdfOcg {
  { pdf, }
}

///|
/// Optional content group.
pub(all) struct Ocg {
  ocg_name : String
  ocg_intent : Array[String]
  ocg_usage : OcgUsage?
} derive(Debug)

///|
/// Optional content group visibility state.
pub(all) enum OcgState {
  On
  Off
  Unchanged
} derive(Debug)

///|
/// Optional content group list mode.
pub(all) enum OcgListMode {
  AllPages
  VisiblePages
} derive(Debug)

///|
/// Placeholder for optional content group application dictionaries.
pub(all) enum OcgAppDict {
  AppDict
} derive(Debug)

///|
/// Placeholder for optional content order tree.
pub(all) enum OcgOrderTree {
  Leaf
  Branch(Int, OcgOrderTree, OcgOrderTree)
} derive(Debug)

///|
/// Optional content group configuration.
pub(all) struct OcgConfig {
  ocgconfig_name : String?
  ocgconfig_creator : String?
  ocgconfig_basestate : OcgState
  ocgconfig_on : Array[Int]?
  ocgconfig_off : Array[Int]?
  ocgconfig_intent : Array[String]
  ocgconfig_usage_application_dictionaries : Array[OcgAppDict]?
  ocgconfig_order : OcgOrderTree?
  ocgconfig_listmode : OcgListMode
  ocgconfig_rbgroups : Array[Array[Int]]
  ocgconfig_locked : Array[Int]
} derive(Debug)

///|
/// Optional content properties.
pub(all) struct OcgProperties {
  ocgs : Array[(Int, Ocg)]
  ocg_default_config : OcgConfig
  ocg_configs : Array[OcgConfig]
} derive(Debug)

///|
fn read_ocgappdict(pdf : @pdf.Pdf, appdict : @pdf.PdfObject) -> OcgAppDict {
  let _ = pdf
  let _ = appdict
  OcgAppDict::AppDict
}

///|
fn read_config(pdf : @pdf.Pdf, config : @pdf.PdfObject) -> OcgConfig {
  let ocgconfig_name = match pdf.lookup_direct("/Name", config) {
    Some(PdfObject::String(s)) => Some(s)
    _ => None
  }
  let ocgconfig_creator = match pdf.lookup_direct("/Creator", config) {
    Some(PdfObject::String(s)) => Some(s)
    _ => None
  }
  let ocgconfig_basestate = match pdf.lookup_direct("/BaseState", config) {
    Some(PdfObject::Name(name)) if name.equal_string_bytes("/ON") =>
      OcgState::On
    Some(PdfObject::Name(name)) if name.equal_string_bytes("/OFF") =>
      OcgState::Off
    Some(PdfObject::Name(name)) if name.equal_string_bytes("/Unchanged") =>
      OcgState::Unchanged
    _ => OcgState::On
  }
  let ocgconfig_on = match pdf.lookup_direct("/ON", config) {
    Some(PdfObject::Array(indirects)) =>
      Some(
        indirects.map(obj => match obj {
          PdfObject::Indirect(n) => n
          _ => 0
        }),
      )
    _ => None
  }
  let ocgconfig_off = match pdf.lookup_direct("/OFF", config) {
    Some(PdfObject::Array(indirects)) =>
      Some(
        indirects.map(obj => match obj {
          PdfObject::Indirect(n) => n
          _ => 0
        }),
      )
    _ => None
  }
  let ocgconfig_intent = match pdf.lookup_direct("/Intent", config) {
    Some(PdfObject::Name(n)) => [n.to_string_bytes()]
    Some(PdfObject::Array(items)) =>
      items.map(item => match pdf.direct(item) {
        PdfObject::Name(n) => n.to_string_bytes()
        _ => ""
      })
    _ => ["/View"]
  }
  let ocgconfig_usage_application_dictionaries = match
    pdf.lookup_direct("/AS", config) {
    Some(PdfObject::Array(appdicts)) =>
      Some(appdicts.map(appdict => read_ocgappdict(pdf, appdict)))
    _ => None
  }
  let ocgconfig_order = None
  let ocgconfig_listmode = match pdf.lookup_direct("/ListMode", config) {
    Some(PdfObject::Name(name)) if name.equal_string_bytes("/VisiblePages") =>
      OcgListMode::VisiblePages
    _ => OcgListMode::AllPages
  }
  let ocgconfig_rbgroups = []
  let ocgconfig_locked = match pdf.lookup_direct("/Locked", config) {
    Some(PdfObject::Array(items)) =>
      items.map(item => match pdf.direct(item) {
        PdfObject::Indirect(n) => n
        _ => 0
      })
    _ => []
  }
  {
    ocgconfig_name,
    ocgconfig_creator,
    ocgconfig_basestate,
    ocgconfig_on,
    ocgconfig_off,
    ocgconfig_intent,
    ocgconfig_usage_application_dictionaries,
    ocgconfig_order,
    ocgconfig_listmode,
    ocgconfig_rbgroups,
    ocgconfig_locked,
  }
}

///|
fn read_ocg_usage(pdf : @pdf.Pdf, usage : @pdf.PdfObject) -> OcgUsage? {
  let _ = pdf
  let _ = usage
  None
}

///|
fn read_individual_ocg(pdf : @pdf.Pdf, ocg : @pdf.PdfObject) -> Ocg raise {
  let ocg_name = match pdf.lookup_direct("/Name", ocg) {
    Some(PdfObject::String(s)) => s
    _ => raise @pdf.PdfError::Msg("No /Name in optional content group")
  }
  let ocg_intent = match pdf.lookup_direct("/Intent", ocg) {
    Some(PdfObject::Name(n)) => [n.to_string_bytes()]
    Some(PdfObject::Array(items)) =>
      items.filter_map(item => match pdf.direct(item) {
        PdfObject::Name(n) => Some(n.to_string_bytes())
        _ => None
      })
    _ => ["/View"]
  }
  let ocg_usage = match pdf.lookup_direct("/Usage", ocg) {
    None => None
    Some(usage) => read_ocg_usage(pdf, usage)
  }
  { ocg_name, ocg_intent, ocg_usage }
}

///|
/// Read optional content data.
pub fn OcgProperties::read(pdf : @pdf.Pdf) -> OcgProperties? raise {
  match pdf.lookup_direct("/Root", pdf.trailerdict) {
    None => raise @pdf.PdfError::Msg("No /Root")
    Some(root) =>
      match pdf.lookup_direct("/OCProperties", root) {
        None => None
        Some(ocproperties) => {
          let ocgs = match pdf.lookup_direct("/OCGs", ocproperties) {
            Some(PdfObject::Array(indirects)) => {
              let out = Array::new()
              for entry in indirects {
                let num = match entry {
                  PdfObject::Indirect(n) => n
                  _ => 0
                }
                out.push((num, read_individual_ocg(pdf, entry)))
              }
              out
            }
            _ => []
          }
          let ocg_default_config = match pdf.lookup_direct("/D", ocproperties) {
            None =>
              raise @pdf.PdfError::Msg("No default config in /OCProperties")
            Some(config) => read_config(pdf, config)
          }
          let ocg_configs = match pdf.lookup_direct("/Configs", ocproperties) {
            Some(PdfObject::Array(configs)) =>
              configs.map(config => read_config(pdf, config))
            _ => []
          }
          Some({ ocgs, ocg_default_config, ocg_configs })
        }
      }
  }
}

///|
/// Write optional content data.
pub fn OcgProperties::write(self : OcgProperties, pdf : @pdf.Pdf) -> Unit {
  let _ = pdf
  let _ = self
  ()
}

///|
pub fn PdfOcg::read(self : PdfOcg) -> OcgProperties? raise {
  OcgProperties::read(self.pdf)
}

///|
pub fn PdfOcg::write(self : PdfOcg, ocg : OcgProperties) -> Unit {
  ocg.write(self.pdf)
}

///|
fn print_ocg(pair : (Int, Ocg)) -> Unit {
  let num = pair.0
  let ocg = pair.1
  @pdfutil.PdfUtil::new().flprint("OCG \{num}\n")
  @pdfutil.PdfUtil::new().flprint("Name \{ocg.ocg_name}\n")
  let sb = StringBuilder::new()
  sb.write_string("Intent(s)")
  for intent in ocg.ocg_intent {
    sb..write_char(' ')..write_string(intent)
  }
  sb.write_char('\n')
  @pdfutil.PdfUtil::new().flprint(sb.to_string())
}

///|
fn print_ocg_config(config : OcgConfig) -> Unit {
  match config.ocgconfig_name {
    None => @pdfutil.PdfUtil::new().flprint("No config name\n")
    Some(name) => @pdfutil.PdfUtil::new().flprint("Config Name: \{name}\n")
  }
}

///|
/// Print information about the document's Optional Content Groups.
/// Debug only.
pub fn PdfOcg::print_document(self : PdfOcg) -> Unit raise {
  match OcgProperties::read(self.pdf) {
    None =>
      @pdfutil.PdfUtil::new().flprint(
        "There are no optional content groups in this document\n",
      )
    Some(ocgs) => {
      @pdfutil.PdfUtil::new().flprint(
        "There are \{ocgs.ocgs.length()} OCGs, and " +
        "\{ocgs.ocg_configs.length()} additional configs\n",
      )
      @pdfutil.PdfUtil::new().flprint("OCGs\n-------------\n")
      for pair in ocgs.ocgs {
        print_ocg(pair)
      }
      @pdfutil.PdfUtil::new().flprint("OCG Configs\n------------\n")
      for config in ocgs.ocg_configs {
        print_ocg_config(config)
      }
    }
  }
}
