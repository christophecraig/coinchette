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
      <.header class="text-center">
        Register for Coinchette
        <:subtitle>
          Already have an account?
          <.link navigate="/login" class="font-semibold text-brand hover:underline">
            Log in
          </.link>
        </:subtitle>
      </.header>

      <.form
        for={@changeset}
        id="registration_form"
        phx-submit="save"
        phx-change="validate"
      >
        <.input field={@changeset[:email]} type="email" label="Email" required />
        <.input field={@changeset[:username]} type="text" label="Username" required />
        <.input field={@changeset[:password]} type="password" label="Password" required />
        <.input
          field={@changeset[:password_confirmation]}
          type="password"
          label="Confirm Password"
          required
        />

        <div class="mt-6">
          <.button type="submit" phx-disable-with="Creating account..." class="w-full">
            Create an account
          </.button>
        </div>
      </.form>
    </div>
    """
  end
end
