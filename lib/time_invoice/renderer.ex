defmodule TimeInvoice.Renderer do
  @moduledoc """
  Renders EEx templates with invoice data.

  Merges variables from project data, configuration, and computed values
  to produce the final invoice output.
  """

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
  Renders a template string with invoice data.

  Takes a template string, project data from JSON, and project config.
  The `invoice_date` parameter sets the date used for invoice number generation.

  Returns `{:ok, rendered_string}` on success.
  """
  @spec render(String.t(), project_data(), project_config(), Date.t()) ::
          {:ok, String.t()} | {:error, term()}
  def render(template, project_data, config, invoice_date) do
    assigns = build_assigns(project_data, config, invoice_date)
    rendered = EEx.eval_string(template, assigns: assigns)
    {:ok, rendered}
  end

  @spec build_assigns(project_data(), project_config(), Date.t()) :: keyword()
  defp build_assigns(project_data, config, invoice_date) do
    hourly_rate = Keyword.get(config, :hourly_rate, 0)
    total_amount = Invoice.calculate_total(project_data.total_hours, hourly_rate)
    invoice_number = Invoice.generate_number(invoice_date)

    # Start with config values (all fields available in template)
    config
    # Add project data
    |> Keyword.merge(
      project: project_data.project,
      start_date: project_data.start_date,
      end_date: project_data.end_date,
      days: project_data.days,
      total_hours: project_data.total_hours
    )
    # Add computed values
    |> Keyword.merge(
      invoice_number: invoice_number,
      invoice_date: invoice_date,
      total_amount: total_amount
    )
  end
end
