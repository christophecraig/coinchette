defmodule Mix.Tasks.GenVapidKeys do
  @moduledoc """
  Generates VAPID keys for Web Push notifications.

  Run with: mix gen_vapid_keys
  """
  use Mix.Task

  @shortdoc "Generates VAPID public and private keys for push notifications"

  def run(_) do
    {public_key, private_key} = :crypto.generate_key(:ecdh, :prime256v1)

    public_key_base64 = Base.url_encode64(public_key, padding: false)
    private_key_base64 = Base.url_encode64(private_key, padding: false)

    Mix.shell().info("""

    VAPID keys generated successfully!

    Add these to your config/runtime.exs or set as environment variables:

    config :coinchette,
      vapid_subject: "mailto:your-email@example.com",
      vapid_public_key: "#{public_key_base64}",
      vapid_private_key: "#{private_key_base64}"

    Or as environment variables:
    export VAPID_SUBJECT="mailto:your-email@example.com"
    export VAPID_PUBLIC_KEY="#{public_key_base64}"
    export VAPID_PRIVATE_KEY="#{private_key_base64}"

    Public key (for client-side): #{public_key_base64}
    """)
  end
end
