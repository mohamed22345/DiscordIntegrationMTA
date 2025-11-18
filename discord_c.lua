local avatarTexture = nil
local maskShader = nil
local roles_conf = {}

function downloadFile(url)
    local tempFile = "temp_avatar.png"
    
    fetchRemote(url, function(responseData, errno)
        if errno == 0 then
            local file = fileCreate(tempFile)
            if file then
                fileWrite(file, responseData)
                fileClose(file)
                
                if avatarTexture and isElement(avatarTexture) then
                    destroyElement(avatarTexture)
                end
                avatarTexture = dxCreateTexture(tempFile)
                fileDelete(tempFile)
            end
        end
    end)
end

function downloadUserAvatar(data)
    if not maskShader then
        local shaderCode = [[
            texture sourceTexture;
            
            sampler2D sourceSampler = sampler_state {
                texture = <sourceTexture>;
                MinFilter = Linear;
                MagFilter = Linear;
                MipFilter = Linear;
                AddressU = Mirror;
                AddressV = Mirror;
            };
            
            float4 maskCircle(float2 tex : TEXCOORD0) : COLOR0 {
                float4 color = tex2D(sourceSampler, tex);
                float2 center = float2(0.5, 0.5);
                float dist = distance(tex, center);
                float circle = 1 - smoothstep(0.45, 0.5, dist);
                return color * circle;
            }
            
            technique Technique1 {
                pass Pass1 {
                    PixelShader = compile ps_2_0 maskCircle();
                }
            }
        ]]
        
        maskShader = dxCreateShader(shaderCode)
        if not maskShader then
            outputDebugString("Failed to create circle mask shader", 1)
        end
    end
    
    if data.avatarURL then
        if avatarTexture and isElement(avatarTexture) then
            destroyElement(avatarTexture)
        end
        downloadFile(data.avatarURL)
    end
end
addEvent("discord:downloadAvatar", true)
addEventHandler("discord:downloadAvatar", root, downloadDiscordAvatar)

addEvent("discord:updateRolesConf", true)
addEventHandler("discord:updateRolesConf", root, function(newRolesConf)
    roles_conf = newRolesConf
end)

function drawPlayerAvatar(avatarSize, x, y)
    local avatarSize = tonumber(avatarSize) or 128
    local avatarX = tonumber(x) or (screen_w - avatarSize) / 2
    local avatarY = tonumber(y) or (screen_h - avatarSize) / 2

    if avatarTexture and isElement(avatarTexture) and maskShader and isElement(maskShader) then
        dxSetShaderValue(maskShader, "sourceTexture", avatarTexture)
        dxDrawImage(avatarX, avatarY, avatarSize, avatarSize, maskShader)
    end
end

function isPlayerDiscordAdmin(player)
    local roles = fromJSON(getElementData(player, "discord:roles") or "[]")
    for _, role in ipairs(roles) do
        if roles_conf[role.id] and roles_conf[role.id].isAdmin then
            return true
        end
    end
    return false
end