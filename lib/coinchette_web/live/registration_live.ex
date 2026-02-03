defmodule CoinchetteWeb.RegistrationLive do
  use CoinchetteWeb, :live_view

  alias Coinchette.Accounts
  alias Coinchette.Accounts.User

  on_mount {CoinchetteWeb.Auth, :mount_current_user}

  def mount(_params, _session, socket) do
    changeset = Accounts.change_user_registration(%User{})

    socket =
      socket
      |> assign(:page_title, "Register")
      |> assign(:changeset, changeset)

    {:ok, socket}
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset =
      %User{}
      |> Accounts.change_user_registration(user_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.register_user(user_params) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Account created successfully!")
         |> redirect(to: "/login")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <h1 class="text-2xl font-bold text-center mb-4">Register for Coinchette</h1>

      <form phx-submit="save" phx-change="validate">
        <div class="mb-4">
          <label for="email">Email</label>
          <input type="email" name="user[email]" id="email" required class="w-full border rounded px-3 py-2" />
        </div>

        <div class="mb-4">
          <label for="username">Username</label>
          <input type="text" name="user[username]" id="username" required class="w-full border rounded px-3 py-2" />
        </div>

        <div class="mb-4">
          <label for="password">Password</label>
          <input type="password" name="user[password]" id="password" required class="w-full border rounded px-3 py-2" />
        </div>

        <div class="mb-4">
          <label for="password_confirmation">Confirm Password</label>
          <input type="password" name="user[password_confirmation]" id="password_confirmation" required class="w-full border rounded px-3 py-2" />
        </div>

        <button type="submit" class="w-full bg-blue-600 text-white rounded px-4 py-2">
          Create an account
        </button>
      </form>

      <p class="mt-4 text-center">
        Already have an account? <a href="/login" class="text-blue-600">Log in</a>
      </p>
    </div>
    """
  end
end
