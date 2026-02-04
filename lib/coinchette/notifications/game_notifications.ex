defmodule Coinchette.Notifications.GameNotifications do
  @moduledoc """
  Helper module for sending game-related push notifications.
  """

  alias Coinchette.Notifications

  @doc """
  Send notification when a player is invited to a game.
  """
  def notify_game_invite(user_id, inviter_name, game_id) do
    Notifications.send_notification(user_id, :game_invite, %{
      title: "Game Invitation",
      body: "#{inviter_name} invited you to play Coinchette!",
      icon: "/images/icon-192.png",
      badge: "/images/icon-96.png",
      tag: "game_invite_#{game_id}",
      requireInteraction: true,
      data: %{
        game_id: game_id,
        type: "game_invite"
      },
      actions: [
        %{
          action: "join_game",
          title: "Join Game"
        },
        %{
          action: "dismiss",
          title: "Dismiss"
        }
      ]
    })
  end

  @doc """
  Send notification when it's a player's turn.
  """
  def notify_your_turn(user_id, opponent_name, game_id) do
    Notifications.send_notification(user_id, :your_turn, %{
      title: "Your Turn!",
      body: "Play against #{opponent_name} in Coinchette",
      icon: "/images/icon-192.png",
      badge: "/images/icon-96.png",
      tag: "your_turn_#{game_id}",
      requireInteraction: false,
      data: %{
        game_id: game_id,
        type: "your_turn"
      },
      actions: [
        %{
          action: "join_game",
          title: "Play Now"
        }
      ]
    })
  end

  @doc """
  Send notification when a game is finished.
  """
  def notify_game_result(user_id, result, opponent_name, game_id) do
    {title, body} =
      case result do
        :won ->
          {"You Won!", "Congratulations! You beat #{opponent_name}"}

        :lost ->
          {"Game Over", "#{opponent_name} won this time. Better luck next game!"}

        :draw ->
          {"Draw", "The game with #{opponent_name} ended in a draw"}
      end

    Notifications.send_notification(user_id, :game_result, %{
      title: title,
      body: body,
      icon: "/images/icon-192.png",
      badge: "/images/icon-96.png",
      tag: "game_result_#{game_id}",
      requireInteraction: false,
      data: %{
        game_id: game_id,
        type: "game_result",
        result: to_string(result)
      },
      actions: [
        %{
          action: "view_game",
          title: "View Game"
        }
      ]
    })
  end

  @doc """
  Send notification when a player receives a chat message in a game.
  """
  def notify_chat_message(user_id, sender_name, message_preview, game_id) do
    Notifications.send_notification(user_id, :chat_message, %{
      title: "Message from #{sender_name}",
      body: String.slice(message_preview, 0, 100),
      icon: "/images/icon-192.png",
      badge: "/images/icon-96.png",
      tag: "chat_#{game_id}",
      requireInteraction: false,
      data: %{
        game_id: game_id,
        type: "chat_message"
      },
      actions: [
        %{
          action: "join_game",
          title: "Reply"
        }
      ]
    })
  end

  @doc """
  Send notification to multiple players (e.g., when a lobby fills up).
  """
  def notify_lobby_ready(user_ids, lobby_code) do
    Notifications.broadcast_notification(user_ids, :game_invite, %{
      title: "Lobby Ready!",
      body: "All players have joined. The game is starting!",
      icon: "/images/icon-192.png",
      badge: "/images/icon-96.png",
      tag: "lobby_ready_#{lobby_code}",
      requireInteraction: false,
      data: %{
        lobby_code: lobby_code,
        type: "lobby_ready"
      }
    })
  end

  @doc """
  Send reminder notification if a player hasn't taken their turn after some time.
  """
  def notify_turn_reminder(user_id, game_id) do
    Notifications.send_notification(user_id, :your_turn, %{
      title: "Turn Reminder",
      body: "Don't forget to take your turn in Coinchette!",
      icon: "/images/icon-192.png",
      badge: "/images/icon-96.png",
      tag: "turn_reminder_#{game_id}",
      requireInteraction: false,
      data: %{
        game_id: game_id,
        type: "turn_reminder"
      }
    })
  end
end
