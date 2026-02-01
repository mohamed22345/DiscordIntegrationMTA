-- s_example.lua
-- Server-side script for Discord integration example

-- Sample: Granting a reward if a player is linked
addCommandHandler("checklink", function(player)
    if exports["discord-integration"]:isPlayerLinked(player) then
        local discordName = getElementData(player, "discord:username")
        outputChatBox("Welcome back, " .. tostring(discordName) .. "! You are verified.", player, 0, 255, 0)
    else
        outputChatBox("Your account is not linked to Discord. Use /linkdiscord [ID] to link it.", player, 255, 100, 100)
    end
end)