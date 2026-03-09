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

    test "renders days list with iteration and formatted dates" do
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

      config = [date_format: :eu]

      {:ok, result} = Renderer.render(template, project_data, config, ~D[2026-03-09])

      assert result =~ "| 02-01-2026 | 3.5 |"
      assert result =~ "| 03-01-2026 | 6.0 |"
    end

    test "renders custom config fields" do
      template = "PO Number: <%= @po_number %>"
      project_data = build_project_data()
      config = [po_number: "PO-12345"]

      {:ok, result} = Renderer.render(template, project_data, config, ~D[2026-03-09])

      assert result == "PO Number: PO-12345"
    end

    test "renders invoice date with eu format" do
      template = "Date: <%= @invoice_date %>"
      project_data = build_project_data()
      config = [date_format: :eu]

      {:ok, result} = Renderer.render(template, project_data, config, ~D[2026-03-09])

      assert result == "Date: 09-03-2026"
    end

    test "renders invoice date with us format" do
      template = "Date: <%= @invoice_date %>"
      project_data = build_project_data()
      config = [date_format: :us]

      {:ok, result} = Renderer.render(template, project_data, config, ~D[2026-03-09])

      assert result == "Date: 03-09-2026"
    end

    test "formats start_date and end_date" do
      template = "Period: <%= @start_date %> - <%= @end_date %>"
      project_data = build_project_data(start_date: ~D[2026-01-01], end_date: ~D[2026-01-31])
      config = [date_format: :eu]

      {:ok, result} = Renderer.render(template, project_data, config, ~D[2026-03-09])

      assert result == "Period: 01-01-2026 - 31-01-2026"
    end

    test "returns error for invalid eex syntax" do
      template = "Invoice: <%= @invoice_number"
      project_data = build_project_data()
      config = []

      assert {:error, {:template_error, message}} =
               Renderer.render(template, project_data, config, ~D[2026-03-09])

      assert message =~ "expected closing"
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
    test "returns file_error for directory path", %{tmp_dir: tmp_dir} do
      # Try to read a directory as a file
      project_data = build_project_data()
      config = []

      assert {:error, {:file_error, :eisdir}} =
               Renderer.render_file(tmp_dir, project_data, config, ~D[2026-03-09])
    end
  end

  describe "decimal formatting" do
    test "rounds total_hours to 2 decimal places" do
      template = "Hours: <%= @total_hours %>"
      project_data = build_project_data(total_hours: 7.174166666666666)
      config = []

      {:ok, result} = Renderer.render(template, project_data, config, ~D[2026-03-09])

      assert result == "Hours: 7.17"
    end

    test "rounds total_amount to 2 decimal places" do
      template = "Amount: <%= @total_amount %>"
      # 7.174166666666666 * 100 = 717.4166666666666
      project_data = build_project_data(total_hours: 7.174166666666666)
      config = [hourly_rate: 100.0]

      {:ok, result} = Renderer.render(template, project_data, config, ~D[2026-03-09])

      assert result == "Amount: 717.42"
    end

    test "rounds hours in days list to 2 decimal places" do
      template = """
      <%= for day <- @days do %>| <%= day.hours %> |
      <% end %>
      """

      project_data =
        build_project_data(
          days: [
            %{date: ~D[2026-01-02], hours: 3.333333333333333},
            %{date: ~D[2026-01-03], hours: 2.166666666666667}
          ]
        )

      config = []

      {:ok, result} = Renderer.render(template, project_data, config, ~D[2026-03-09])

      assert result =~ "| 3.33 |"
      assert result =~ "| 2.17 |"
    end

    test "rounds up at .005" do
      template = "Hours: <%= @total_hours %>"
      project_data = build_project_data(total_hours: 1.125)
      config = []

      {:ok, result} = Renderer.render(template, project_data, config, ~D[2026-03-09])

      assert result == "Hours: 1.13"
    end

    test "handles values already within 2 decimal places" do
      template = "Hours: <%= @total_hours %>"
      project_data = build_project_data(total_hours: 5.10)
      config = []

      {:ok, result} = Renderer.render(template, project_data, config, ~D[2026-03-09])

      assert result == "Hours: 5.1"
    end

    test "handles integer input" do
      template = "Hours: <%= @total_hours %>"
      project_data = build_project_data(total_hours: 5)
      config = []

      {:ok, result} = Renderer.render(template, project_data, config, ~D[2026-03-09])

      assert result == "Hours: 5.0"
    end

    test "rounds very small decimals" do
      template = "Hours: <%= @total_hours %>"
      project_data = build_project_data(total_hours: 0.001)
      config = []

      {:ok, result} = Renderer.render(template, project_data, config, ~D[2026-03-09])

      assert result == "Hours: 0.0"
    end
  end

  describe "edge cases" do
    test "handles empty days list" do
      template = "Days: <%= length(@days) %>"
      project_data = build_project_data(days: [], total_hours: 0)
      config = []

      {:ok, result} = Renderer.render(template, project_data, config, ~D[2026-03-09])

      assert result == "Days: 0"
    end

    test "handles zero total hours" do
      template = "Total: <%= @currency %><%= @total_amount %>"
      project_data = build_project_data(total_hours: 0)
      config = [hourly_rate: 100.0, currency: "$"]

      {:ok, result} = Renderer.render(template, project_data, config, ~D[2026-03-09])

      assert result == "Total: $0.0"
    end

    test "defaults to eu date format when not specified" do
      template = "Date: <%= @invoice_date %>"
      project_data = build_project_data()
      config = []

      {:ok, result} = Renderer.render(template, project_data, config, ~D[2026-03-09])

      assert result == "Date: 09-03-2026"
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
