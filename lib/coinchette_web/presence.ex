defmodule CoinchetteWeb.Presence do
  @moduledoc """
  Provides presence tracking for multiplayer games.

  Tracks which users are currently connected to which games,
  enabling disconnect/reconnect detection and recovery.
  """
  use Phoenix.Presence,
    otp_app: :coinchette,
    pubsub_server: Coinchette.PubSub
end
