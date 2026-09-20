defmodule TestOtpApp do
  @moduledoc """
  Test OTP application.
  """

  def main do
    IO.puts("Hello from test_otp_app!")
    bad_call()
  end

  defp bad_call do
    String.to_integer(:not_a_string)
  end
end
