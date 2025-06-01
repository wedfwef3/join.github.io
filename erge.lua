if not game:IsLoaded() then game.Loaded:Wait() task.wait(5) end

local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local WEBHOOK_URL = "https://discord.com/api/webhooks/1378772687652126841/GyLa8hEeYb8mwmOcQJRBhiHKpCkDETBbT69kHxIScsRVFxV9eYNuH7CD7StH6ngG_Dnn"

local currentJobId = game.JobId
local currentPlaceId = game.PlaceId

local function sendToDiscord(msg)
    local payload = HttpService:JSONEncode({content = msg})
    pcall(function()
        request({
            Url = WEBHOOK_URL,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = payload
        })
    end)
end

local function getShopStock(GuiName, Data, ItemNameField, RarityField)
    local Items, Rarities = {}, {}
    for name, item in pairs(Data) do
        if item.DisplayInShop ~= false then
            table.insert(Items, name)
            Rarities[name] = item[RarityField] or "Unknown"
        end
    end
    local ShopGui = PlayerGui:FindFirstChild(GuiName, true)
    local msg = {}
    if ShopGui and ShopGui:FindFirstChild("Frame", true) then
        local ScrollingFrame = ShopGui.Frame:FindFirstChild("ScrollingFrame", true)
        if ScrollingFrame then
            for _, frame in pairs(ScrollingFrame:GetChildren()) do
                if frame:IsA("Frame") and frame.Name ~= "ItemPadding" then
                    local MainFrame = frame:FindFirstChild("Main_Frame")
                    local StockText = MainFrame and MainFrame:FindFirstChild("Stock_Text")
                    local ItemText = MainFrame and (MainFrame:FindFirstChild("Seed_Text") or MainFrame:FindFirstChild("Gear_Text") or MainFrame:FindFirstChild("Item_Name_Text"))
                    if StockText and ItemText then
                        local itemName = ItemText.Text:gsub(" Seed$", "")
                        if table.find(Items, itemName) then
                            table.insert(msg, string.format("%s (%s): %s", itemName, Rarities[itemName], StockText.Text:match("%d+") or "?"))
                        end
                    end
                end
            end
        end
    end
    return msg
end

local function getEggStock(PetEggData)
    local Eggs = {}
    local EggLoc = workspace:FindFirstChild("NPCS", true)
        and workspace.NPCS:FindFirstChild("Pet Stand", true)
        and workspace.NPCS["Pet Stand"]:FindFirstChild("EggLocations", true)
    if EggLoc then
        for _, child in pairs(EggLoc:GetChildren()) do
            if PetEggData[child.Name] then
                Eggs[child.Name] = (Eggs[child.Name] or 0) + 1
            end
        end
    end
    local result = {}
    for k, v in pairs(Eggs) do
        table.insert(result, k..": "..v)
    end
    return result
end

local function getCosmetics()
    local out = {}
    local cShop = PlayerGui:FindFirstChild("CosmeticShop_UI", true)
    if not cShop then return out end
    local function grab(segment)
        if not segment then return end
        for _, frame in pairs(segment:GetChildren()) do
            local main = frame:FindFirstChild("Main")
            local stock = main and main:FindFirstChild("Stock") and main.Stock:FindFirstChild("STOCK_TEXT")
            if stock then
                table.insert(out, frame.Name .. ": " .. (stock.Text:match("%d+") or "0"))
            end
        end
    end
    local cf = cShop.CosmeticShop.Main.Holder.Shop.ContentFrame
    grab(cf.TopSegment)
    grab(cf.BottomSegment)
    return out
end

local function weatherHook()
    local GameEvents = ReplicatedStorage:FindFirstChild("GameEvents")
    if not GameEvents then return end
    GameEvents.WeatherEventStarted.OnClientEvent:Connect(function(EventType, EventDuration)
        local joinLink = string.format("https://www.roblox.com/games/%d?jobId=%s", currentPlaceId, currentJobId)
        local info = string.format(
            ":cloud: **Weather Event:** %s for %ds\nGame ID: `%s`\nJob ID: `%s`\n[Join this server](%s)",
            EventType, EventDuration, tostring(currentPlaceId), tostring(currentJobId), joinLink
        )
        sendToDiscord(info)
    end)
end

local function report()
    local SeedData = require(ReplicatedStorage.Data.SeedData)
    local GearData = require(ReplicatedStorage.Data.GearData)
    local PetEggData = require(ReplicatedStorage.Data.PetEggData)
    local HoneyData = require(ReplicatedStorage.Data.HoneyEventShopData)
    local joinLink = string.format("https://www.roblox.com/games/%d?jobId=%s", currentPlaceId, currentJobId)
    local msg = {
        ":information_source: **Server Info**\nGame ID: `" .. tostring(currentPlaceId) .. "`\nJob ID: `" .. tostring(currentJobId) .. "`\n[Join this server]("..joinLink..")",
        ":seedling: **Seed Shop**\n" .. table.concat(getShopStock("Seed_Shop", SeedData, "SeedName", "SeedRarity"), "\n"),
        ":crossed_swords: **Gear Shop**\n" .. table.concat(getShopStock("Gear_Shop", GearData, "GearName", "GearRarity"), "\n"),
        ":honey_pot: **Honey Shop**\n" .. table.concat(getShopStock("HoneyEventShop_UI", HoneyData, "HoneyName", "SeedRarity"), "\n"),
        ":egg: **Egg Stand**\n" .. table.concat(getEggStock(PetEggData), "\n"),
        ":lipstick: **Cosmetic Shop**\n" .. table.concat(getCosmetics(), "\n")
    }
    sendToDiscord(table.concat(msg, "\n\n"))
end

task.spawn(function()
    while true do
        report()
        task.wait(300)
    end
end)

weatherHook()

local function joinAnyServer()
    local Http = game:GetService("HttpService")
    local placeId = game.PlaceId
    local cursor = ""
    local foundId = nil
    local function fetchServers()
        local url = string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100", placeId)
        if cursor ~= "" then
            url = url.."&cursor="..cursor
        end
        local response = game:HttpGet(url)
        local data = Http:JSONDecode(response)
        for _, server in ipairs(data.data or {}) do
            if not server.full then
                foundId = server.id
                return true
            end
        end
        cursor = data.nextPageCursor or ""
        return cursor ~= "" and not foundId
    end
    for i = 1,3 do
        if fetchServers() or foundId then break end
    end
    if foundId then
        TeleportService:TeleportToPlaceInstance(placeId, foundId, Player)
    end
end

local retrying = false
local function startRetryJoin()
    if retrying then return end
    retrying = true
    task.spawn(function()
        while retrying do
            local lastJob = game.JobId
            joinAnyServer()
            task.wait(3)
            if not Players.LocalPlayer or not game:IsLoaded() then break end
            if game.JobId ~= lastJob then
                retrying = false
                -- Update new job/place ID, send notification ONCE when a new server is joined
                currentJobId = game.JobId
                currentPlaceId = game.PlaceId
                local joinLink = string.format("https://www.roblox.com/games/%d?jobId=%s", currentPlaceId, currentJobId)
                sendToDiscord(":rocket: **Joined new server!**\nGame ID: `"..currentPlaceId.."`\nJob ID: `"..currentJobId.."`\n[Join this server]("..joinLink..")")
                break
            end
        end
    end)
end

task.spawn(function()
    task.wait(5)
    startRetryJoin()
end)
