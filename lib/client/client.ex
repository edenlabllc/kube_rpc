defmodule KubeRPC.Client do
  @moduledoc false

  defmacro __using__(app) do
    quote do
      require Logger

      @behaviour KubeRPC.Client.Behaviour

      def run(basename, module, function, args, timeout \\ nil),
        do: do_run(basename, module, function, args, get_timeout(timeout), 0, [])

      defp get_timeout(timeout) when is_integer(timeout) and timeout > 0,
        do: timeout

      defp get_timeout(_),
        do: config()[:timeout] || 5_000

      defp do_run(selector, module, function, args, timeout, attempts, skip_servers) do
        basename = get_basename(selector)

        with :ok <- check_attempts(attempts),
             servers <- filter_servers(selector, skip_servers),
             {:ok, server} <- get_random_rpc_server(servers),
             {:ok, pid} <- get_rpc_server_process_pid(selector, server),
             {:ok, response} <- call_rpc(pid, server, module, function, args, timeout) do
          response
        else
          {:error, {:bad_server, server}} ->
            do_run(selector, module, function, args, timeout, attempts + 1, [server | skip_servers])

          {:error, :too_many_attempts} ->
            Logger.warn("Failed RPC request to: #{basename}. #{module}.#{function}: #{sanitized_inspect(args)}")
            {:error, :badrpc}

          {:error, :no_servers_available} ->
            Logger.warn("No RPC servers available for basename: #{basename}")
            {:error, :badrpc}
        end
      end

      defp get_basename({basename, _regex}),
        do: basename

      defp get_basename(basename),
        do: basename

      defp check_attempts(attempts) do
        cond do
          attempts >= config()[:max_attempts] ->
            {:error, :too_many_attempts}

          true ->
            :ok
        end
      end

      defp filter_servers(selector, skip_servers) do
        Node.list()
        |> filter_servers_by_selector(selector)
        |> Enum.filter(fn server -> server not in skip_servers end)
      end

      defp filter_servers_by_selector(servers, {basename, regex}) do
        servers
        |> filter_servers_by_selector(basename)
        |> Enum.filter(&(&1 |> to_string() |> String.match?(regex)))
      end

      defp filter_servers_by_selector(servers, basename) do
        Enum.filter(servers, fn server ->
          case String.split(to_string(server), "@") do
            [^basename | _] -> true
            _ -> false
          end
        end)
      end

      # Invalid basename or all servers are down
      defp get_random_rpc_server([]),
        do: {:error, :no_servers_available}

      defp get_random_rpc_server(servers),
        do: {:ok, Enum.random(servers)}

      defp get_rpc_server_process_pid(basename, server) do
        case :global.whereis_name(server) do
          # try to find a process
          :undefined ->
            find_and_set_rpc_server_process_pid(basename, server)

          pid ->
            {:ok, pid}
        end
      end

      defp call_rpc(pid, server, module, function, args, timeout) do
        Logger.info("RPC request to: #{server}, #{module}.#{function} started")

        try do
          result = GenServer.call(pid, {module, function, args, Logger.metadata()[:request_id]}, timeout)
          Logger.info("RPC request to: #{server}, #{module}.#{function} finished")
          {:ok, result}
        catch
          :exit, error ->
            error |> sanitized_inspect() |> Logger.error()
            {:error, {:bad_server, server}}
        end
      end

      defp find_and_set_rpc_server_process_pid(basename, server) do
        # attempt to connect to ergonode
        case get_ergonode(basename) do
          # try a different server
          nil ->
            {:error, {:bad_server, server}}

          ergonode_config ->
            try do
              pid = GenServer.call({ergonode_config["process"], server}, ergonode_config["pid_message"])
              :global.register_name(server, pid)

              {:ok, pid}
            catch
              :exit, error ->
                error |> sanitized_inspect() |> Logger.error()
                {:error, {:bad_server, server}}
            end
        end
      end

      defp get_ergonode(basename), do: Enum.find(config()[:ergonodes] || [], &(Map.get(&1, "basename") == basename))

      defp sanitized_inspect(value) do
        case Logger.level() do
          :debug -> inspect(value)
          _ -> sanitize(value)
        end
      end

      defp sanitize({state, {GenServer, :call, [pid, {module, func, args, request_id}, timeout]}})
           when length(args) > 0 do
        inspect({state, {GenServer, :call, [pid, {module, func, [], request_id}, timeout]}})
      end

      defp sanitize([_ | _]),
        do: []

      defp sanitize(message),
        do: inspect(message)

      defp config,
        do: Application.fetch_env!(unquote(app), __MODULE__)
    end
  end
end
