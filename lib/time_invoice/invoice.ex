defmodule TimeInvoice.Invoice do
  @moduledoc """
  Invoice number generation and amount calculation.
  """

  @doc """
  Generates an invoice number based on the given date.

  Format: `INV-YY-MM-DD` where YY is two-digit year.

  ## Examples

      iex> TimeInvoice.Invoice.generate_number(~D[2026-03-09])
      "INV-26-03-09"

  """
  @spec generate_number(Date.t()) :: String.t()
  def generate_number(%Date{year: year, month: month, day: day}) do
    yy = rem(year, 100)
    "INV-#{pad(yy)}-#{pad(month)}-#{pad(day)}"
  end

  @doc """
  Calculates total amount from hours worked and hourly rate.

  ## Examples

      iex> TimeInvoice.Invoice.calculate_total(10.0, 100.0)
      1000.0

      iex> TimeInvoice.Invoice.calculate_total(10, 100)
      1000

  """
  @spec calculate_total(number(), number()) :: number()
  def calculate_total(hours, hourly_rate) do
    hours * hourly_rate
  end

  @spec pad(integer()) :: String.t()
  defp pad(number) when number < 10, do: "0#{number}"
  defp pad(number), do: "#{number}"
end
