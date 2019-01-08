defmodule KubeRPC.Application do
  use Application

  alias KubeRPC.Server

  def start(_type, _args) do
    children = [
      {Server, []}
    ]

    opts = [strategy: :one_for_one, name: KubeRPC.Supervisor]

    {:ok, pid} = Supervisor.start_link(children, opts)
    [{_, server_pid, _, _}] = Supervisor.which_children(pid)
    :global.register_name(Node.self(), server_pid)
    {:ok, pid}
  end
end
