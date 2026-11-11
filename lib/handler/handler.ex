defmodule KubeRPC.Handler do
  @moduledoc false

  require Logger

  def handle(module, function, args, request_id) do
    Process.group_leader(self(), Process.whereis(:user))
    Logger.metadata(request_id: request_id)
    Logger.info("Calling #{module}.#{function}")

    try do
      apply(module, function, args)
    rescue
      error ->
        {:error, Exception.message(error)}
    end
  end
end
