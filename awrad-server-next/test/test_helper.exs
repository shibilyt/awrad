ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Awrad.Repo, :manual)
# Recordings go to an in-memory stand-in for R2 (config/test.exs).
Awrad.Audio.FakeStorage.start()
