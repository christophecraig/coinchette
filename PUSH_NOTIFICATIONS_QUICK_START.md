# Push Notifications - Quick Start Guide

Get push notifications working in under 5 minutes!

## For Developers

### 1. Setup (Already Done!)

Everything is already configured:
- ✅ Dependencies installed (`web_push_encryption`)
- ✅ Database migration run
- ✅ VAPID keys generated and configured
- ✅ Service worker updated
- ✅ JavaScript modules added
- ✅ Settings page created

### 2. Test It Out

```bash
# Start the server
mix phx.server

# Visit the app
open http://localhost:4000
```

### 3. Enable Notifications (User Flow)

1. Login to your account
2. Go to Profile (click your username)
3. Click "🔔 Notifications" button in the top right
4. Click "Enable Push Notifications"
5. Grant permission when browser prompts
6. Click "Test Notification" to verify

### 4. Send a Notification (Code Example)

```elixir
# In your LiveView or controller
alias Coinchette.Notifications.GameNotifications

# When a game event happens
def handle_event("play_card", _params, socket) do
  # ... game logic ...

  # Notify next player it's their turn
  GameNotifications.notify_your_turn(
    next_player_id,
    socket.assigns.current_user.username,
    game_id
  )

  {:noreply, socket}
end
```

## For Users

### Enable Notifications

1. **Open Coinchette**
   - Go to https://your-domain.com or localhost:4000

2. **Login**
   - Sign in to your account

3. **Go to Settings**
   - Click your username/profile
   - Click the 🔔 Notifications button

4. **Enable Push**
   - Click "Enable Push Notifications"
   - Allow when browser asks for permission
   - Test with "Test Notification" button

5. **Customize Preferences**
   - Toggle notification types:
     - ✅ Game invitations (recommended)
     - ✅ Your turn to play (recommended)
     - ✅ Game results
     - ⬜ Chat messages (opt-in)

### What You'll Get Notified About

- **Game Invites**: When someone invites you to play
- **Your Turn**: When it's your turn in a game
- **Game Results**: When a game finishes (win/loss/draw)
- **Chat Messages**: New chat messages (if enabled)

### Platform Support

| Platform | Support | Notes |
|----------|---------|-------|
| 🖥️ Chrome (Desktop) | ✅ Full | Works great! |
| 📱 Chrome (Android) | ✅ Full | Best mobile experience |
| 🦊 Firefox | ✅ Full | Works great! |
| 🧭 Safari (macOS) | ✅ Full | Safari 16+ |
| 📱 Safari (iOS) | ⚠️ Partial | Must add to Home Screen first |
| 💻 Edge | ✅ Full | Works great! |

## Quick Testing Checklist

- [ ] Dependencies installed (`mix deps.get`)
- [ ] Migration run (`mix ecto.migrate`)
- [ ] Assets compiled (`cd assets && npm run build`)
- [ ] Server running (`mix phx.server`)
- [ ] Navigate to `/settings/notifications`
- [ ] Click "Enable Push Notifications"
- [ ] Grant browser permission
- [ ] Click "Test Notification"
- [ ] See notification appear (even if browser is in background)
- [ ] Click notification - opens app

## Common Integration Points

### 1. Game Turn Change

```elixir
# In MultiplayerGameLive
def handle_info({:turn_changed, next_player_id}, socket) do
  GameNotifications.notify_your_turn(
    next_player_id,
    socket.assigns.current_user.username,
    socket.assigns.game.id
  )
  {:noreply, socket}
end
```

### 2. Game Invitation

```elixir
# In LobbyLive
def handle_event("invite_player", %{"user_id" => user_id}, socket) do
  GameNotifications.notify_game_invite(
    user_id,
    socket.assigns.current_user.username,
    socket.assigns.game.id
  )
  {:noreply, socket}
end
```

### 3. Game Finished

```elixir
# In MultiplayerGameLive
def handle_info({:game_finished, winner_id}, socket) do
  game = socket.assigns.game

  # Notify each player of the result
  for player <- game.players do
    result = if player.id == winner_id, do: :won, else: :lost
    opponent = get_opponent(player, game)

    GameNotifications.notify_game_result(
      player.id,
      result,
      opponent.username,
      game.id
    )
  end

  {:noreply, socket}
end
```

## Troubleshooting

### Notifications Not Showing?

**Check 1: Browser Support**
```javascript
// In browser console
console.log('ServiceWorker:', 'serviceWorker' in navigator);
console.log('PushManager:', 'PushManager' in window);
console.log('Notification:', 'Notification' in window);
console.log('Permission:', Notification.permission);
// All should be true/granted
```

**Check 2: Service Worker Registered**
```javascript
// In browser console
navigator.serviceWorker.getRegistration().then(reg => {
  console.log('SW registered:', !!reg);
  console.log('SW active:', !!reg.active);
});
```

**Check 3: Subscription Exists**
```javascript
// In browser console
navigator.serviceWorker.ready.then(reg => {
  reg.pushManager.getSubscription().then(sub => {
    console.log('Subscribed:', !!sub);
    if (sub) console.log('Endpoint:', sub.endpoint);
  });
});
```

**Check 4: VAPID Keys Configured**
```bash
# In terminal
mix run -e "IO.inspect Application.get_env(:coinchette, :vapid_public_key)"
# Should print a long base64 string
```

### iOS Safari Not Working?

iOS requires the PWA to be "Add to Home Screen" first:
1. Open Safari
2. Tap Share button
3. Tap "Add to Home Screen"
4. Open app from home screen
5. Then enable notifications

### Permission Denied?

If user clicked "Block":
1. Click the lock icon in address bar
2. Find "Notifications"
3. Change to "Allow"
4. Refresh page
5. Try enabling again

## Need More Help?

📖 See full documentation: `PUSH_NOTIFICATIONS.md`

🐛 Issues? Check:
- Browser console for errors
- Network tab for failed requests
- Server logs for push sending errors
- Service worker logs in DevTools

## Quick Reference

**Settings Page**: `/settings/notifications`

**Send Notification**:
```elixir
GameNotifications.notify_your_turn(user_id, opponent_name, game_id)
```

**Check Subscriptions**:
```elixir
Notifications.list_user_subscriptions(user_id)
```

**Update Preferences**:
```elixir
Notifications.update_preferences(subscription_id, user_id, %{
  notify_game_invite: true,
  notify_your_turn: false
})
```

---

That's it! Your push notifications are ready to go! 🎉

For detailed implementation guide, see `PUSH_NOTIFICATIONS.md`
