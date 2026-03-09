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

    test "returns error when JSON root is an array" do
      json = ~s([1, 2, 3])

      assert {:error, reason} = JsonParser.parse(json)
      assert reason =~ "expected object"
    end

    test "returns error when projects is not an object" do
      json = ~s({"start_date": "2026-01-01", "end_date": "2026-01-31", "projects": []})

      assert {:error, reason} = JsonParser.parse(json)
      assert reason =~ "projects must be an object"
    end

    test "returns error when project value is not an object" do
      json =
        ~s({"start_date": "2026-01-01", "end_date": "2026-01-31", "projects": {"acme": "invalid"}})

      assert {:error, reason} = JsonParser.parse(json)
      assert reason =~ "project acme must be an object"
    end

    test "returns error when days is not an array" do
      json =
        ~s({"start_date": "2026-01-01", "end_date": "2026-01-31", "projects": {"acme": {"days": "invalid", "total_hours": 5.0}}})

      assert {:error, reason} = JsonParser.parse(json)
      assert reason =~ "days must be an array"
    end

    test "returns error when day is not an object" do
      json =
        ~s({"start_date": "2026-01-01", "end_date": "2026-01-31", "projects": {"acme": {"days": ["not an object"], "total_hours": 5.0}}})

      assert {:error, reason} = JsonParser.parse(json)
      assert reason =~ "day 0 must be an object"
    end

    test "returns error when day is missing date" do
      json =
        ~s({"start_date": "2026-01-01", "end_date": "2026-01-31", "projects": {"acme": {"days": [{"hours": 5.0}], "total_hours": 5.0}}})

      assert {:error, reason} = JsonParser.parse(json)
      assert reason =~ "day 0 missing date"
    end

    test "returns error when day is missing hours" do
      json =
        ~s({"start_date": "2026-01-01", "end_date": "2026-01-31", "projects": {"acme": {"days": [{"date": "2026-01-02"}], "total_hours": 5.0}}})

      assert {:error, reason} = JsonParser.parse(json)
      assert reason =~ "day 0 missing hours"
    end

    test "returns error when day has invalid date format" do
      json =
        ~s({"start_date": "2026-01-01", "end_date": "2026-01-31", "projects": {"acme": {"days": [{"date": "bad-date", "hours": 5.0}], "total_hours": 5.0}}})

      assert {:error, reason} = JsonParser.parse(json)
      assert reason =~ "invalid date"
    end

    test "returns error when hours is not a number" do
      json =
        ~s({"start_date": "2026-01-01", "end_date": "2026-01-31", "projects": {"acme": {"days": [{"date": "2026-01-02", "hours": "five"}], "total_hours": 5.0}}})

      assert {:error, reason} = JsonParser.parse(json)
      assert reason =~ "hours must be a number"
    end

    test "returns error when total_hours is not a number" do
      json =
        ~s({"start_date": "2026-01-01", "end_date": "2026-01-31", "projects": {"acme": {"days": [], "total_hours": "invalid"}}})

      assert {:error, reason} = JsonParser.parse(json)
      assert reason =~ "total_hours must be a number"
    end

    test "returns error when date is not a string" do
      json = ~s({"start_date": 20260101, "end_date": "2026-01-31", "projects": {}})

      assert {:error, reason} = JsonParser.parse(json)
      assert reason =~ "invalid date"
    end
  end

  describe "extract_project/2" do
    test "extracts project data with date range" do
      report = %{
        start_date: ~D[2026-01-01],
        end_date: ~D[2026-01-31],
        projects: %{
          "acme" => %{
            days: [%{date: ~D[2026-01-02], hours: 3.5}],
            total_hours: 3.5
          }
        }
      }

      assert {:ok, extracted} = JsonParser.extract_project(report, "acme")
      assert extracted.project == "acme"
      assert extracted.start_date == ~D[2026-01-01]
      assert extracted.end_date == ~D[2026-01-31]
      assert extracted.days == [%{date: ~D[2026-01-02], hours: 3.5}]
      assert extracted.total_hours == 3.5
    end

    test "extracts only the requested project from multiple" do
      report = %{
        start_date: ~D[2026-01-01],
        end_date: ~D[2026-01-31],
        projects: %{
          "acme" => %{
            days: [%{date: ~D[2026-01-02], hours: 3.5}],
            total_hours: 3.5
          },
          "widgets" => %{
            days: [%{date: ~D[2026-01-05], hours: 8.0}],
            total_hours: 8.0
          }
        }
      }

      assert {:ok, extracted} = JsonParser.extract_project(report, "acme")
      assert extracted.project == "acme"
      assert extracted.days == [%{date: ~D[2026-01-02], hours: 3.5}]
      assert extracted.total_hours == 3.5
      refute Map.has_key?(extracted, "widgets")
    end

    test "returns error when project not found" do
      report = %{
        start_date: ~D[2026-01-01],
        end_date: ~D[2026-01-31],
        projects: %{
          "acme" => %{days: [], total_hours: 0},
          "widgets" => %{days: [], total_hours: 0}
        }
      }

      assert {:error, {:project_not_found, "unknown", available}} =
               JsonParser.extract_project(report, "unknown")

      assert "acme" in available
      assert "widgets" in available
    end

    test "returns error with empty list when no projects exist" do
      report = %{
        start_date: ~D[2026-01-01],
        end_date: ~D[2026-01-31],
        projects: %{}
      }

      assert {:error, {:project_not_found, "acme", []}} =
               JsonParser.extract_project(report, "acme")
    end
  end

  describe "parse/1 edge cases" do
    test "parses empty projects map" do
      json = ~s({"start_date": "2026-01-01", "end_date": "2026-01-31", "projects": {}})

      assert {:ok, result} = JsonParser.parse(json)
      assert result.projects == %{}
    end

    test "parses project with empty days array" do
      json =
        ~s({"start_date": "2026-01-01", "end_date": "2026-01-31", "projects": {"acme": {"days": [], "total_hours": 0}}})

      assert {:ok, result} = JsonParser.parse(json)
      assert result.projects["acme"].days == []
      assert result.projects["acme"].total_hours == 0
    end

    test "accepts integer hours" do
      json =
        ~s({"start_date": "2026-01-01", "end_date": "2026-01-31", "projects": {"acme": {"days": [{"date": "2026-01-02", "hours": 8}], "total_hours": 8}}})

      assert {:ok, result} = JsonParser.parse(json)
      assert result.projects["acme"].days |> hd() |> Map.get(:hours) == 8
    end
  end
end
