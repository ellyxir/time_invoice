defmodule TimeInvoice.CLI do
  @moduledoc """
  CLI entry point for time_invoice.

  Parses command-line arguments and orchestrates the invoice generation
  pipeline: read stdin -> parse JSON -> load config -> extract project ->
  format dates -> render template -> output markdown.
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
          | {:config_not_found, String.t()}
          | {:config_error, String.t()}

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
          {:ok, String.t()} | {:error, {:template_not_found, String.t()}}
  defp render_template(template_path, project_data, project_config) do
    invoice_date = Date.utc_today()

    case Renderer.render_file(template_path, project_data, project_config, invoice_date) do
      {:ok, rendered} -> {:ok, rendered}
      {:error, {:template_not_found, path}} -> {:error, {:template_not_found, path}}
      {:error, {:file_error, _reason}} -> {:error, {:template_not_found, template_path}}
    end
  end
end
