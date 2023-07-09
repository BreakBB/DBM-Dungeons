if DBM:GetTOC() < 100105 then return end
local mod	= DBM:NewMod(2536, "DBM-Party-Dragonflight", 9, 1209)
local L		= mod:GetLocalizedStrings()

mod:SetRevision("@file-date-integer@")
mod:SetCreatureID(198999)
mod:SetEncounterID(2671)
mod:SetUsedIcons(1, 2, 3, 4, 5, 6)
mod:SetHotfixNoticeRev(20230708000000)
--mod:SetMinSyncRevision(20221015000000)
--mod.respawnTime = 29
mod.sendMainBossGUID = true

mod:RegisterCombat("combat")

mod:RegisterEventsInCombat(
	"SPELL_CAST_START 404916 403891 404364 405279 406481",
--	"SPELL_CAST_SUCCESS",
	"SPELL_SUMMON 403902",
	"SPELL_AURA_APPLIED 401200 401667",
	"SPELL_AURA_REMOVED 401200"
--	"SPELL_PERIODIC_DAMAGE",
--	"SPELL_PERIODIC_MISSED",
--	"UNIT_SPELLCAST_SUCCEEDED boss1"
)

--[[
(ability.id = 404916 or ability.id = 403891 or ability.id = 405279 or ability.id = 406481) and type = "begincast"
 or type = "dungeonencounterstart" or type = "dungeonencounterend"
 or ability.id = 404364 and type = "begincast"
--]]
--NOTE:, based on logs, tank can NOT sidestep Sand Blast, so warning is using generic text cause tank positions, rest avoid
--TODO, Initial data (literally just 2 pulls sadly, suggests timers are sequenced in a fixed pattern. If that's case then mod needs some LONG pulls to populate tables
--TODO, announce https://www.wowhead.com/ptr-2/spell=413208/sand-buffeted for healers?
--TODO, nameplate aura on trapped familar face? need to see how good visual is for it first
local warnMoreProblems								= mod:NewCountAnnounce(403891, 3)
local warnFamiliarFaces								= mod:NewCountAnnounce(405279, 3)
local warnTimeStasis								= mod:NewTargetNoFilterAnnounce(401667, 4)

local specWarnSandBlast								= mod:NewSpecialWarningCount(404916, nil, nil, nil, 2, 2)
local specWarnDragonBreath							= mod:NewSpecialWarningDodge(404364, nil, nil, nil, 3, 2)
local specWarnTimeTraps								= mod:NewSpecialWarningDodgeCount(406481, nil, nil, nil, 3, 2)
--local specWarnGTFO								= mod:NewSpecialWarningGTFO(386201, nil, nil, nil, 1, 8)

local timerSandBlastCD								= mod:NewCDCountTimer(21.8, 404916, nil, nil, nil, 5, nil, DBM_COMMON_L.TANK_ICON)--21.8-38.8
local timerMoreProblemsCD							= mod:NewCDCountTimer(40, 403891, nil, nil, nil, 6)--40-52
local timerFamiliarFacesCD							= mod:NewCDCountTimer(23, 405279, nil, nil, nil, 5)--Only cast once
local timerTimeTrapsCD								= mod:NewCDCountTimer(50.9, 406481, nil, nil, nil, 3)

--mod:AddInfoFrameOption(391977, true)
mod:AddSetIconOption("SetIconOnImages", 403891, true, 5, {1, 2, 3, 4, 5, 6})
mod:AddNamePlateOption("NPAuraOnFixate", 401200)

local askShown = false
mod.vb.blastCount = 0
mod.vb.problemsCount = 0
mod.vb.problemIcons = 1
mod.vb.facesCount = 0
mod.vb.trapsCount = 0
local allTimers = {
	--Sand Blast
	[404916] = {4.6, 38.8, 29.1, 21.8, 29.1, 23, 29.1},
	--More Problems
	[403891] = {10.6, 40, 48.5, 52.1},
	--Time Traps
	[406481] = {30.1, 50.9, 52.1},
}

--[[
local function updateAllTimers(self, ICD)
	DBM:Debug("updateAllTimers running", 3)
	--Abilities that exist in P1 and P2
	if timerSandBlastCD:GetRemaining(self.vb.blastCount+1) < ICD then
		local elapsed, total = timerSandBlastCD:GetTime(self.vb.blastCount+1)
		local extend = ICD - (total-elapsed)
		DBM:Debug("timerSandBlastCD extended by: "..extend, 2)
		timerSandBlastCD:Update(elapsed, total+extend, self.vb.blastCount+1)
	end
	if timerMoreProblemsCD:GetRemaining(self.vb.problemIcons+1) < ICD then
		local elapsed, total = timerMoreProblemsCD:GetTime(self.vb.problemIcons+1)
		local extend = ICD - (total-elapsed)
		DBM:Debug("timerMoreProblemsCD extended by: "..extend, 2)
		timerMoreProblemsCD:Update(elapsed, total+extend, self.vb.problemIcons+1)
	end
	if timerTimeTrapsCD:GetRemaining(self.vb.trapsCount+1) < ICD then
		local elapsed, total = timerTimeTrapsCD:GetTime(self.vb.trapsCount+1)
		local extend = ICD - (total-elapsed)
		DBM:Debug("timerTimeTrapsCD extended by: "..extend, 2)
		timerTimeTrapsCD:Update(elapsed, total+extend, self.vb.trapsCount+1)
	end
end
--]]

function mod:OnCombatStart(delay)
	askShown = false
	self.vb.blastCount = 0
	self.vb.problemsCount = 0
	self.vb.facesCount = 0
	self.vb.trapsCount = 0
	timerSandBlastCD:Start(4.6-delay, 1)
	timerMoreProblemsCD:Start(10-delay, 1)
	timerTimeTrapsCD:Start(30-delay, 1)
	timerFamiliarFacesCD:Start(38.6-delay, 1)
	if self.Options.NPAuraOnFixate then
		DBM:FireEvent("BossMod_EnableHostileNameplates")
	end
end

function mod:OnCombatEnd()
--	if self.Options.RangeFrame then
--		DBM.RangeCheck:Hide()
--	end
--	if self.Options.InfoFrame then
--		DBM.InfoFrame:Hide()
--	end
	if self.Options.NPAuraOnFixate then
		DBM.Nameplate:Hide(true, nil, nil, nil, true, true)
	end
end

function mod:SPELL_CAST_START(args)
	local spellId = args.spellId
	if spellId == 404916 then
		self.vb.blastCount = self.vb.blastCount + 1
		specWarnSandBlast:Show(self.vb.blastCount)
		specWarnSandBlast:Play("shockwave")
		timerSandBlastCD:Start(nil, self.vb.blastCount+1)
		local timer = self:GetFromTimersTable(allTimers, false, false, spellId, self.vb.blastCount+1)
		if timer then
			timerSandBlastCD:Start(timer, self.vb.blastCount+1)
		else
			if not askShown then
				askShown = true
				DBM:AddMsg("Timers not known beyond this point, please share your WCL with DBM authors if you can")
			end
		end
--		updateAllTimers(self, 4.9)
	elseif spellId == 403891 then
		self.vb.problemsCount = self.vb.problemsCount + 1
		self.vb.problemIcons = 1
		warnMoreProblems:Show(self.vb.problemIcons)
		local timer = self:GetFromTimersTable(allTimers, false, false, spellId, self.vb.blastCount+1)
		if timer then
			timerMoreProblemsCD:Start(timer, self.vb.problemsCount+1)
		else
			if not askShown then
				askShown = true
				DBM:AddMsg("Timers not known beyond this point, please share your WCL with DBM authors if you can")
			end
		end
	elseif spellId == 404364 and self:AntiSpam(3, 1) then--All 6 cast it at once
		specWarnDragonBreath:Show()
		specWarnDragonBreath:Play("breathsoon")
	elseif spellId == 405279 then
		elf.vb.facesCount = elf.vb.facesCount + 1
		warnFamiliarFaces:Show(elf.vb.facesCount)
	elseif spellId == 406481 then
		self.vb.trapsCount = self.vb.trapsCount + 1
		specWarnTimeTraps:Show(self.vb.trapsCount)
		specWarnTimeTraps:Play("watchstep")
		local timer = self:GetFromTimersTable(allTimers, false, false, spellId, self.vb.trapsCount+1)
		if timer then
			timerTimeTrapsCD:Start(timer, self.vb.trapsCount+1)
		else
			if not askShown then
				askShown = true
				DBM:AddMsg("Timers not known beyond this point, please share your WCL with DBM authors if you can")
			end
		end
	end
end

--[[
function mod:SPELL_CAST_SUCCESS(args)
	local spellId = args.spellId
	if spellId == 387691 then

	end
end
--]]

function mod:SPELL_SUMMON(args)
	local spellId = args.spellId
	if spellId == 403902 then
		if self.Options.SetIconOnImages then
			self:ScanForMobs(args.destGUID, 2, self.vb.problemIcons, 1, nil, 12, "SetIconOnImages")
		end
		self.vb.problemIcons = self.vb.problemIcons + 1
	end
end

function mod:SPELL_AURA_APPLIED(args)
	local spellId = args.spellId
	if spellId == 401200 and args:IsPlayer() then
		if self.Options.NPAuraOnFixate then
			DBM.Nameplate:Show(true, args.sourceGUID, spellId)
		end
	elseif spellId == 401667 then
		warnTimeStasis:Show(args.destName)
	end
end
--mod.SPELL_AURA_APPLIED_DOSE = mod.SPELL_AURA_APPLIED

function mod:SPELL_AURA_REMOVED(args)
	local spellId = args.spellId
	if spellId == 401200 and args:IsPlayer() then
		if self.Options.NPAuraOnFixate then
			DBM.Nameplate:Hide(true, args.sourceGUID, spellId)
		end
	end
end

--[[
function mod:SPELL_PERIODIC_DAMAGE(_, _, _, _, destGUID, _, _, _, spellId, spellName)
	if spellId == 386201 and destGUID == UnitGUID("player") and self:AntiSpam(2, 4) then
		specWarnGTFO:Show(spellName)
		specWarnGTFO:Play("watchfeet")
	end
end
mod.SPELL_PERIODIC_MISSED = mod.SPELL_PERIODIC_DAMAGE
--]]

--[[
function mod:UNIT_SPELLCAST_SUCCEEDED(uId, _, spellId)
	if spellId == 353193 then

	end
end
--]]
