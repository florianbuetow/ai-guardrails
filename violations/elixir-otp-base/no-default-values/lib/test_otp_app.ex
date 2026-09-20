defmodule TestOtpApp do
  @moduledoc """
  Test OTP application
  """

  @doc """
  Main entry point.
  """
  def main do
    IO.puts(greet("test_otp_app"))
  end

  def greet(name \\ "test_otp_app") do
    "Hello from #{name}!"
  end
end
