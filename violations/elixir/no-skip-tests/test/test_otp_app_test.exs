defmodule TestOtpAppTest do
  use ExUnit.Case

  @tag :skip
  test "main/0 runs without error" do
    assert TestOtpApp.main() == :ok
  end
end
