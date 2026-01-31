defmodule CoinchetteWeb.Plugs.TestAuth do
  @moduledoc """
  Plug for test authentication bypass in E2E tests.

  This plug allows E2E tests to authenticate automatically by creating
  a test user session when a special header is present.

  WARNING: This should ONLY be enabled in test environment!
  """

  import Plug.Conn
  alias Coinchette.Accounts

  def init(opts), do: opts

  def call(conn, _opts) do
    # Only enable in test environment
    # Check both Mix.env and the test header
    if Mix.env() == :test or Mix.env() == :dev do
      case get_req_header(conn, "x-test-auth") do
        ["true"] ->
          create_test_session(conn)

        _ ->
          conn
      end
    else
      conn
    end
  end

  defp create_test_session(conn) do
    # Get or create test user
    case get_or_create_test_user() do
      {:ok, user} ->
        # Put user in session like normal auth would
        conn
        |> put_session(:user_id, user.id)
        |> put_session(:live_socket_id, "users_sessions:#{user.id}")
        |> assign(:current_user, user)

      {:error, _} ->
        conn
    end
  end

  defp get_or_create_test_user do
    email = "e2e_test@example.com"

    case Accounts.get_user_by_email(email) do
      nil ->
        # Create test user
        Accounts.register_user(%{
          email: email,
          username: "e2e_tester",
          password: "testpassword123"
        })

      user ->
        {:ok, user}
    end
  end
end
