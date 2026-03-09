defmodule TimeInvoice.Renderer do
  @moduledoc """
  Renders EEx templates with invoice data.

  Merges variables from project data, configuration, and computed values
  to produce the final invoice output. Dates are formatted according to
  the `date_format` config option (`:eu` or `:us`).
  """

  alias TimeInvoice.DateFormat
  alias TimeInvoice.Invoice

  @typedoc "Project data extracted from JSON input"
  @type project_data :: %{
          project: String.t(),
          start_date: Date.t(),
          end_date: Date.t(),
          days: [%{date: Date.t(), hours: number()}],
          total_hours: number()
        }

  @typedoc "Project configuration from config file"
  @type project_config :: keyword()

  @doc """
  Renders a template file with invoice data.

  Loads a template from the given path (supports `~` expansion),
  then renders it with merged variables from project data and config.

  Returns `{:ok, rendered_string}` on success, or
  `{:error, {:template_not_found, path}}` if the file doesn't exist,
  `{:error, {:template_error, message}}` on EEx syntax errors, or
  `{:error, {:file_error, reason}}` for other file read errors.
  """
  @spec render_file(String.t(), project_data(), project_config(), Date.t()) ::
          {:ok, String.t()}
          | {:error, {:template_not_found, String.t()}}
          | {:error, {:template_error, String.t()}}
          | {:error, {:file_error, atom()}}
  def render_file(path, project_data, config, invoice_date) do
    expanded_path = Path.expand(path)

    case File.read(expanded_path) do
      {:ok, template} ->
        render(template, project_data, config, invoice_date)

      {:error, :enoent} ->
        {:error, {:template_not_found, expanded_path}}

      {:error, reason} ->
        {:error, {:file_error, reason}}
    end
  end

  @doc """
  Renders a template string with invoice data.

  Takes a template string, project data from JSON, and project config.
  The `invoice_date` parameter sets the date used for invoice number generation.

  Returns `{:ok, rendered_string}` on success, or
  `{:error, {:template_error, message}}` on EEx syntax errors.
  """
  @spec render(String.t(), project_data(), project_config(), Date.t()) ::
          {:ok, String.t()} | {:error, {:template_error, String.t()}}
  def render(template, project_data, config, invoice_date) do
    assigns = build_assigns(project_data, config, invoice_date)
    rendered = EEx.eval_string(template, assigns: assigns)
    {:ok, rendered}
  rescue
    e in EEx.SyntaxError ->
      {:error, {:template_error, Exception.message(e)}}
  end

  @spec build_assigns(project_data(), project_config(), Date.t()) :: keyword()
  defp build_assigns(project_data, config, invoice_date) do
    hourly_rate = Keyword.get(config, :hourly_rate, 0)
    date_format = Keyword.get(config, :date_format)
    total_amount = Invoice.calculate_total(project_data.total_hours, hourly_rate)
    invoice_number = Invoice.generate_number(invoice_date)

    formatted_days =
      Enum.map(project_data.days, fn day ->
        %{date: DateFormat.format(day.date, date_format), hours: day.hours}
      end)

    # Start with config values (all fields available in template)
    config
    # Add project data (with formatted dates)
    |> Keyword.merge(
      project: project_data.project,
      start_date: DateFormat.format(project_data.start_date, date_format),
      end_date: DateFormat.format(project_data.end_date, date_format),
      days: formatted_days,
      total_hours: project_data.total_hours
    )
    # Add computed values
    |> Keyword.merge(
      invoice_number: invoice_number,
      invoice_date: DateFormat.format(invoice_date, date_format),
      total_amount: total_amount
    )
  end
end
