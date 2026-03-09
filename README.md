# TimeInvoice

Takes JSON output from [Time Watcher](https://codeberg.org/ellyxir/time_watcher) containing
daily work hours per project and generates a markdown invoice. Pipe to pandoc for PDF.

It doesn't need to work with Time Watcher, you could just create the JSON needed and it will
create the invoice just fine.

```sh
tw report --json --from 2026-01-01 --to 2026-01-31 | ti --project my_client | pandoc -o invoice.pdf
```

## Installation

### Nix

```sh
nix profile install git+https://codeberg.org/ellyxir/time_invoice
```

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

## Configuration

Create a config file at `~/.config/time_invoice/config.exs` (or `$XDG_CONFIG_HOME/time_invoice/config.exs`):

```elixir
import Config

config :time_invoice, :projects,
  my_client: [
    template: :default,  # uses built-in template, or path like "~/.config/time_invoice/templates/custom.md.eex"
    business_name: "My Consulting LLC",
    business_address: "123 Main Street\nSometown, ST 12345",
    business_email: "billing@example.com",
    client_name: "Acme Corporation",
    client_address: "456 Corporate Blvd\nBigcity, BC 67890",
    hourly_rate: 150.00,
    currency: "$"
  ]
```

### Required fields

| Field | Description |
|-------|-------------|
| `template` | `:default` for built-in, or path to custom EEx template |
| `business_name` | Name of business sending invoice |
| `client_name` | Name of client receiving invoice |
| `hourly_rate` | Rate per hour |
| `currency` | Currency symbol (e.g., `"$"`, `"€"`) |

### Optional fields

| Field | Description |
|-------|-------------|
| `business_address` | Address of business (can include newlines) |
| `business_email` | Contact email |
| `client_address` | Address of client |
| `date_format` | `:eu` (day-month-year) or `:us` (month-day-year), defaults to `:eu` |

Additional custom fields can be added and will be available in templates.

## Custom Templates

Templates are EEx files. Use `@variable_name` to access variables.

### Variables from JSON input

| Variable | Type | Description |
|----------|------|-------------|
| `@project` | string | Project name |
| `@start_date` | string | Formatted start date of report period |
| `@end_date` | string | Formatted end date of report period |
| `@days` | list | List of `%{date: string, hours: number}` |
| `@total_hours` | number | Total hours for the project |

### Variables from config

All config fields are available with `@` prefix (e.g., `@business_name`, `@hourly_rate`).

### Computed variables

| Variable | Type | Description |
|----------|------|-------------|
| `@invoice_number` | string | Generated as `INV-YY-MM-DD` based on generation date |
| `@invoice_date` | string | Date invoice was generated (formatted) |
| `@total_amount` | number | `@total_hours * @hourly_rate` |

Numeric values (`@total_hours`, `@total_amount`, and hours in `@days`) are rounded to 2 decimal places.

### Example template

```eex
# Invoice <%= @invoice_number %>

**Date:** <%= @invoice_date %>

---

**From:**
<%= @business_name %>
<%= @business_address %>
<%= @business_email %>

**To:**
<%= @client_name %>
<%= @client_address %>

---

## Services Rendered

**Period:** <%= @start_date %> - <%= @end_date %>

| Date | Hours |
|------|-------|
<%= for day <- @days do %>| <%= day.date %> | <%= day.hours %> |
<% end %>

---

## Summary

| Description | Amount |
|-------------|--------|
| Total Hours | <%= @total_hours %> |
| Hourly Rate | <%= @currency %><%= @hourly_rate %> |
| **Total Due** | **<%= @currency %><%= @total_amount %>** |

---

Thank you for your business!
```

Save this to `~/.config/time_invoice/templates/custom.md.eex` and reference it in your config:

```elixir
template: "~/.config/time_invoice/templates/custom.md.eex"
```

