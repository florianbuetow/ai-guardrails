defmodule TestOtpApp.CycleA do
  @moduledoc """
  VIOLATION: Application modules form a circular dependency.
  """

  def call do
    TestOtpApp.CycleB.call()
  end
end

defmodule TestOtpApp.CycleB do
  @moduledoc false

  def call do
    TestOtpApp.CycleA.call()
  end
end
