defmodule KubeRPC.Server do
  @moduledoc false

  use GenServer
  require Logger

  def start_link(_) do
    GenServer.start_link(__MODULE__, [])
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_call({module, function, args}, from, state) when is_list(args) do
    Task.start(fn ->
      Logger.info("Calling #{module}.#{function} with args: #{inspect(args)}")
      GenServer.reply(from, apply(module, function, args))
    end)

    {:noreply, state}
  end

  @impl true
  def handle_call(_, _, state) do
    {:reply, {:error, :badrpc}, state}
  end

  @impl true
  def handle_info(_, state) do
    {:noreply, state}
  end
end
