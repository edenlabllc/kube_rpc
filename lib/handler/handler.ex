defmodule KubeRPC.Handler do
  @moduledoc false

  require Logger

  def handle(module, function, args, request_id) do
    Logger.metadata(request_id: request_id)
    Logger.info("Calling #{module}.#{function}")
    apply(module, function, args)
  end
end
