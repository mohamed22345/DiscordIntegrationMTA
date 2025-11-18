local discord_data = {}

local dis_bot_token = "bot-token-here" --> replace with your bot token
local dis_api_url = "https://discord.com/api/v10" --> don't touch
local dis_guild_id = "discord-guild-id" --> right click your server icon > copy server ID
local roles_conf = {
    ["role-id"] = { name = "Admin", isAdmin = true },
    ["role-id"] = { name = "Member", isAdmin = false },
}

function isPlayerLinked(player)
    local account = getPlayerAccount(player)
    if not account or isGuestAccount(account) then
        return false
    end
    local accountName = getAccountName(account)
    return discord_data[accountName] ~= nil
end

function isPlayerDiscordAdmin(player)
    if not isPlayerLinked(player) then
        return false
    end

    local account = getPlayerAccount(player)
    local accountName = getAccountName(account)
    local data = discord_data[accountName]
    for _, role in ipairs(data.roles) do
        if roles_conf[role.id] and roles_conf[role.id].isAdmin then
            return true
        end
    end
    return false
end

function linkDiscordAccount(player, discordID)
    local account = getPlayerAccount(player)
    if not account or isGuestAccount(account) then
        outputChatBox("You must log in or register first.", player, 255, 0, 0)
        return false
    end

    local accountName = getAccountName(account)
    if not discordID or discordID == "" or not tonumber(discordID) then
        outputChatBox("Invalid Discord ID.", player, 255, 0, 0)
        return false
    end

    outputChatBox("Linking your Discord account, please wait...", player, 255, 200, 0)

    local url = string.format("%s/guilds/%s/members/%s", dis_api_url, dis_guild_id, discordID)
    fetchRemote(url,
        {
            method = "GET",
            headers = {
                ["Authorization"] = "Bot " .. dis_bot_token,
                ["Content-Type"] = "application/json"
            },
            queueName = "discord",
            connectionAttempts = 3,
            connectTimeout = 10000
        },
        function(responseData, info)
            if not info.success then
                local errorMsg = info.statusCode and ("HTTP " .. info.statusCode) or "Connection Failed"
                outputChatBox("Discord API connection error (" .. errorMsg .. ")", player, 255, 0, 0)
                outputDebugString("[DiscordAPI] fetchRemote failed: " .. tostring(info.statusCode or "unknown"))
                return
            end

            local memberData = fromJSON(responseData)
            if not memberData then
                outputChatBox("Invalid response from Discord API.", player, 255, 0, 0)
                outputDebugString("[DiscordAPI] Invalid JSON: " .. tostring(responseData))
                return
            end

            if memberData.message == "Unknown Member" then
                outputChatBox("Could not find a Discord member with that ID in the guild.", player, 255, 150, 0)
                return
            end

            local userData = memberData.user
            if not userData then
                outputChatBox("Discord member has no user data.", player, 255, 150, 0)
                return
            end

            local avatarURL = "https://cdn.discordapp.com/embed/avatars/0.png"
            if userData.avatar then
                avatarURL = string.format("https://cdn.discordapp.com/avatars/%s/%s.png", discordID, userData.avatar)
            end

            local roles = {}
            if memberData.roles then
                for _, roleId in ipairs(memberData.roles) do
                    if roles_conf[roleId] then
                        table.insert(roles, { id = roleId, name = roles_conf[roleId].name })
                    else
                        table.insert(roles, { id = roleId, name = "Unknown Role" })
                    end
                end
            end

            discord_data[accountName] = {
                id = discordID,
                username = userData.username,
                discriminator = userData.discriminator or "0",
                avatar = userData.avatar,
                avatarURL = avatarURL,
                roles = roles
            }

            setAccountData(account, "discord:id", discordID)
            setAccountData(account, "discord:username", userData.username)
            setAccountData(account, "discord:avatar", userData.avatar or "default")
            setAccountData(account, "discord:avatarURL", avatarURL)
            setAccountData(account, "discord:roles", toJSON(roles))
            setAccountData(account, "discord:guildMember", true)

            outputChatBox("Discord account linked successfully!", player, 0, 255, 0)
            outputChatBox("Username: " .. userData.username .. "#" .. (userData.discriminator or "0000"), player, 100, 255, 100)
            outputDebugString(string.format("[DiscordAPI] %s linked to %s#%s", accountName, userData.username, userData.discriminator or "0000"))
        end
    )

    return true
end

function unlinkDiscordAccount(player)
    local account = getPlayerAccount(player)
    if not account or isGuestAccount(account) then
        outputChatBox("You must log in or register first.", player, 255, 0, 0)
        return false
    end

    local accountName = getAccountName(account)
    if not isPlayerLinked(player) then
        outputChatBox("Your account is not linked to any Discord account.", player, 255, 200, 0)
        return false
    end

    discord_data[accountName] = nil
    setAccountData(account, "discord:id", nil)
    setAccountData(account, "discord:username", nil)
    setAccountData(account, "discord:avatar", nil)
    setAccountData(account, "discord:avatarURL", nil)
    setAccountData(account, "discord:roles", nil)
    setAccountData(account, "discord:guildMember", nil)

    outputChatBox("Your Discord account has been unlinked successfully.", player, 0, 255, 0)
    outputDebugString(string.format("[DiscordAPI] %s unlinked their Discord account.", accountName))
    return true
end

function getPlayerRoles(player)
    if not isPlayerLinked(player) then
        return {}
    end

    local account = getPlayerAccount(player)
    local accountName = getAccountName(account)
    local data = discord_data[accountName]
    return data.roles
end

addCommandHandler("linkdiscord", function(player, cmd, discordID)
    if not discordID then
        outputChatBox("Usage: /linkdiscord [Discord ID]", player, 255, 100, 100)
        outputChatBox("To get your Discord ID, go to Settings > Advanced > Enable Developer Mode.", player, 200, 200, 200)
        return
    end
    
    if isPlayerLinked(player) then
        outputChatBox("Your account is already linked! Use /unlinkdiscord to unlink it.", player, 255, 200, 0)
        return
    end
    
    linkDiscordAccount(player, discordID)
end)

addCommandHandler("discordinfo", function(player, cmd, targetPlayer)
    local target = player
    
    if targetPlayer then
        target = getPlayerFromName(targetPlayer)
        if not target then
            outputChatBox("Player not found.", player, 255, 0, 0)
            return
        end
    end
    
    if not isPlayerLinked(target) then
        local name = targetPlayer and getPlayerName(target) or "You"
        outputChatBox(name .. " do not have a linked Discord account.", player, 255, 0, 0)
        return
    end
    
    local account = getPlayerAccount(target)
    local accountName = getAccountName(account)
    local data = discord_data[accountName]
    
    fetchRemote(dis_api_url .. "/guilds/"..dis_guild_id.."/members/" .. data.id,
        {
            method = "GET",
            headers = {
                ["Authorization"] = "Bot " .. dis_bot_token,
                ["Content-Type"] = "application/json"
            },
            queueName = "discord"
        },
        function(memberData, memberInfo)
            local roles = {}
            if memberInfo.success then
                local memberJSON = fromJSON(memberData)
                if memberJSON and memberJSON.roles then
                    for _, roleId in ipairs(memberJSON.roles) do
                        if roles_conf[roleId] then
                            table.insert(roles, {
                                id = roleId,
                                name = roles_conf[roleId].name
                            })
                        end
                    end
                end
            end
            
            triggerClientEvent(player, "discord:downloadAvatar", player, {
                accountName = accountName,
                username = data.username,
                avatarURL = data.avatarURL,
                discordID = data.id,
                roles = roles
            })
        end
    )
end)

function isPlayerGuildMember(player)
    if not isPlayerLinked(player) then
        return false
    end

    local account = getPlayerAccount(player)
    local accountName = getAccountName(account)
    local data = discord_data[accountName]
    return data ~= nil
end

addCommandHandler("unlinkdiscord", function(player)
    if not isPlayerLinked(player) then
        outputChatBox("Your account is not linked to any Discord account.", player, 255, 200, 0)
        return
    end
    
    unlinkDiscordAccount(player)
end)

addEvent("requestDiscordAvatar", true)
addEventHandler("requestDiscordAvatar", root, function()
    local account = getPlayerAccount(source)
    if not account or isGuestAccount(account) then
        return
    end
    triggerClientEvent(source, "discord:downloadAvatar", source, {
        accountName = getAccountName(account),
        username = getAccountData(account, "discord:username"),
        avatarURL = getAccountData(account, "discord:avatarURL"),
        discordID = getAccountData(account, "discord:id"),
        roles = fromJSON(getAccountData(account, "discord:roles") or "[]")
    })
end)

addEventHandler("onResourceStart", resourceRoot, function()
    for _, player in ipairs(getElementsByType("player")) do
        triggerClientEvent(player, "discord:updateRolesConf", player, roles_conf)
    end
end)

addEventHandler("onPlayerJoin", root, function()
    triggerClientEvent(source, "discord:updateRolesConf", source, roles_conf)
end)