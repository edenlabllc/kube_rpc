defmodule KubeRPC.MixProject do
  use Mix.Project

  def project do
    [
      app: :kube_rpc,
      version: "0.1.0",
      elixir: "~> 1.7",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      name: "kube_rpc",
      source_url: "https://github.com/edenlabllc/kube_rpc"
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {KubeRPC.Application, []}
    ]
  end

  defp package() do
    [
      maintainers: ["Alex Kovalevych"],
      files: ~w(lib mix.exs README.md),
      licenses: ["Apache 2.0"],
      links: %{"GitHub" => "https://github.com/edenlabllc/kube_rpc"}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:confex, "~> 3.4"}
    ]
  end
end
