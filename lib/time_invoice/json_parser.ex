defmodule TimeInvoice.JsonParser do
  @moduledoc """
  Parses timewatcher JSON format into structured data.
  """

  @typedoc "A single day of work with date and hours"
  @type day :: %{date: Date.t(), hours: number()}

  @typedoc "Project data containing days worked and total hours"
  @type project :: %{days: [day()], total_hours: number()}

  @typedoc "Parsed report containing date range and projects"
  @type report :: %{
          start_date: Date.t(),
          end_date: Date.t(),
          projects: %{String.t() => project()}
        }

  @typedoc "Extracted project data with date range included"
  @type extracted_project :: %{
          project: String.t(),
          start_date: Date.t(),
          end_date: Date.t(),
          days: [day()],
          total_hours: number()
        }

  @doc """
  Parses JSON string into a structured report.

  Returns `{:ok, report}` on success or `{:error, reason}` on failure.
  """
  @spec parse(String.t()) :: {:ok, report()} | {:error, String.t()}
  def parse(json) do
    with {:ok, decoded} <- decode_json(json),
         {:ok, start_date} <- parse_required_date(decoded, "start_date"),
         {:ok, end_date} <- parse_required_date(decoded, "end_date"),
         {:ok, projects_raw} <- get_required_field(decoded, "projects"),
         {:ok, projects} <- parse_projects(projects_raw) do
      {:ok, %{start_date: start_date, end_date: end_date, projects: projects}}
    end
  end

  @doc """
  Extracts a specific project's data from a parsed report.

  Returns the project data along with the report's date range.
  Returns `{:error, {:project_not_found, project_name, available_projects}}`
  if the project does not exist.
  """
  @spec extract_project(report(), String.t()) ::
          {:ok, extracted_project()} | {:error, {:project_not_found, String.t(), [String.t()]}}
  def extract_project(report, project_name) do
    case Map.fetch(report.projects, project_name) do
      {:ok, project_data} ->
        {:ok,
         %{
           project: project_name,
           start_date: report.start_date,
           end_date: report.end_date,
           days: project_data.days,
           total_hours: project_data.total_hours
         }}

      :error ->
        available = Map.keys(report.projects)
        {:error, {:project_not_found, project_name, available}}
    end
  end

  @spec decode_json(String.t()) :: {:ok, map()} | {:error, String.t()}
  defp decode_json(json) do
    case Jason.decode(json) do
      {:ok, decoded} when is_map(decoded) -> {:ok, decoded}
      {:ok, _} -> {:error, "invalid JSON: expected object"}
      {:error, %Jason.DecodeError{}} -> {:error, "invalid JSON"}
    end
  end

  @spec get_required_field(map(), String.t()) :: {:ok, term()} | {:error, String.t()}
  defp get_required_field(map, field) do
    case Map.fetch(map, field) do
      {:ok, value} -> {:ok, value}
      :error -> {:error, "missing required field: #{field}"}
    end
  end

  @spec parse_required_date(map(), String.t()) :: {:ok, Date.t()} | {:error, String.t()}
  defp parse_required_date(map, field) do
    with {:ok, date_string} <- get_required_field(map, field) do
      parse_date(date_string, field)
    end
  end

  @spec parse_date(term(), String.t()) :: {:ok, Date.t()} | {:error, String.t()}
  defp parse_date(date_string, field) when is_binary(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} -> {:ok, date}
      {:error, _} -> {:error, "invalid date format for #{field}: expected YYYY-MM-DD"}
    end
  end

  defp parse_date(_, field) do
    {:error, "invalid date format for #{field}: expected YYYY-MM-DD"}
  end

  @spec validate_number(term(), String.t()) :: {:ok, number()} | {:error, String.t()}
  defp validate_number(value, _context) when is_number(value), do: {:ok, value}
  defp validate_number(_, context), do: {:error, "#{context} must be a number"}

  @spec parse_projects(map()) :: {:ok, %{String.t() => project()}} | {:error, String.t()}
  defp parse_projects(projects_raw) when is_map(projects_raw) do
    projects_raw
    |> Enum.reduce_while({:ok, %{}}, fn {name, data}, {:ok, acc} ->
      case parse_project(name, data) do
        {:ok, project} -> {:cont, {:ok, Map.put(acc, name, project)}}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp parse_projects(_), do: {:error, "projects must be an object"}

  @spec parse_project(String.t(), map()) :: {:ok, project()} | {:error, String.t()}
  defp parse_project(name, data) when is_map(data) do
    with {:ok, days_raw} <- get_project_field(data, "days", name),
         {:ok, total_hours_raw} <- get_project_field(data, "total_hours", name),
         {:ok, total_hours} <- validate_number(total_hours_raw, "project #{name}: total_hours"),
         {:ok, days} <- parse_days(days_raw, name) do
      {:ok, %{days: days, total_hours: total_hours}}
    end
  end

  defp parse_project(name, _), do: {:error, "project #{name} must be an object"}

  @spec get_project_field(map(), String.t(), String.t()) :: {:ok, term()} | {:error, String.t()}
  defp get_project_field(map, field, project_name) do
    case Map.fetch(map, field) do
      {:ok, value} -> {:ok, value}
      :error -> {:error, "project #{project_name} missing required field: #{field}"}
    end
  end

  @spec parse_days(list(), String.t()) :: {:ok, [day()]} | {:error, String.t()}
  defp parse_days(days_raw, project_name) when is_list(days_raw) do
    days_raw
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {day_raw, index}, {:ok, acc} ->
      case parse_day(day_raw, project_name, index) do
        {:ok, day} -> {:cont, {:ok, [day | acc]}}
        {:error, _} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, days} -> {:ok, Enum.reverse(days)}
      error -> error
    end
  end

  defp parse_days(_, project_name), do: {:error, "project #{project_name}: days must be an array"}

  @spec parse_day(map(), String.t(), non_neg_integer()) :: {:ok, day()} | {:error, String.t()}
  defp parse_day(day_raw, project_name, index) when is_map(day_raw) do
    with {:ok, date_string} <- get_day_field(day_raw, "date", project_name, index),
         {:ok, hours_raw} <- get_day_field(day_raw, "hours", project_name, index),
         {:ok, date} <- parse_date(date_string, "day #{index} date in #{project_name}"),
         {:ok, hours} <- validate_number(hours_raw, "project #{project_name}: day #{index} hours") do
      {:ok, %{date: date, hours: hours}}
    end
  end

  defp parse_day(_, project_name, index) do
    {:error, "project #{project_name}: day #{index} must be an object"}
  end

  @spec get_day_field(map(), String.t(), String.t(), non_neg_integer()) ::
          {:ok, term()} | {:error, String.t()}
  defp get_day_field(map, field, project_name, index) do
    case Map.fetch(map, field) do
      {:ok, value} -> {:ok, value}
      :error -> {:error, "project #{project_name}: day #{index} missing #{field}"}
    end
  end
end
