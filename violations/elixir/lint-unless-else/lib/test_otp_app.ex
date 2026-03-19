defmodule TestOtpApp do
  @moduledoc """
  Test OTP application.
  """

  def main do
    value = true
    unless !value do
      IO.puts("Hello from test_otp_app!")
    end
  end
end
