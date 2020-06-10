# KubeRpc

Client-server library for erlang/elixir RPC microservices interactions.
Can be used for avoid code duplication between microservices.

## Features:

- erlang native RPC usage
- GenServer/call function for sending messages to remote processes
- non blocking server queue
- RPC retry calls in case of fail
- health check support
- k8s scaling support allowing to send messages to equal microservices from the same namespace

## Server

Starts automatically with the application. Will create a separate async process for each RPC request to avoid long messages mailbox queue.
Supports 2 ways of health check:

- sync `:ping`
- async `:check`

## Client

Provides interface for calling the Server.
Can retry RPC call up to 3 (configured value) times.
Randomly chose a server among available erlang nodes in the cluster which match the `basename` pattern.


## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `kube_rpc` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:kube_rpc, "~> 0.4.1"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/kube_rpc](https://hexdocs.pm/kube_rpc).

## Usage

For server, just add library to project and connect it to the erlang cluster.

For client, create it for your application:

```elixir
defmodule Core.Rpc.Worker do
  @moduledoc false

  use KubeRPC.Client, :core
end
```

and connect it to the erlang cluster.
You are able to call any public function in any module on the server:

```elixir
  alias Core.Rpc.Worker
  Worker.run("my_basename", MyBasename.RpcServer, :run, args)
```

"my_basename" - is the server basename which is the part of the erlang node name (before `@`)

`MyBasename.RpcServer` - module to call

`:run` - function to call

args - list of args to call the function with
