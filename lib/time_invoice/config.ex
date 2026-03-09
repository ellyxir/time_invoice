defmodule TimeInvoice.Config do
  @moduledoc """
  Loads project configuration from XDG config path.

  Configuration is stored in `~/.config/time_invoice/config.exs` (or
  `$XDG_CONFIG_HOME/time_invoice/config.exs` if set).
  """

  @typedoc "Project configuration keyword list"
  @type project_config :: keyword()

  @typedoc "Full configuration keyword list"
  @type config :: keyword()

  @doc """
  Returns the path to the config file.

  Uses `$XDG_CONFIG_HOME/time_invoice/config.exs` if `XDG_CONFIG_HOME` is set,
  otherwise falls back to `~/.config/time_invoice/config.exs`.
  """
  @spec config_path() :: String.t()
  def config_path do
    config_home =
      case System.get_env("XDG_CONFIG_HOME") do
        nil -> Path.join(System.user_home!(), ".config")
        "" -> Path.join(System.user_home!(), ".config")
        path -> path
      end

    Path.join([config_home, "time_invoice", "config.exs"])
  end

  @doc """
  Loads configuration from the given path.

  Returns `{:ok, config}` on success, or `{:error, reason}` on failure.
  """
  @spec load(String.t()) :: {:ok, config()} | {:error, :not_found | {:syntax_error, String.t()}}
  def load(path) do
    if File.exists?(path) do
      try do
        config = Config.Reader.read!(path)
        {:ok, Keyword.get(config, :time_invoice, [])}
      rescue
        e in [SyntaxError, TokenMissingError] ->
          {:error, {:syntax_error, Exception.message(e)}}
      end
    else
      {:error, :not_found}
    end
  end

  @doc """
  Retrieves configuration for a specific project.

  Accepts project name as string or atom. Returns `{:ok, project_config}` if found,
  or `{:error, {:project_not_found, project_name, available_projects}}` if not.
  """
  @spec get_project(config(), String.t() | atom()) ::
          {:ok, project_config()} | {:error, {:project_not_found, String.t(), [String.t()]}}
  def get_project(config, project_name) do
    project_string = to_string(project_name)
    projects = Keyword.get(config, :projects, [])

    case to_atom(project_name) do
      nil ->
        available = projects |> Keyword.keys() |> Enum.map(&to_string/1)
        {:error, {:project_not_found, project_string, available}}

      project_atom ->
        case Keyword.fetch(projects, project_atom) do
          {:ok, project_config} ->
            {:ok, project_config}

          :error ->
            available = projects |> Keyword.keys() |> Enum.map(&to_string/1)
            {:error, {:project_not_found, project_string, available}}
        end
    end
  end

  @doc """
  Expands the given path to an absolute path.

  Resolves `~` to the user's home directory and converts relative paths
  to absolute paths based on the current working directory.
  """
  @spec expand_path(String.t()) :: String.t()
  def expand_path(path), do: Path.expand(path)

  @spec to_atom(String.t() | atom()) :: atom() | nil
  defp to_atom(name) when is_atom(name), do: name

  defp to_atom(name) when is_binary(name) do
    String.to_existing_atom(name)
  rescue
    ArgumentError -> nil
  end
end
