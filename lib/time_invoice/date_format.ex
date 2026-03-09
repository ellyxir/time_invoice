defmodule TimeInvoice.DateFormat do
  @moduledoc """
  Formats dates according to EU or US style preferences.

  - EU style: day-month-year (e.g., "03-01-2026")
  - US style: month-day-year (e.g., "01-03-2026")
  """

  @typedoc "Date format style"
  @type style :: :eu | :us

  @doc """
  Formats a date according to the given style.

  Defaults to EU format if style is `nil`.

  ## Examples

      iex> TimeInvoice.DateFormat.format(~D[2026-01-03], :eu)
      "03-01-2026"

      iex> TimeInvoice.DateFormat.format(~D[2026-01-03], :us)
      "01-03-2026"

  """
  @spec format(Date.t(), style() | nil) :: String.t()
  def format(date, style \\ :eu)

  def format(%Date{year: year, month: month, day: day}, :us) do
    "#{pad(month)}-#{pad(day)}-#{year}"
  end

  def format(%Date{year: year, month: month, day: day}, :eu) do
    "#{pad(day)}-#{pad(month)}-#{year}"
  end

  def format(%Date{year: year, month: month, day: day}, nil) do
    "#{pad(day)}-#{pad(month)}-#{year}"
  end

  @spec pad(integer()) :: String.t()
  defp pad(number) when number < 10, do: "0#{number}"
  defp pad(number), do: "#{number}"
end
