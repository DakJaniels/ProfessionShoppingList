-------------------------------------------------------
-- Profession Shopping List: ProfessionKnowledge.lua --
-------------------------------------------------------
-- Profession Knowledge module

-- Initialisation
local appName, app = ...	-- Returns the AddOn name and a unique table

------------------
-- INITIAL LOAD --
------------------

-- Create default user settings and session variables
function app.InitialiseProfessionKnowledge()
	-- Initialise session variables
	app.Flag["knowledgeAssets"] = false
end

-- When the AddOn is fully loaded
app.Event:Register("ADDON_LOADED", function(addOnName, containsBindings)
	if addOnName == appName then
		app.InitialiseProfessionKnowledge()
	end
end)

-----------------------
-- KNOWLEDGE TRACKER --
-----------------------

-- Create knowledge tracker
function app.CreateProfessionKnowledgeAssets()
	-- Create Knowledge Point tracker
	if not app.KnowledgePointTracker then
		-- Bar wrapper
		app.KnowledgePointTracker = CreateFrame("Frame", "KnowledgePointTracker", ProfessionsFrame.SpecPage, "TooltipBackdropTemplate")
		app.KnowledgePointTracker:SetBackdropBorderColor(0.5, 0.5, 0.5)
		app.KnowledgePointTracker:SetSize(470,25)
		app.KnowledgePointTracker:SetPoint("TOPRIGHT", ProfessionsFrame.SpecPage, "TOPRIGHT", -5, -24)
		app.KnowledgePointTracker:SetFrameStrata("HIGH")

		-- Bar
		app.KnowledgePointTracker.Bar = CreateFrame("StatusBar", nil, app.KnowledgePointTracker)
		app.KnowledgePointTracker.Bar:SetStatusBarTexture("Interface\\AddOns\\ProfessionShoppingList\\assets\\profbars\\generic.blp")
		
		app.KnowledgePointTracker.Bar:SetPoint("TOPLEFT", 5, -5)
		app.KnowledgePointTracker.Bar:SetPoint("BOTTOMRIGHT", -5, 5)
		Mixin(app.KnowledgePointTracker.Bar, SmoothStatusBarMixin)

		-- Text
		app.KnowledgePointTracker.Text = app.KnowledgePointTracker.Bar:CreateFontString("OVERLAY", nil, "GameFontNormalOutline")
		app.KnowledgePointTracker.Text:SetPoint("CENTER", app.KnowledgePointTracker, "CENTER", 0, 0)
		app.KnowledgePointTracker.Text:SetTextColor(1, 1, 1, 1)
	end

	-- Create Knowledge Point tracker tooltip
	if not app.KnowledgePointTooltip then
		app.KnowledgePointTooltip = CreateFrame("Frame", nil, app.KnowledgePointTracker, "BackdropTemplate")
		app.KnowledgePointTooltip:SetPoint("CENTER")
		app.KnowledgePointTooltip:SetPoint("TOP", app.KnowledgePointTracker, "BOTTOM", 0, 0)
		app.KnowledgePointTooltip:SetFrameStrata("TOOLTIP")
		app.KnowledgePointTooltip:SetBackdrop({
			bgFile = "Interface/Tooltips/UI-Tooltip-Background",
			edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
			edgeSize = 16,
			insets = { left = 4, right = 4, top = 4, bottom = 4 },
		})
		app.KnowledgePointTooltip:SetBackdropColor(0, 0, 0, 0.9)
		app.KnowledgePointTooltip:EnableMouse(false)
		app.KnowledgePointTooltip:SetMovable(false)
		app.KnowledgePointTooltip:Hide()

		app.KnowledgePointTooltipText = app.KnowledgePointTooltip:CreateFontString("ARTWORK", nil, "GameFontNormal")
		app.KnowledgePointTooltipText:SetPoint("TOPLEFT", app.KnowledgePointTooltip, "TOPLEFT", 10, -10)
		app.KnowledgePointTooltipText:SetJustifyH("LEFT")
	end

	app.Flag["knowledgeAssets"] = true
end

-- Populate knowledge tracker
function app.KnowledgeTracker()
	-- Show stuff depending on which profession+expansion is opened
	local skillLineID = C_TradeSkillUI.GetProfessionChildSkillLineID()
	local professionID = C_TradeSkillUI.GetProfessionInfoBySkillLineID(skillLineID).profession

	-- Knowledge Point Tracker
	local function setKnowledgePointTracker()
		-- Variables
		local configID = C_ProfSpecs.GetConfigIDForSkillLine(skillLineID)
		local specTabIDs = C_ProfSpecs.GetSpecTabIDsForSkillLine(skillLineID)

		-- Helper functions
		local appendChildPathIDsForRoot -- Declare this one before the function itself, otherwise it can't find the function to refer to within itself apparently
		appendChildPathIDsForRoot = function(t, pathID)
			t[pathID] = 1
			for _, childID in ipairs(C_ProfSpecs.GetChildrenForPath(pathID)) do
				appendChildPathIDsForRoot(t, childID)
			end
		end

		-- Get all profession specialisation paths
		local pathIDs = {}
		for _, specTabID in ipairs(C_ProfSpecs.GetSpecTabIDsForSkillLine(skillLineID)) do
			appendChildPathIDsForRoot(pathIDs, C_ProfSpecs.GetRootPathForTab(specTabID))
		end

		-- Get all perks
		local perkCount = 0
		local perkIDs = {}
		for pathID, _ in pairs(pathIDs) do
			local perks = C_ProfSpecs.GetPerksForPath(pathID)
			for no, perk in pairs(perks) do
				perkCount = perkCount + 1
				perkIDs[perkCount] = perk.perkID
			end
		end

		-- Get perk info
		local perksEarned = 0
		for no, perk in pairs(perkIDs) do
			if C_ProfSpecs.GetStateForPerk(perk, configID) == 2 then
				perksEarned = perksEarned + 1
			end
		end

		-- Get knowledge info
		local knowledgeSpent = 0
		local knowledgeMax = 0
		for pathID, _ in pairs(pathIDs) do
			local pathInfo = C_Traits.GetNodeInfo(C_ProfSpecs.GetConfigIDForSkillLine(skillLineID), pathID)
			knowledgeSpent = knowledgeSpent + math.max(0,(pathInfo.activeRank - 1))
			knowledgeMax = knowledgeMax + (pathInfo.maxRanks - 1)
		end

		-- Set text, background, and progress, then show bar
		app.KnowledgePointTracker.Text:SetText(perksEarned.."/"..perkCount.." perks unlocked ("..knowledgeSpent.."/"..knowledgeMax.." knowledge)")
		app.KnowledgePointTracker.Bar:SetMinMaxSmoothedValue(0, knowledgeMax)
		app.KnowledgePointTracker.Bar:SetSmoothedValue(knowledgeSpent)
		app.KnowledgePointTracker.Bar:SetStatusBarTexture("Interface\\AddOns\\ProfessionShoppingList\\assets\\profbars\\"..professionID..".blp")
		app.KnowledgePointTracker:Show()
	end

	-- Professions with Knowledge Points
	if professionID == 1
	or professionID == 2
	or professionID == 3
	or professionID == 4
	or professionID == 6
	or professionID == 7
	or professionID == 8
	or professionID == 9
	or professionID == 11
	or professionID == 12
	or professionID == 13 then
		-- When not viewing another character's
		if C_TradeSkillUI.IsTradeSkillLinked() == false and C_TradeSkillUI.IsTradeSkillGuild() == false then
			setKnowledgePointTracker()
		end
	else
		app.KnowledgePointTracker:Hide()
	end

	-- Knowledge point tooltip
	local function kpTooltip()
		-- Populate the profession knowledge tooltip
		if app.ProfessionKnowledge[skillLineID] then
			local renownCount = 0
			
			-- Vendors
			local text = "Vendors"

			for k, v in ipairs(app.ProfessionKnowledge[skillLineID]) do
				-- Completion status
				local icon = app.iconNotReady
				if C_QuestLog.IsQuestFlaggedCompleted(v.quest) then
					icon = app.iconReady
				end

				if v.type == "vendor" then
					-- Item link
					if not C_Item.IsItemDataCachedByID(v.item) then local item = Item:CreateFromItemID(v.item) end
					local _, itemLink = C_Item.GetItemInfo(v.item)
					-- Grab faction name if applicable
					local factionName, status, zoneName
					if v.renown then
						factionName = C_Reputation.GetFactionDataByID(v.source).name
						if C_MajorFactions.GetRenownLevels(v.source)[v.renown].locked then
							status = "|cffD222D"
						else
							status = "|cff238823"
						end
					elseif v.sourceType == "zone" then
						zoneName = C_Map.GetMapInfo(v.source).name
					end
					-- If anything is missing, try again
					if not itemLink or (v.renown and not factionName) or (v.sourceType == "zone" and not zoneName) then
						RunNextFrame(kpTooltip)
						do return end
					end

					-- Add text
					if v.renown then
						text = text .. "\n" .. "|T"..icon..":0|t " .. itemLink .. "|cffffffff ("..factionName.." - "..status..RENOWN_LEVEL_LABEL..v.renown.."|r)|r"
					elseif v.sourceType == "zone" then
						text = text .. "\n" .. "|T"..icon..":0|t " .. itemLink .. "|cffffffff ("..zoneName..")|r"
					elseif v.sourceType == "static" then
						text = text .. "\n" .. "|T"..icon..":0|t " .. itemLink .. "|cffffffff ("..v.source..")|r"
					end
				end

				-- Count Renown
				if v.type == "renown" then
					renownCount = renownCount + 1
				end
			end

			-- Renown
			if renownCount > 0 then
				text = text .. "\n\n" .. "Renown"

				for k, v in ipairs(app.ProfessionKnowledge[skillLineID]) do
					-- Completion status
					local icon = app.iconNotReady
					if C_QuestLog.IsQuestFlaggedCompleted(v.quest) then
						icon = app.iconReady
					end
	
					if v.type == "renown" then
						-- Quest and faction info
						local questTitle = C_QuestLog.GetTitleForQuestID(v.quest)
						local factionTitle = C_Reputation.GetFactionDataByID(v.faction).name
						local status
						if C_MajorFactions.GetRenownLevels(v.faction)[v.renown].locked then
							status = "|cffD222D"
						else
							status = "|cff238823"
						end
						-- If anything missing, try again
						if not questTitle or not factionTitle then
							RunNextFrame(kpTooltip)
							do return end
						end
	
						-- Add text
						text = text .. "\n" .. "|T"..icon ..":0|t " .. "|cffffff00|Hquest:"..v.quest.."62|h["..questTitle.."]|h|r" .. "|cffffffff ("..factionTitle.." - "..status..RENOWN_LEVEL_LABEL..v.renown.."|r)|r"
					end
				end
			end

			-- World
			text = text .. "\n\n" .. "World"

			for k, v in ipairs(app.ProfessionKnowledge[skillLineID]) do
				-- Completion status
				local icon = app.iconNotReady
				if C_QuestLog.IsQuestFlaggedCompleted(v.quest) then
					icon = app.iconReady
				end

				if v.type == "world" then
					-- Zone name
					local zone = C_Map.GetMapInfo(v.zone).name

					-- Item link
					local _, itemLink
					if v.item then
						if not C_Item.IsItemDataCachedByID(v.item) then local item = Item:CreateFromItemID(v.item) end
						_, itemLink = C_Item.GetItemInfo(v.item)

						-- If anything is missing, try again
						if not itemLink or not zone then
							RunNextFrame(kpTooltip)
							do return end
						end
					else
						itemLink = "Hidden Profession Master"
					end

					-- Add text
					text = text .. "\n" .. "|T"..icon..":0|t |cffffffff" .. itemLink .. " ("..zone..")|r"
				end
			end

			-- Set the tooltip text
			app.KnowledgePointTooltipText:SetText(text)
			-- Set the tooltip size to fit its contents
			app.KnowledgePointTooltip:SetHeight(app.KnowledgePointTooltipText:GetStringHeight()+20)
			app.KnowledgePointTooltip:SetWidth(app.KnowledgePointTooltipText:GetStringWidth()+20)
		end
	end

	-- Refresh and show the tooltip on mouse-over
	app.KnowledgePointTracker:SetScript("OnEnter", function()
		kpTooltip()
		app.KnowledgePointTooltip:Show()
	end)
	-- Hide the tooltip when not mouse-over
	app.KnowledgePointTracker:SetScript("OnLeave", function()
		app.KnowledgePointTooltip:Hide()
	end)
end

-- When a tradeskill window is opened
app.Event:Register("TRADE_SKILL_SHOW", function()
	if C_AddOns.IsAddOnLoaded("Blizzard_Professions") == true then
		app.CreateProfessionKnowledgeAssets()
	end
end)

-- When a recipe is selected (also used to determine professionID, which TRADE_SKILL_SHOW() is too quick for)
app.Event:Register("SPELL_DATA_LOAD_RESULT", function(spellID, success)
	if C_AddOns.IsAddOnLoaded("Blizzard_Professions") == true and app.Flag["knowledgeAssets"] == true then
		app.KnowledgeTracker()
	end
end)

-- When profession knowledge is spent
app.Event:Register("TRAIT_CONFIG_UPDATED", function(spellID, success)
	if C_AddOns.IsAddOnLoaded("Blizzard_Professions") == true and app.Flag["knowledgeAssets"] == true then
		app.KnowledgeTracker()
	end
end)