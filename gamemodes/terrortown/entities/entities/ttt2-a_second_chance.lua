if SERVER then
	AddCSLuaFile()

	resource.AddFile("vgui/ttt/icon_asc.vmt")

	util.AddNetworkString("ASCBuyed")
	util.AddNetworkString("ASCKill")
	util.AddNetworkString("ASCError")
	util.AddNetworkString("ASCRespawn")
	util.AddNetworkString("ASCRespawned")
end

local detectiveCanUse = CreateConVar("ttt_secondchance_det", 1, {FCVAR_SERVER_CAN_EXECUTE, FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Should the Detective be able to use the Second Chance.")
local traitorCanUse = CreateConVar("ttt_secondchance_tr", 1, {FCVAR_SERVER_CAN_EXECUTE, FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Should the Traitor be able to use the Second Chance.")

EQUIP_ASC = (GenerateNewEquipmentID and GenerateNewEquipmentID()) or 8

local ASecondChance = {
	id = EQUIP_ASC,
	loadout = false,
	type = "item_passive",
	material = "vgui/ttt/icon_asc",
	name = "A Second Chance",
	desc = "Life for a second time but only with a given Chance. \nYour Chance will change per kill.\nIt also works if the round should end.",
	hud = true
}

if detectiveCanUse:GetBool() then
	table.insert(EquipmentItems[ROLE_DETECTIVE], ASecondChance)
end

if traitorCanUse:GetBool() then
	table.insert(EquipmentItems[ROLE_TRAITOR], ASecondChance)
end

hook.Add("Initialize", "TTTASCCheckForTTTVersion", function()
	if CLIENT then
		local material = Material("vgui/ttt/perks/hud_asc.png")

		if not TTT2 then
			-- feel for to use this function for your own perk, but please credit Zaratusa
			-- your perk needs a "hud = true" in the table, to work properly
			local defaultY = ScrH() * 0.5 + 20

			local function getYCoordinate(currentPerkID)
				local amount, i, perk = 0, 1

				while i < currentPerkID do
					local role = LocalPlayer():GetRole()

					if role == ROLE_INNOCENT then --he gets it in a special way
						if GetEquipmentItem(ROLE_TRAITOR, i) then
							role = ROLE_TRAITOR -- Temp fix what if a perk is just for Detective
						elseif GetEquipmentItem(ROLE_DETECTIVE, i) then
							role = ROLE_DETECTIVE
						end
					end

					perk = GetEquipmentItem(role, i)

					if istable(perk) and perk.hud and LocalPlayer():HasEquipmentItem(perk.id) then
						amount = amount + 1
					end

					i = i * 2
				end

				return defaultY - 80 * amount
			end

			local yCoordinate = defaultY

			-- best performance, but the has about 0.5 seconds delay to the HasEquipmentItem() function
			hook.Add("TTTBoughtItem", "TTTASC2", function()
				if LocalPlayer():HasEquipmentItem(EQUIP_ASC) then
					yCoordinate = getYCoordinate(EQUIP_ASC)
				end
			end)

			hook.Add("HUDPaint", "TTTASC", function()
				if LocalPlayer():HasEquipmentItem(EQUIP_ASC) then
					surface.SetMaterial(material)
					surface.SetDrawColor(255, 255, 255, 255)
					surface.DrawTexturedRect(20, yCoordinate, 64, 64)
				end
			end)
		else
			AddHUDItem(EQUIP_ASC, material)
		end
	end
end)

if SERVER then
	hook.Add("TTTOrderedEquipment", "TTTASC", function(ply, id, is_item)
		if id == EQUIP_ASC then
			ply.shouldasc = true

			if ply:GetTraitor() or (ply.IsEvil and ply:IsEvil()) then -- just normal Ts for TTT2
				ply.SecondChanceChance = math.random(25, 35)
			elseif ply:GetRole() == ROLE_DETECTIVE then
				ply.SecondChanceChance = math.random(40, 60)
			else
				ply.SecondChanceChance = math.random(20, 40)
			end

			for _, v in ipairs(ply.kills) do
				local victim = TTT2 and player.GetBySteamID64(v) or player.GetBySteamID(v)

				if IsValid(victim) then
					if not TTT2 then
						if (ply:GetTraitor() or ply.IsEvil and ply:IsEvil()) and ((victim:GetRole() == ROLE_INNOCENT or victim:GetRole() == ROLE_DETECTIVE) or (victim.GetGood and (victim:GetGood() or victim:IsNeutral()))) then
							ply.SecondChanceChance = math.Clamp(ply.SecondChanceChance + math.random(10, 20), 0, 99)
						elseif (ply:GetRole() == ROLE_DETECTIVE or ply:GetRole() == ROLE_INNOCENT or (ply.GetGood and ply:GetGood())) and (victim:GetTraitor() or (victim.IsEvil and (victim:IsEvil() or victim:IsNeutral()))) then
							ply.SecondChanceChance = math.Clamp(ply.SecondChanceChance + math.random(20, 30), 0, 99)
						elseif ply.IsNeutral and ply:IsNeutral() and (victim:GetGood() or victim:GetEvil()) then
							ply.SecondChanceChance = math.Clamp(ply.SecondChanceChance + math.random(15, 25), 0, 99)
						end
					elseif not victim:IsInTeam(ply) then
						if ply:GetTraitor() then -- just normal Ts
							ply.SecondChanceChance = math.Clamp(ply.SecondChanceChance + math.random(10, 20), 0, 99)
						elseif ply:HasTeam(TEAM_INNOCENT) then
							ply.SecondChanceChance = math.Clamp(ply.SecondChanceChance + math.random(20, 30), 0, 99)
						else
							ply.SecondChanceChance = math.Clamp(ply.SecondChanceChance + math.random(15, 25), 0, 99)
						end
					end
				end
			end

			net.Start("ASCBuyed")
			net.WriteInt(ply.SecondChanceChance, 8)
			net.Send(ply)
		end
	end)

	local plymeta = FindMetaTable("Player")

	function SecondChance(victim, inflictor, attacker)
		local SecondChanceRandom = math.random(1, 100)
		local PlayerChance = math.Clamp(math.Round(victim.SecondChanceChance, 0), 0, 99)

		if victim.shouldasc == true and SecondChanceRandom <= PlayerChance then
			victim.NOWINASC = true
			victim.ASCTimeLeft = CurTime() + 10

			net.Start("ASCRespawn")
			net.WriteBit(true)
			net.Send(victim)
		elseif victim.shouldasc == true and SecondChanceRandom > PlayerChance then
			victim.shouldasc = false

			net.Start("ASCRespawn")
			net.WriteFloat(victim.ASCTimeLeft)
			net.WriteBool(false)
			net.Send(victim)
		end
	end

	local function ASCThink()
		local t = CurTime()

		for _, ply in ipairs(player.GetAll()) do
			if ply.NOWINASC and ply.ASCTimeLeft <= t + 8 then
				ply.ASCCanRespawn = true

				if ply.ASCTimeLeft <= t then
					ply:ASCHandleRespawn(true)
				end
			end
		end
	end

	hook.Add("Think", "ASCThink", ASCThink)

	local Positions = {}

	-- Populate Around Player
	for i = 0, 360, 22.5 do
		table.insert(Positions, Vector(math.cos(i), math.sin(i), 0))
	end

	table.insert(Positions, Vector(0, 0, 1)) -- Populate Above Player

	-- I stole a bit of the Code from NiandraLades because its good
	local function FindASCPosition(ply)
		local size = Vector(32, 32, 72)

		local StartPos = ply:GetPos() + Vector(0, 0, size.z * 0.5)

		local len = #Positions

		for i = 1, len do
			local v = Positions[i]
			local Pos = StartPos + v * size * 1.5

			local tr = {}
			tr.start = Pos
			tr.endpos = Pos
			tr.mins = size * 0.5 * -1
			tr.maxs = size * 0.5

			local trace = util.TraceHull(tr)

			if not trace.Hit then
				return Pos - Vector(0, 0, size.z * 0.5)
			end
		end

		return false
	end

	-- From TTT Ulx Commands, sorry
	local function FindCorpse(ply)
		for _, ent in pairs(ents.FindByClass("prop_ragdoll")) do
			if ent.uqid == ply:UniqueID() and IsValid(ent) then
				return ent or false
			end
		end
	end

	function plymeta:ASCHandleRespawn(corpse)
		if not IsValid(self) then return end

		local body = FindCorpse(self)

		if not IsValid(body) or body:IsOnFire() then
			if SERVER then
				net.Start("ASCError")
				net.WriteBool(false)
				net.Send(self)
			end

			self.shouldasc = false
			self.NOWINASC = false

			timer.Remove("TTTASC" .. self:EntIndex())

			self.ASCCanRespawn = false

			self:SetNWInt("ASCthetimeleft", 10)

			return
		end

		if corpse then
			local spawnPos = FindASCPosition(body)

			if not spawnPos then
				if SERVER then
					net.Start("ASCError")
					net.WriteBool(true)
					net.Send(self)
				end

				self:ASCHandleRespawn(false)

				return
			end

			self:SpawnForRound(true)
			self:SetPos(spawnPos)
			self:SetEyeAngles(Angle(0, body:GetAngles().y, 0))
		else
			self:SpawnForRound(true)
		end

		self:SetMaxHealth(100)

		self.ASCCanRespawn = false
		self.ASCTimeLeft = 0
		self.shouldasc = false
		self.NOWINASC = false

		local credits = CORPSE.GetCredits(body, 0)

		self:SetCredits(credits)
		body:Remove()

		DamageLog("SecondChance: " .. self:Nick() .. " has been respawned.")

		net.Start("ASCRespawned")
		net.Send(self)
	end

	hook.Add("KeyPress", "ASCRespawn", function(ply, key)
		if ply.ASCCanRespawn then
			if key == IN_RELOAD then
				ply:ASCHandleRespawn(true)
			elseif key == IN_JUMP then
				ply:ASCHandleRespawn(false)
			end
		end
	end)

	local function CUSTOMWIN()
		for _, v in ipairs(player.GetAll()) do
			if v.NOWINASC == true then
				return WIN_NONE
			end
		end
	end

	local function CheckifAsc(ply, attacker, dmg)
		if IsValid(attacker) and ply ~= attacker and attacker:IsPlayer() and attacker:HasEquipmentItem(EQUIP_ASC) then
			if not TTT2 then
				if (attacker:GetTraitor() or (attacker.IsEvil and attacker:IsEvil())) and ((ply:GetRole() == ROLE_INNOCENT or ply:GetRole() == ROLE_DETECTIVE) or (ply.GetGood and (ply:GetGood() or ply:IsNeutral()))) then
					attacker.SecondChanceChance = math.Clamp(attacker.SecondChanceChance + math.random(10, 20), 0, 99)
				elseif (attacker:GetRole() == ROLE_DETECTIVE or (attacker.GetGood and attacker:GetGood())) and (ply:GetTraitor() or (ply.IsEvil and (ply:IsEvil() or ply:IsNeutral()))) then
					attacker.SecondChanceChance = math.Clamp(attacker.SecondChanceChance + math.random(20, 30), 0, 99)
				elseif attacker.IsNeutral and attacker:IsNeutral() and (ply:GetGood() or ply:GetEvil()) then
					attacker.SecondChanceChance = math.Clamp(attacker.SecondChanceChance + math.random(15, 25), 0, 99)
				end
			elseif not ply:IsInTeam(attacker) then
				if attacker:GetTraitor() or attacker.IsEvil and attacker:IsEvil() then -- just normal Ts
					attacker.SecondChanceChance = math.Clamp(attacker.SecondChanceChance + math.random(10, 20), 0, 99)
				elseif attacker:HasTeam(TEAM_INNOCENT) then
					attacker.SecondChanceChance = math.Clamp(attacker.SecondChanceChance + math.random(20, 30), 0, 99)
				else
					attacker.SecondChanceChance = math.Clamp(attacker.SecondChanceChance + math.random(15, 25), 0, 99)
				end
			end

			net.Start("ASCKill")
			net.WriteInt(attacker.SecondChanceChance, 8)
			net.Send(attacker)
		end
	end

	hook.Add("DoPlayerDeath", "ASCChance", CheckifAsc)
	hook.Add("PlayerDeath", "ASCCHANCE", SecondChance)
	hook.Add("TTTCheckForWin", "ASCCHECKFORWIN", CUSTOMWIN)
end

local function ResettinAsc()
	for _, v in ipairs(player.GetAll()) do
		v.ASCCanRespawn = false
		v.ASCTimeLeft = 0

		if SERVER then
			v.SecondChanceChance = 0
			v.shouldasc = false
			v.NOWINASC = false
		end
	end
end

hook.Add("TTTPrepareRound", "ASCRESET", ResettinAsc)

if CLIENT then
	local width = 300
	local height = 100
	local color = Color(255, 80, 80, 255)

	function DrawASCHUD()
		local client = LocalPlayer()
		local t = CurTime()

		if client.ASCCanRespawn and client.ASCTimeLeft > t then
			local x = ScrW() * 0.5 - width * 0.5
			local y = ScrH() / 3 - height

			draw.RoundedBox(20, x, y, 300, 100, color)

			surface.SetDrawColor(255, 255, 255, 255)

			local w = (client.ASCTimeLeft - t) * 20

			draw.SimpleText("Time Left: " .. math.Round(client.ASCTimeLeft - t, 1), DermaDefault, x + width * 0.5, y + height / 1.2, Color(255, 255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText("Press R to Respawn on your Corpse", DermaDefault, x + width * 0.5, y + height / 6, Color(255, 255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText("Press Space to Respawn on Map Spawn", DermaDefault, x + width * 0.5, y + height / 3, Color(255, 255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

			surface.DrawRect(x + width / 6, y + height * 0.5, w, 20)

			surface.SetDrawColor(0, 0, 0, 255)
			surface.DrawOutlinedRect(x + width / 6, y + height * 0.5, 200, 20)

			if client.ASCTimeLeft > t + 8 then
				surface.SetDrawColor(COLOR_RED)
				surface.DrawLine(x, y, x + 300, y + 100)
				surface.DrawLine(x + 300, y, x, y + 100)
			end
		end
	end

	hook.Add("HUDPaint", "DrawASCHUD", DrawASCHUD)
end

hook.Add("PlayerDisconnected", "ASCDisconnect", function(ply)
	if IsValid(ply) then
		ply.shouldasc = false
		ply.ASCTimeLeft = 0
		ply.NOWINASC = false
		ply.SecondChanceChance = 0
		ply.ASCCanRespawn = false
	end
end)

hook.Add("PlayerSpawn", "ASCReset", function(ply)
	if IsValid(ply) and ply:IsTerror() then
		ply.shouldasc = false
		ply.ASCTimeLeft = 0
		ply.NOWINASC = false
		ply.SecondChanceChance = 0
		ply.ASCCanRespawn = false
	end
end)

if CLIENT then
	net.Receive("ASCRespawned", function()
		LocalPlayer().ASCCanRespawn = false
		LocalPlayer().ASCTimeLeft = 0
	end)

	net.Receive("ASCBuyed", function()
		local chance = net.ReadInt(8)

		chat.AddText("SecondChance: ", Color(255, 255, 255), "You will be revived with a chance of " .. chance .. "% !")
		chat.PlaySound()
	end)

	net.Receive("ASCKill", function()
		local chance = net.ReadInt(8)

		chat.AddText("SecondChance: ", Color(255, 255, 255), "Your chance of has been changed to " .. chance .. "% !")
		chat.PlaySound()
	end)

	net.Receive("ASCRespawn", function()
		local respawn = net.ReadBool()

		if respawn then
			LocalPlayer().ASCCanRespawn = true
			LocalPlayer().ASCTimeLeft = CurTime() + 10

			chat.AddText("SecondChance: ", Color(255, 255, 255), "Press Reload to spawn at your body. Press Space to spawn at the map spawn.")
		else
			chat.AddText("SecondChance: ", Color(255, 255, 255), "You will not be revived.")
		end

		chat.PlaySound()
	end)

	net.Receive("ASCError", function()
		local spawnpos = net.ReadBool()

		if spawnpos then
			chat.AddText("SecondChance ", COLOR_RED, "ERROR", COLOR_WHITE, ": ", Color(255, 255, 255), "No Valid Spawnpoints! Spawning at Map Spawn.")
		else
			chat.AddText("SecondChance ", COLOR_RED, "ERROR", COLOR_WHITE, ": ", Color(255, 255, 255), "Body not found or on fire, so you cant revive yourself.")
		end

		chat.PlaySound()
	end)

	hook.Add("TTTBodySearchEquipment", "ASCCorpseIcon", function(search, eq)
		search.eq_asc = util.BitSet(eq, EQUIP_ASC)
	end)

	hook.Add("TTTBodySearchPopulate", "ASCCorpseIcon", function(search, raw)
		if not raw.eq_asc then return end

		local highest = 0

		for _, v in pairs(search) do
			highest = math.max(highest, v.p)
		end

		search.eq_asc = {img = "vgui/ttt/icon_asc", text = "They maybe will have a Second Chance...", p = highest + 1}
	end)
end
