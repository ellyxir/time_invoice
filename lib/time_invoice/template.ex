defmodule TimeInvoice.Template do
  @moduledoc """
  Provides access to bundled invoice templates.

  time_invoice ships with a default template at `priv/templates/default.md.eex`.
  Use `:default` as the template path in project configuration to use it.
  """

  @doc """
  Returns the path to the default template file.

  The default template is bundled with the application in the priv directory.
  """
  @spec default_path() :: String.t()
  def default_path do
    :code.priv_dir(:time_invoice)
    |> Path.join("templates/default.md.eex")
  end

  @doc """
  Reads the content of the default template.

  Returns `{:ok, content}` on success, or `{:error, reason}` on failure.
  """
  @spec read_default() :: {:ok, String.t()} | {:error, File.posix()}
  def read_default do
    File.read(default_path())
  end
end
