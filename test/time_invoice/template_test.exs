defmodule TimeInvoice.TemplateTest do
  use ExUnit.Case, async: true

  alias TimeInvoice.Template

  describe "default_path/0" do
    test "returns path to default template" do
      path = Template.default_path()

      assert String.ends_with?(path, "default.md.eex")
      assert File.exists?(path)
    end
  end

  describe "read_default/0" do
    test "reads the default template content" do
      {:ok, content} = Template.read_default()

      assert content =~ "Invoice"
      assert content =~ "@invoice_number"
      assert content =~ "@business_name"
      assert content =~ "@client_name"
      assert content =~ "@total_hours"
      assert content =~ "@hourly_rate"
      assert content =~ "@total_amount"
    end
  end
end
