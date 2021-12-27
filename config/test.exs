use Mix.Config

config :testing_app, KubeRPC.TestClient,
  timeout: 5_000,
  max_attempts: 1
