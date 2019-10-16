
----------------------
--      Locals      --
----------------------

local MAX_ACCOUNT_MACROS = 36
local MACRO_NAME_HEALTH = 'AutoHP'
local MACRO_NAME_MANA = 'AutoMP'
local MACRO_BODY_HEALTH = '#showtooltip\n%MACRO%'
local MACRO_BODY_MANA = '#showtooltip\n%MACRO%'
local RESET_TIME = 2
--@debug@
local DEBUG_ON = true
--@end-debug@

local bests = {}
bests['home'] = {}
bests['spell1'] = {}
bests['spell2'] = {}
bests['hstone'] = {}
bests['mstone'] = {}
bests['bandage'] = {}
bests['conjref'] = {}
bests['conjfood'] = {}
bests['conjdrink'] = {}
bests['refresh'] = {}
bests['food'] = {}
bests['drink'] = {}
bests['bpot'] = {}
bests['hpot'] = {}
bests['mpot'] = {}
local dirty = true
local called = false

local locale = GetLocale()
local gameLocale = locale or 'enUS'
local L = {}

-----------------------------
--      Event Handler      --
-----------------------------

DrinkIt = CreateFrame('frame')
DrinkIt:SetScript('OnEvent', function(self, event, ...) if self[event] then return self[event](self, event, ...) end end)
DrinkIt:RegisterEvent('ADDON_LOADED')

function DrinkIt:Print(...)
	SendSystemMessage(string.join(' ', '|cFF33FF99DrinkIt|r:', ...))
end

function DrinkIt:GetLocale()
	return gameLocale
end


function DrinkIt:ADDON_LOADED(event, addon)
	if addon:lower() ~= 'drinkit' then return end
	self:UnregisterEvent('ADDON_LOADED')

	L = LibStub("AceLocale-3.0"):GetLocale("DrinkIt")

	self.ADDON_LOADED = nil
	if IsLoggedIn() then self:PLAYER_LOGIN() else self:RegisterEvent('PLAYER_LOGIN') end
end


function DrinkIt:PLAYER_LOGIN()
	self:RegisterEvent('PLAYER_LOGOUT')
	self:RegisterEvent('PLAYER_REGEN_ENABLED')
	self:RegisterEvent('BAG_UPDATE')
	self:RegisterEvent('ITEM_PUSH')
	self:RegisterEvent('PLAYER_LEVEL_UP')

	-----------------
	--Create Macros--
	-----------------
	if GetMacroIndexByName(MACRO_NAME_HEALTH) == 0 then
		if GetNumMacros() < MAX_ACCOUNT_MACROS then
			CreateMacro(MACRO_NAME_HEALTH, 'INV_Misc_QuestionMark', MACRO_BODY_HEALTH)
			self:Print(L["Created macro:"]..' \"'..MACRO_NAME_HEALTH..'\"')
		else
			self:Print(L["Can't create new macro:"]..' \"'..MACRO_NAME_HEALTH..'\" '..L["Make enough space in your general macro section."])
		end
	end

	if GetMacroIndexByName(MACRO_NAME_MANA) == 0 then
		if GetNumMacros() < MAX_ACCOUNT_MACROS then
			CreateMacro(MACRO_NAME_MANA, 'INV_Misc_QuestionMark', MACRO_BODY_MANA)
			self:Print(L["Created macro:"]..' \"'..MACRO_NAME_MANA..'\"')
		else
			self:Print(L["Can't create new macro:"]..' \"'..MACRO_NAME_MANA..'\" '..L["Make enough space in your general macro section."])
		end
	end

	for i = 1,10 do
		C_Timer.NewTimer(i*RESET_TIME, function ()
			dirty = true
			if not InCombatLockdown() then
				self:Scan()
			end
		end)
	end

	self:UnregisterEvent('PLAYER_LOGIN')
	self.PLAYER_LOGIN = nil
end


function DrinkIt:PLAYER_LOGOUT()
end


function DrinkIt:PLAYER_REGEN_ENABLED()
	if dirty then self:Scan() end
end


function DrinkIt:PLAYER_LEVEL_UP()
	self:BAG_UPDATE()
end


function DrinkIt:ITEM_PUSH()
	self:BAG_UPDATE()
end


function DrinkIt:BAG_UPDATE()
	dirty = true
	if not called then
		called = true
		if not InCombatLockdown() then
			self:Scan()
		end
		C_Timer.NewTimer(RESET_TIME, function ()
			called = false
			if dirty and not InCombatLockdown() then self:Scan() end
		end)
	end
end

function DrinkIt:NewBest(sort, id, name, count, isPercent, health, mana)
	bests[sort]['id'] = id
	bests[sort]['name'] = name
	bests[sort]['count'] = count
	bests[sort]['isPercent'] = isPercent
	bests[sort]['health'] = health
	bests[sort]['mana'] = mana
end


function DrinkIt:Scan()
	for _,t in pairs(bests) do for i in pairs(t) do t[i] = nil end end
	dirty = false
	--------------------
	--Find your spells--
	--------------------
	bests['home']['id'] = 6948
	local myLevel = UnitLevel('player')
	local myClassName, _, _ = UnitClass('player')
	myClassName = myClassName and myClassName:lower()
	local numSpells = 0
	for tab = 1, GetNumSpellTabs() do
		local _, _, _, numEntries, _, _ = GetSpellTabInfo(tab)
		numSpells = numSpells + numEntries
	end
	for spellIndex = 1, numSpells do
		local spellName, _ = GetSpellBookItemName(spellIndex,'spell')
		spellName = spellName and spellName:lower()
		local _, _, _, _, _, _, spellID = GetSpellInfo(spellName)
		local spellDesc = spellID and GetSpellDescription(spellID)
		spellDesc = spellDesc and desc:lower()
		if myClassName and spellName and spellID and spellDesc then
			--------------------
			--Find mage spells--
			--------------------
			if string.match(myClassName,L["mage"]:lower()) and string.match(spellName, L["conjure"]:lower()) then
				if string.match(spellName, L["refreshment"]:lower()) and (not bests['spell1']['id'] or (bests['spell1']['id'] and bests['spell1']['id'] < spellID)) then
					self:NewBest('spell1', spellID, spellName, nil, nil, nil, nil)
				end
				if string.match(spellName, L["food"]:lower()) and (not bests['spell1']['id'] or (bests['spell1']['id'] and bests['spell1']['id'] < spellID)) then
					self:NewBest('spell1', spellID, spellName, nil, nil, nil, nil)
				end
				if string.match(spellName, L["water"]:lower()) and (not bests['spell2']['id'] or (bests['spell2']['id'] and bests['spell2']['id'] < spellID)) then
					self:NewBest('spell2', spellID, spellName, nil, nil, nil, nil)
				end
			end
			-----------------------
			--Find warlock spells--
			-----------------------
			if string.match(myClassName,L["warlock"]:lower()) and string.match(spellName, L["healthstone"]:lower()) then
				local isPercent, health, mana = self:ScanSpell(desc)
				if health > 0 and mana == 0 and (not bests['spell1']['id'] or (bests['spell1']['id'] and ((not bests['spell1']['isPercent'] and isPercent) or (bests['spell1']['isPercent'] == isPercent and bests['spell1']['health'] < health)))) then
					self:NewBest('spell1', spellID, spellName, nil, isPercent, health, mana)
				end
			end
		end
	end

	for bag=0,4 do
		for slot=1,GetContainerNumSlots(bag) do
			local _, itemCount, _, _, _, _, itemLink, _, _, itemID = GetContainerItemInfo(bag, slot)
			if itemLink then
				local itemName, _, _, _, itemMinLevel, itemType, itemSubType, _, _, _, _ = GetItemInfo(itemLink)
				itemName = itemName and itemName:lower()
				itemType = itemType and itemType:lower()
				itemSubType = itemSubType and itemSubType:lower()

				--@debug@
				if DEBUG_ON then
					self:Print('item: '..(itemName or '')..' - '..(itemType or '')..' - '..(itemSubType or '')..' - '..(itemMinLevel or ''))
				end
				--@end-debug@

				if itemType and ((string.match(itemType, L["armor"]:lower()) and string.match(itemSubType, L["miscellaneous"]:lower())) or string.match(itemType, L["consumable"]:lower()) or string.match(itemType, L["miscellaneous"]:lower())) and itemMinLevel <= myLevel then
					local spellName, spellID = GetItemSpell(itemLink)
					spellName = spellName and spellName:lower()
					local desc = spellID and GetSpellDescription(spellID)
					desc = desc and desc:lower()
					if spellName and itemSubType and desc then

						--@debug@
						if DEBUG_ON then
							self:Print('spell: '..(itemName or '')..' - '..(itemType or '')..' - '..(itemSubType or '')..' - '..(spellName or '')..' - '..(itemMinLevel or ''))
						end
						--@end-debug@

						---------------
						--Healthstone--
						---------------
						if string.match(spellName,L["healthstone"]:lower()) and string.match(desc,L["restores"]:lower()) then
							local isPercent, health, mana = self:ScanSpell(desc)
							if health > 0 and mana == 0 and (not bests['hstone']['id'] or (bests['hstone']['id'] and ((not bests['hstone']['isPercent'] and isPercent) or (bests['hstone']['isPercent'] == isPercent and bests['hstone']['health'] < health)))) then
								self:NewBest('hstone', itemID, itemName, itemCount, isPercent, health, mana)
							end
						end
						-------------
						--Manastone--
						-------------
						if string.match(spellName,L["mana"]:lower()) and not string.match(itemName,L["potion"]:lower()) and string.match(desc,L["restores"]:lower()) then
							local isPercent, health, mana = self:ScanSpell(desc)
							if health == 0 and mana > 0 and (not bests['mstone']['id'] or (bests['mstone']['id'] and ((not bests['mstone']['isPercent'] and isPercent) or (bests['mstone']['isPercent'] == isPercent and bests['mstone']['health'] < health)))) then
								self:NewBest('mstone', itemID, itemName, itemCount, isPercent, health, mana)
							end
						end
						------------
						--Bandages--
						------------
						if (string.match(itemSubType,L["bandage"]:lower()) or string.match(spellName,L["first aid"]:lower())) and string.match(desc,L["heals"]:lower()) then
							local isPercent, health, mana = self:ScanSpell(desc)
							if health > 0 and mana == 0 and (not bests['bandage']['id'] or (bests['bandage']['id'] and ((not bests['bandage']['isPercent'] and isPercent) or (bests['bandage']['isPercent'] == isPercent and bests['bandage']['health'] < health)))) then
								self:NewBest('bandage', itemID, itemName, itemCount, isPercent, health, mana)
							end
						end
						------------------
						--Conjured Stuff--
						------------------
						if string.match(itemName,L["conjured"]:lower()) and (string.match(itemSubType, L["food & drink"]) or string.match(spellName, L["food"]:lower()) or string.match(spellName, L["drink"]:lower())) and string.match(desc,L["restores"]:lower()) and string.match(desc,L["remain seated"]:lower()) then
							local isPercent, health, mana = self:ScanSpell(desc)
							------------------------
							--Conjured Food&Drinks--
							------------------------
							if health > 0 and mana > 0 and (not bests['conjref']['id'] or (bests['conjref']['id'] and ((not bests['conjref']['isPercent'] and isPercent) or (bests['conjref']['isPercent'] == isPercent and bests['conjref']['health'] < health)))) then
								self:NewBest('conjref', itemID, itemName, itemCount, isPercent, health, mana)
							end
							-----------------
							--Conjured Food--
							-----------------
							if health > 0 and mana == 0 and (not bests['conjfood']['id'] or (bests['conjfood']['id'] and ((not bests['conjfood']['isPercent'] and isPercent) or (bests['conjfood']['isPercent'] == isPercent and bests['conjfood']['health'] < health)))) then
								self:NewBest('conjfood', itemID, itemName, itemCount, isPercent, health, mana)
							end
							-------------------
							--Conjured Drinks--
							-------------------
							if health == 0 and mana > 0 and (not bests['conjdrink']['id'] or (bests['conjdrink']['id'] and ((not bests['conjdrink']['isPercent'] and isPercent) or (bests['conjdrink']['isPercent'] == isPercent and bests['conjdrink']['mana'] < mana)))) then
								self:NewBest('conjdrink', itemID, itemName, itemCount, isPercent, health, mana)
							end
						end
						----------------
						--normal Stuff--
						----------------
						if not string.match(itemName,L["conjured"]:lower()) and (string.match(itemSubType, L["food & drink"]:lower()) or string.match(itemSubType, L["reagent"]:lower()) or  string.match(spellName, L["food"]:lower()) or string.match(spellName, L["drink"]:lower())) and string.match(desc,L["restores"]:lower()) and string.match(desc,L["remain seated"]:lower()) and not (string.match(desc,L["spend at least"]:lower()) or string.match(desc,L["well fed"]:lower())) then
							local isPercent, health, mana = self:ScanSpell(desc)
							----------------
							--Refreshments--
							----------------
							if health > 0 and mana > 0 and (not bests['refresh']['id'] or (bests['refresh']['id'] and ((not bests['refresh']['isPercent'] and isPercent) or (bests['refresh']['isPercent'] == isPercent and bests['refresh']['health'] < health)))) then
								self:NewBest('refresh', itemID, itemName, itemCount, isPercent, health, mana)
							end
							--------
							--Food--
							--------
							if health > 0 and mana == 0 and (not bests['food']['id'] or (bests['food']['id'] and ((not bests['food']['isPercent'] and isPercent) or (bests['food']['isPercent'] == isPercent and bests['food']['health'] < health)))) then
								self:NewBest('food', itemID, itemName, itemCount, isPercent, health, mana)
							end
							----------
							--Drinks--
							----------
							if health == 0 and mana > 0 and (not bests['drink']['id'] or (bests['drink']['id'] and ((not bests['drink']['isPercent'] and isPercent) or (bests['drink']['isPercent'] == isPercent and bests['drink']['mana'] < mana)))) then
								self:NewBest('drink', itemID, itemName, itemCount, isPercent, health, mana)
							end
						end
						-----------
						--Potions--
						-----------
						if (string.match(itemSubType, L["potion"]:lower()) or string.match(spellName,L["restore"]:lower()) or string.match(spellName, L["potion"]:lower()) or string.match(itemName, L["potion"]:lower())) and string.match(desc,L["restores"]:lower()) and not (string.match(desc,L["battleground"]:lower()) or string.match(desc,L["remain seated"]:lower()) or string.match(desc,L["well fed"]:lower())) then
							local isPercent, health, mana = self:ScanSpell(desc)
							----------------------
							--Health&Mana Potion--
							----------------------
							if health > 0 and mana > 0 and (not bests['bpot']['id'] or (bests['bpot']['id'] and ((not bests['bpot']['isPercent'] and isPercent) or (bests['bpot']['isPercent'] == isPercent and bests['bpot']['health'] < health)))) then
								self:NewBest('bpot', itemID, itemName, itemCount, isPercent, health, mana)
							end
							-----------------
							--Health Potion--
							-----------------
							if health > 0 and mana == 0 and (not bests['hpot']['id'] or (bests['hpot']['id'] and ((not bests['hpot']['isPercent'] and isPercent) or (bests['hpot']['isPercent'] == isPercent and bests['hpot']['health'] < health)))) then
								self:NewBest('hpot', itemID, itemName, itemCount, isPercent, health, mana)
							end
							---------------
							--Mana Potion--
							---------------
							if health == 0 and mana > 0 and (not bests['mpot']['id'] or (bests['mpot']['id'] and ((not bests['mpot']['isPercent'] and isPercent) or (bests['mpot']['isPercent'] == isPercent and bests['mpot']['mana'] < mana)))) then
								self:NewBest('mpot', itemID, itemName, itemCount, isPercent, health, mana)
							end
						end
					end
				end
			end
		end
	end

	--@debug@
	if DEBUG_ON then
		self:Print('bests: '..(bests['hstone']['name'] or '')..' - '..(bests['mstone']['name'] or '')..' - '..(bests['bandage']['name'] or '')..' || '..(bests['conjref']['name'] or '')..' - '..(bests['conjfood']['name'] or '')..' - '..(bests['conjdrink']['name'] or '')..' || '..(bests['refresh']['name'] or '')..' - '..(bests['food']['name'] or '')..' - '..(bests['drink']['name'] or '')..' || '..(bests['bpot']['name'] or '')..' - '..(bests['hpot']['name'] or '')..' - '..(bests['mpot']['name'] or '')..' || '..(bests['home']['name'] or '')..' - '..(bests['spell1']['name'] or '')..' - '..(bests['spell2']['name'] or ''))
	end
	--@end-debug@

	self:MacroEdit(MACRO_NAME_HEALTH, MACRO_BODY_HEALTH, (bests['conjref']['id'] or bests['conjfood']['id'] or bests['refresh']['id'] or bests['food']['id'] or bests['bandage']['id'] or bests['hstone']['id'] or bests['bpot']['id'] or bests['hpot']['id']), (bests['hpot']['id'] or bests['bpot']['id']), bests['hstone']['id'], bests['bandage']['id'], bests['home']['id'], bests['spell1']['name'])

	self:MacroEdit(MACRO_NAME_MANA, MACRO_BODY_MANA, (bests['conjdrink']['id'] or bests['drink']['id'] or bests['mstone']['id'] or bests['mpot']['id'] or bests['bandage']['id']), (bests['bpot']['id'] or bests['mpot']['id']), bests['mstone']['id'], nil, bests['home']['id'], bests['spell2']['name'])

	dirty = false
end


function DrinkIt:MacroEdit(name, substring, food, pot, stone, bandage, home, spell)
	local macroID = GetMacroIndexByName(name)
	if not macroID then return end

	local items ={stone, pot, bandage}
	local body = ''
	local conds = ''
	local nomod = 'nomod'
	if spell and not bandage then nomod = nomod..':ctrl' end
	if not spell and bandage then nomod = nomod..':shift' end

	if spell then
		body = body..'/cast [mod:ctrl]'..spell..'\n'
	end
	if bandage then
		body = body..'/use [mod:shift]item:'..bandage..'\n'
	end

	conds = '[combat'
	if spell or bandage then conds = conds..','..nomod end
	conds = conds..']'
	if (pot and not stone and not bandage) or (not pot and stone and not bandage) or (not pot and not stone and bandage) then
		body = body..'/use '..conds..'item:'..(pot or stone or bandage)..'\n'
	end
	if not ((pot and not stone and not bandage) or (not pot and stone and not bandage) or (not pot and not stone and bandage)) and (pot or stone or bandage) then
		body = body..'/castsequence '..conds..'reset=120/combat '
		local isFirst = true
		for _, item in pairs(items) do
			if item then
				if not isFirst then
					body = body..','
				end
				body = body..'item:'..item
				isFirst = false
			end
		end
		body = body..'\n'
	end

	conds = '['
	if pot or stone then conds = conds..'nocombat' end
	if (pot or stone) and (spell or bandage) then conds = conds..',' end
	if spell or bandage then conds = conds..nomod end
	conds = conds..']'
	if food then
		body = body..'/use '..conds..'item:'..food..'\n'
	else
		body = body..'/use '..conds..'item:'..home..'\n'
	end

	EditMacro(macroID, nil, nil, substring:gsub('%%MACRO%%', body))
end


function DrinkIt:ScanValue(desc, isPercent, key)
	if (isPercent) then
		return string.match(desc, '(%d*).?(%d*).?(%d+)%s?%%%s?[a-z()]-%s'..key:lower())
	else
		return string.match(desc, '(%d*).?(%d*).?(%d+)%s?[a-z()]-%s'..key:lower())
	end
end


function DrinkIt:ScanSpell(desc)
	local isPercent = string.match(desc, '%%') ~= nil
	local h1, h2, h3, m1, m2, m3
	local health, mana
	h1, h2, h3 = self:ScanValue(desc, isPercent, L["health"])
	if not h3 then
		h1, h2, h3 = self:ScanValue(desc, isPercent, L["life"])
	end
	if not h3 then
		h1, h2, h3 = self:ScanValue(desc, isPercent, L["damage"])
	end
	m1, m2, m3 = self:ScanValue(desc, isPercent, L["mana"])
	health = tonumber((h1 or '')..(h2 or '')..(h3 or '0'))
	mana = tonumber((m1 or '')..(m2 or '')..(m3 or '0'))

	--@debug@
	if DEBUG_ON then
		self:Print('scan: ', health, mana)
	end
	--@end-debug@

	return isPercent, health, mana
end