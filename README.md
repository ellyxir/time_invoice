# TimeInvoice

Takes JSON output from [Time Watcher](https://codeberg.org/ellyxir/time_watcher) containing
daily work hours per project and generates a markdown invoice. Pipe to pandoc for PDF.

It doesn't need to work with Time Watcher, you could just create the JSON needed and it will
create the invoice just fine.

```sh
tw report --json --from 2026-01-01 --to 2026-01-31 | ti --project my_client | pandoc -o invoice.pdf
```

More info to come once it's built!

