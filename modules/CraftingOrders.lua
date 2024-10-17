--------------------------------------------------
-- Profession Shopping List: CraftingOrders.lua --
--------------------------------------------------
-- Crafting Orders module

-- Initialisation
local appName, app = ...	-- Returns the AddOn name and a unique table

------------------
-- INITIAL LOAD --
------------------

-- Create SavedVariables, default user settings, and session variables
function app.InitialiseCraftingOrders()
	-- Enable default user settings
	if ProfessionShoppingList_Settings["useLocalReagents"] == nil then ProfessionShoppingList_Settings["useLocalReagents"] = false end

	-- Initialise some session variables
	app.Flag["craftingOrderAssets"] = false
	app.Flag["quickOrder"] = 0
	app.QuickOrderRecipeID = 0
	app.QuickOrderAttempts = 0
	app.QuickOrderErrors = 0
end

-- Create buttons for the Crafting Orders window
function app.CreateCraftingOrdersAssets()
	-- Hide and disable existing tracking buttons
	ProfessionsCustomerOrdersFrame.Form.TrackRecipeCheckbox:SetAlpha(0)
	ProfessionsCustomerOrdersFrame.Form.TrackRecipeCheckbox.Checkbox:EnableMouse(false)

	-- Create the place crafting orders UI Track button
	if not app.TrackPlaceOrderButton then
		app.TrackPlaceOrderButton = app.Button(ProfessionsCustomerOrdersFrame.Form, "Track")
		app.TrackPlaceOrderButton:SetPoint("TOPLEFT", ProfessionsCustomerOrdersFrame.Form, "TOPLEFT", 12, -73)
		app.TrackPlaceOrderButton:SetScript("OnClick", function()
			app.TrackRecipe(app.SelectedRecipeID, 1)
		end)
	end

	-- Create the place crafting orders UI untrack button
	if not app.UntrackPlaceOrderButton then
		app.UntrackPlaceOrderButton = app.Button(ProfessionsCustomerOrdersFrame.Form, "Untrack")
		app.UntrackPlaceOrderButton:SetPoint("TOPLEFT", app.TrackPlaceOrderButton, "TOPRIGHT", 2, 0)
		app.UntrackPlaceOrderButton:SetScript("OnClick", function()
			app.UntrackRecipe(app.SelectedRecipeID, 1)
	
			-- Show windows
			app.Show()
		end)
	end

	-- Create the place crafting orders UI personal order name field
	if not app.QuickOrderTargetBox then
		app.QuickOrderTargetBox = CreateFrame("EditBox", nil, ProfessionsCustomerOrdersFrame.Form, "InputBoxTemplate")
		app.QuickOrderTargetBox:SetSize(80,20)
		app.QuickOrderTargetBox:SetPoint("CENTER", app.TrackPlaceOrderButton, "CENTER", 0, 0)
		app.QuickOrderTargetBox:SetPoint("LEFT", app.TrackPlaceOrderButton, "LEFT", 415, 0)
		app.QuickOrderTargetBox:SetAutoFocus(false)
		app.QuickOrderTargetBox:SetCursorPosition(0)
		app.QuickOrderTargetBox:SetScript("OnEditFocusLost", function(self)
			ProfessionShoppingList_CharacterData.Orders[app.SelectedRecipeID] = tostring(app.QuickOrderTargetBox:GetText())
			app.UpdateAssets()
		end)
		app.QuickOrderTargetBox:SetScript("OnEnterPressed", function(self)
			ProfessionShoppingList_CharacterData.Orders[app.SelectedRecipeID] = tostring(app.QuickOrderTargetBox:GetText())
			self:ClearFocus()
			app.UpdateAssets()
		end)
		app.QuickOrderTargetBox:SetScript("OnEscapePressed", function(self)
			app.UpdateAssets()
		end)
		app.QuickOrderTargetBox:SetScript("OnEnter", function()
			app.QuickOrderTooltip:Show()
		end)
		app.QuickOrderTargetBox:SetScript("OnLeave", function()
			app.QuickOrderTooltip:Hide()
		end)
		app.Border(app.QuickOrderTargetBox, -6, 1, 2, -2)
	end

	local function quickOrder(recipeID)
		-- Create crafting info variables
		app.QuickOrderRecipeID = recipeID
		local reagentInfo = {}
		local craftingReagentInfo = {}

		-- Signal that PSL is currently working on a quick order
		app.Flag["quickOrder"] = 1

		local function localReagentsOrder()
			-- Cache reagent tier info
			local _ = {}
			app.GetReagents(_, recipeID, 1, false)

			-- Get recipe info
			local recipeInfo = C_TradeSkillUI.GetRecipeSchematic(recipeID, false).reagentSlotSchematics
			
			-- Go through all the reagents for this recipe
			local no1 = 1
			local no2 = 1
			for i, _ in ipairs(recipeInfo) do
				if recipeInfo[i].reagentType == 1 then
					-- Get the required quantity
					local quantityNo = recipeInfo[i].quantityRequired

					-- Get the primary reagent itemID
					local reagentID = recipeInfo[i].reagents[1].itemID

					-- Add the info for tiered reagents to craftingReagentItems
					if ProfessionShoppingList_Cache.ReagentTiers[reagentID].three ~= 0 then
						-- Set it to the lowest quality we have enough of for this order
						if C_Item.GetItemCount(ProfessionShoppingList_Cache.ReagentTiers[reagentID].one, true, false, true, true) >= quantityNo then
							craftingReagentInfo[no1] = {itemID = ProfessionShoppingList_Cache.ReagentTiers[reagentID].one, dataSlotIndex = i, quantity = quantityNo}
							no1 = no1 + 1
						elseif C_Item.GetItemCount(ProfessionShoppingList_Cache.ReagentTiers[reagentID].two, true, false, true, true) >= quantityNo then
							craftingReagentInfo[no1] = {itemID = ProfessionShoppingList_Cache.ReagentTiers[reagentID].two, dataSlotIndex = i, quantity = quantityNo}
							no1 = no1 + 1
						elseif C_Item.GetItemCount(ProfessionShoppingList_Cache.ReagentTiers[reagentID].three, true, false, true, true) >= quantityNo then
							craftingReagentInfo[no1] = {itemID = ProfessionShoppingList_Cache.ReagentTiers[reagentID].three, dataSlotIndex = i, quantity = quantityNo}
							no1 = no1 + 1
						end
					-- Add the info for non-tiered reagents to reagentItems
					else
						if C_Item.GetItemCount(reagentID, true, false, true, true) >= quantityNo then
							reagentInfo[no2] = {itemID = ProfessionShoppingList_Cache.ReagentTiers[reagentID].one, quantity = quantityNo}
							no2 = no2 + 1
						end
					end
				end
			end
		end

		-- Only add the reagentInfo if the option is enabled
		if ProfessionShoppingList_Settings["useLocalReagents"] == true then localReagentsOrder() end

		-- Signal that PSL is currently working on a quick order with tiered local reagents, if applicable
		local next = next
		if next(craftingReagentInfo) ~= nil and ProfessionShoppingList_Settings["useLocalReagents"] == true then
			app.Flag["quickOrder"] = 2
		end

		-- Place a guild order if the recipient is "GUILD"
		local typeOrder = 2
		if ProfessionShoppingList_CharacterData.Orders[recipeID] == "GUILD" then
			typeOrder = 1
		end

		-- Place the order
		C_CraftingOrders.PlaceNewOrder({ skillLineAbilityID=ProfessionShoppingList_Library[recipeID].abilityID, orderType=typeOrder, orderDuration=ProfessionShoppingList_Settings["quickOrderDuration"], tipAmount=100, customerNotes="", orderTarget=ProfessionShoppingList_CharacterData.Orders[recipeID], reagentItems=reagentInfo, craftingReagentItems=craftingReagentInfo })
		
		-- If there are tiered reagents and the user wants to use local reagents, adjust the dataSlotIndex and try again in case the first one failed
		local next = next
		if next(craftingReagentInfo) ~= nil and ProfessionShoppingList_Settings["useLocalReagents"] == true then
			for i, _ in ipairs(craftingReagentInfo) do
				craftingReagentInfo[i].dataSlotIndex = math.max(craftingReagentInfo[i].dataSlotIndex - 1, 0)
			end

			-- Place the alternative order (only one can succeed, worst case scenario it'll fail again)
			C_CraftingOrders.PlaceNewOrder({ skillLineAbilityID=ProfessionShoppingList_Library[recipeID].abilityID, orderType=typeOrder, orderDuration=ProfessionShoppingList_Settings["quickOrderDuration"], tipAmount=100, customerNotes="", orderTarget=ProfessionShoppingList_CharacterData.Orders[recipeID], reagentItems=reagentInfo, craftingReagentItems=craftingReagentInfo })
		
			for i, _ in ipairs(craftingReagentInfo) do
				craftingReagentInfo[i].dataSlotIndex = math.max(craftingReagentInfo[i].dataSlotIndex - 1, 0)
			end

			-- Place the alternative order (only one can succeed, worst case scenario it'll fail again)
			C_CraftingOrders.PlaceNewOrder({ skillLineAbilityID=ProfessionShoppingList_Library[recipeID].abilityID, orderType=typeOrder, orderDuration=ProfessionShoppingList_Settings["quickOrderDuration"], tipAmount=100, customerNotes="", orderTarget=ProfessionShoppingList_CharacterData.Orders[recipeID], reagentItems=reagentInfo, craftingReagentItems=craftingReagentInfo })
		
			for i, _ in ipairs(craftingReagentInfo) do
				craftingReagentInfo[i].dataSlotIndex = math.max(craftingReagentInfo[i].dataSlotIndex - 1, 0)
			end

			-- Place the alternative order (only one can succeed, worst case scenario it'll fail again)
			C_CraftingOrders.PlaceNewOrder({ skillLineAbilityID=ProfessionShoppingList_Library[recipeID].abilityID, orderType=typeOrder, orderDuration=ProfessionShoppingList_Settings["quickOrderDuration"], tipAmount=100, customerNotes="", orderTarget=ProfessionShoppingList_CharacterData.Orders[recipeID], reagentItems=reagentInfo, craftingReagentItems=craftingReagentInfo })
		end
	end

	-- Create the place crafting orders personal order button
	if not app.QuickOrderButton then
		app.QuickOrderButton = app.Button(ProfessionsCustomerOrdersFrame.Form, "Quick Order")
		app.QuickOrderButton:SetPoint("CENTER", app.QuickOrderTargetBox, "CENTER", 0, 0)
		app.QuickOrderButton:SetPoint("RIGHT", app.QuickOrderTargetBox, "LEFT", -8, 0)
		app.QuickOrderButton:SetScript("OnClick", function()
			quickOrder(app.SelectedRecipeID)
		end)
		app.QuickOrderButton:SetScript("OnEnter", function()
			app.QuickOrderTooltip:Show()
		end)
		app.QuickOrderButton:SetScript("OnLeave", function()
			app.QuickOrderTooltip:Hide()
		end)
	end

	-- Create the place crafting orders personal order button tooltip
	if not app.QuickOrderTooltip then
		app.QuickOrderTooltip = CreateFrame("Frame", nil, app.QuickOrderButton, "BackdropTemplate")
		app.QuickOrderTooltip:SetPoint("CENTER")
		app.QuickOrderTooltip:SetPoint("TOP", app.QuickOrderButton, "BOTTOM", 0, 0)
		app.QuickOrderTooltip:SetFrameStrata("TOOLTIP")
		app.QuickOrderTooltip:SetBackdrop({
			bgFile = "Interface/Tooltips/UI-Tooltip-Background",
			edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
			edgeSize = 16,
			insets = { left = 4, right = 4, top = 4, bottom = 4 },
		})

		app.QuickOrderTooltip:SetBackdropColor(0, 0, 0, 0.9)
		app.QuickOrderTooltip:EnableMouse(false)
		app.QuickOrderTooltip:SetMovable(false)
		app.QuickOrderTooltip:Hide()

		personalOrderTooltipText = app.QuickOrderTooltip:CreateFontString("ARTWORK", nil, "GameFontNormal")
		personalOrderTooltipText:SetPoint("TOPLEFT", app.QuickOrderTooltip, "TOPLEFT", 10, -10)
		personalOrderTooltipText:SetJustifyH("LEFT")
		personalOrderTooltipText:SetText("|cffFF0000Instantly|r create a crafting order for the specified recipient.\n\nUse |cffFFFFFFGUILD|r (all uppercase) to place a Guild Order.\nUse a character name to place a Personal Order.\nRecipients are saved per recipe.\n\nIf the button is |cff9D9D9Dgreyed|r out, you need to cache the profession\nand/or enter a valid recipient to send the order to.")

		-- Set the tooltip size to fit its contents
		app.QuickOrderTooltip:SetHeight(personalOrderTooltipText:GetStringHeight()+20)
		app.QuickOrderTooltip:SetWidth(personalOrderTooltipText:GetStringWidth()+20)
	end

	-- Create the local reagents checkbox
	if not app.LocalReagentsCheckbox then
		app.LocalReagentsCheckbox = CreateFrame("CheckButton", nil, ProfessionsCustomerOrdersFrame.Form, "InterfaceOptionsCheckButtonTemplate")
		app.LocalReagentsCheckbox.Text:SetText("Use local reagents")
		app.LocalReagentsCheckbox.Text:SetTextColor(1, 1, 1, 1)
		app.LocalReagentsCheckbox.Text:SetScale(1.2)
		app.LocalReagentsCheckbox:SetPoint("BOTTOMLEFT", app.QuickOrderButton, "TOPLEFT", 0, 0)
		app.LocalReagentsCheckbox:SetFrameStrata("HIGH")
		app.LocalReagentsCheckbox:SetChecked(ProfessionShoppingList_Settings["useLocalReagents"])
		app.LocalReagentsCheckbox:SetScript("OnClick", function(self)
			ProfessionShoppingList_Settings["useLocalReagents"] = self:GetChecked()

			if ProfessionShoppingList_CharacterData.Orders["last"] ~= nil and ProfessionShoppingList_CharacterData.Orders["last"] ~= 0 then
				local reagents = "false"
				local recipient = ProfessionShoppingList_CharacterData.Orders[ProfessionShoppingList_CharacterData.Orders["last"]]
				if ProfessionShoppingList_Settings["useLocalReagents"] == true then reagents = "true" end
				app.RepeatQuickOrderTooltipText:SetText("Repeat the last Quick Order done on this character.\nRecipient: "..recipient.."\nUse local reagents: "..reagents)
				app.RepeatQuickOrderTooltip:SetHeight(app.RepeatQuickOrderTooltipText:GetStringHeight()+20)
				app.RepeatQuickOrderTooltip:SetWidth(app.RepeatQuickOrderTooltipText:GetStringWidth()+20)
			end
		end)
		app.LocalReagentsCheckbox:SetScript("OnEnter", function()
			app.LocalReagentsTooltip:Show()
		end)
		app.LocalReagentsCheckbox:SetScript("OnLeave", function()
			app.LocalReagentsTooltip:Hide()
		end)
	end

	-- Create the local reagents tooltip
	if not app.LocalReagentsTooltip then
		app.LocalReagentsTooltip = CreateFrame("Frame", nil, app.LocalReagentsCheckbox, "BackdropTemplate")
		app.LocalReagentsTooltip:SetPoint("CENTER")
		app.LocalReagentsTooltip:SetPoint("TOP", app.LocalReagentsCheckbox, "BOTTOM", 0, 0)
		app.LocalReagentsTooltip:SetFrameStrata("TOOLTIP")
		app.LocalReagentsTooltip:SetBackdrop({
			bgFile = "Interface/Tooltips/UI-Tooltip-Background",
			edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
			edgeSize = 16,
			insets = { left = 4, right = 4, top = 4, bottom = 4 },
		})
		app.LocalReagentsTooltip:SetBackdropColor(0, 0, 0, 0.9)
		app.LocalReagentsTooltip:EnableMouse(false)
		app.LocalReagentsTooltip:SetMovable(false)
		app.LocalReagentsTooltip:Hide()

		useLocalReagentsTooltipText = app.LocalReagentsTooltip:CreateFontString("ARTWORK", nil, "GameFontNormal")
		useLocalReagentsTooltipText:SetPoint("TOPLEFT", app.LocalReagentsTooltip, "TOPLEFT", 10, -10)
		useLocalReagentsTooltipText:SetJustifyH("LEFT")
		useLocalReagentsTooltipText:SetText("Use (the lowest quality) available local reagents.\nWhich reagents are used |cffFF0000cannot|r be customised.")

		-- Set the tooltip size to fit its contents
		app.LocalReagentsTooltip:SetHeight(useLocalReagentsTooltipText:GetStringHeight()+20)
		app.LocalReagentsTooltip:SetWidth(useLocalReagentsTooltipText:GetStringWidth()+20)
	end

	-- Create the repeat last crafting order button
	if not app.RepeatQuickOrderButton then
		app.RepeatQuickOrderButton = app.Button(ProfessionsCustomerOrdersFrame, "")
		app.RepeatQuickOrderButton:SetPoint("BOTTOMLEFT", ProfessionsCustomerOrdersFrame, 170, 5)
		app.RepeatQuickOrderButton:SetScript("OnClick", function()
			if ProfessionShoppingList_CharacterData.Orders["last"] ~= nil and ProfessionShoppingList_CharacterData.Orders["last"] ~= 0 then
				quickOrder(ProfessionShoppingList_CharacterData.Orders["last"])
				ProfessionsCustomerOrdersFrame.MyOrdersPage:RefreshOrders()
			else
				app.Print("No last Quick Order found.")
			end
		end)
		app.RepeatQuickOrderButton:SetScript("OnEnter", function()
			app.RepeatQuickOrderTooltip:Show()
		end)
		app.RepeatQuickOrderButton:SetScript("OnLeave", function()
			app.RepeatQuickOrderTooltip:Hide()
		end)

		-- Set the last used recipe name for the repeat order button title
		local recipeName = "No last Quick Order found"
		-- Check for the name if there has been a last order
		if ProfessionShoppingList_CharacterData.Orders["last"] ~= nil and ProfessionShoppingList_CharacterData.Orders["last"] ~= 0 then
			recipeName = C_TradeSkillUI.GetRecipeSchematic(ProfessionShoppingList_CharacterData.Orders["last"], false).name
		end
		app.RepeatQuickOrderButton:SetText(recipeName)
		app.RepeatQuickOrderButton:SetWidth(app.RepeatQuickOrderButton:GetTextWidth()+20)
	end

	-- Create the local reagents tooltip
	if not app.RepeatQuickOrderTooltip then
		app.RepeatQuickOrderTooltip = CreateFrame("Frame", nil, app.RepeatQuickOrderButton, "BackdropTemplate")
		app.RepeatQuickOrderTooltip:SetPoint("CENTER")
		app.RepeatQuickOrderTooltip:SetPoint("TOP", app.RepeatQuickOrderButton, "BOTTOM", 0, 0)
		app.RepeatQuickOrderTooltip:SetFrameStrata("TOOLTIP")
		app.RepeatQuickOrderTooltip:SetBackdrop({
			bgFile = "Interface/Tooltips/UI-Tooltip-Background",
			edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
			edgeSize = 16,
			insets = { left = 4, right = 4, top = 4, bottom = 4 },
		})
		app.RepeatQuickOrderTooltip:SetBackdropColor(0, 0, 0, 0.9)
		app.RepeatQuickOrderTooltip:EnableMouse(false)
		app.RepeatQuickOrderTooltip:SetMovable(false)
		app.RepeatQuickOrderTooltip:Hide()

		app.RepeatQuickOrderTooltipText = app.RepeatQuickOrderTooltip:CreateFontString("ARTWORK", nil, "GameFontNormal")
		app.RepeatQuickOrderTooltipText:SetPoint("TOPLEFT", app.RepeatQuickOrderTooltip, "TOPLEFT", 10, -10)
		app.RepeatQuickOrderTooltipText:SetJustifyH("LEFT")
		if ProfessionShoppingList_CharacterData.Orders["last"] ~= nil and ProfessionShoppingList_CharacterData.Orders["last"] ~= 0 then
			local reagents = "false"
			local recipient = ProfessionShoppingList_CharacterData.Orders[ProfessionShoppingList_CharacterData.Orders["last"]]
			if ProfessionShoppingList_Settings["useLocalReagents"] == true then reagents = "true" end
			app.RepeatQuickOrderTooltipText:SetText("Repeat the last Quick Order done on this character.\nRecipient: "..recipient.."\nUse local reagents: "..reagents)
		else
			app.RepeatQuickOrderTooltipText:SetText("Repeat the last Quick Order done on this character.")
		end
		
		-- Set the tooltip size to fit its contents
		app.RepeatQuickOrderTooltip:SetHeight(app.RepeatQuickOrderTooltipText:GetStringHeight()+20)
		app.RepeatQuickOrderTooltip:SetWidth(app.RepeatQuickOrderTooltipText:GetStringWidth()+20)
	end

	-- Set the flag for assets created to true
	app.Flag["craftingOrderAssets"] = true
end

-- When the AddOn is fully loaded, actually run the components
app.Event:Register("ADDON_LOADED", function(addOnName, containsBindings)
	if addOnName == appName then
		app.InitialiseCraftingOrders()
	end
end)

---------------------
-- CRAFTING ORDERS --
---------------------

-- When opening the crafting orders window
app.Event:Register("CRAFTINGORDERS_SHOW_CUSTOMER", function()
	app.CreateCraftingOrdersAssets()
end)

-- When closing the crafting orders window
app.Event:Register("CRAFTINGORDERS_HIDE_CUSTOMER", function()
	app.Flag["recraft"] = false
end)

-- When fulfilling an order
app.Event:Register("CRAFTINGORDERS_FULFILL_ORDER_RESPONSE", function(result, orderID)
	if ProfessionShoppingList_Settings["removeCraft"] == true then
		for k, v in pairs (ProfessionShoppingList_Data.Recipes) do
			if tonumber(string.match(k, ":(%d+):")) == orderID then
				-- Remove 1 tracked recipe when it has been crafted (if the option is enabled)
				app.UntrackRecipe(k, 1)
				break
			end
		end

		-- Close window if no recipes are left and the option is enabled
		local next = next
		if next(ProfessionShoppingList_Data.Recipes) == nil and ProfessionShoppingList_Settings["closeWhenDone"] then
			app.Window:Hide()
		end
	end
end)

------------------
-- QUICK ORDERS --
------------------

-- If placing a crafting order through PSL
app.Event:Register("CRAFTINGORDERS_ORDER_PLACEMENT_RESPONSE", function(result)
	if app.Flag["quickOrder"] >= 1 then
		-- Count a(nother) quick order attempt
		app.QuickOrderAttempts = app.QuickOrderAttempts + 1
		
		-- If this gives an error
		if result ~= 0 then
			-- Count a(nother) error for the quick order attempt
			app.QuickOrderErrors = app.QuickOrderErrors + 1

			-- Hide the error frame
			UIErrorsFrame:Hide()

			-- Clear the error frame before showing it again
			C_Timer.After(1.0, function() UIErrorsFrame:Clear() UIErrorsFrame:Show() end)

			-- If all 4 attempts fail, tell the user this
			if app.QuickOrderErrors >= 4 then
				app.Print("Quick order failed. Sorry. :(")
			end
		end
		-- Separate error messages
		if result == 29 then
			app.Print("Can't create a quick order for items with mandatory reagents. Sorry. :(")
		elseif result == 34 then
			app.Print("Can't create a quick order with items in the Warbank.")
		elseif result == 37 then
			app.Print("Cannot place a guild order while not in a guild.")
		elseif result == 40 then
			app.Print("Target recipient cannot craft that item. Please enter a valid recipient name.")
		end

		-- Save this info as the last order done, unless it was a failed order
		if (result ~= 29 and result ~= 34 and result ~= 37 and result ~= 40) or app.QuickOrderErrors >= 4 then ProfessionShoppingList_CharacterData.Orders["last"] = app.QuickOrderRecipeID end

		-- Set the last used recipe name for the repeat order button title
		local recipeName = "No last order found"
		-- Check for the name if there has been a last order
		if ProfessionShoppingList_CharacterData.Orders["last"] ~= nil and ProfessionShoppingList_CharacterData.Orders["last"] ~= 0 then
			recipeName = C_TradeSkillUI.GetRecipeSchematic(ProfessionShoppingList_CharacterData.Orders["last"], false).name

			local reagents = "false"
			local recipient = ProfessionShoppingList_CharacterData.Orders[ProfessionShoppingList_CharacterData.Orders["last"]]
			if ProfessionShoppingList_Settings["useLocalReagents"] == true then reagents = "true" end
			app.RepeatQuickOrderTooltipText:SetText("Repeat the last Quick Order done on this character.\nRecipient: "..recipient.."\nUse local reagents: "..reagents)
			app.RepeatQuickOrderTooltip:SetHeight(app.RepeatQuickOrderTooltipText:GetStringHeight()+20)
			app.RepeatQuickOrderTooltip:SetWidth(app.RepeatQuickOrderTooltipText:GetStringWidth()+20)
		end
		app.RepeatQuickOrderButton:SetText(recipeName)
		app.RepeatQuickOrderButton:SetWidth(app.RepeatQuickOrderButton:GetTextWidth()+20)

		-- Reset all the numbers if we're done
		if (app.Flag["quickOrder"] == 1 and app.QuickOrderAttempts >= 1) or (app.Flag["quickOrder"] == 2 and app.QuickOrderAttempts >= 4) then
			app.Flag["quickOrder"] = 0
			app.QuickOrderAttempts = 0
			app.QuickOrderErrors = 0
		end
	end
end)