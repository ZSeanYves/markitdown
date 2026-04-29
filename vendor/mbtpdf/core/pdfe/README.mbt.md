# @bobzhang/mbtpdf/core/pdfe

Error logging utilities for PDF operations.

## Overview

This package provides a configurable logging system for error messages during PDF processing. It uses a replaceable logger function that defaults to writing to stderr.

In addition, it provides:

- A `quiet` flag to suppress `@pdfe.log` output.
- Scoped helpers (`with_silenced_logs`, `with_logger`) that restore state even if the action fails.

## Types

### Logger

Type alias for logging functions:

```moonbit nocheck
///|
pub type Logger = (String) -> Unit
```

## Values

### logger

The current error logger, stored as a mutable reference. Can be replaced for custom logging behavior.

```moonbit nocheck
pub let logger : Ref[Logger]
```

### quiet

When `true`, calls to `@pdfe.log` are suppressed.

```moonbit nocheck
pub let quiet : Ref[Bool]
```

### read_debug

Debug flag for PDF reading operations. Set to `true` to enable debug output.

```moonbit nocheck
pub let read_debug : Ref[Bool]
```

## Functions

### log

Log a message using the current logger.

```moonbit check
///|
test "log: captures messages with custom logger" {
  let messages : Array[String] = []
  @pdfe.with_logger(fn(msg) { messages.push(msg) }, fn() {
    @pdfe.log("hello")
    @pdfe.log("world")
    ()
  })
  inspect(messages, content="[\"hello\", \"world\"]")
}
```

### with_silenced_logs

Run an action with logging suppressed, restoring the previous state.

```moonbit check
///|
test "with_silenced_logs: suppresses log calls within scope" {
  let messages : Array[String] = []
  @pdfe.with_logger(fn(msg) { messages.push(msg) }, fn() {
    @pdfe.with_silenced_logs(fn() {
      @pdfe.log("hidden")
      ()
    })
    @pdfe.log("shown")
    ()
  })
  inspect(messages, content="[\"shown\"]")
}
```

### with_logger

Run an action with a temporary logger, restoring the previous logger.

```moonbit nocheck
pub fn[T] with_logger(Logger, () -> T raise) -> T raise
```

## Usage

**Capture logs in tests:**

```moonbit nocheck
let messages : Array[String] = []
@pdfe.with_logger(fn(msg) { messages.push(msg) }, fn() {
  // ... code that calls @pdfe.log() ...
  ()
})
```

**Silence noisy logs for a scope (recommended for tests that trigger malformed inputs):**

```moonbit nocheck
@pdfe.with_silenced_logs(fn() {
  // ... code that calls @pdfe.log() ...
  ()
})
```

**Enable debug mode:**

```moonbit nocheck
@pdfe.read_debug.val = true
```
