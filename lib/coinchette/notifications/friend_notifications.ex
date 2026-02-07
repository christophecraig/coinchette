defmodule Coinchette.Notifications.FriendNotifications do
  @moduledoc """
  Helper module for sending friend-related push notifications.
  """

  alias Coinchette.Notifications

  @doc """
  Send notification when a user receives a friend request.
  """
  def notify_friend_request(user_id, requester_name) do
    Notifications.send_notification(user_id, :friend_request, %{
      title: "Nouvelle demande d'ami",
      body: "#{requester_name} veut devenir votre ami !",
      icon: "/images/icon-192.png",
      badge: "/images/icon-96.png",
      tag: "friend_request_#{requester_name}",
      requireInteraction: true,
      data: %{
        type: "friend_request",
        url: "/friends"
      },
      actions: [
        %{
          action: "view_request",
          title: "Voir"
        },
        %{
          action: "dismiss",
          title: "Plus tard"
        }
      ]
    })
  end

  @doc """
  Send notification when a friend request is accepted.
  """
  def notify_friend_accepted(user_id, acceptor_name) do
    Notifications.send_notification(user_id, :friend_request, %{
      title: "Demande acceptée",
      body: "#{acceptor_name} a accepté votre demande d'ami !",
      icon: "/images/icon-192.png",
      badge: "/images/icon-96.png",
      tag: "friend_accepted_#{acceptor_name}",
      requireInteraction: false,
      data: %{
        type: "friend_accepted",
        url: "/friends"
      }
    })
  end
end
