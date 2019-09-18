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
      Logger.info("Calling #{module}.#{function}")
      GenServer.reply(from, apply(module, function, args))
    end)

    {:noreply, state}
  end

  @impl true
  def handle_call({module, function, args, request_id}, from, state) when is_list(args) do
    Task.start(fn ->
      Logger.metadata(request_id: request_id)
      Logger.info("Calling #{module}.#{function}")
      GenServer.reply(from, apply(module, function, args))
    end)

    {:noreply, state}
  end

  @impl true
  def handle_call(:ping, _, state) do
    {:reply, "pong", state}
  end

  @impl true
  def handle_call(_, _, state) do
    {:reply, {:error, :badrpc}, state}
  end

  @impl true
  def handle_cast(:check, state) do
    Task.start(fn ->
      case File.open(System.get_env("HEALTH_CHECK_PATH") || "/tmp/healthy", [:write]) do
        {:ok, pid} -> File.close(pid)
        error -> Logger.error("Failed to create file: #{inspect(error)}")
      end
    end)

    {:noreply, state}
  end

  @impl true
  def handle_info(_, state) do
    {:noreply, state}
  end
end
