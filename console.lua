
-- console.lua

-- Implements things related to console commands





function HandleConsoleClear(Split)
	if (#Split == 1) then
		return true, "Usage: clear <PlayerName>"
    end
    
    local InventoryCleared = false;
    local ClearInventory = function(Player)
        if (Player:GetName() == Split[2]) then
            Player:GetInventory():Clear()
            InventoryCleared = true
        end
    end

    cRoot:Get():FindAndDoWithPlayer(Split[2], ClearInventory);
    if (InventoryCleared) then
        return true, "You cleared the inventory of " .. Split[2]
    else
        return true, "Player not found" 
    end
end





function HandleConsoleKick(Split)
	if (#Split < 2) then
		return true, "Usage: kick <PlayerName> [<Reason>]"
	end

	local Reason = cChatColor.Red .. "You have been kicked."
	if (#Split > 2) then
		Reason = table.concat(Split, " ", 3)
	end

	if (KickPlayer(Split[2], Reason)) then
		return true
	end

	return true, "Cannot find player " .. Split[2]
end





function HandleConsoleKill(Split)
	-- Check the params:
	if (#Split == 1) then
		return true, "Usage: kill <PlayerName>"
	end

	-- Kill the player:
	local HasKilled = false;
	cRoot:Get():FindAndDoWithPlayer(Split[2],
		function(Player)
			if (Player:GetName() == Split[2]) then
				Player:TakeDamage(dtAdmin, nil, 1000, 1000, 0)
				HasKilled = true
			end
		end
	);
	
	-- Report success or failure:
	if (HasKilled) then
		return true, "Player " .. Split[2] .. " is killed" 
	else
		return true, "Player not found" 
	end
end






function HandleConsoleList(Split)
	local PlayerTable = {}

	cRoot:Get():ForEachPlayer(
		function(a_Player)
			table.insert(PlayerTable, a_Player:GetName())
		end
	)
	table.sort(PlayerTable)

	local Out = "Players (" .. #PlayerTable .. "): " .. table.concat(PlayerTable, ", ")
	return true, Out
end





function HandleConsoleListGroups(a_Split)
	if (a_Split[3] ~= nil) then
		-- Too many params:
		return true, "Too many parameters. Usage: listgroups [<RankName>]"
	end
	
	-- If no params are given, list all groups that the manager knows:
	local RankName = a_Split[2]
	if (RankName == nil) then
		-- Get all the groups:
		local Groups = cRankManager:GetAllGroups()

		-- Output the groups, concatenated to a string:
		local Out = "Available groups:\n"
		Out = Out .. table.concat(Groups, ", ")
		return true, Out
	end
	
	-- A rank name is given, list the groups in that rank:
	local Groups = cRankManager:GetRankGroups(RankName)
	local Out = "Groups in rank " .. RankName .. ":\n" .. table.concat(Groups, ", ")
	return true, Out
end





function HandleConsoleListRanks(Split)
	-- Get all the groups:
	local Groups = cRankManager:GetAllRanks()

	-- Output the groups, concatenated to a string:
	local Out = "Available ranks:\n"
	Out = Out .. table.concat(Groups, ", ")
	return true, Out
end





function HandleConsoleNumChunks(Split)
	-- List each world's chunk count into a table, sum the total chunk count:
	local Output = {}
	local Total = 0
	cRoot:Get():ForEachWorld(
		function(a_World)
			table.insert(Output, a_World:GetName() .. ": " .. a_World:GetNumChunks() .. " chunks")
			Total = Total + a_World:GetNumChunks()
		end
	)
	table.sort(Output)

	-- Return the complete report:
	return true, table.concat(Output, "\n") .. "\nTotal: " .. Total .. " chunks\n"
end





function HandleConsolePlayers(Split)
	local PlayersInWorlds = {}    -- "WorldName" => [players array]
	local AddToTable = function(Player)
		local WorldName = Player:GetWorld():GetName()
		if (PlayersInWorlds[WorldName] == nil) then
			PlayersInWorlds[WorldName] = {}
		end
		table.insert(PlayersInWorlds[WorldName], Player:GetName() .. " @ " ..  Player:GetIP())
	end

	cRoot:Get():ForEachPlayer(AddToTable)

	local Out = ""
	for WorldName, Players in pairs(PlayersInWorlds) do
		Out = Out .. "World " .. WorldName .. ":\n"
		for i, PlayerName in ipairs(Players) do
			Out = Out .. "  " .. PlayerName .. "\n"
		end
	end

	return true, Out
end





function HandleConsolePlugins(Split)
	local PluginManager = cRoot:Get():GetPluginManager()
	local PluginList = PluginManager:GetAllPlugins()

	local PluginTable = {}
	for k, Plugin in pairs(PluginList) do
		if Plugin then
			table.insert(PluginTable, Plugin:GetName())
		end
	end
	table.sort(PluginTable)

	local Out = "There are " .. #PluginTable .. " loaded plugins: " .. table.concat(PluginTable, ", ")
	return true, Out
end





function HandleConsoleRank(a_Split)
	-- Check parameters:
	if ((a_Split[2] == nil) or (a_Split[4] ~= nil)) then
		-- Not enough or too many parameters
		return true, "Usage: rank <Player> [<Rank>]"
	end
	
	-- Translate the PlayerName to a UUID:
	local PlayerName = a_Split[2]
	local PlayerUUID
	if (cRoot:Get():GetServer():ShouldAuthenticate()) then
		-- The server is in online-mode, get the UUID from Mojang servers and check for validity:
		PlayerUUID = cMojangAPI:GetUUIDFromPlayerName(PlayerName)
		if ((PlayerUUID == nil) or (string.len(PlayerUUID) ~= 32)) then
			return true, "There is no such player: " .. PlayerName
		end
	else
		-- The server is in offline mode, generate an offline-mode UUID, no validity check is possible:
		PlayerUUID = cClientHandle:GenerateOfflineUUID(PlayerName)
	end
	
	-- View the player's rank, if requested:
	if (a_Split[3] == nil) then
		-- "/rank <PlayerName>" usage, display the rank:
		local CurrRank = cRankManager:GetPlayerRankName(PlayerUUID)
		if (CurrRank == "") then
			return true, "The player has no rank assigned to them."
		else
			return true, "The player's rank is " .. CurrRank
		end
	end

	-- Change the player's rank:
	local NewRank = a_Split[3]
	if not(cRankManager:RankExists(NewRank)) then
		return true, "The specified rank does not exist!"
	end
	cRankManager:SetPlayerRank(PlayerUUID, PlayerName, NewRank)

	-- Update all players in the game of the given name and let them know:
	cRoot:Get():ForEachPlayer(
		function(a_CBPlayer)
			if (a_CBPlayer:GetName() == PlayerName) then
				a_CBPlayer:SendMessageInfo("You were assigned the rank " .. NewRank .. " by the server console")
				a_CBPlayer:LoadRank()
			end
		end
	)
	return true, "Player " .. PlayerName .. " is now in rank " .. NewRank
end





function HandleConsoleSaveAll(Split)
	cRoot:Get():SaveAllChunks()
	return true
end





function HandleConsoleSay(a_Split)
	cRoot:Get():BroadcastChat(cChatColor.Gold .. "[SERVER] " .. cChatColor.Yellow .. table.concat(a_Split, " ", 2))
	return true
end






function HandleConsoleTeleport(Split)
	local TeleportToCoords = function(Player)
		if (Player:GetName() == Split[2]) then
			IsPlayerOnline = true
			Player:TeleportToCoords(Split[3], Split[4], Split[5])
		end
	end
	
	local IsPlayerOnline = false;
	local FirstPlayerOnline = false;
	local GetPlayerCoords = function(Player)
		if (Player:GetName() == Split[3]) then
			PosX = Player:GetPosX()
			PosY = Player:GetPosY()
			PosZ = Player:GetPosZ()
			FirstPlayerOnline = true
		end
	end
	
	local TeleportToPlayer = function(Player)
		if (Player:GetName() == Split[2]) then
		    Player:TeleportToCoords(PosX, PosY, PosZ)
			IsPlayerOnline = true
		end
	end

	if (#Split == 3) then
		cRoot:Get():FindAndDoWithPlayer(Split[3], GetPlayerCoords);
		if (FirstPlayerOnline) then
			cRoot:Get():FindAndDoWithPlayer(Split[2], TeleportToPlayer);
			if (IsPlayerOnline) then
				return true, "Teleported " .. Split[2] .." to " .. Split[3]
			end
		else
				return true, "Player " .. Split[3] .." not found"
		end
	elseif (#Split == 5) then
		cRoot:Get():FindAndDoWithPlayer(Split[2], TeleportToCoords);
		if (IsPlayerOnline) then
			return true, "You teleported " .. Split[2] .. " to [X:" .. Split[3] .. " Y:" .. Split[4] .. " Z:" .. Split[5] .. "]"
		else
			return true, "Player not found"
		end
	else
		return true, "Usage: tp <PlayerName> <ToPlayerName> or tp <PlayerName> <X> <Y> <Z>"
	end
end




function HandleConsoleUnload(Split)
	local UnloadChunks = function(World)
		World:QueueUnloadUnusedChunks()
	end

	local Out = "Num loaded chunks before: " .. cRoot:Get():GetTotalChunkCount() .. "\n"
	cRoot:Get():ForEachWorld(UnloadChunks)
	Out = Out .. "Num loaded chunks after: " .. cRoot:Get():GetTotalChunkCount()
	return true, Out
end






function HandleConsoleUnrank(a_Split)
	-- Check params:
	if ((a_Split[2] == nil) or (a_Split[3] ~= nil)) then
		-- Too few or too many parameters:
		return true, "Usage: unrank <PlayerName>"
	end

	-- Translate the PlayerName to a UUID:
	local PlayerName = a_Split[2]
	local PlayerUUID
	if (cRoot:Get():GetServer():ShouldAuthenticate()) then
		-- The server is in online-mode, get the UUID from Mojang servers and check for validity:
		PlayerUUID = cMojangAPI:GetUUIDFromPlayerName(PlayerName)
		if ((PlayerUUID == nil) or (string.len(PlayerUUID) ~= 32)) then
			return true, "There is no such player: " .. PlayerName
		end
	else
		-- The server is in offline mode, generate an offline-mode UUID, no validity check is possible:
		PlayerUUID = cClientHandle:GenerateOfflineUUID(PlayerName)
	end
	
	-- Unrank the player:
	cRankManager:RemovePlayerRank(PlayerUUID)

	-- Update all players in the game of the given name and let them know:
	cRoot:Get():ForEachPlayer(
		function(a_CBPlayer)
			if (a_CBPlayer:GetName() == PlayerName) then
				a_CBPlayer:SendMessageInfo("You were unranked by the server console")
				a_CBPlayer:LoadRank()
			end
		end
	)
	return true, "Player " .. PlayerName .. " is now in the default rank."
end
