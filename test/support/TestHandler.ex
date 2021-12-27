defmodule TestHandler do
  @moduledoc false

  def respond(res), do: res

  def raise_error(error), do: raise(error)

  def sleep_and_respond(ms, res) do
    Process.sleep(ms)
    res
  end
end
