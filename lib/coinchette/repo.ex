defmodule Coinchette.Repo do
  use Ecto.Repo,
    otp_app: :coinchette,
    adapter: Ecto.Adapters.Postgres
end
