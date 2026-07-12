# external_bench provenance audit

This note records the local provenance and redistribution review for the
`copied_from_external_bench` rows currently accepted in
`external_bench/MANIFEST.tsv`.

Scope of this round:

- Only the 24 `copied_from_external_bench` rows were reviewed here.
- `copied_from_samples`, `copied_from_external_quality`,
  `derived_from_external_quality`, and `generated_tracked` rows are out of
  scope for this note.
- This note is not legal advice. It records the repository's current evidence
  anchors, local file self-identification, and redistribution judgment.

Review method:

- Match each accepted `bench_id` to its tracked payload in `external_bench/`.
- Check whether the payload self-identifies its source, title, document family,
  or dataset structure.
- Retain a public provenance anchor for the upstream source family or exact
  public endpoint where practical.
- Distinguish static document/spec sources from dynamic data-feed snapshots.

## RFC editor / IETF text documents

Bench rows:

- `txt_small_rfc8259_v1` -> `external_bench/txt/small/txt_small_rfc8259_v1.txt`
- `txt_medium_rfc3986_v1` -> `external_bench/txt/medium/txt_medium_rfc3986_v1.txt`

Local evidence:

- `txt_small_rfc8259_v1.txt` begins with RFC front matter identifying
  `Request for Comments: 8259`, `December 2017`, and the RFC Editor info URL
  `https://www.rfc-editor.org/info/rfc8259`.
- `txt_medium_rfc3986_v1.txt` begins with RFC front matter identifying
  `Request for Comments: 3986`, `STD: 66`, and says `Distribution of this memo
  is unlimited`.

Public anchors:

- Exact text forms:
  - `https://www.rfc-editor.org/rfc/rfc8259.txt`
  - `https://www.rfc-editor.org/rfc/rfc3986.txt`
- IETF Trust legal page:
  `https://trustee.ietf.org/documents/trust-legal-provisions/`

Conclusion:

- Retain as RFC/IETF document samples with stable public provenance.
- Repository handling should continue to preserve RFC attribution and the IETF
  Trust licensing context referenced by the document family.

Residual risk:

- Low. These are stable standards documents with strong self-identification and
  stable public text URLs.

## USGS earthquake CSV feed snapshots

Bench rows:

- `csv_small_usgs_all_day_v1` ->
  `external_bench/csv/small/csv_small_usgs_all_day_v1.csv`
- `csv_large_usgs_all_month_v1` ->
  `external_bench/csv/large/csv_large_usgs_all_month_v1.csv`

Local evidence:

- Both files begin with the canonical USGS earthquake CSV header:
  `time,latitude,longitude,depth,...`.
- Both payloads contain live earthquake feed record fields such as `net`, `id`,
  `updated`, `place`, `status`, `locationSource`, and `magSource`.

Public anchors:

- Feed endpoints:
  - `https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/all_day.csv`
  - `https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/all_month.csv`
- USGS copyright policy anchor:
  `https://www.usgs.gov/information-policies-and-instructions/copyrights-and-credits`
- The official USGS policy page states that `USGS-authored or produced data and
  information are considered to be in the U.S. Public Domain`, while also
  warning that some non-USGS images/graphics on USGS sites may remain
  third-party copyrighted.

Conclusion:

- Retain as public USGS feed snapshots with strong endpoint-level provenance.
- The official USGS copyright policy matches the repository's treatment of
  these earthquake CSV feed snapshots as public-domain style USGS-authored data.
- Treat these rows as tracked snapshots of dynamic public feeds, not as claims
  that the current upstream feed still matches the checked-in bytes.

Residual risk:

- Low. Endpoint provenance is clear and the official USGS policy page states
  that USGS-authored or produced data and information are in the U.S. public
  domain.

## Our World in Data CC BY dataset snapshot

Bench row:

- `csv_medium_owid_life_expectancy_v1` ->
  `external_bench/csv/medium/csv_medium_owid_life_expectancy_v1.csv`

Local evidence:

- The CSV header is `Entity,Code,Year,Life expectancy`.
- The first records match the public OWID grapher dataset structure for life
  expectancy.

Public anchors:

- Exact dataset endpoint:
  `https://ourworldindata.org/grapher/life-expectancy.csv`
- Exact metadata endpoint:
  `https://ourworldindata.org/grapher/life-expectancy.metadata.json?v=1&csvType=full&useColumnShortNames=false`
- OWID topic/chart pages for this dataset state `Reuse this work freely` and
  say that `All visualizations, data, and articles produced by Our World in
  Data are completely open access under the Creative Commons BY license`.
- The metadata for this chart records
  `citationShort: ... with major processing by Our World in Data` and
  `owidProcessingLevel: major`.
- General CC license anchor:
  `https://creativecommons.org/licenses/by/4.0/`

Conclusion:

- Retain as a CC BY OWID-produced long-run dataset snapshot with exact public
  endpoint and metadata-level provenance.
- The chart metadata makes clear that this downloadable series is a combined
  OWID-produced dataset with major processing layered on top of cited upstream
  demographic sources.

Residual risk:

- Low. The exact CSV endpoint is strong and the chart/topic pages plus chart
  metadata now provide direct CC BY and OWID-processing evidence for this
  downloadable dataset.

## UniProt TSV dataset snapshot

Bench row:

- `tsv_small_uniprot_reviewed_v1` ->
  `external_bench/tsv/small/tsv_small_uniprot_reviewed_v1.tsv`

Local evidence:

- The TSV header is `Entry`, `Entry Name`, `Protein names`, `Organism`,
  `Length`.
- The records are UniProt-style accession rows for reviewed proteins.

Public anchors:

- Exact reproducible REST export checked against the tracked TSV:
  `https://rest.uniprot.org/uniprotkb/search?format=tsv&fields=accession,id,protein_name,organism_name,length&size=20&query=%28reviewed%3Atrue%29%20AND%20%28organism_id%3A9606%29`
- Exact REST record endpoint exposing the current copyright statement:
  `https://rest.uniprot.org/uniprotkb/A0A0C5B5G6.xml`
- Source family anchor:
  `https://www.uniprot.org/`
- The REST XML payload for `A0A0C5B5G6` contains the line
  `Copyrighted by the UniProt Consortium ... Distributed under the Creative Commons Attribution (CC BY 4.0) License`.
- The current help/license page is heavily app-rendered in the command-line
  environment, so the repository retained the REST-delivered copyright
  statement as the stronger machine-readable legal anchor in this round.
- License category retained in repository metadata remains `CC-BY-4.0`.

Conclusion:

- Retain as a UniProt public dataset snapshot with strong query-level
  provenance and repository-level CC-BY-4.0 attribution expectations.
- The checked-in TSV exactly matches the reviewed-human REST export returned by
  the query above for the inspected rows, including the header and the first
  accession records.

Residual risk:

- Low. The payload provenance is strong at the export-query level and the
  official REST record payload exposes the current CC BY 4.0 copyright
  statement directly.

## SPDX JSON data

Bench rows:

- `json_small_spdx_exceptions_v1` ->
  `external_bench/json/small/json_small_spdx_exceptions_v1.json`
- `json_medium_spdx_licenses_v1` ->
  `external_bench/json/medium/json_medium_spdx_licenses_v1.json`

Local evidence:

- The small JSON contains SPDX exception objects with fields such as
  `licenseExceptionId`, `detailsUrl`, and `reference`.
- The medium JSON contains SPDX license list entries with fields such as
  `licenseId`, `detailsUrl`, `reference`, and `isOsiApproved`.

Public anchors:

- SPDX data site references embedded in the files point to `https://spdx.org/`.
- Repository metadata classifies these sources as `CC0-1.0`.

Conclusion:

- Retain as SPDX structured license metadata with strong self-identification.

Residual risk:

- Low. The payloads directly self-identify as SPDX license-list data.

## World Bank API snapshots

Bench rows:

- `json_large_worldbank_population_v1` ->
  `external_bench/json/large/json_large_worldbank_population_v1.json`
- `xml_large_worldbank_population_v1` ->
  `external_bench/xml/large/xml_large_worldbank_population_v1.xml`

Local evidence:

- The JSON payload starts with a World Bank API metadata array containing
  `page`, `pages`, `per_page`, `total`, `sourceid`, and `lastupdated`.
- The XML payload begins with `<wb:data ... xmlns:wb="http://www.worldbank.org">`
  and includes indicator `SP.POP.TOTL`.
- Both checked-in files are clearly the World Bank `Population, total` API
  output family.

Public anchors:

- Exact API endpoints:
  - `https://api.worldbank.org/v2/country/all/indicator/SP.POP.TOTL?format=json&per_page=20000`
  - `https://api.worldbank.org/v2/country/all/indicator/SP.POP.TOTL?format=xml&per_page=20000`
- World Bank legal/terms page:
  `https://www.worldbank.org/ext/en/legal/terms-conditions`

Conclusion:

- Retain as exact public API snapshots with strong endpoint-level provenance.
- Treat the checked-in files as benchmark snapshots; upstream API contents and
  `lastupdated` values are expected to drift over time.

Residual risk:

- Medium-low. Provenance is strong, but these are inherently dynamic API
  snapshots.

## GitHub / Kubernetes / Swagger YAML sources

Bench rows:

- `yaml_tiny_k8s_deployment_v1` ->
  `external_bench/yaml/tiny/yaml_tiny_k8s_deployment_v1.yaml`
- `yaml_small_swagger_petstore_v1` ->
  `external_bench/yaml/small/yaml_small_swagger_petstore_v1.yaml`

Local evidence:

- `yaml_tiny_k8s_deployment_v1.yaml` contains the canonical deployment example
  with `apiVersion: apps/v1`, `kind: Deployment`, and
  `metadata.name: nginx-deployment`.
- `yaml_small_swagger_petstore_v1.yaml` contains `openapi: 3.0.4`, identifies
  itself as `Swagger Petstore - OpenAPI 3.0`, links to the upstream Petstore
  repository, and includes an inline `license` object naming `Apache 2.0`.

Public anchors:

- Kubernetes example family anchor:
  `https://kubernetes.io/docs/concepts/workloads/controllers/deployment/`
- Swagger Petstore repo family anchor:
  `https://github.com/swagger-api/swagger-petstore`
- Repository metadata classifies both rows under Apache-2.0.

Conclusion:

- Retain as public OSS example/configuration samples.
- The Swagger row has strong in-file license self-identification.
- The Kubernetes row is a canonical tutorial example with strong content-family
  provenance even though this round's raw GitHub fetch timed out.

Residual risk:

- Low for `yaml_small_swagger_petstore_v1`.
- Medium-low for `yaml_tiny_k8s_deployment_v1` because the exact raw source URL
  was not re-fetched in this environment.

## W3C specifications

Bench rows:

- `html_medium_wcag22_v1` ->
  `external_bench/html/medium/html_medium_wcag22_v1.html`
- `html_large_wai_aria_v1` ->
  `external_bench/html/large/html_large_wai_aria_v1.html`

Local evidence:

- `html_medium_wcag22_v1.html` includes the generated subtitle
  `W3C Recommendation 12 December 2024` and title
  `Web Content Accessibility Guidelines (WCAG) 2.2`.
- `html_large_wai_aria_v1.html` includes the generated subtitle
  `W3C Recommendation 06 June 2023` and title
  `Accessible Rich Internet Applications (WAI-ARIA) 1.2`.

Public anchors:

- Spec URLs:
  - `https://www.w3.org/TR/WCAG22/`
  - `https://www.w3.org/TR/wai-aria-1.2/`
- W3C document license:
  `https://www.w3.org/copyright/document-license-2023/`

Conclusion:

- Retain as W3C specification samples with strong exact-document provenance.
- Redistribution must continue to follow the W3C document-license notice and
  attribution requirements.

Residual risk:

- Low. Both payloads self-identify clearly and the exact document-license page
  was revalidated during this review.

## Project Gutenberg EPUB / HTML package samples

Bench rows:

- `zip_large_gutenberg_sherlock_html_v1` ->
  `external_bench/zip/large/zip_large_gutenberg_sherlock_html_v1.zip`
- `epub_medium_alice_v1` ->
  `external_bench/epub/medium/epub_medium_alice_v1.epub`
- `epub_large_moby_dick_v1` ->
  `external_bench/epub/large/epub_large_moby_dick_v1.epub`

Local evidence:

- The ZIP contains `pg1661-images.html` and `images/cover.jpg`; the HTML title
  reads `The Adventures of Sherlock Holmes | Project Gutenberg`.
- `epub_medium_alice_v1.epub` `content.opf` records:
  - `dc:title`: `Alice's Adventures in Wonderland`
  - `dc:identifier`: `http://www.gutenberg.org/11`
  - `dc:rights`: `Public domain in the USA.`
  - `dc:source`: `https://www.gutenberg.org/files/11/11-h/11-h.htm`
- `epub_large_moby_dick_v1.epub` `content.opf` records:
  - `dc:title`: `Moby Dick; Or, The Whale`
  - `dc:identifier`: `http://www.gutenberg.org/2701`
  - `dc:rights`: `Public domain in the USA.`
  - `dc:source`: `https://www.gutenberg.org/files/2701/2701-h/2701-h.htm`

Public anchors:

- Exact public pages:
  - `https://www.gutenberg.org/cache/epub/1661/pg1661-images.html`
  - `https://www.gutenberg.org/files/11/11-h/11-h.htm`
  - `https://www.gutenberg.org/files/2701/2701-h/2701-h.htm`
- Project Gutenberg policy/help page fetched during review:
  `https://www.gutenberg.org/policy/permission.html`

Conclusion:

- Retain as Project Gutenberg public ebook/package samples.
- Repository handling should keep the Project Gutenberg provenance and embedded
  rights/header context intact.

Residual risk:

- Low. These samples have strong in-file source metadata and exact public page
  matches.

## NIST native-text PDFs

Bench rows:

- `pdf_medium_nist_800_207_v1` ->
  `external_bench/pdf/medium/pdf_medium_nist_800_207_v1.pdf`
- `pdf_large_nist_800_53r5_v1` ->
  `external_bench/pdf/large/pdf_large_nist_800_53r5_v1.pdf`

Local evidence:

- `pdfinfo` for `pdf_medium_nist_800_207_v1.pdf` reports title
  `Zero Trust Architecture` and a 59-page NIST publication.
- `pdfinfo` for `pdf_large_nist_800_53r5_v1.pdf` reports title
  `Security and Privacy Controls for Information Systems and Organizations` and
  a 492-page NIST publication.

Public anchors:

- Exact files:
  - `https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-207.pdf`
  - `https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-53r5.pdf`
- NIST open-license page:
  `https://www.nist.gov/open/license`

Conclusion:

- Retain as official NIST technical-series PDFs.
- This aligns with the existing repository treatment of NIST technical-series
  material as U.S. public-domain style in the United States with NIST's stated
  republication permissions.

Residual risk:

- Low. Exact publication filenames and local PDF metadata align strongly.

## UK open-government Office documents

Bench rows:

- `docx_small_dvla_user_guide_v1` ->
  `external_bench/docx/small/docx_small_dvla_user_guide_v1.docx`
- `pptx_large_nhs_diabetes_v1` ->
  `external_bench/pptx/large/pptx_large_nhs_diabetes_v1.pptx`
- `xlsx_medium_regional_1971_2020_v1` ->
  `external_bench/xlsx/medium/xlsx_medium_regional_1971_2020_v1.xlsx`
- `xlsx_large_myeb_2011_2022_v1` ->
  `external_bench/xlsx/large/xlsx_large_myeb_2011_2022_v1.xlsx`
- `xlsx_huge_myeb_2011_2024_v1` ->
  `external_bench/xlsx/huge/xlsx_huge_myeb_2011_2024_v1.xlsx`

Local evidence:

- The DVLA DOCX core properties title is `Driving Licence Data User Guide`, and
  the document body begins with that same title and explicitly references the
  `Driver and Vehicle Licensing Agency (DVLA)`.
- The DVLA DOCX also records `Company` = `DVLA` in OOXML app properties and
  embeds external GOV.UK hyperlinks in document relationships.
- The NHS PPTX first slide text reads
  `Diabetes Prevention Programme, 2017-18 Diagnoses and Demographics`,
  `England`, `11 July 2019`.
- The ONS regional XLSX core title is
  `Estimates of the population for the UK, England and Wales, Scotland and Northern Ireland`
  and workbook sheets include `Terms and conditions`, `Notes and definitions`,
  and numbered tables.
- The two MYEB XLSX files have weaker core metadata, but workbook sheet names
  such as `Cover sheet`, `Contents`, `Notes`, `Related publications`, and
  `MYEB1`...`MYEB5` strongly match ONS mid-year estimate workbook structure.

Public anchors:

- UK Open Government Licence v3.0:
  `https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/`
- Department for Transport dataset page:
  `https://www.data.gov.uk/dataset/d0be1ed2-9907-4ec4-b552-c048f6aec16a/driving-licence-data`
- Exact public download URLs recovered during this review:
  - DVLA DOCX:
    `https://data.dft.gov.uk/driving-licence-data/driving-licence-data-user-guide-sep-2017.docx`
  - NHS PPTX:
    `https://files.digital.nhs.uk/A6/CD0E5A/NDA_DPP_MainReport_1718_1.1.pptx`
  - ONS regional workbook:
    `https://www.ons.gov.uk/file?uri=%2Fpeoplepopulationandcommunity%2Fpopulationandmigration%2Fpopulationestimates%2Fdatasets%2Fpopulationestimatesforukenglandandwalesscotlandandnorthernireland%2Fmid2001tomid2020detailedtimeseries%2Fregionalpopestimatesenglandandwales19712020.xlsx`
  - ONS MYEB 2011-2022 workbook:
    `https://www.ons.gov.uk/file?uri=%2Fpeoplepopulationandcommunity%2Fpopulationandmigration%2Fpopulationestimates%2Fdatasets%2Fpopulationestimatesforukenglandandwalesscotlandandnorthernireland%2Fmid2011tomid2022%2Fmyebtablesuk20112022.xlsx`
  - ONS MYEB 2011-2024 workbook:
    `https://www.ons.gov.uk/file?uri=%2Fpeoplepopulationandcommunity%2Fpopulationandmigration%2Fpopulationestimates%2Fdatasets%2Fpopulationestimatesforukenglandandwalesscotlandandnorthernireland%2Fmid2011tomid2024%2Fmyebtablesuk20112024.xlsx`

Conclusion:

- Retain as UK public-sector/open-government Office samples under OGL-UK-3.0.
- The Department for Transport dataset page exposes `UK Open Government Licence
  (OGL)` metadata and links directly to the DVLA user-guide DOCX.
- The checked-in `docx_small_dvla_user_guide_v1.docx` matches the public DVLA
  user-guide download exactly by byte size `22817` and SHA-256
  `4f330dbb878996b684409933a1dde9c28bc22fd5119326aff1be5ee5c91ac021`.
- The NHS and ONS workbook files now have both strong in-file identification
  and exact public download URLs retained in this note.
- These rows should continue to preserve attribution requirements and should not
  be described as project-owned material.

Residual risk:

- Low. The OGL legal basis is strong and the DVLA, NHS, and ONS files now all
  have exact public download anchors retained in this note.

## Overall conclusion for this scope

- All 24 `copied_from_external_bench` rows reviewed here have usable local
  provenance anchors and can remain `accepted` in `external_bench/MANIFEST.tsv`.
- The strongest source families in this scope are RFC/IETF, W3C, Project
  Gutenberg, NIST, World Bank, and the Swagger OpenAPI sample.
- No material legal blockers remain inside this reviewed `copied_from_external_bench`
  subset.
- The remaining caveats are documentary rather than infringement blockers:
  - Dynamic feeds and APIs such as USGS and World Bank should continue to be
    treated as tracked snapshots rather than freshness claims about current
    upstream bytes.

## Project-owned balance audio contracts

- `audio_contract_wav_v1`, `audio_contract_mp3_v1`, and
  `audio_contract_m4a_v1` are exact copies of the Apache-2.0 main-repository
  fixtures under `samples/fixtures/contracts/audio/`.
- They are retained only for deterministic balance-mode self-baseline runs.
- SHA-256 values and byte sizes are recorded in `external_bench/MANIFEST.tsv`;
  accurate mode is intentionally excluded from all benchmark suites.
