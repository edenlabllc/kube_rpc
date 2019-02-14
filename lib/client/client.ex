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

            case :global.whereis_name(server) do
              # try a different server
              :undefined ->
                # attempt to connect to ergonode
                case get_ergonode(basename) do
                  nil ->
                    run(basename, module, function, args, attempt + 1, [server | skip_servers])

                  ergonode_config ->
                    try do
                      pid = GenServer.call({ergonode_config["process"], server}, ergonode_config["pid_message"])
                      :global.register_name(server, pid)
                    catch
                      :exit, error ->
                        Logger.error(inspect(error))
                        run(basename, module, function, args, attempt + 1, [server | skip_servers])
                    end
                end

              pid ->
                try do
                  GenServer.call(pid, {module, function, args}, timeout)
                catch
                  :exit, error ->
                    Logger.error(inspect(error))
                    {:error, :badrpc}
                end
            end
        end
      end

      defp get_ergonode(basename) do
        Enum.find(config()[:ergonodes] || [], &(Map.get(&1, "basename") == basename))
      end
    end
  end
end
