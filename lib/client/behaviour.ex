defmodule KubeRPC.Client.Behaviour do
  @moduledoc false

  @callback run(
              basename :: binary(),
              module :: atom(),
              function :: atom(),
              args :: list()
            ) :: any()

  @callback run(
              basename :: binary(),
              module :: atom(),
              function :: atom(),
              args :: list(),
              timeout :: integer() | nil
            ) :: any()
end
