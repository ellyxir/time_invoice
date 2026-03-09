defmodule TimeInvoice.CLI do
  @moduledoc """
  CLI entry point for time_invoice.

  Parses command-line arguments and orchestrates the invoice generation
  pipeline: read stdin -> parse JSON -> load config -> extract project ->
  format dates -> render template -> output markdown.

  Configuration is loaded from `~/.config/time_invoice/config.exs` (or
  `$XDG_CONFIG_HOME/time_invoice/config.exs` if set). See `TimeInvoice.Config`
  for the expected format.
  """

  alias TimeInvoice.Config
  alias TimeInvoice.JsonParser
  alias TimeInvoice.Renderer

  @typedoc "Error types returned by run/3"
  @type run_error ::
          :missing_project
          | {:invalid_json, String.t()}
          | {:project_not_in_config, String.t(), [String.t()]}
          | {:project_not_in_json, String.t(), [String.t()]}
          | {:template_not_found, String.t()}
          | {:template_error, String.t()}
          | {:config_not_found, String.t()}
          | {:config_error, String.t()}

  @doc """
  Parses command-line arguments to extract the project name.

  Returns `{:ok, project_name}` when `--project` or `-p` is provided,
  or `{:error, :missing_project}` otherwise.
  """
  @spec parse_args([String.t()]) :: {:ok, String.t()} | {:error, :missing_project}
  def parse_args(args) do
    {opts, _, _} = OptionParser.parse(args, strict: [project: :string], aliases: [p: :project])

    case Keyword.fetch(opts, :project) do
      {:ok, project} -> {:ok, project}
      :error -> {:error, :missing_project}
    end
  end

  @doc """
  Runs the invoice generation pipeline.

  Takes command-line args, JSON input, and config path. Orchestrates parsing,
  config loading, and template rendering. Returns `{:ok, rendered_markdown}`
  on success or `{:error, reason}` on failure.
  """
  @spec run([String.t()], String.t(), String.t()) :: {:ok, String.t()} | {:error, run_error()}
  def run(args, json_input, config_path) do
    with {:ok, project_name} <- parse_args(args),
         {:ok, report} <- parse_json(json_input),
         {:ok, config} <- load_config(config_path),
         {:ok, project_config} <- get_project_config(config, project_name),
         {:ok, project_data} <- extract_project(report, project_name),
         {:ok, template_path} <- get_template_path(project_config) do
      render_template(template_path, project_data, project_config)
    end
  end

  @spec parse_json(String.t()) ::
          {:ok, JsonParser.report()} | {:error, {:invalid_json, String.t()}}
  defp parse_json(json_input) do
    case JsonParser.parse(json_input) do
      {:ok, report} -> {:ok, report}
      {:error, message} -> {:error, {:invalid_json, message}}
    end
  end

  @spec load_config(String.t()) ::
          {:ok, Config.config()}
          | {:error, {:config_not_found, String.t()} | {:config_error, String.t()}}
  defp load_config(config_path) do
    case Config.load(config_path) do
      {:ok, config} -> {:ok, config}
      {:error, :not_found} -> {:error, {:config_not_found, config_path}}
      {:error, {:syntax_error, message}} -> {:error, {:config_error, message}}
    end
  end

  @spec get_project_config(Config.config(), String.t()) ::
          {:ok, Config.project_config()}
          | {:error, {:project_not_in_config, String.t(), [String.t()]}}
  defp get_project_config(config, project_name) do
    case Config.get_project(config, project_name) do
      {:ok, project_config} ->
        {:ok, project_config}

      {:error, {:project_not_found, name, available}} ->
        {:error, {:project_not_in_config, name, available}}
    end
  end

  @spec extract_project(JsonParser.report(), String.t()) ::
          {:ok, JsonParser.extracted_project()}
          | {:error, {:project_not_in_json, String.t(), [String.t()]}}
  defp extract_project(report, project_name) do
    case JsonParser.extract_project(report, project_name) do
      {:ok, project_data} ->
        {:ok, project_data}

      {:error, {:project_not_found, name, available}} ->
        {:error, {:project_not_in_json, name, available}}
    end
  end

  @spec get_template_path(Config.project_config()) ::
          {:ok, String.t()} | {:error, {:template_not_found, String.t()}}
  defp get_template_path(project_config) do
    case Keyword.fetch(project_config, :template) do
      {:ok, path} -> {:ok, path}
      :error -> {:error, {:template_not_found, "no template configured"}}
    end
  end

  @spec render_template(String.t(), JsonParser.extracted_project(), Config.project_config()) ::
          {:ok, String.t()}
          | {:error, {:template_not_found, String.t()}}
          | {:error, {:template_error, String.t()}}
  defp render_template(template_path, project_data, project_config) do
    invoice_date = Date.utc_today()

    case Renderer.render_file(template_path, project_data, project_config, invoice_date) do
      {:ok, rendered} -> {:ok, rendered}
      {:error, {:template_not_found, path}} -> {:error, {:template_not_found, path}}
      {:error, {:template_error, message}} -> {:error, {:template_error, message}}
      {:error, {:file_error, _reason}} -> {:error, {:template_not_found, template_path}}
    end
  end

  @doc """
  Formats an error for display on stderr.
  """
  @spec format_error(run_error()) :: String.t()
  def format_error(:missing_project) do
    "error: missing required argument: --project\nusage: ti --project <name>"
  end

  def format_error({:invalid_json, message}) do
    "error: invalid JSON input: #{message}"
  end

  def format_error({:project_not_in_config, project, available}) do
    "error: project '#{project}' not found in config\navailable projects: #{Enum.join(available, ", ")}"
  end

  def format_error({:project_not_in_json, project, available}) do
    "error: project '#{project}' not found in JSON input\navailable projects: #{Enum.join(available, ", ")}"
  end

  def format_error({:template_not_found, path}) do
    "error: template not found: #{path}"
  end

  def format_error({:config_not_found, path}) do
    "error: config file not found: #{path}"
  end

  def format_error({:config_error, message}) do
    "error: config syntax error: #{message}"
  end

  def format_error({:template_error, message}) do
    "error: template syntax error: #{message}"
  end

  @doc """
  Returns the exit code for a given result.

  Exit codes:
  - 0: Success
  - 1: Project not found in config, config file not found, config syntax error,
       or missing --project argument
  - 2: Project not found in JSON input
  - 3: Template file not found or template syntax error
  - 4: Invalid JSON input
  """
  @spec exit_code(:ok | run_error()) :: non_neg_integer()
  def exit_code(:ok), do: 0
  def exit_code(:missing_project), do: 1
  def exit_code({:project_not_in_config, _, _}), do: 1
  def exit_code({:config_not_found, _}), do: 1
  def exit_code({:config_error, _}), do: 1
  def exit_code({:project_not_in_json, _, _}), do: 2
  def exit_code({:template_not_found, _}), do: 3
  def exit_code({:template_error, _}), do: 3
  def exit_code({:invalid_json, _}), do: 4

  @doc """
  Main entry point for the CLI.

  Reads JSON from stdin, runs the pipeline, outputs to stdout on success
  or stderr on error, and halts with the appropriate exit code.
  """
  @spec main([String.t()]) :: no_return()
  def main(args) do
    json_input = IO.read(:stdio, :eof)
    config_path = Config.config_path()

    case run(args, json_input, config_path) do
      {:ok, output} ->
        IO.write(output)
        System.halt(0)

      {:error, error} ->
        IO.puts(:stderr, format_error(error))
        System.halt(exit_code(error))
    end
  end
end
