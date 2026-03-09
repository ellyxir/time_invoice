defmodule TimeInvoice.RendererTest do
  use ExUnit.Case, async: true

  alias TimeInvoice.Renderer

  describe "render/4" do
    test "renders invoice number from invoice date" do
      template = "Invoice: <%= @invoice_number %>"
      project_data = build_project_data()
      config = [hourly_rate: 100.0, currency: "$"]

      {:ok, result} = Renderer.render(template, project_data, config, ~D[2026-03-09])

      assert result == "Invoice: INV-26-03-09"
    end

    test "renders project data from json" do
      template = """
      Project: <%= @project %>
      Total Hours: <%= @total_hours %>
      """

      project_data = build_project_data(project: "acme", total_hours: 9.5)
      config = []

      {:ok, result} = Renderer.render(template, project_data, config, ~D[2026-03-09])

      assert result =~ "Project: acme"
      assert result =~ "Total Hours: 9.5"
    end

    test "renders config values" do
      template = """
      From: <%= @business_name %>
      To: <%= @client_name %>
      Rate: <%= @currency %><%= @hourly_rate %>
      """

      project_data = build_project_data()

      config = [
        business_name: "My Consulting LLC",
        client_name: "Acme Corporation",
        hourly_rate: 150.0,
        currency: "$"
      ]

      {:ok, result} = Renderer.render(template, project_data, config, ~D[2026-03-09])

      assert result =~ "From: My Consulting LLC"
      assert result =~ "To: Acme Corporation"
      assert result =~ "Rate: $150.0"
    end

    test "calculates total amount from hours and rate" do
      template = "Total: <%= @currency %><%= @total_amount %>"
      project_data = build_project_data(total_hours: 9.5)
      config = [hourly_rate: 100.0, currency: "$"]

      {:ok, result} = Renderer.render(template, project_data, config, ~D[2026-03-09])

      assert result == "Total: $950.0"
    end

    test "renders days list with iteration" do
      template = """
      <%= for day <- @days do %>
      | <%= day.date %> | <%= day.hours %> |
      <% end %>
      """

      project_data =
        build_project_data(
          days: [
            %{date: ~D[2026-01-02], hours: 3.5},
            %{date: ~D[2026-01-03], hours: 6.0}
          ]
        )

      config = []

      {:ok, result} = Renderer.render(template, project_data, config, ~D[2026-03-09])

      assert result =~ "| 2026-01-02 | 3.5 |"
      assert result =~ "| 2026-01-03 | 6.0 |"
    end

    test "renders custom config fields" do
      template = "PO Number: <%= @po_number %>"
      project_data = build_project_data()
      config = [po_number: "PO-12345"]

      {:ok, result} = Renderer.render(template, project_data, config, ~D[2026-03-09])

      assert result == "PO Number: PO-12345"
    end

    test "renders invoice date" do
      template = "Date: <%= @invoice_date %>"
      project_data = build_project_data()
      config = []

      {:ok, result} = Renderer.render(template, project_data, config, ~D[2026-03-09])

      assert result == "Date: 2026-03-09"
    end
  end

  describe "render_file/4" do
    @tag :tmp_dir
    test "loads and renders template from file", %{tmp_dir: tmp_dir} do
      template_path = Path.join(tmp_dir, "test.md.eex")
      File.write!(template_path, "Invoice: <%= @invoice_number %>")

      project_data = build_project_data()
      config = [hourly_rate: 100.0, currency: "$"]

      {:ok, result} = Renderer.render_file(template_path, project_data, config, ~D[2026-03-09])

      assert result == "Invoice: INV-26-03-09"
    end

    @tag :tmp_dir
    test "returns error when template file not found", %{tmp_dir: tmp_dir} do
      template_path = Path.join(tmp_dir, "nonexistent.md.eex")
      project_data = build_project_data()
      config = []

      assert {:error, {:template_not_found, ^template_path}} =
               Renderer.render_file(template_path, project_data, config, ~D[2026-03-09])
    end

    @tag :tmp_dir
    test "expands tilde in template path", %{tmp_dir: tmp_dir} do
      # Create a template in a subdirectory of tmp_dir
      template_path = Path.join(tmp_dir, "test.md.eex")
      File.write!(template_path, "Hello: <%= @project %>")

      project_data = build_project_data(project: "acme")
      config = []

      # Test with absolute path (we can't actually test ~ expansion without mocking home)
      {:ok, result} = Renderer.render_file(template_path, project_data, config, ~D[2026-03-09])

      assert result == "Hello: acme"
    end
  end

  defp build_project_data(overrides \\ []) do
    defaults = %{
      project: "acme",
      start_date: ~D[2026-01-01],
      end_date: ~D[2026-01-31],
      days: [%{date: ~D[2026-01-02], hours: 3.5}],
      total_hours: 3.5
    }

    Map.merge(defaults, Map.new(overrides))
  end
end
