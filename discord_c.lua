local screen_w, screen_h = guiGetScreenSize()
local avatarTexture = nil
local maskShader = nil
local roles_conf = {}

local function createMaskShader()
    if maskShader and isElement(maskShader) then return true end
    local shaderCode = [[
        texture sourceTexture;
        sampler2D sourceSampler = sampler_state {
            texture = <sourceTexture>;
            MinFilter = Linear; MagFilter = Linear; MipFilter = Linear;
            AddressU = Mirror; AddressV = Mirror;
        };
        float4 maskCircle(float2 tex : TEXCOORD0) : COLOR0 {
            float4 color = tex2D(sourceSampler, tex);
            float dist = distance(tex, float2(0.5, 0.5));
            return color * (1 - smoothstep(0.48, 0.5, dist));
        }
        technique T1 { pass P1 { PixelShader = compile ps_2_0 maskCircle(); } }
    ]]
    maskShader = dxCreateShader(shaderCode)
    return maskShader ~= false
end

function downloadUserAvatar(data)
    if not data or not data.avatarURL then return end
    fetchRemote(data.avatarURL, function(responseData, errno)
        if errno == 0 and responseData then
            if avatarTexture and isElement(avatarTexture) then
                destroyElement(avatarTexture)
            end
            avatarTexture = dxCreateTexture(responseData)
        end
    end)
end
addEvent("discord:downloadAvatar", true)
addEventHandler("discord:downloadAvatar", root, downloadUserAvatar)

function drawPlayerAvatar(avatarSize, x, y, isCircular)
    if not avatarTexture or not isElement(avatarTexture) then return false end
    local size = tonumber(avatarSize) or 128
    local posX = tonumber(x) or (screen_w - size) / 2
    local posY = tonumber(y) or (screen_h - size) / 2
    
    if isCircular ~= false and createMaskShader() then
        dxSetShaderValue(maskShader, "sourceTexture", avatarTexture)
        dxDrawImage(posX, posY, size, size, maskShader)
    else
        dxDrawImage(posX, posY, size, size, avatarTexture)
    end
    return true
end

local base64AvatarCache = {} 
local pendingCallbacks = {} 

function getAvatarBase64(discordId, callbackEvent)
    if not callbackEvent or not discordId or discordId == "" then
        if callbackEvent then triggerEvent(callbackEvent, localPlayer, nil) end
        return
    end
    discordId = tostring(discordId)
    if base64AvatarCache[discordId] then
        triggerEvent(callbackEvent, localPlayer, base64AvatarCache[discordId])
        return
    end
    if not pendingCallbacks[discordId] then
        pendingCallbacks[discordId] = {}
        triggerServerEvent("discord:requestAvatarBase64", localPlayer, discordId)
    end
    table.insert(pendingCallbacks[discordId], callbackEvent)
end

function getMyAvatarBase64(callbackEvent, attempts)
    attempts = attempts or 10
    local function tryGet(remaining)
        local discordId = getElementData(localPlayer, "discord:id")
        if discordId and discordId ~= "none" then
            getAvatarBase64(discordId, callbackEvent)
        elseif remaining > 0 then
            setTimer(tryGet, 500, 1, remaining - 1)
        else
            if callbackEvent then triggerEvent(callbackEvent, localPlayer, nil) end
        end
    end
    tryGet(attempts)
end

function getAvatarByDiscordId(discordId, callbackEvent)
    getAvatarBase64(discordId, callbackEvent)
end

function getCachedAvatar(discordId)
    return discordId and base64AvatarCache[tostring(discordId)] or nil
end

addEvent("discord:receiveAvatarBase64", true)
addEventHandler("discord:receiveAvatarBase64", root, function(discordId, dataURL)
    discordId = tostring(discordId)
    if dataURL then base64AvatarCache[discordId] = dataURL end
    if pendingCallbacks[discordId] then
        for _, eventName in ipairs(pendingCallbacks[discordId]) do
            triggerEvent(eventName, localPlayer, dataURL)
        end
        pendingCallbacks[discordId] = nil
    end
end)

function isPlayerDiscordAdmin(player)
    local roles = getElementData(player, "discord:roles") or {}
    for _, role in ipairs(roles) do
        if roles_conf[role.id] and roles_conf[role.id].isAdmin then
            return true
        end
    end
    return false
end

addEvent("discord:updateRolesConf", true)
addEventHandler("discord:updateRolesConf", root, function(newRolesConf)
    roles_conf = newRolesConf
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    if avatarTexture and isElement(avatarTexture) then destroyElement(avatarTexture) end
    if maskShader and isElement(maskShader) then destroyElement(maskShader) end
end)
