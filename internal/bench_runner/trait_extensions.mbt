///|
pub extend BenchError with Show::{to_string, output}

///|
pub extend BenchCliError with Show::{to_string, output}

///|
pub extend BenchRow with ToJson::{to_json}

///|
pub extend RunSummary with ToJson::{to_json}

///|
pub extend SampleRow with ToJson::{to_json}

///|
pub extend CaseAggregate with ToJson::{to_json}

///|
pub extend SelectorStats with ToJson::{to_json}
