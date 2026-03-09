defmodule TimeInvoice.CLITest do
  use ExUnit.Case, async: true

  alias TimeInvoice.CLI

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
end
