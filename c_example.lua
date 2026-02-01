local panelX, panelY, panelWidth, panelHeight
local isPanelOpen = false

local function renderDiscordPanel()
    if not isPanelOpen then return end
    
    dxDrawRectangle(panelX, panelY, panelWidth, panelHeight, tocolor(20, 20, 25, 230))
    dxDrawRectangle(panelX, panelY, panelWidth, 30, tocolor(115, 40, 192, 255)) -- Server Theme Color #7328c0
    
    dxDrawText("Discord Integration Info", panelX, panelY, panelX + panelWidth, panelY + 30, tocolor(255, 255, 255), 1, "default-bold", "center", "center")
    
    local username = getElementData(localPlayer, "discord:username") or "Connecting..."
    local discordId = getElementData(localPlayer, "discord:id") or "N/A"
    
    dxDrawText("Username:", panelX + 10, panelY + 45, nil, nil, tocolor(200, 200, 200), 1, "default")
    dxDrawText(username, panelX + 10, panelY + 60, nil, nil, tocolor(255, 255, 255), 1, "default-bold")
    
    dxDrawText("Discord ID:", panelX + 10, panelY + 85, nil, nil, tocolor(200, 200, 200), 1, "default")
    dxDrawText(discordId, panelX + 10, panelY + 100, nil, nil, tocolor(255, 255, 255), 1, "default")
    
    -- Draw Avatar (Circular)
    drawPlayerAvatar(64, panelX + panelWidth - 74, panelY + 45, true)
    
    dxDrawText("Press /discorduser to toggle", panelX, panelY + panelHeight - 20, panelX + panelWidth, nil, tocolor(150, 150, 150), 0.8, "default", "center")
end

addCommandHandler("discorduser", function()
    if isPanelOpen then
        removeEventHandler("onClientRender", root, renderDiscordPanel)
        isPanelOpen = false
        return
    end

    triggerServerEvent("requestDiscordAvatar", localPlayer)
    
    local screenWidth, screenHeight = guiGetScreenSize()
    panelWidth, panelHeight = 320, 160
    panelX, panelY = (screenWidth - panelWidth) / 2, (screenHeight - panelHeight) / 2
    
    isPanelOpen = true
    addEventHandler("onClientRender", root, renderDiscordPanel)
    
    -- Auto-close after 15 seconds
    setTimer(function()
        if isPanelOpen then
            removeEventHandler("onClientRender", root, renderDiscordPanel)
            isPanelOpen = false
        end
    end, 15000, 1)
end)