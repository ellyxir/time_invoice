defmodule TimeInvoice.DateFormatTest do
  use ExUnit.Case, async: true

  alias TimeInvoice.DateFormat

  describe "format/2" do
    test "formats date in EU style (day-month-year)" do
      date = ~D[2026-01-03]
      assert DateFormat.format(date, :eu) == "03-01-2026"
    end

    test "formats date in US style (month-day-year)" do
      date = ~D[2026-01-03]
      assert DateFormat.format(date, :us) == "01-03-2026"
    end

    test "pads single digit day with leading zero" do
      date = ~D[2026-12-05]
      assert DateFormat.format(date, :eu) == "05-12-2026"
      assert DateFormat.format(date, :us) == "12-05-2026"
    end

    test "pads single digit month with leading zero" do
      date = ~D[2026-03-15]
      assert DateFormat.format(date, :eu) == "15-03-2026"
      assert DateFormat.format(date, :us) == "03-15-2026"
    end

    test "handles end of year date" do
      date = ~D[2026-12-31]
      assert DateFormat.format(date, :eu) == "31-12-2026"
      assert DateFormat.format(date, :us) == "12-31-2026"
    end

    test "handles beginning of year date" do
      date = ~D[2026-01-01]
      assert DateFormat.format(date, :eu) == "01-01-2026"
      assert DateFormat.format(date, :us) == "01-01-2026"
    end

    test "defaults to EU format when style is nil" do
      date = ~D[2026-03-09]
      assert DateFormat.format(date, nil) == "09-03-2026"
    end

    test "defaults to EU format when called with single argument" do
      date = ~D[2026-03-09]
      assert DateFormat.format(date) == "09-03-2026"
    end
  end

  doctest TimeInvoice.DateFormat
end
