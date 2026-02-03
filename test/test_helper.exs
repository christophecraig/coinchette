# Ensure the application is started before tests
{:ok, _} = Application.ensure_all_started(:coinchette)

ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Coinchette.Repo, :manual)
