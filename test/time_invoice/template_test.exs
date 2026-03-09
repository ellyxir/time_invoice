defmodule TimeInvoice.TemplateTest do
  use ExUnit.Case, async: true

  alias TimeInvoice.Renderer
  alias TimeInvoice.Template

  describe "default_path/0" do
    test "returns path to default template" do
      path = Template.default_path()

      assert String.ends_with?(path, "default.md.eex")
      assert File.exists?(path)
    end
  end

  describe "read_default/0" do
    test "reads the default template content" do
      {:ok, content} = Template.read_default()

      assert content =~ "Invoice"
      assert content =~ "@invoice_number"
      assert content =~ "@business_name"
      assert content =~ "@client_name"
      assert content =~ "@total_hours"
      assert content =~ "@hourly_rate"
      assert content =~ "@total_amount"
    end
  end

  describe "default template rendering" do
    test "renders with all required fields" do
      project_data = %{
        project: "acme",
        start_date: ~D[2026-01-01],
        end_date: ~D[2026-01-31],
        days: [
          %{date: ~D[2026-01-02], hours: 3.5},
          %{date: ~D[2026-01-03], hours: 6.0}
        ],
        total_hours: 9.5
      }

      config = [
        business_name: "My Consulting LLC",
        business_address: "123 Main Street\nSometown, ST 12345",
        business_email: "billing@myconsulting.example",
        client_name: "Acme Corporation",
        client_address: "456 Corporate Blvd\nBigcity, BC 67890",
        hourly_rate: 150.0,
        currency: "$",
        date_format: :eu
      ]

      {:ok, result} =
        Renderer.render_file(Template.default_path(), project_data, config, ~D[2026-03-09])

      # Header
      assert result =~ "# Invoice INV-26-03-09"
      assert result =~ "**Date:** 09-03-2026"

      # Business info
      assert result =~ "My Consulting LLC"
      assert result =~ "123 Main Street"
      assert result =~ "billing@myconsulting.example"

      # Client info
      assert result =~ "Acme Corporation"
      assert result =~ "456 Corporate Blvd"

      # Services table
      assert result =~ "| 02-01-2026 | 3.5 |"
      assert result =~ "| 03-01-2026 | 6.0 |"

      # Summary
      assert result =~ "| Total Hours | 9.5 |"
      assert result =~ "| Hourly Rate | $150.0 |"
      assert result =~ "| **Total Due** | **$1425.0** |"
    end
  end
end
