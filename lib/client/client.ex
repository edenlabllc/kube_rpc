defmodule KubeRPC.Client do
  @moduledoc false

  defmacro __using__(app) do
    quote do
      use Confex, otp_app: unquote(app)
      require Logger

      @behaviour KubeRPC.Client.Behaviour

      def run(basename, module, function, args, attempt \\ 0, skip_servers \\ []) do
        if attempt >= config()[:max_attempts] do
          Logger.warn("Failed RPC request to: #{basename}. #{module}.#{function}: #{inspect(args)}")

          {:error, :badrpc}
        else
          do_run(basename, module, function, args, attempt, skip_servers)
        end
      end

      defp do_run(basename, module, function, args, attempt, skip_servers) do
        servers =
          Node.list()
          |> Enum.filter(&String.starts_with?(to_string(&1), basename))
          |> Enum.filter(fn server -> server not in skip_servers end)

        case servers do
          # Invalid basename or all servers are down
          [] ->
            Logger.warn("No RPC servers available for basename: #{basename}")
            {:error, :badrpc}

          _ ->
            server = Enum.random(servers)
            Logger.info("RPC request to: #{server}, #{module}.#{function}: #{inspect(args)}")
            timeout = config()[:timeout] || 5_000

            case :global.whereis_name(String.to_atom(server)) do
              # try a different server
              :undefined ->
                run(basename, module, function, args, attempt + 1, [server | skip_servers])

              pid ->
                try do
                  GenServer.call(server, {module, function, args}, timeout)
                catch
                  :exit, error ->
                    Logger.error(inspect(error))
                    {:error, :badrpc}
                end
            end
        end
      end
    end
  end
end
