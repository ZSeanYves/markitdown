///|
fn bench_elapsed_us_since(started : Int64) -> Int {
  let now = now_us()
  if now <= started {
    0
  } else {
    (now - started).to_int()
  }
}

///|
fn print_bench_usage() -> Unit {
  println("Usage:")
  println("  markitdown-mb-bench _bench-noop")
  println(
    "  markitdown-mb-bench _bench-startup-profile <noop|help|normal_txt_small> ...",
  )
  println(
    "  markitdown-mb-bench _bench-product-path --input <path> --output-root <dir> [--with-metadata] [--with-assets]",
  )
}

///|
async fn main {
  let startup_profile_started = now_us()
  let args = @sys.get_cli_args()
  let args_available_us = bench_elapsed_us_since(startup_profile_started)
  let cli_args : Array[String] = normalize_cli_args(args)
  let cli_args_ready_us = bench_elapsed_us_since(startup_profile_started)

  if cli_args.length() == 0 {
    print_bench_usage()
    return
  }

  if maybe_run_hidden_bench_command(
      cli_args,
      startup_profile_started,
      args.length(),
      args_available_us,
      cli_args_ready_us,
    ) {
    return
  }

  let parser = new_cli_parser()
  let value = @clap.SimpleValue::new("markitdown-mb-bench")
  let subcmd_help = parser.parse(value, cli_args[:]) catch {
    e => {
      println(e)
      print_bench_usage()
      return
    }
  }

  match subcmd_help {
    Some(msg) => println(msg)
    None =>
      match value.subcmd {
        Some(sub) => {
          let positional = sub.positional_args
          let with_metadata = sub.get_flag("with-metadata").unwrap_or(false)
          if sub.name != "normal" {
            exit_error(
              "bench only supports hidden bench commands and `normal` for cold-start benchmarks",
            )
            print_bench_usage()
            @sys.exit(2)
            return
          }

          if positional.length() < 1 || positional.length() > 2 {
            exit_error("usage: normal [--with-metadata] <input> [output]")
            print_bench_usage()
            @sys.exit(2)
            return
          }

          let input = positional[0]
          let output_opt = if positional.length() >= 2 {
            Some(positional[1])
          } else {
            None
          }
          cmd_convert(
            input,
            output_opt,
            None,
            6,
            None,
            false,
            false,
            false,
            with_metadata,
          )
        }
        None => print_bench_usage()
      }
  }
}
