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

    test "returns error when config file not found" do
      result = CLI.run(["--project", "acme"], @valid_json, "/nonexistent/config.exs")

      assert {:error, {:config_not_found, "/nonexistent/config.exs"}} = result
    end

    test "returns error when template file not found", %{
      config_path: config_path,
      template_path: template_path
    } do
      File.rm!(template_path)

      result = CLI.run(["--project", "acme"], @valid_json, config_path)

      assert {:error, {:template_not_found, ^template_path}} = result
    end

    test "returns error for template syntax error", %{
      config_path: config_path,
      template_path: template_path
    } do
      File.write!(template_path, "<%= @unclosed")

      result = CLI.run(["--project", "acme"], @valid_json, config_path)

      assert {:error, {:template_error, _message}} = result
    end

    test "uses bundled default template when template is :default" do
      config_dir = Path.join(System.tmp_dir!(), "default_tpl_#{:rand.uniform(100_000)}")
      File.mkdir_p!(config_dir)
      config_path = Path.join(config_dir, "config.exs")

      config_content = """
      import Config

      config :time_invoice, :projects,
        acme: [
          template: :default,
          business_name: "Test LLC",
          business_address: "123 Test St",
          business_email: "test@example.com",
          client_name: "Acme Corp",
          client_address: "456 Acme Way",
          hourly_rate: 100.0,
          currency: "$"
        ]
      """

      File.write!(config_path, config_content)

      on_exit(fn -> File.rm_rf!(config_dir) end)

      result = CLI.run(["--project", "acme"], @valid_json, config_path)

      assert {:ok, output} = result
      assert output =~ "Invoice INV-"
      assert output =~ "Test LLC"
      assert output =~ "Acme Corp"
      assert output =~ "Total Hours | 9.5"
      assert output =~ "Hourly Rate | $100.0"
    end
  end

  describe "format_error/1" do
    test "formats missing project error" do
      message = CLI.format_error(:missing_project)

      assert message =~ "missing required argument: --project"
      assert message =~ "ti --project <name>"
    end

    test "formats invalid json error" do
      message = CLI.format_error({:invalid_json, "unexpected token"})

      assert message =~ "invalid JSON input"
      assert message =~ "unexpected token"
    end

    test "formats project not in config error" do
      message = CLI.format_error({:project_not_in_config, "acme", ["foo", "bar"]})

      assert message =~ "project 'acme' not found in config"
      assert message =~ "foo"
      assert message =~ "bar"
    end

    test "formats project not in json error" do
      message = CLI.format_error({:project_not_in_json, "acme", ["other"]})

      assert message =~ "project 'acme' not found in JSON input"
      assert message =~ "other"
    end

    test "formats template not found error" do
      message = CLI.format_error({:template_not_found, "/path/to/template.eex"})

      assert message =~ "template not found"
      assert message =~ "/path/to/template.eex"
    end

    test "formats config not found error" do
      message = CLI.format_error({:config_not_found, "/path/to/config.exs"})

      assert message =~ "config file not found"
      assert message =~ "/path/to/config.exs"
    end

    test "formats config syntax error" do
      message = CLI.format_error({:config_error, "unexpected token"})

      assert message =~ "config syntax error"
      assert message =~ "unexpected token"
    end

    test "formats template syntax error" do
      message = CLI.format_error({:template_error, "missing closing tag"})

      assert message =~ "template syntax error"
      assert message =~ "missing closing tag"
    end
  end

  describe "exit_code/1" do
    test "returns 0 for success" do
      assert CLI.exit_code(:ok) == 0
    end

    test "returns 1 for project not in config" do
      assert CLI.exit_code({:project_not_in_config, "acme", []}) == 1
    end

    test "returns 2 for project not in json" do
      assert CLI.exit_code({:project_not_in_json, "acme", []}) == 2
    end

    test "returns 3 for template not found" do
      assert CLI.exit_code({:template_not_found, "/path"}) == 3
    end

    test "returns 4 for invalid json" do
      assert CLI.exit_code({:invalid_json, "error"}) == 4
    end

    test "returns 1 for missing project argument" do
      assert CLI.exit_code(:missing_project) == 1
    end

    test "returns 1 for config not found" do
      assert CLI.exit_code({:config_not_found, "/path"}) == 1
    end

    test "returns 1 for config syntax error" do
      assert CLI.exit_code({:config_error, "error"}) == 1
    end

    test "returns 3 for template syntax error" do
      assert CLI.exit_code({:template_error, "error"}) == 3
    end
  end
end
