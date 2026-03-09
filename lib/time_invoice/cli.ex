defmodule TimeInvoice.CLI do
  @moduledoc """
  CLI entry point for time_invoice.

  Parses command-line arguments and orchestrates the invoice generation
  pipeline: read stdin -> parse JSON -> load config -> extract project ->
  format dates -> render template -> output markdown.
  """

  @doc """
  Parses command-line arguments to extract the project name.

  Returns `{:ok, project_name}` when `--project` or `-p` is provided,
  or `{:error, :missing_project}` otherwise.
  """
  @spec parse_args([String.t()]) :: {:ok, String.t()} | {:error, :missing_project}
  def parse_args(args) do
    case OptionParser.parse(args, strict: [project: :string], aliases: [p: :project]) do
      {opts, _, _} ->
        case Keyword.fetch(opts, :project) do
          {:ok, project} -> {:ok, project}
          :error -> {:error, :missing_project}
        end
    end
  end
end
