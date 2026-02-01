local activation_codes = {}
local discord_data = {}
local avatarCache = {}

local function safeFromJSON(data)
    if not data or data == "" then return nil end
    local success, result = pcall(fromJSON, data)
    return success and result or nil
end

local requestQueue = {}
local lastRequestTick = 0
local processTimer = nil

local function processQueue()
    if #requestQueue == 0 then
        if isTimer(processTimer) then killTimer(processTimer) end
        processTimer = nil
        return
    end

    local now = getTickCount()
    if now - lastRequestTick < (Config.RateLimitInterval / Config.RateLimitRequests) then
        return
    end

    local request = table.remove(requestQueue, 1)
    lastRequestTick = now

    fetchRemote(request.url, request.options, function(responseData, info)
        if request.callback then
            request.callback(responseData, info)
        end
    end)

    if #requestQueue > 0 and not processTimer then
        processTimer = setTimer(processQueue, Config.RateLimitInterval / Config.RateLimitRequests, 0)
    end
end

local function discordFetch(url, options, callback)
    table.insert(requestQueue, { url = url, options = options, callback = callback })
    if not processTimer then
        processQueue()
    end
end

local function cleanupAvatarCache()
    local now = getRealTime().timestamp
    local count = 0
    for discordId, data in pairs(avatarCache) do
        if now - data.timestamp > Config.CacheTTL then
            avatarCache[discordId] = nil
            count = count + 1
        end
    end
    if count > 0 then
        outputDebugString(string.format("[Discord] Cleaned up %d expired avatars from cache.", count))
    end
end
setTimer(cleanupAvatarCache, 600000, 0)

local function getPlayerAccountName(player)
    if not isElement(player) or getElementType(player) ~= "player" then return false end
    local account = getPlayerAccount(player)
    if not account or isGuestAccount(account) then return false end
    return getAccountName(account)
end

function generateActivationCode()
    local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    local code = ""
    for i = 1, 6 do
        local rand = math.random(1, #chars)
        code = code .. string.sub(chars, rand, rand)
    end
    return code
end

function sendDiscordDM(discordID, message, callback)
    if not discordID or not tostring(discordID):match("^%d+$") then
        outputDebugString("[Discord] Invalid Discord ID format: " .. tostring(discordID))
        if callback then callback(false, "Invalid Discord ID") end
        return
    end
    
    local createDMUrl = Config.ApiURL .. "/users/@me/channels"
    local postData = { recipient_id = tostring(discordID) }
    
    discordFetch(createDMUrl,
        {
            method = "POST",
            headers = {
                ["Authorization"] = "Bot " .. Config.BotToken,
                ["Content-Type"] = "application/json"
            },
            postData = toJSON(postData):sub(2, -2),
            queueName = "discord",
            connectionAttempts = 3,
            connectTimeout = 10000
        },
        function(responseData, info)
            if not info.success then
                outputDebugString("[Discord] Failed to create DM channel: HTTP " .. tostring(info.statusCode))
                if callback then callback(false, "API Error " .. tostring(info.statusCode)) end
                return
            end
            
            local dmData = safeFromJSON(responseData)
            if not dmData or not dmData.id then
                outputDebugString("[Discord] Invalid DM response")
                if callback then callback(false, "Invalid API Response") end
                return
            end
            
            local sendMessageUrl = Config.ApiURL .. "/channels/" .. dmData.id .. "/messages"
            local messageData = { content = message }
            
            discordFetch(sendMessageUrl,
                {
                    method = "POST",
                    headers = {
                        ["Authorization"] = "Bot " .. Config.BotToken,
                        ["Content-Type"] = "application/json"
                    },
                    postData = toJSON(messageData):sub(2, -2),
                    queueName = "discord"
                },
                function(msgResponseData, msgInfo)
                    if msgInfo.success then
                        if callback then callback(true, "Sent") end
                    else
                        outputDebugString("[Discord] Failed to send DM: " .. tostring(msgInfo.statusCode))
                        if callback then callback(false, "Send Failure") end
                    end
                end
            )
        end
    )
end

function sendActivationCode(player, discordID)
    if not isElement(player) then return false end
    
    if not discordID or discordID == "" or not tostring(discordID):match("^%d+$") then
        outputChatBox("Invalid Discord ID.", player, 255, 0, 0)
        return false
    end
    
    local accountName = getPlayerAccountName(player)
    if not accountName then
        outputChatBox("You must log in first.", player, 255, 0, 0)
        return false
    end
    
    local code = generateActivationCode()
    activation_codes[accountName] = {
        code = code,
        discordID = discordID,
        timestamp = getTickCount(),
        attempts = 0
    }
    
    outputChatBox("Sending activation code to Discord...", player, 255, 200, 0)
    
    local message = string.format([[🔐 **MTA Server Verification Code**

Your activation code is: **%s**

Please use this code in-game with the command:
`/verify %s`

⏰ This code will expire in 10 minutes.
🔒 Do not share this code with anyone.]], code, code)
    
    sendDiscordDM(discordID, message, function(success, errorMsg)
        if success then
            outputChatBox("Activation code has been sent! Check your Discord DMs.", player, 0, 255, 0)
        else
            outputChatBox("Failed to send activation code. Error: " .. tostring(errorMsg), player, 255, 0, 0)
            activation_codes[accountName] = nil
        end
    end)
    
    setTimer(function()
        if activation_codes[accountName] and activation_codes[accountName].code == code then
            activation_codes[accountName] = nil
        end
    end, Config.VerificationExpiry, 1)
    
    return true
end

function verifyActivationCode(player, code)
    if not isElement(player) then return false end
    
    local accountName = getPlayerAccountName(player)
    if not accountName then return false end
    
    local data = activation_codes[accountName]
    if not data then
        outputChatBox("No pending verification found. Use /linkdiscord first.", player, 255, 0, 0)
        return false
    end
    
    if data.attempts >= Config.MaxVerificationAttempts then
        outputChatBox("Too many failed attempts. Request a new code.", player, 255, 0, 0)
        activation_codes[accountName] = nil
        return false
    end
    
    if code ~= data.code then
        data.attempts = data.attempts + 1
        outputChatBox(string.format("Invalid code! %d attempts remaining.", Config.MaxVerificationAttempts - data.attempts), player, 255, 100, 0)
        return false
    end
    
    activation_codes[accountName] = nil
    linkDiscordAccount(player, data.discordID)
    return true
end

function isPlayerLinked(player)
    local accountName = getPlayerAccountName(player)
    return accountName and discord_data[accountName] ~= nil
end

function isPlayerDiscordAdmin(player)
    local accountName = getPlayerAccountName(player)
    if not accountName or not discord_data[accountName] then return false end
    
    local data = discord_data[accountName]
    for _, role in ipairs(data.roles or {}) do
        if Config.Roles[role.id] and Config.Roles[role.id].isAdmin then
            return true
        end
    end
    return false
end

function hasRole(player, roleName)
    local accountName = getPlayerAccountName(player)
    if not accountName or not discord_data[accountName] then return false end
    
    local data = discord_data[accountName]
    for _, role in ipairs(data.roles or {}) do
        if Config.Roles[role.id] and Config.Roles[role.id].name == roleName then
            return true
        end
    end
    return false
end

function linkDiscordAccount(player, discordID)
    local accountName = getPlayerAccountName(player)
    if not accountName then return false end

    if not discordID or not tostring(discordID):match("^%d+$") then return false end

    discordFetch(string.format("%s/guilds/%s/members/%s", Config.ApiURL, Config.GuildID, discordID),
        {
            method = "GET",
            headers = {
                ["Authorization"] = "Bot " .. Config.BotToken,
                ["Content-Type"] = "application/json"
            }
        },
        function(responseData, info)
            if not info.success then
                outputDebugString("[Discord] Fetch error: " .. tostring(info.statusCode))
                return
            end

            local memberData = safeFromJSON(responseData)
            if not memberData or not memberData.user then return end

            local userData = memberData.user
            local avatarURL = userData.avatar and string.format("https://cdn.discordapp.com/avatars/%s/%s.png", discordID, userData.avatar) or "https://cdn.discordapp.com/embed/avatars/0.png"

            local roles = {}
            for _, roleId in ipairs(memberData.roles or {}) do
                table.insert(roles, { id = roleId, name = Config.Roles[roleId] and Config.Roles[roleId].name or "Unknown Role" })
            end

            discord_data[accountName] = {
                id = discordID,
                username = userData.username,
                avatar = userData.avatar,
                avatarURL = avatarURL,
                roles = roles
            }

            setElementData(player, "discord:id", discordID)
            setElementData(player, "discord:username", userData.username)
            setElementData(player, "discord:avatar", userData.avatar or "default")
            setElementData(player, "discord:avatarURL", avatarURL)
            setElementData(player, "discord:roles", roles)
            setElementData(player, "discord:guildMember", true)

            setAccountData(getPlayerAccount(player), "discord_id", discordID)

            outputChatBox("Discord account linked successfully!", player, 0, 255, 0)
            outputDebugString(string.format("[Discord] Linked %s to %s", accountName, userData.username))
        end
    )
    return true
end

function unlinkDiscordAccount(player)
    local accountName = getPlayerAccountName(player)
    if not accountName or not discord_data[accountName] then return false end

    discord_data[accountName] = nil
    local keys = {"discord:id", "discord:username", "discord:avatar", "discord:avatarURL", "discord:roles", "discord:guildMember"}
    for _, key in ipairs(keys) do
        setElementData(player, key, key == "discord:id" and "none" or nil)
    end

    setAccountData(getPlayerAccount(player), "discord_id", nil)

    outputChatBox("Discord account unlinked.", player, 255, 200, 0)
    return true
end

addCommandHandler("linkdiscord", function(player, cmd, discordID)
    if isPlayerLinked(player) then
        outputChatBox("Already linked! Use /unlinkdiscord first.", player, 255, 200, 0)
        return
    end
    sendActivationCode(player, discordID)
end)

addCommandHandler("verify", function(player, cmd, code)
    if not code then return end
    verifyActivationCode(player, code:upper())
end)

addCommandHandler("unlinkdiscord", function(player)
    unlinkDiscordAccount(player)
end)

function getAvatar(playerOrDiscordId, callback)
    if not callback then return end

    local discordId, avatarHash
    if isElement(playerOrDiscordId) then
        discordId = getElementData(playerOrDiscordId, "discord:id")
        avatarHash = getElementData(playerOrDiscordId, "discord:avatar")
    else
        discordId = tostring(playerOrDiscordId)
    end

    if not discordId or discordId == "" or discordId == "none" then
        callback(nil)
        return
    end

    if avatarCache[discordId] then
        callback(avatarCache[discordId].data)
        return
    end

    if avatarHash and avatarHash ~= "default" then
        local url = string.format("https://cdn.discordapp.com/avatars/%s/%s.png?size=64", discordId, avatarHash)
        discordFetch(url, {}, function(data, info)
            if info.success and data and #data > 0 then
                local dataURL = "data:image/png;base64," .. encodeString("base64", data)
                avatarCache[discordId] = { data = dataURL, timestamp = getRealTime().timestamp }
                callback(dataURL)
            else
                callback(nil)
            end
        end)
        return
    end

    -- Fallback: Fetch user data if hash unknown
    discordFetch(Config.ApiURL .. "/users/" .. discordId, 
        { headers = { ["Authorization"] = "Bot " .. Config.BotToken } },
        function(responseData, info)
            if not info.success then callback(nil) return end
            local userData = safeFromJSON(responseData)
            if not userData or not userData.avatar then callback(nil) return end
            
            local url = string.format("https://cdn.discordapp.com/avatars/%s/%s.png?size=64", discordId, userData.avatar)
            discordFetch(url, {}, function(imgData, imgInfo)
                if imgInfo.success and imgData and #imgData > 0 then
                    local dataURL = "data:image/png;base64," .. encodeString("base64", imgData)
                    avatarCache[discordId] = { data = dataURL, timestamp = getRealTime().timestamp }
                    callback(dataURL)
                else
                    callback(nil)
                end
            end)
        end
    )
end

function getPlayerAvatarWithRetry(player, callback, attempts)
    attempts = attempts or 5
    local function tryFetch(remaining)
        if remaining <= 0 or not isElement(player) then
            callback(nil)
            return
        end
        local discordId = getElementData(player, "discord:id")
        if not discordId or discordId == "none" then
            setTimer(tryFetch, 1000, 1, remaining - 1)
            return
        end
        getAvatar(player, callback)
    end
    tryFetch(attempts)
end

addEvent("discord:requestAvatarBase64", true)
addEventHandler("discord:requestAvatarBase64", root, function(discordId)
    local requester = client
    if not discordId or discordId == "" then
        triggerClientEvent(requester, "discord:receiveAvatarBase64", requester, discordId, nil)
        return
    end
    getAvatar(discordId, function(dataURL)
        if isElement(requester) then
            triggerClientEvent(requester, "discord:receiveAvatarBase64", requester, discordId, dataURL)
        end
    end)
end)

function getDiscordId(playerOrId)
    if isElement(playerOrId) then return getElementData(playerOrId, "discord:id") end
    return tostring(playerOrId)
end

function addRole(playerOrId, roleId, callback)
    local discordId = getDiscordId(playerOrId)
    if not discordId or discordId == "none" then return false end
    
    discordFetch(string.format("%s/guilds/%s/members/%s/roles/%s", Config.ApiURL, Config.GuildID, discordId, roleId),
        {
            method = "PUT",
            headers = { ["Authorization"] = "Bot " .. Config.BotToken },
            postData = "{}"
        },
        function(data, info)
            local ok = info.success and (info.statusCode == 204 or info.statusCode == 200)
            if callback then callback(ok, info.statusCode) end
        end
    )
    return true
end

function removeRole(playerOrId, roleId, callback)
    local discordId = getDiscordId(playerOrId)
    if not discordId or discordId == "none" then return false end
    
    discordFetch(string.format("%s/guilds/%s/members/%s/roles/%s", Config.ApiURL, Config.GuildID, discordId, roleId),
        {
            method = "DELETE",
            headers = { ["Authorization"] = "Bot " .. Config.BotToken }
        },
        function(data, info)
            local ok = info.success and (info.statusCode == 204 or info.statusCode == 200)
            if callback then callback(ok, info.statusCode) end
        end
    )
    return true
end

function sendChannelEmbed(channelId, embedData, messageId, callback)
    local url = string.format("%s/channels/%s/messages", Config.ApiURL, channelId)
    local method = "POST"
    if messageId and messageId ~= "" then
        url = url .. "/" .. messageId
        method = "PATCH"
    end

    discordFetch(url,
        {
            method = method,
            headers = {
                ["Authorization"] = "Bot " .. Config.BotToken,
                ["Content-Type"] = "application/json"
            },
            postData = toJSON({ embeds = { embedData } }):sub(2, -2)
        },
        function(data, info)
            local ok = info.success and (info.statusCode == 200 or info.statusCode == 201)
            if callback then callback(ok, safeFromJSON(data), info.statusCode) end
        end
    )
end

function getChannelMessages(channelId, limit, callback)
    discordFetch(string.format("%s/channels/%s/messages?limit=%d", Config.ApiURL, channelId, limit or 50),
        { headers = { ["Authorization"] = "Bot " .. Config.BotToken } },
        function(data, info)
            if callback then callback(info.success, safeFromJSON(data)) end
        end
    )
end

function bulkDeleteMessages(channelId, messageIds, callback)
    if #messageIds == 1 then
        discordFetch(string.format("%s/channels/%s/messages/%s", Config.ApiURL, channelId, messageIds[1]),
            { method = "DELETE", headers = { ["Authorization"] = "Bot " .. Config.BotToken } },
            function(data, info) if callback then callback(info.success) end end
        )
        return
    end

    discordFetch(string.format("%s/channels/%s/messages/bulk-delete", Config.ApiURL, channelId),
        {
            method = "POST",
            headers = {
                ["Authorization"] = "Bot " .. Config.BotToken,
                ["Content-Type"] = "application/json"
            },
            postData = toJSON({ messages = messageIds }):sub(2, -2)
        },
        function(data, info)
            if callback then callback(info.success) end
        end
    )
end

local function loadPlayerDiscordData(player)
    local account = getPlayerAccount(player)
    if not account or isGuestAccount(account) then return end
    
    local discordID = getAccountData(account, "discord_id")
    if discordID and discordID ~= "none" then
        linkDiscordAccount(player, discordID)
    end
end

addEventHandler("onResourceStart", resourceRoot, function()
    for _, player in ipairs(getElementsByType("player")) do
        triggerClientEvent(player, "discord:updateRolesConf", player, Config.Roles)
        loadPlayerDiscordData(player)
    end
end)

addEventHandler("onPlayerJoin", root, function()
    triggerClientEvent(source, "discord:updateRolesConf", source, Config.Roles)
end)

addEventHandler("onPlayerLogin", root, function()
    loadPlayerDiscordData(source)
end)

addEvent("onAccountPlayerLogin", true)
addEventHandler("onAccountPlayerLogin", root, function()
    loadPlayerDiscordData(source)
end)

addEvent("requestDiscordAvatar", true)
addEventHandler("requestDiscordAvatar", root, function()
    local player = source
    if not isElement(player) then return end
    triggerClientEvent(player, "discord:downloadAvatar", player, {
        username = getElementData(player, "discord:username"),
        avatarURL = getElementData(player, "discord:avatarURL")
    })
end)

