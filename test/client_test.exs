defmodule KubeRPC.ClientTest do
  @moduledoc """
  Note that you must have ensured that epmd has been started before using this test; typically with epmd -daemon.
  """

  use ExUnit.Case

  require Logger

  import ExUnit.CaptureLog

  alias KubeRPC.TestClient

  test "returns :ok from remote server handler" do
    [node] = LocalCluster.start_nodes("testing_server", 1)

    log =
      capture_log(fn ->
        assert :ok == TestClient.run(get_node_basename(node), TestHandler, :respond, [:ok])
      end)

    logs = String.split(log, "\n")

    assert Enum.any?(logs, &(&1 =~ "RPC request to: testing_server1@127.0.0.1, Elixir.TestHandler.respond started"))
    assert Enum.any?(logs, &(&1 =~ "RPC request to: testing_server1@127.0.0.1, Elixir.TestHandler.respond finished"))
  end

  test "returns {:error, :badrpc} when no servers available" do
    assert capture_log(fn ->
             assert {:error, :badrpc} == TestClient.run("wrong_basename", TestHandler, :respond, [:ok])
           end) =~ "No RPC servers available for basename: wrong_basename"
  end

  test "returns {:error, :badrpc} when all attempts are exhausted" do
    [node] = LocalCluster.start_nodes("testing_server", 1)

    assert capture_log(fn ->
             assert {:error, :badrpc} ==
                      TestClient.run(get_node_basename(node), TestHandler, :raise_error, ["error"], 100)
           end) =~ "Failed RPC request to: testing_server"
  end

  test "returns {:error, :badrpc} on waiting timeout" do
    [node] = LocalCluster.start_nodes("testing_server", 1)

    assert capture_log(fn ->
             assert {:error, :badrpc} ==
                      TestClient.run(
                        get_node_basename(node),
                        TestHandler,
                        :sleep_and_respond,
                        [200, :ok],
                        100
                      )
           end) =~ "Failed RPC request to: testing_server"
  end

  defp get_node_basename(node), do: node |> to_string() |> String.split("@") |> hd()
end
