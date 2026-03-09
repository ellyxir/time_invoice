defmodule TimeInvoice.CLITest do
  use ExUnit.Case, async: true

  alias TimeInvoice.CLI

  @valid_json """
  {
    "start_date": "2026-01-01",
    "end_date": "2026-01-31",
    "projects": {
      "acme": {
        "days": [
          {"date": "2026-01-02", "hours": 3.5},
          {"date": "2026-01-03", "hours": 6.0}
        ],
        "total_hours": 9.5
      }
    }
  }
  """

  @simple_template """
  # Invoice <%= @invoice_number %>
  Project: <%= @project %>
  Total: <%= @currency %><%= @total_amount %>
  """

  describe "parse_args/1" do
    test "parses --project argument" do
      assert {:ok, "acme"} = CLI.parse_args(["--project", "acme"])
    end

    test "parses -p short form" do
      assert {:ok, "acme"} = CLI.parse_args(["-p", "acme"])
    end

    test "returns error when --project is missing" do
      assert {:error, :missing_project} = CLI.parse_args([])
    end

    test "returns error when --project value is missing" do
      assert {:error, :missing_project} = CLI.parse_args(["--project"])
    end

    test "ignores extra arguments" do
      assert {:ok, "acme"} = CLI.parse_args(["--project", "acme", "--extra", "stuff"])
    end
  end

  describe "run/3" do
    setup do
      template_dir = Path.join(System.tmp_dir!(), "time_invoice_test_#{:rand.uniform(100_000)}")
      File.mkdir_p!(template_dir)
      template_path = Path.join(template_dir, "test.md.eex")
      File.write!(template_path, @simple_template)

      config_dir = Path.join(System.tmp_dir!(), "time_invoice_config_#{:rand.uniform(100_000)}")
      File.mkdir_p!(config_dir)
      config_path = Path.join(config_dir, "config.exs")

      config_content = """
      import Config

      config :time_invoice, :projects,
        acme: [
          template: "#{template_path}",
          hourly_rate: 100.0,
          currency: "$"
        ],
        configured_but_not_in_json: [
          template: "#{template_path}",
          hourly_rate: 50.0,
          currency: "€"
        ]
      """

      File.write!(config_path, config_content)

      on_exit(fn ->
        File.rm_rf!(template_dir)
        File.rm_rf!(config_dir)
      end)

      %{config_path: config_path, template_path: template_path}
    end

    test "renders invoice successfully", %{config_path: config_path} do
      result = CLI.run(["--project", "acme"], @valid_json, config_path)

      assert {:ok, output} = result
      assert output =~ "Project: acme"
      assert output =~ "Total: $950.0"
    end

    test "returns error for invalid json", %{config_path: config_path} do
      result = CLI.run(["--project", "acme"], "not json", config_path)

      assert {:error, {:invalid_json, _message}} = result
    end

    test "returns error when project not in json", %{config_path: config_path} do
      result = CLI.run(["--project", "configured_but_not_in_json"], @valid_json, config_path)

      assert {:error, {:project_not_in_json, "configured_but_not_in_json", ["acme"]}} = result
    end

    test "returns error when project not in config", %{config_path: config_path} do
      json_with_other_project = """
      {
        "start_date": "2026-01-01",
        "end_date": "2026-01-31",
        "projects": {
          "other": {
            "days": [{"date": "2026-01-02", "hours": 1.0}],
            "total_hours": 1.0
          }
        }
      }
      """

      result = CLI.run(["--project", "other"], json_with_other_project, config_path)

      assert {:error, {:project_not_in_config, "other", available}} = result
      assert "acme" in available
      assert "configured_but_not_in_json" in available
    end

    test "returns error when missing --project argument", %{config_path: config_path} do
      result = CLI.run([], @valid_json, config_path)

      assert {:error, :missing_project} = result
    end
  end
end
