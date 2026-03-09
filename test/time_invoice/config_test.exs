defmodule TimeInvoice.ConfigTest do
  use ExUnit.Case, async: false

  alias TimeInvoice.Config

  describe "config_path/0" do
    test "returns XDG_CONFIG_HOME path when set" do
      System.put_env("XDG_CONFIG_HOME", "/custom/config")

      try do
        assert Config.config_path() == "/custom/config/time_invoice/config.exs"
      after
        System.delete_env("XDG_CONFIG_HOME")
      end
    end

    test "falls back to ~/.config when XDG_CONFIG_HOME not set" do
      System.delete_env("XDG_CONFIG_HOME")

      path = Config.config_path()
      home = System.user_home!()

      assert path == "#{home}/.config/time_invoice/config.exs"
    end

    test "falls back to ~/.config when XDG_CONFIG_HOME is empty string" do
      System.put_env("XDG_CONFIG_HOME", "")

      try do
        path = Config.config_path()
        home = System.user_home!()
        assert path == "#{home}/.config/time_invoice/config.exs"
      after
        System.delete_env("XDG_CONFIG_HOME")
      end
    end
  end

  describe "load/1" do
    setup do
      tmp_dir = System.tmp_dir!()
      config_dir = Path.join(tmp_dir, "time_invoice_test_#{:rand.uniform(100_000)}")
      File.mkdir_p!(config_dir)

      on_exit(fn -> File.rm_rf!(config_dir) end)

      {:ok, config_dir: config_dir}
    end

    test "loads valid config file", %{config_dir: config_dir} do
      config_path = Path.join(config_dir, "config.exs")

      File.write!(config_path, """
      import Config

      config :time_invoice,
        date_format: :eu

      config :time_invoice, :projects,
        acme: [
          template: "~/.config/time_invoice/templates/default.md.eex",
          business_name: "Test Business",
          client_name: "Acme Corp",
          hourly_rate: 150.0,
          currency: "$"
        ]
      """)

      assert {:ok, config} = Config.load(config_path)
      assert config[:date_format] == :eu
      assert config[:projects][:acme][:business_name] == "Test Business"
    end

    test "returns error for non-existent file" do
      assert {:error, :not_found} = Config.load("/nonexistent/path/config.exs")
    end

    test "returns error for invalid elixir syntax", %{config_dir: config_dir} do
      config_path = Path.join(config_dir, "config.exs")
      File.write!(config_path, "this is not valid { elixir")

      assert {:error, {:syntax_error, _}} = Config.load(config_path)
    end
  end

  describe "get_project/2" do
    test "returns project config when project exists" do
      config = [
        projects: [
          acme: [
            template: "template.md.eex",
            business_name: "My Business",
            client_name: "Acme Corp",
            hourly_rate: 100.0,
            currency: "$"
          ]
        ]
      ]

      assert {:ok, project} = Config.get_project(config, "acme")
      assert project[:business_name] == "My Business"
      assert project[:hourly_rate] == 100.0
    end

    test "returns error when project not found" do
      config = [
        projects: [
          acme: [business_name: "Acme"]
        ]
      ]

      assert {:error, {:project_not_found, "unknown", ["acme"]}} =
               Config.get_project(config, "unknown")
    end

    test "returns error when project name is not an existing atom" do
      config = [projects: [acme: [business_name: "Acme"]]]

      # Use a string that cannot be an existing atom
      random_name = "nonexistent_project_#{:rand.uniform(1_000_000)}"

      assert {:error, {:project_not_found, ^random_name, ["acme"]}} =
               Config.get_project(config, random_name)
    end

    test "returns error when no projects configured" do
      config = []

      assert {:error, {:project_not_found, "acme", []}} = Config.get_project(config, "acme")
    end

    test "accepts atom project name" do
      config = [
        projects: [
          acme: [business_name: "Acme"]
        ]
      ]

      assert {:ok, project} = Config.get_project(config, :acme)
      assert project[:business_name] == "Acme"
    end
  end

  describe "expand_path/1" do
    test "expands tilde to home directory" do
      home = System.user_home!()
      assert Config.expand_path("~/foo/bar") == "#{home}/foo/bar"
    end

    test "leaves absolute paths unchanged" do
      assert Config.expand_path("/absolute/path") == "/absolute/path"
    end

    test "expands relative paths to absolute" do
      result = Config.expand_path("relative/path")
      assert String.starts_with?(result, "/")
      assert String.ends_with?(result, "relative/path")
    end
  end
end
