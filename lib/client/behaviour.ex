defmodule KubeRPC.Client.Behaviour do
  @moduledoc false

  @callback run(basename :: binary, module :: atom, function :: atom, args :: list()) :: any()
end
