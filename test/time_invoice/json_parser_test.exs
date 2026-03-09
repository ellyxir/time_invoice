defmodule TimeInvoice.JsonParserTest do
  use ExUnit.Case, async: true

  alias TimeInvoice.JsonParser

  describe "parse/1 with valid JSON" do
    test "parses single project" do
      json = """
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

      assert {:ok, result} = JsonParser.parse(json)
      assert result.start_date == ~D[2026-01-01]
      assert result.end_date == ~D[2026-01-31]
      assert Map.has_key?(result.projects, "acme")

      acme = result.projects["acme"]
      assert acme.total_hours == 9.5
      assert length(acme.days) == 2

      [day1, day2] = acme.days
      assert day1.date == ~D[2026-01-02]
      assert day1.hours == 3.5
      assert day2.date == ~D[2026-01-03]
      assert day2.hours == 6.0
    end

    test "parses multiple projects" do
      json = """
      {
        "start_date": "2026-01-01",
        "end_date": "2026-01-31",
        "projects": {
          "acme": {
            "days": [{"date": "2026-01-02", "hours": 3.5}],
            "total_hours": 3.5
          },
          "widgets": {
            "days": [{"date": "2026-01-05", "hours": 8.0}],
            "total_hours": 8.0
          }
        }
      }
      """

      assert {:ok, result} = JsonParser.parse(json)
      assert Map.has_key?(result.projects, "acme")
      assert Map.has_key?(result.projects, "widgets")
      assert result.projects["acme"].total_hours == 3.5
      assert result.projects["widgets"].total_hours == 8.0
    end
  end

  describe "parse/1 with invalid JSON" do
    test "returns error for malformed JSON" do
      json = "{ invalid json }"

      assert {:error, reason} = JsonParser.parse(json)
      assert reason =~ "invalid" or reason =~ "JSON"
    end

    test "returns error for missing start_date" do
      json = """
      {
        "end_date": "2026-01-31",
        "projects": {}
      }
      """

      assert {:error, reason} = JsonParser.parse(json)
      assert reason =~ "start_date"
    end

    test "returns error for missing end_date" do
      json = """
      {
        "start_date": "2026-01-01",
        "projects": {}
      }
      """

      assert {:error, reason} = JsonParser.parse(json)
      assert reason =~ "end_date"
    end

    test "returns error for missing projects" do
      json = """
      {
        "start_date": "2026-01-01",
        "end_date": "2026-01-31"
      }
      """

      assert {:error, reason} = JsonParser.parse(json)
      assert reason =~ "projects"
    end

    test "returns error for invalid date format" do
      json = """
      {
        "start_date": "01-01-2026",
        "end_date": "2026-01-31",
        "projects": {}
      }
      """

      assert {:error, reason} = JsonParser.parse(json)
      assert reason =~ "date" or reason =~ "invalid"
    end

    test "returns error for project missing days" do
      json = """
      {
        "start_date": "2026-01-01",
        "end_date": "2026-01-31",
        "projects": {
          "acme": {
            "total_hours": 5.0
          }
        }
      }
      """

      assert {:error, reason} = JsonParser.parse(json)
      assert reason =~ "days"
    end

    test "returns error for project missing total_hours" do
      json = """
      {
        "start_date": "2026-01-01",
        "end_date": "2026-01-31",
        "projects": {
          "acme": {
            "days": []
          }
        }
      }
      """

      assert {:error, reason} = JsonParser.parse(json)
      assert reason =~ "total_hours"
    end
  end
end
