Config = {}

-- API Settings
Config.BotToken = "YOUR-BOT-TOKEN-HERE"
Config.GuildID = "YOUR-GUILD-ID-HERE"
Config.ApiURL = "https://discord.com/api/v10"

-- Performance
Config.CacheTTL = 3600 -- 1 hour
Config.RateLimitRequests = 5 -- 5 requests per second
Config.RateLimitInterval = 1000 -- 1 second

-- Roles
Config.Roles = {
    ["role-id"] = { name = "Admin", isAdmin = true },
    ["role-id"] = { name = "Member", isAdmin = false },
}

-- Security
Config.VerificationExpiry = 600000 -- 10 minutes
Config.MaxVerificationAttempts = 3
