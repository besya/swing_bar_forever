local secretwrap = secretwrap;
local ShouldUnitSpellCastingBeSecret = C_Secrets.ShouldUnitSpellCastingBeSecret;

local function WrapValueInSpellCastSecrecy(unitToken, value)
	if unitToken ~= nil and ShouldUnitSpellCastingBeSecret(unitToken) then
		return secretwrap(value);
	end

	return value;
end

Player = {};

SwingTypeSlotIDs = {
	[0] = INVSLOT_MAINHAND,
	[1] = INVSLOT_OFFHAND,
	[2] = INVSLOT_RANGED
};

-- Swing bar type
SwingBarType = {
	Standard = "standard",
	Interrupted = "interrupted",
};

-- Visual config for each SwingBarType.
SwingBarTypeInfo = {
	[SwingBarType.Standard] = {
		filling = "ui-castingbar-filling-standard",
		full = "ui-castingbar-full-standard",
		glow = "ui-castingbar-full-glow-standard",
		sparkFx = "StandardGlow",
		finishAnim = "StandardFinish",
		classicFillColor = CASTBAR_CLASSIC_YELLOW,
		classicFullColor = CASTBAR_CLASSIC_GREEN,
	},
	[SwingBarType.Interrupted] = {
		filling = "ui-castingbar-interrupted",
		full = "ui-castingbar-interrupted",
		glow = "ui-castingbar-full-glow-standard",
		classicFillColor = CASTBAR_CLASSIC_RED,
		classicFullColor = CASTBAR_CLASSIC_RED,
	},
};

SwingBarMixin = {};

--[[
	Event Handlers
]]
function SwingBarMixin:OnLoad(unit)
	self:SetUnit(unit);

	self.showSwingbar = true;

	local point, relativeTo, relativePoint, offsetX, offsetY = self.Spark:GetPoint(1);
	if ( point == "CENTER" ) then
		self.Spark.offsetY = offsetY;
	end
end

function SwingBarMixin:OnEvent(event, ...)
	if (event == "PLAYER_SWING") then
		local duration, type = ...;
		self:HandleSwingStart(duration, type);
	elseif ( event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" or event == "UNIT_SPELLCAST_EMPOWER_START" ) then
		self:HandleSwingStop(event);
	end
end

function SwingBarMixin:OnUpdate(elapsed)
	if ( self.swinging ) then
		self.value = self.value + elapsed;

		if ( self.value >= self.maxValue ) then
			self:SetValue(self.maxValue);
			self:UpdateSwingTimeText();
			self:FinishSwing();
			self:HideSpark();
			return;
		end

		self:SetValue(self.value);
		self:UpdateSwingTimeText();

		if ( self.Flash ) then
			self.Flash:Hide();
		end

		if ( self.Spark ) then
			local sparkPosition = (math.max(0, self.value) / self.maxValue) * self:GetWidth();
			self.Spark:SetPoint("CENTER", self, "LEFT", sparkPosition, self.Spark.offsetY or 0);
		end
	end
end

function SwingBarMixin:OnShow()
	if ( self.unit ) then
		if ( self.swinging ) then
			if ( self.startTime ) then
				self.value = (GetTime() - (self.startTime));
			end
		else
			if ( self.endTime ) then
				self.value = ((self.endTime) - GetTime());
			end
		end
	end
end

--[[
	SwingBarType Functions
]]
function SwingBarMixin:GetTypeInfo(barType)
	if not barType then
		barType = SwingBarType.Standard;
	end

	return SwingBarTypeInfo[barType];
end

--[[
	Swing Event Handlers
]]

function SwingBarMixin:HandleSwingStart(duration, type)
	local slotID = SwingTypeSlotIDs[type];
	local weaponItemID = GetInventoryItemID("player", slotID);
	local weaponName = C_Item.GetItemInfo(weaponItemID)
	local text = weaponName;

	self.barType = WrapValueInSpellCastSecrecy(self.unit, SwingBarType.Standard);

	self:ShowSpark();

	self.value = 0.0;
	self.maxValue = duration;
	self.startTime = GetTime();
	self.endTime = self.startTime + duration * 1000;

	self:SetMinMaxValues(0, self.maxValue);
	self:SetValue(self.value);

	-- self:UpdateSwingTimeText();
	if ( self.Text ) then
		self.Text:SetText(text);
	end
	
	-- if ( self.Icon ) then
		-- self.Icon:SetTexture(texture);
	-- end

	self.swinging = true;
	self.type = type;

	-- self:UpdateIconShown();
	self:StopAnims();
	self:ApplyAlpha(1.0);

	-- self:UpdateHighlightImportantCast();
	-- self:UpdateHighlightWhenCastTarget();
	-- self:UpdateTargetNameText();
	-- self:UpdateShownState(self:ShouldShowSwingBar());
	self:Show();
end

function SwingBarMixin:HandleSwingStop(event)
	if ( not self:IsVisible() ) then
		local desiredShowFalse = false;
		self:UpdateShownState(desiredShowFalse);
	end

	if ( (self.swinging and (event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" or event == "UNIT_SPELLCAST_EMPOWER_START")) ) then
		-- if ( not castComplete) then
			-- if ( event == "UNIT_SPELLCAST_EMPOWER_STOP" or event == "UNIT_SPELLCAST_CHANNEL_STOP" ) then
				self:HandleInterruptOrSwingFailed(true, event, 0, nil);
				return;
			-- end
		-- end

		-- Cast info not available once stopped, so update bar based on cached barType
		-- local barTypeInfo = self:GetTypeInfo(self.barType);
		-- self:UpdateBarFillTexture(true);

	
		-- self:HideSpark();


		-- if ( self.Flash ) then
		-- 	if (not self.classicStyleCastBar) then
		-- 		self.Flash:SetAtlas(barTypeInfo.glow);
		-- 	end
		-- 	self.Flash:SetAlpha(0.0);
		-- 	self.Flash:Show();
		-- end

		-- self:SetValue(self.maxValue);
		-- self:UpdateCastTimeText();

		-- self:PlayFadeAnim();
		-- self:PlayFinishAnim();


		-- self.swinging = nil;

	end
end

function SwingBarMixin:HandleInterruptOrSwingFailed(empoweredInterrupt, event, castID, interruptedBy)
	if ( empoweredInterrupt or (self:IsShown() and (self.swinging) and (not self.FadeOutAnim or not self.FadeOutAnim:IsPlaying()))) then
		self.barType = WrapValueInSpellCastSecrecy(self.unit, SwingBarType.Interrupted); -- failed and interrupted use same bar art

		self:UpdateBarFillTexture(true);

		self:ShowSpark();

		if ( self.Text ) then
			if ( event == "UNIT_SPELLCAST_FAILED" ) then
				self.Text:SetText(FAILED);
			else
				self.Text:SetText(INTERRUPTED);
			end
		end

		self.swinging = nil;

		self:PlayInterruptAnims();

		if (self.classicStyleCastBar) then
			-- Mainline has some quirky behavior where
			-- an interrupted cast bar does not fill immediately
			-- but rather waits for the InterruptSparkAnim to finish.
			-- We don't have the InterruptSparkAnim for Classic,
			-- so just fill it immediately. Snappy!
			self:ApplyInterruptFilledState();
		end
	end
end

function SwingBarMixin:FinishSwing()
	if self.maxValue then
		self:SetValue(self.maxValue);
		self:UpdateSwingTimeText();
	end

	local barTypeInfo = self:GetTypeInfo(self.barType);
	self:UpdateBarFillTexture(true);

	self:HideSpark();

	if ( self.Flash ) then
		if (not self.classicStyleCastBar) then
			self.Flash:SetAtlas(barTypeInfo.glow);
		end
		self.Flash:SetAlpha(0.0);
		self.Flash:Show();
	end

	self:PlayFadeAnim();
	self:PlayFinishAnim();

	self.swinging = nil;
end

--[[
	State Management and Visibility
]]
function SwingBarMixin:SetUnit(unit)
	if self.unit ~= unit then
		self.unit = unit;

		self.swinging = nil;

		self:StopAnims();

		if unit then
			self:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", unit);
			self:RegisterUnitEvent("UNIT_SPELLCAST_DELAYED", unit);
			self:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", unit);
			self:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_UPDATE", unit);
			self:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", unit);
			self:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_START", unit);
			self:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_UPDATE", unit);
			self:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_STOP", unit);
			self:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTIBLE", unit);
			self:RegisterUnitEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE", unit);
			self:RegisterUnitEvent("UNIT_SPELLCAST_START", unit);
			self:RegisterUnitEvent("UNIT_SPELLCAST_STOP", unit);
			self:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", unit);
			self:RegisterEvent("PLAYER_ENTERING_WORLD");
			self:RegisterEvent("PLAYER_SWING");

			self:OnEvent("PLAYER_ENTERING_WORLD")
		else
			self:UnregisterEvent("UNIT_SPELLCAST_INTERRUPTED");
			self:UnregisterEvent("UNIT_SPELLCAST_DELAYED");
			self:UnregisterEvent("UNIT_SPELLCAST_CHANNEL_START");
			self:UnregisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE");
			self:UnregisterEvent("UNIT_SPELLCAST_CHANNEL_STOP");
			self:UnregisterEvent("UNIT_SPELLCAST_EMPOWER_START");
			self:UnregisterEvent("UNIT_SPELLCAST_EMPOWER_UPDATE");
			self:UnregisterEvent("UNIT_SPELLCAST_EMPOWER_STOP");
			self:UnregisterEvent("UNIT_SPELLCAST_INTERRUPTIBLE");
			self:UnregisterEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE");
			self:UnregisterEvent("UNIT_SPELLCAST_START");
			self:UnregisterEvent("UNIT_SPELLCAST_STOP");
			self:UnregisterEvent("UNIT_SPELLCAST_FAILED");
			self:UnregisterEvent("PLAYER_ENTERING_WORLD");
			self:UnregisterEvent("PLAYER_SWING");

			local desiredShowFalse = false;
			self:UpdateShownState(desiredShowFalse);
		end
	end
end

function SwingBarMixin:ShouldShowSwingBar()
	return self.showSwingbar and (self.unit ~= nil);
end

function SwingBarMixin:SetAndUpdateShowSwingbar(showSwingbar)
	self.showSwingbar = showSwingbar;
	self:UpdateIsShown();
end

function SwingBarMixin:UpdateIsShown()
	if ( self.swinging and self:ShouldShowSwingBar() ) then
		self:OnEvent("PLAYER_ENTERING_WORLD")
	else
		local desiredShowFalse = false;
		self:UpdateShownState(desiredShowFalse);
	end
end

function SwingBarMixin:UpdateShownState(desiredShow)
	if (self == PlayerSwingBarFrame) and not GameRulesUtil.ShouldShowPlayerCastBar() then
		desiredShow = false;
	end

	self:UpdateSwingTimeTextShown();

	if self.isInEditMode then
		-- If we are in edit mode then override and just show
		self:StopFinishAnims();
		self:ApplyAlpha(1.0);
		self:Show();
		return;
	end

	if desiredShow ~= nil then
		self:SetShown(desiredShow);
		return;
	end

	self:SetShown(self.swinging and self:ShouldShowSwingBar());
end

--[[
	Bar Fill Texture
]]
function SwingBarMixin:UpdateBarFillTexture(isFull)
	local barType = self.barType or SwingBarType.Standard;
	local barTypeInfo = self:GetTypeInfo(barType);

	if (self.classicStyleCastBar) then
		-- For Classic style, set the vertex color based on bar type.
		local colorInfo = isFull and barTypeInfo.classicFullColor or barTypeInfo.classicFillColor;
		self:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar");
		self:SetStatusBarColor(colorInfo:GetRGB());
	else
		-- Look up the appropriate atlas based on bar type.
		local texture = isFull and barTypeInfo.full or barTypeInfo.filling;
		self:SetStatusBarTexture(texture);
		self:SetStatusBarColor(1, 1, 1);
	end
end

--[[
	Animations and FX
]]
function SwingBarMixin:ApplyAlpha(alpha)
	self:SetAlpha(alpha);
	if self.additionalFadeWidgets then
		for widget in pairs(self.additionalFadeWidgets) do
			widget:SetAlpha(alpha);
		end
	end
end

function SwingBarAnim_OnInterruptSparkAnimFinish(self)
	local swingBar = self:GetParent();
	swingBar:ApplyInterruptFilledState();
end

function SwingBarMixin:ApplyInterruptFilledState()
	self:SetValue(self.maxValue);
	self:UpdateSwingTimeText();
	self:HideSpark();
end

function SwingBarMixin:ShowSpark()
	if ( self.Spark ) then
		self.Spark:Show();
	end

	local currentBarType = self.barType;

	if not self.classicStyleCastBar then -- Classic Style uses a static Spark texture.
		if currentBarType == SwingBarType.Interrupted then
			self.Spark:SetAtlas("ui-castingbar-pip-red");
			self.Spark.offsetY = 0;
		elseif currentBarType == SwingBarType.Empowered then
			self.Spark:SetAtlas("ui-castingbar-empower-cursor");
			self.Spark.offsetY = 4;
		else
			self.Spark:SetAtlas("ui-castingbar-pip");
			self.Spark.offsetY = 0;
		end
	end

	for barType, barTypeInfo in pairs(SwingBarTypeInfo) do
		local sparkFx = barTypeInfo.sparkFx and self[barTypeInfo.sparkFx];
		if sparkFx then
			sparkFx:SetShown(self.playCastFX and barType == currentBarType);
		end
	end
end

function SwingBarMixin:HideSpark()
	if ( self.Spark ) then
		self.Spark:Hide();
	end

	for barType, barTypeInfo in pairs(SwingBarTypeInfo) do
		local sparkFx = barTypeInfo.sparkFx and self[barTypeInfo.sparkFx];
		if sparkFx then
			sparkFx:Hide();
		end
	end
end

function SwingBarMixin:PlayInterruptAnims()
	if self.HoldFadeOutAnim then
		self.HoldFadeOutAnim:Play();
	end

	if not self.playCastFX then
		return;
	end

	if self.InterruptShakeAnim and tonumber(GetCVar("ShakeStrengthUI")) > 0 then
		self.InterruptShakeAnim:Play();
	end
	if self.InterruptGlowAnim then
		self.InterruptGlowAnim:Play();
	end
	if self.InterruptSparkAnim then
		self.InterruptSparkAnim:Play();
	end
end

function SwingBarMixin:StopInterruptAnims()
	if self.HoldFadeOutAnim then
		self.HoldFadeOutAnim:Stop();
	end
	if self.InterruptShakeAnim then
		self.InterruptShakeAnim:Stop();
	end
	if self.InterruptGlowAnim then
		self.InterruptGlowAnim:Stop();
	end
	if self.InterruptSparkAnim then
		self.InterruptSparkAnim:Stop();
	end
end

function SwingBarMixin:PlayFadeAnim()
	if self.FlashLoopingAnim then
		self.FlashLoopingAnim:Stop();
	end

	if self.FlashAnim then
		self.FlashAnim:Play();
	end

	if self.FadeOutAnim and self:GetAlpha() > 0 and self:IsVisible() then
		if self.reverseChanneling and self.CurrSpellStage < self.NumStages then
			self.HoldFadeOutAnim:Play();
		elseif not self.isInEditMode then
			self.FadeOutAnim:Play();
		end
	end
end

function SwingBarMixin:PlayFinishAnim()
	if not self.playCastFX then
		return;
	end

	local barTypeInfo = self:GetTypeInfo(self.barType);

	local playFinish = not barTypeInfo.finishCondition or barTypeInfo.finishCondition(self);
	if playFinish then
		local finishAnim = barTypeInfo.finishAnim and self[barTypeInfo.finishAnim];
		if finishAnim then
			finishAnim:Play();
		end
	end

	if self.barType == SwingBarType.Empowered then
		for i = 1, self.CurrSpellStage do
			local stageTier = self.StageTiers[i];
			if stageTier and stageTier.FinishAnim then
				stageTier.FlashAnim:Stop();
				stageTier.FinishAnim:Play();
			end
		end
	end
end

function SwingBarMixin:StopFinishAnims()
	if self.FlashAnim then
		self.FlashAnim:Stop();
	end
	if self.FadeOutAnim then
		self.FadeOutAnim:Stop();
	end

	for _, barTypeInfo in pairs(SwingBarTypeInfo) do
		local finishAnim = barTypeInfo.finishAnim and self[barTypeInfo.finishAnim];
		if finishAnim then
			finishAnim:Stop();
		end
	end
end

function SwingBarMixin:StopAnims()
	self:StopInterruptAnims();
	self:StopFinishAnims();
end

--[[
	Name Text
]]
function SwingBarMixin:SetNameTextShown(showNameText)
	if not self.Text then
		return;
	end

	self.Text:SetShown(showNameText);
end

--[[
	Swing Time Text
]]
function SwingBarMixin:SetSwingTimeTextShown(showSwingTime)
	self.showSwingTimeSetting = showSwingTime;
	self:UpdateSwingTimeTextShown();
end

function SwingBarMixin:UpdateSwingTimeTextShown()
	if not self.SwingTimeText then
		return;
	end

	local showSwingTime = self.showSwingTimeSetting and self.swinging or self.isInEditMode;
	self.SwingTimeText:SetShown(showSwingTime);
	if showSwingTime and self.isInEditMode and not self.SwingTimeText.text then
		self:UpdateSwingTimeText();
	end
end

function SwingBarMixin:UpdateSwingTimeText()
	if not self.SwingTimeText then
		return;
	end

	local seconds = 0;
	if self.swinging then
		local min, max = self:GetMinMaxValues();
		if self.swinging then
			seconds = math.max(min, max - self:GetValue());
		else
			seconds = math.max(min, self:GetValue());
		end
	elseif self.isInEditMode then
		seconds = 10;
	end

	local text = string.format(SWING_BAR_CAST_TIME, seconds);
	self.SwingTimeText:SetText(text);
end


PlayerSwingBarMixin = {};

function PlayerSwingBarMixin:OnLoad()
	SwingBarMixin.OnLoad(self, "player");
end

function PlayerSwingBarMixin:IsAttachedToPlayerFrame()
	-- return self.attachedToPlayerFrame;
end

function PlayerSwingBarMixin:OnEvent(...)
	if not InputUtil.IsGamepadUIEnabled() then
		SwingBarMixin.OnEvent(self, ...)
	end
end

PlayerSwingBarFrameMixin = {};

function PlayerSwingBarFrameMixin:OnShow()
	SwingBarMixin.OnShow(self);
	ManagedFrameMixin.OnShow(self);
end

-- Gamepad UI specific overrides
GamepadPlayerSwingBarFrameMixin = {};

function GamepadPlayerSwingBarFrameMixin:OnEvent(...)
	if InputUtil.IsGamepadUIEnabled() then
		SwingBarMixin.OnEvent(self, ...)
	end
end

-- Alternate Player Swing Bar for use over frames whose content triggers contextual player casts
OverlayPlayerSwingBarMixin = {};

function OverlayPlayerSwingBarMixin:OnLoad()
	-- local showTradeSkills = true;
	-- local showShieldNo = false;
	-- WeaponBarMixin.OnLoad(self, "player", showTradeSkills, showShieldNo);
	-- self.Icon:Hide();
	-- self.showCastbar = false;
end