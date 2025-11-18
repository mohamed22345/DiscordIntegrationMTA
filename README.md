# DiscordIntegrationMTA
Discord Integration to link discord account with player account in MTA:SA server


Sure! Here is your text rewritten and properly formatted for a **GitHub README.md** file, with clean Markdown structure, code formatting, and professional styling:

---

# 🛰️ Discord Integration System for MTA:SA

A complete system that connects players inside **MTA:SA** with their **Discord** accounts by linking their in-game profiles to their **Discord User ID**.

This integration securely retrieves selected user information through the **Discord API** and displays it in-game — without exposing any sensitive data or putting the player’s account at risk.

---

## ⚙️ Features (First Release)

### 🔗 `linkWithDiscord`

Starts the linking process between the player and Discord.
The player provides their **Discord User ID**, and the system links their in-game account to their Discord profile.

### 🧩 `isPlayerLinked`

Checks whether a player is linked with Discord.
Useful for validating in your own scripts.

### 🛡️ `isPlayerDiscordAdmin`

Checks whether the player has **administrative roles** on the connected Discord server.
Allows you to create staff/admin-only features.

### 👥 `isPlayerGuildMember`

Detects whether the player is a member of your Discord server.

### 🖼️ `downloadUserAvatar`

Downloads and locally caches the player’s Discord avatar for better performance.

### 🎨 `drawPlayerAvatar`

Useful for drawing the player's Discord avatar inside your own UI elements or custom panels.

### 🏷️ `getPlayerRoles`

Retrieves all **Discord roles** assigned to the player.

---

## 📦 Upcoming Features

Planned for future updates:

### 🖼️ `downloadUserBanner`

Download and cache the user’s profile banner.

### 🎉 `downloadUserDecoration`

Download and cache the user’s avatar decoration or frame.

### 🆔 `getRoleID`

Retrieve a role’s ID by its name.

### 🔤 `getRoleName`

Retrieve a role’s name by its ID.

### 🔧 More Features

Additional functions and improvements will be announced in future releases.

---

This content has been enhanced and refined using AI assistance.
