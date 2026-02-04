defmodule CoinchetteWeb.SetupController do
  use CoinchetteWeb, :controller

  def migrate(conn, _params) do
    # Execute migrations
    Coinchette.Release.migrate()

    conn
    |> put_flash(:info, "Database migrations completed successfully!")
    |> redirect(to: "/")
  end
end
