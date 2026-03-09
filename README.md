# TimeInvoice

Takes JSON output from [Time Watcher](https://codeberg.org/ellyxir/time_watcher) containing
daily work hours per project and generates a markdown invoice. Pipe to pandoc for PDF.

It doesn't need to work with Time Watcher, you could just create the JSON needed and it will
create the invoice just fine.

```sh
tw report --json --from 2026-01-01 --to 2026-01-31 | ti --project my_client | pandoc -o invoice.pdf
```

## Installation

### From source

Requires Elixir 1.18+.

```sh
git clone https://codeberg.org/ellyxir/time_invoice.git
cd time_invoice
mix deps.get
MIX_ENV=prod mix release time_invoice
```

This builds the release at `_build/prod/rel/time_invoice/`. The `ti` command lives inside it:

```sh
# Run directly from the build
_build/prod/rel/time_invoice/bin/ti --project acme < report.json

# Or symlink it onto your PATH
ln -s "$(pwd)/_build/prod/rel/time_invoice/bin/ti" ~/.local/bin/ti
```

