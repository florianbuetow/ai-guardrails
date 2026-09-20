defmodule TestOtpApp do
  @moduledoc """
  Test OTP application
  """

  @doc """
  Main entry point.
  """
  def main do
    endpoint = nil
    value = endpoint || "https://example.local"
    IO.puts("Hello from #{value}!")
  end
end
