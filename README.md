# 🛰️ Discord Integration for MTA:SA

A professional, high-performance, and secure integration between **MTA:SA** and **Discord (v10 API)**. Link your players' in-game accounts to their Discord profiles with ease.

## ✨ Features
- 🔒 **Secure Account Linking**: Uses a 6-digit verification code sent via Discord DMs.
- ⚡ **API Rate Limiting**: Built-in request queuing to prevent Discord API bans.
- 💾 **Built-in Storage**: Uses the MTA:SA account system (`internal.db`) for zero external dependencies.
- 🖼️ **Avatar Integration**: Fetch and render circular Discord avatars in-game using shaders.
- 🎭 **Role Synchronization**: Check for specific Discord roles or administrative permissions.
- 🧹 **Optimized & Clean**: Automatic cache cleanup (TTL) and memory leak protection.
- 🧼 **Clean Codebase**: Aggressively refactored for readability and performance.

---

## 🚀 Installation

1. **Download**: Clone or download this repository into your MTA server's `resources` directory.
2. **Discord Bot**:
   - Create a bot on the [Discord Developer Portal](https://discord.com/developers/applications).
   - Enable `Server Members Intent` under the **Bot** tab.
   - Invite the bot to your server with `Manage Roles` and `Send Messages` permissions.
3. **Configuration**:
   - Open `config.lua` and add your **Bot Token** and **Guild ID**.
   - Map your Discord Role IDs to friendly names in the `Config.Roles` table.
4. **ACL Permissions**:
   - Add the resource to your `ACL.xml` with access to `function.fetchRemote`.
   ```xml
   <group name="RPC">
       <object name="resource.discord-integration" />
   </group>
   ```
5. **Start**: Run `refresh` and `start discord-integration` in your server console.

---

## 🛠️ Global API

### Server-Side
| Function | Description |
| :--- | :--- |
| `isPlayerLinked(player)` | Returns `true` if linked. |
| `isPlayerDiscordAdmin(player)` | Checks for admin roles defined in config. |
| `hasRole(player, "RoleName")` | Checks if player has a specific role by name. |
| `getAvatar(playerOrId, callback)` | Retrieves avatar in Base64 format. |
| `sendDiscordDM(discordID, message, callback)` | Sends a private message to a user. |
| `addRole(playerOrId, roleId, callback)` | Adds a Discord role to the user. |
| `removeRole(playerOrId, roleId, callback)` | Removes a Discord role. |

### Client-Side
| Function | Description |
| :--- | :--- |
| `drawPlayerAvatar(size, x, y, isCircular)` | Draws the local player's avatar. |
| `getAvatarBase64(discordId, eventName)` | Requests avatar data (triggers event). |
| `isPlayerDiscordAdmin(player)` | Shared-access admin check. |

---

## Usage Examples

### Server-Side: Check Role & Reward
```lua
-- Granting a reward if a player has a specific Discord role
addCommandHandler("getreward", function(player)
    local discord = exports["discord-integration"]
    if discord:hasRole(player, "VIP Member") then
        givePlayerMoney(player, 5000)
        outputChatBox("Bonus received for being a VIP!", player, 0, 255, 0)
    else
        outputChatBox("You need the VIP Member role on Discord!", player, 255, 0, 0)
    end
end)
```

### Server-Side: Send DM Notification
```lua
function notifyPlayerOnDiscord(player, message)
    local discordID = getElementData(player, "discord:id")
    if discordID and discordID ~= "none" then
        exports["discord-integration"]:sendDiscordDM(discordID, "🔔 **Server Notification:**\n" .. message)
    end
end
```

### Client-Side: Custom UI Avatar
```lua
addEventHandler("onClientRender", root, function()
    -- Draw 64x64 circular avatar at top left
    exports["discord-integration"]:drawPlayerAvatar(64, 10, 10, true)
end)
```

### Global: Fetching Base64 Avatar
```lua
-- Client-side request
addEventHandler("onClientResourceStart", resourceRoot, function()
    exports["discord-integration"]:getAvatarBase64("DISCORD_USER_ID", "onAvatarReceived")
end)

addEvent("onAvatarReceived", true)
addEventHandler("onAvatarReceived", root, function(base64Data)
    if base64Data then
        outputChatBox("Received Avatar Base64!")
        -- Use base64Data in your UI (Browser/Texture)
    end
end)
```

---

## 📋 Commands
- `/linkdiscord [DiscordID]` — Starts the linking process.
- `/verify [Code]` — Verifies the code sent to your DMs.
- `/unlinkdiscord` — Removes the link from your account.
- `/discorduser` — (Example) Toggles the info panel.

---

## 🤝 Contributing
Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License
This project is licensed under the MIT License.
