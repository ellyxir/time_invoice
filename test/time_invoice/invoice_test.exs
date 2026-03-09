defmodule TimeInvoice.InvoiceTest do
  use ExUnit.Case, async: true

  alias TimeInvoice.Invoice

  doctest TimeInvoice.Invoice

  describe "generate_number/1" do
    test "formats invoice number as INV-YY-MM-DD" do
      date = ~D[2026-03-09]
      assert Invoice.generate_number(date) == "INV-26-03-09"
    end

    test "pads single digit month with leading zero" do
      date = ~D[2026-01-15]
      assert Invoice.generate_number(date) == "INV-26-01-15"
    end

    test "pads single digit day with leading zero" do
      date = ~D[2026-12-05]
      assert Invoice.generate_number(date) == "INV-26-12-05"
    end

    test "handles end of year date" do
      date = ~D[2026-12-31]
      assert Invoice.generate_number(date) == "INV-26-12-31"
    end

    test "handles beginning of year date" do
      date = ~D[2026-01-01]
      assert Invoice.generate_number(date) == "INV-26-01-01"
    end

    test "uses two digit year format" do
      date = ~D[2030-06-15]
      assert Invoice.generate_number(date) == "INV-30-06-15"
    end
  end

  describe "calculate_total/2" do
    test "multiplies hours by hourly rate" do
      assert Invoice.calculate_total(10.0, 100.0) == 1000.0
    end

    test "handles decimal hours" do
      assert Invoice.calculate_total(9.5, 100.0) == 950.0
    end

    test "handles decimal rates" do
      assert Invoice.calculate_total(8.0, 125.50) == 1004.0
    end

    test "handles small amounts" do
      assert Invoice.calculate_total(0.25, 100.0) == 25.0
    end

    test "handles large amounts" do
      assert Invoice.calculate_total(160.0, 250.0) == 40_000.0
    end

    test "handles zero hours" do
      assert Invoice.calculate_total(0, 100.0) == 0.0
    end

    test "handles integer arguments" do
      assert Invoice.calculate_total(10, 100) == 1000
    end
  end
end
