defmodule TestOtpApp do
  @moduledoc """
  Test OTP application
  """

  @doc """
  Main entry point.
  """
  def main do
    config = %{name: "test_otp_app"}
    port = Map.get(config, :port, 4000)
    IO.puts("Hello from test_otp_app on port #{port}!")
  end
end
