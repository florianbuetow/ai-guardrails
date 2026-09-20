defmodule TestOtpApp do
  @moduledoc """
  Test OTP application
  """

  @dialyzer {:nowarn_function, main: 0}

  @doc """
  Main entry point.
  """
  def main do
    IO.puts("Hello from test_otp_app!")
  end
end
