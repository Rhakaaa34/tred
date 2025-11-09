local rS = game:GetService('ReplicatedStorage')
local players = game:GetService('Players')
local pack = rS.Packages._Index['sleitnick_net@0.2.0'].net 
local tradeRequest = pack['RF/InitiateTrade']
local notification = pack['RE/TextNotification']
local satanUi = loadstring(game:HttpGet('https://raw.githubusercontent.com/dravenox/roblox/refs/heads/main/WindUi.lua'))()
local tier = require(rS.Shared.TierUtility)

local selectedUser, selectedUserId, selectedType, selectedRarity
local tradeAmount, autoTrade, current = 1, false, 0
local waitingForResponse = false
local tradeDelay = 3 

local function log(bool: boolean, title: string, message: string) 
		pcall(function()
				satanUi:Notify({
						Title = title,
						Content = message,
						Icon = bool and 'check' or 'x',
						Duration = 3 
				})
		end)
end 

local function getInv()
		local rslt = {}
		for _, item in pairs(require(rS.Packages.Replion).Client:GetReplion('Data'):GetExpect('Inventory').Items) do 
				table.insert(rslt, { id = item.Id, uuid = item.UUID, meta = item.Metadata })
		end 
		return rslt
end 

local function getInfo(items)
		for _, item in pairs(require(rS.Items)) do 
				if item.Data and item.Data.Id == items then
						local itemType = item.Data.Type 
						local rarities = 'Not Selected.'
						if itemType == 'Fish' then
								local chance = item.Probability and item.Probability.Chance or 0 
								rarities = tier:GetTierFromRarity(chance).Name or 'Unknown Rarities.'
						else 
								rarities = 'Unknown Rarities.'
						end
						return { 
								name = item.Data.Name,
								type = itemType,
								rarities = rarities
						}
				end 
		end 
end

local function trade(uid, uuid)
    if not uid or not uuid then return false end
    local ok, err = pcall(function()
        return tradeRequest:InvokeServer(uid, uuid)
    end)
    return ok, err
end

local window = satanUi:CreateWindow({
    Title = 'Satan Script X Rakhaa',
    Icon = 'terminal',
    Author = 'SatanScript',
    Size = UDim2.fromOffset(320, 280),
    Transparent = true,
    Theme = 'Dark',
    Resizable = true,
    SideBarWidth = 180,
    BackgroundImageTransparency = 0.42,
    HideSearchBar = true,
    ScrollBarEnabled = false
})

local _ttab = { 
		['Trade Tab'] = window:Tab({ Title = 'Trade Options', Icon = 'check', Locked = false }) 
}

local _tsec = {
		['Trade Section'] = _ttab['Trade Tab']:Section({ Title = 'Trade Options', Icon = 'check', Opened = false })
}

local _tpar = {
		['Trade Status'] = _tsec['Trade Section']:Paragraph({ Title = 'Trade Status', Desc = 'User: Not Selected\nType: Not Selected\nStatus: Idle'}),
		['Trade Progress'] =  _tsec['Trade Section']:Paragraph({ Title = 'Trade Progress', Desc = '0 / 0'})
}

local function updateProgress()
    local ratio = current / tradeAmount
    local color = ratio == 0 and 'rgb(255,0,0)' or ratio < 1 and 'rgb(255,255,0)' or 'rgb(0,255,0)'
    _tpar['Trade Progress']:SetDesc(string.format("<font color='%s'>%d / %d</font>", color, current, tradeAmount))
end

_tsec['Trade Section']:Space()

local selectUser = _tsec['Trade Section']:Dropdown({
		Title = 'Select User',
		Values = {},
		Callback = function(choice)
				local plrs = players:FindFirstChild(choice)
				if plrs then
						selectedUser = plrs.Name 
						selectedUserId = plrs.UserId 
						_tpar['Trade Status']:SetDesc(('• User: %s\n• ItemType: %s\n• Status: Ready'):format(selectedUser, selectedType or 'Not Selected'))
				end 
		end
})

_tsec['Trade Section']:Button({
    Title = 'Refresh User List',
    Callback = function()
        local list = {}
        for _, p in ipairs(players:GetPlayers()) do
            if p ~= players.LocalPlayer then table.insert(list, p.Name) end
        end
        selectUser:Refresh(list)
        log(true, 'SatanScript', 'User List Has Been Refreshed.')
    end
})

_tsec['Trade Section']:Space()

local rarityDropdown

local selectType = _tsec['Trade Section']:Dropdown({
    Title = 'Item Type',
    Values = { 'Fish', 'Enchant Stones' },
    Callback = function(choice)
        selectedType = choice
        _tpar['Trade Status']:SetDesc(('• User: %s\n• ItemType: %s\n• Status: Ready'):format(selectedUser or 'None', selectedType))
        if choice == 'Fish' then
            rarityDropdown:Unlock()
        else
            rarityDropdown:Lock()
            selectedRarity = nil
        end
    end
})

rarityDropdown = _tsec['Trade Section']:Dropdown({
    Title = 'Select Rarities',
    Values = { 'Common', 'Uncommon', 'Rare', 'Epic', 'Legendary', 'Mythic', 'Secret' },
    Locked = true,
    Callback = function(choice)
        selectedRarity = choice
        log(true, 'SatanScript', 'Rarity Selected ' .. choice)
    end
})

_tsec['Trade Section']:Space()

_tsec['Trade Section']:Input({
    Title = 'Trade Amount',
    Value = '1',
    Callback = function(v)
        tradeAmount = tonumber(v) or 1
        updateProgress()
    end
})

_tsec['Trade Section']:Input({
    Title = 'Trade Delay',
    Value = '3',
    Callback = function(v)
        tradeDelay = tonumber(v) or 3
    end
})

_tsec['Trade Section']:Toggle({
    Title = 'Start Auto Trade',
    type = 'Checkbox',
    Callback = function(state)
        autoTrade = state
        if not state then
            log(true, 'SatanScript', 'Auto Trade Stopped.')
            waitingForResponse = false
            return
        end
        if not selectedUserId or not selectedType then
            log(false, 'SatanScript', 'Select User And Item Type First!')
            return
        end
        if selectedType == 'Fish' and not selectedRarity then
            log(false, 'SatanScript', 'Select Fish Rarities First!')
            return
        end
        current = 0
        updateProgress()
        _tpar['Trade Status']:SetDesc(('• User: %s\n• ItemType: %s\n• Status: Running'):format(selectedUser, selectedType))
        task.spawn(function()
            while autoTrade and current < tradeAmount do
                local inv = getInv()
                local found
                for _, item in ipairs(inv) do
                    local info = getInfo(item.id)
                    if info and info.type == selectedType then
                        if selectedType == 'Fish' then
                            print('[SatanLog] => ( Fish :', info.name, '| Rarity :', info.rarities, '| Target :', selectedRarity, ' )')
                            if info.rarities == selectedRarity then
                                found = item
                                break
                            end
                        else
                            found = item
                            break
                        end
                    end
                end
                if not found then
                    log(false, 'SatanScript', 'No Matching Item Found?!')
                    autoTrade = false
                    break
                end
                local target = players:GetPlayerByUserId(selectedUserId)
                local lp = players.LocalPlayer
                if target and target.Character and lp.Character then
                    local h1 = lp.Character:FindFirstChild('HumanoidRootPart')
                    local h2 = target.Character:FindFirstChild('HumanoidRootPart')
                    if h1 and h2 and (h1.Position - h2.Position).Magnitude > 10 then
                        h1.CFrame = h2.CFrame + Vector3.new(0, 3, 0)
                        task.wait(0.5)
                    end
                end
                print('[SatanLog] => ( Sending Trade Request )')
                waitingForResponse = true
                trade(selectedUserId, found.uuid)
                task.wait(tradeDelay)
                local timeout = 0
                while waitingForResponse and timeout < 200 do
                    task.wait(0.1)
                    timeout = timeout + 1
                end
                if waitingForResponse then
                    log(false, 'SatanScript', 'Are U Lagging?!')
                    waitingForResponse = false
                end
                task.wait(1)
            end
            if current >= tradeAmount then
                log(true, 'SatanScript', 'Progress Finished!')
                _tpar['Trade Status']:SetDesc(('• User: %s\n• ItemType: %s\n• Status: Successfully!'):format(selectedUser, selectedType))
            end
        end)
    end
})

notification.OnClientEvent:Connect(function(packet)
    if not packet or type(packet) ~= 'table' then return end
    local text = packet.Text
    if not text then return end
    if text == 'Trade completed!' then
        print('[SatanLog] => ( Trade Success )')
        current = current + 1
        updateProgress()
        waitingForResponse = false
        log(true, 'SatanScript', string.format('Trade %d/%d Completed!', current, tradeAmount))
    end
    if text == 'Trade was declined' then
        print('[SatanLog] => ( Trade Declined?! )')
        waitingForResponse = false
        log(false, 'SatanLog', 'Trade Declined, Are You Lagging?!')
    end
end)
