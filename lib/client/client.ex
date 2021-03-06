defmodule KubeRPC.Client do
  @moduledoc false

  defmacro __using__(app) do
    quote do
      require Logger

      @behaviour KubeRPC.Client.Behaviour

      def run(basename, module, function, args, attempt \\ 0, skip_servers \\ []) do
        if attempt >= config()[:max_attempts] do
          Logger.warn("Failed RPC request to: #{basename}. #{module}.#{function}: #{sanitized_inspect(args)}")

          {:error, :badrpc}
        else
          do_run(basename, module, function, args, attempt, skip_servers)
        end
      end

      defp do_run(basename, module, function, args, attempt, skip_servers) do
        servers =
          Node.list()
          |> Enum.filter(fn node ->
            case String.split(to_string(node), "@") do
              [^basename | _] -> true
              _ -> false
            end
          end)
          |> Enum.filter(fn server -> server not in skip_servers end)

        case servers do
          # Invalid basename or all servers are down
          [] ->
            Logger.warn("No RPC servers available for basename: #{basename}")
            {:error, :badrpc}

          _ ->
            server = Enum.random(servers)
            Logger.info("RPC request to: #{server}, #{module}.#{function}")
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
                      gen_call(pid, {module, function, args}, timeout)
                    catch
                      :exit, error ->
                        error |> sanitized_inspect() |> Logger.error()
                        run(basename, module, function, args, attempt + 1, [server | skip_servers])
                    end
                end

              pid ->
                case gen_call(pid, {module, function, args}, timeout) do
                  {:error, :badrpc} -> run(basename, module, function, args, attempt + 1, [server | skip_servers])
                  response -> response
                end
            end
        end
      end

      defp get_ergonode(basename) do
        Enum.find(config()[:ergonodes] || [], &(Map.get(&1, "basename") == basename))
      end

      def gen_call(pid, {module, function, args}, timeout) do
        try do
          GenServer.call(pid, {module, function, args, Logger.metadata()[:request_id]}, timeout)
        catch
          :exit, error ->
            error |> sanitized_inspect() |> Logger.error()
            {:error, :badrpc}
        end
      end

      def sanitized_inspect(value) do
        case Logger.level() do
          :debug -> inspect(value)
          _ -> sanitize(value)
        end
      end

      def sanitize({state, {GenServer, :call, [pid, {module, func, args, request_id}, timeout]}})
          when length(args) > 0 do
        inspect({state, {GenServer, :call, [pid, {module, func, [], request_id}, timeout]}})
      end

      def sanitize([_ | _]), do: []
      def sanitize(message), do: inspect(message)

      defp config do
        Application.fetch_env!(unquote(app), __MODULE__)
      end
    end
  end
end
