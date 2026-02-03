defmodule CoinchetteWeb.TestRegisterLive do
  use CoinchetteWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, :test, "Hello")}
  end

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm p-8">
      <h1 class="text-2xl font-bold">Test Page</h1>
      <p>Si vous voyez ce message sans rafraîchissement, le problème est dans RegistrationLive.</p>
      <p>Test value: {@test}</p>
    </div>
    """
  end
end
