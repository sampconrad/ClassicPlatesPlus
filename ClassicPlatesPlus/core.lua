----------------------------------------
-- Core
----------------------------------------
local _, core = ...;

core.func = {};
core.data = {
    colors = {
        border = {r = 0.75, g = 0.60, b = 0, a = 1},
        blue   = {r = 0.0,  g = 0.75, b = 1},
        green  = {r = 0,    g = 1,    b = 0},
        yellow = {r = 1,    g = 0.90, b = 0},
        orange = {r = 1,    g = 0.5,  b = 0},
        red    = {r = 1,    g = 0,    b = 0},
        purple = {r = 1,    g = 0.3,  b = 1},
    },
    tanks = {},
    members = {},
    tickers = {},
    nameplates = {},
    myTarget = {},
    isClassic = WOW_PROJECT_ID == WOW_PROJECT_CLASSIC,
    isRetail  = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE,
    isWrath   = WOW_PROJECT_ID == WOW_PROJECT_WRATH_CLASSIC,
    cvars = {},
    classBarHeight = 0,
    hooks = {}
};

local func = core.func;
local data = core.data;

----------------------------------------
-- CVars
----------------------------------------
function func:CVars(event)
    if event == "VARIABLES_LOADED" then

        -- Storing settings we are going to use frequently
        data.cvars.nameplateHideHealthAndPower = tostring(GetCVar("nameplateHideHealthAndPower"));
        data.cvars.nameplateShowFriendlyBuffs = tostring(GetCVar("nameplateShowFriendlyBuffs"));
        data.cvars.nameplateResourceOnTarget = tostring(GetCVar("nameplateResourceOnTarget"));
        data.cvars.nameplateShowSelf = tostring(GetCVar("nameplateShowSelf"));
        data.cvars.NamePlateVerticalScale = tostring(GetCVar("NamePlateVerticalScale"));

        -- Distance
        SetCVar("nameplateMinScale", data.isClassic and 1 or Config.ScaleWithDistance and 0.8 or 1);
        SetCVar("nameplateMaxScale", 1.0);
        SetCVar("nameplateMinScaleDistance", 10);
        SetCVar("nameplateMaxScaleDistance", 10);
        SetCVar("nameplateMinAlpha", 1);

        -- Selected
        SetCVar("nameplateNotSelectedAlpha", 1.0);
        SetCVar("nameplateSelectedAlpha", 1.0);
        SetCVar("nameplateSelectedScale", Config.EnlargeSelected and 1.2 or not Config.EnlargeSelected and 1);

        -- Inset
        local classPowerScale = data.isRetail and 0 or Config.ClassPowerScale;
        SetCVar("nameplateOtherTopInset", .08 * Config.NameplatesScale + (.024 * Config.AurasScale) + (0.018 * classPowerScale));

        -- Nameplates size
        SetCVar("nameplateGlobalScale", Config.NameplatesScale);

        -- Rest
        SetCVar("nameplateTargetRadialPosition", 2);
        SetCVar("clampTargetNameplateToScreen", 1);

    elseif event == "PLAYER_LOGOUT" then

        -- Distance
        SetCVar("nameplateMinScale", 1.0);
        SetCVar("nameplateMaxScale", 1.0);
        SetCVar("nameplateMinScaleDistance", 10);
        SetCVar("nameplateMaxScaleDistance", 10);
        SetCVar("nameplateMinAlpha", 0.6);

        -- Selected
        SetCVar("nameplateNotSelectedAlpha", 0.5);
        SetCVar("nameplateSelectedAlpha", 1.0);
        SetCVar("nameplateSelectedScale", 1.0);

        -- Inset
        SetCVar("nameplateOtherTopInset", .08);

        -- Nameplates size
        SetCVar("nameplateGlobalScale", 1.0);

        -- Rest
        SetCVar("nameplateTargetRadialPosition", 0);
        SetCVar("clampTargetNameplateToScreen", 0);
    end
end

----------------------------------------
-- Update CVars
----------------------------------------
function func:Update_CVars(cvarName, value)
    if cvarName == "nameplateHideHealthAndPower"
    or cvarName == "nameplateResourceOnTarget"
    or cvarName == "nameplateShowSelf"
    then
        data.cvars[cvarName] = value;
        func:PersonalNameplateAdd(cvarName, value);
        func:Update_Auras("player");
    end

    if cvarName == "nameplateShowFriendlyBuffs" then
        data.cvars[cvarName] = value;
        func:Update_Auras("player");
    end
end

----------------------------------------
-- Resize nameplates clickable base
----------------------------------------
function func:ResizeNameplates()
    local function work()
        local inInstance, instanceType = IsInInstance();

        -- Width
        local portrait = Config.Portrait and 18 or 0;
        local level = Config.ShowLevel and 18 or 0;

        -- Height
        local portraitY = Config.Portrait and 2 or 0;
        local powerbarY = Config.Powerbar and 6 or 0;
        local inverseScale = 1 - Config.NameplatesScale;

        local width = 128 + portrait + level;
        local height = 16 + portraitY + powerbarY
            + ((Config.LargeName and 14 or 10) * (Config.NameplatesScale + inverseScale))
            + (Config.ShowGuildName and ((Config.LargeGuildName and 13 or 10) * (Config.NameplatesScale + inverseScale)) or Config.ThreatPercentage and 10 or 0);

        -- Friendly Nameplates
        if inInstance and (instanceType == "party" or instanceType == "raid") then
            C_NamePlate.SetNamePlateFriendlySize(128, 30);
        else
            C_NamePlate.SetNamePlateFriendlySize(width, height);
        end

        -- Enemy Nameplates
        C_NamePlate.SetNamePlateEnemySize(width, height);
    end

    if not InCombatLockdown() then
        work();
    else
        if not data.tickers.frameOptions then
            data.tickers.frameOptions = C_Timer.NewTicker(1, function()
                if not InCombatLockdown() then
                    work();

                    data.tickers.frameOptions:Cancel();
                    data.tickers.frameOptions = nil;
                end
            end)
        end
    end
end

hooksecurefunc(NamePlateDriverFrame,"ApplyFrameOptions", function(_, nameplateFrame)
    func:ResizeNameplates();
end);

----------------------------------------
-- Hiding default personal power bars
----------------------------------------
function func:DefaultPowerBars()
    local function work(frame)
        frame:SetAlpha(0);
        frame:ClearAllPoints();

        if data.nameplate.extraBar:IsShown() then
            frame:SetPoint("bottom", 0, -12);
        else
            frame:SetPoint("bottom");
        end
    end

    -- Main power bar
    if NamePlateDriverFrame.classNamePlatePowerBar then
        work(NamePlateDriverFrame.classNamePlatePowerBar);

        if not data.hooks.classNamePlatePowerBar then
            NamePlateDriverFrame.classNamePlatePowerBar:SetScript("OnShow", function(self)
                self:SetAlpha(0);
            end);

            local isReanchoring = false;
            hooksecurefunc(NamePlateDriverFrame.classNamePlatePowerBar, "SetPoint", function(self)
                if isReanchoring then
                    return
                end

                isReanchoring = true;
                work(self);
                isReanchoring = false;
            end);

            data.hooks.classNamePlatePowerBar = 1;
        end
    end

    -- Alternate power bar
    if NamePlateDriverFrame.classNamePlateAlternatePowerBar then
        work(NamePlateDriverFrame.classNamePlateAlternatePowerBar);

        if not data.hooks.classNamePlateAlternatePowerBar then
            work(NamePlateDriverFrame.classNamePlateAlternatePowerBar);

            NamePlateDriverFrame.classNamePlateAlternatePowerBar:SetScript("OnShow", function(self)
                self:SetAlpha(0);
            end);

            local isReanchoring = false;
            hooksecurefunc(NamePlateDriverFrame.classNamePlateAlternatePowerBar, "SetPoint", function(self)
                if isReanchoring then
                    return
                end

                isReanchoring = true;
                work(self);
                isReanchoring = false;
            end);

            data.hooks.classNamePlateAlternatePowerBar = 1;
        end
    end
end

----------------------------------------
-- Class Bar Height
----------------------------------------
function func:ClassBarHeight()
    local classID = select(3, UnitClass("player"));

    if classID == 2 then -- Paladin
        data.classBarHeight = 30;
    elseif classID == 4 then -- Rogue
        data.classBarHeight = 14;
    elseif classID == 6 then -- Death Knight
        data.classBarHeight = 15.6;
    elseif classID == 9 then -- Warlock
        data.classBarHeight = 21;
    elseif classID == 11 then -- Druid
        data.classBarHeight = 14;
    elseif classID == 13 then -- Evoker
        data.classBarHeight = 18;
    end
end

----------------------------------------
-- Hiding default personal friendly buffs
----------------------------------------
if PersonalFriendlyBuffFrame then
    PersonalFriendlyBuffFrame:Hide();
    PersonalFriendlyBuffFrame:SetScript("OnShow", function(self)
        self:Hide();
    end);
end

----------------------------------------
-- Tracking player's targets
----------------------------------------
function func:myTarget()
    if UnitExists("target") then
        local nameplate = C_NamePlate.GetNamePlateForUnit("target", false);

        if nameplate then
            data.myTarget.previous = data.myTarget.current;
            data.myTarget.current = nameplate.unitFrame;

            func:InteractIcon(nameplate);
        else
            data.myTarget.previous = data.myTarget.current;
            data.myTarget.current = nil;
        end
    else
        data.myTarget.previous = data.myTarget.current;
        data.myTarget.current = nil;
    end

    local unitFramePrev = data.myTarget.previous;
    local unitFrameCurr = data.myTarget.current;

    -- Widget
    if unitFramePrev and unitFramePrev.unit then
        func:Nameplate_Added(unitFramePrev.unit);
    end
    if unitFrameCurr and unitFrameCurr.unit then
        func:Nameplate_Added(unitFrameCurr.unit);
    end

    if data.cvars.nameplateResourceOnTarget == "1" or not data.isRetail then
        if data.myTarget.previous then
            func:PositionAuras(data.myTarget.previous);
        end
        if data.myTarget.current then
            func:PositionAuras(data.myTarget.current);
        end
    end
end

----------------------------------------
-- Getting percentage
----------------------------------------
function func:GetPercent(maxValue, percent)
    if tonumber(percent) and tonumber(maxValue) then
        return (maxValue * percent) / 100;
    else
        return false;
    end
end

----------------------------------------
-- Unit in your party (not raid, just your party)
----------------------------------------
function func:UnitInYourParty(unit)
    for i = 1, 5 do
        local member = "party" .. i;

        if UnitIsUnit(member, unit) then
            return true;
        end
    end
end

----------------------------------------
-- UTF8 Aware sting sub
----------------------------------------
-- This function can return a substring of a UTF-8 string, properly
-- handling UTF-8 codepoints. Rather than taking a start index and
-- optionally an end index, it takes the string, the start index, and
-- the number of characters to select from the string.
--
-- UTF-8 Reference:
-- 0xxxxxx - ASCII character
-- 110yyyxx - 2 byte UTF codepoint
-- 1110yyyy - 3 byte UTF codepoint
-- 11110zzz - 4 byte UTF codepoint

function func:utf8sub(str, start, numChars)
    local currentIndex = start;

    while numChars > 0 and currentIndex <= #str do
        local char = string.byte(str, currentIndex);

        if char >= 240 then
            currentIndex = currentIndex + 4;
        elseif char >= 225 then
            currentIndex = currentIndex + 3;
        elseif char >= 192 then
            currentIndex = currentIndex + 2;
        else
            currentIndex = currentIndex + 1;
        end

        numChars = numChars - 1;
    end

    return str:sub(start, currentIndex - 1);
end

----------------------------------------
-- Format time
----------------------------------------
function func:formatTime(value)
    local seconds = math.floor(value);
    local minutes = math.floor(seconds / 60);
    local hours = math.floor(minutes / 60);
    local days = math.floor(hours / 24);
    local remainingSeconds = seconds % 60;

    local function roundUp(val)
        if remainingSeconds > 0 then
            return val + 1;
        else
            return val;
        end
    end

    if value < 0 then
        return "";
    elseif value == 0 then
        return "0"
    elseif seconds < 10 then
        return string.format("%.1f", value);
    elseif seconds <= 60 then
        return seconds;
    elseif days > 0 then
        if days < 2  and remainingSeconds <= 0 then
            return roundUp(hours) .. "h";
        else
            return roundUp(days) .. "d";
        end
    elseif hours > 0 then
        if hours < 2  and remainingSeconds <= 0 then
            return roundUp(minutes) .. "m";
        else
            return roundUp(hours) .. "h";
        end
    elseif minutes > 0 then
        return roundUp(minutes) .. "m";
    end
end

-- Interract icon
function func:InteractIcon(nameplate)
    if nameplate and data.isRetail then
        local unitFrame = nameplate.unitFrame;
        local interactIcon = nameplate.UnitFrame and nameplate.UnitFrame.SoftTargetFrame and nameplate.UnitFrame.SoftTargetFrame.Icon;
        local auras = unitFrame and unitFrame.buffs["auras"] and (unitFrame.buffs["auras"][1] or unitFrame.debuffs["auras"][1]);
        local resourceOnTarget = data.cvars.nameplateResourceOnTarget;

        if interactIcon then
            interactIcon:SetParent(unitFrame);
            interactIcon:SetScale(0.5);
            interactIcon:ClearAllPoints();

            if auras and auras:IsShown() then
                interactIcon:SetPoint("bottom", auras, "top", 0, 8);
                interactIcon:SetPoint("center", unitFrame.name, "center");
            elseif resourceOnTarget == "1" and unitFrame.ClassBarDummy then
                interactIcon:SetPoint("bottom", unitFrame.ClassBarDummy, "top", 0, 4);
            else
                interactIcon:SetPoint("bottom", unitFrame.name, "top", 0, 4);
            end
        end
    end
end

----------------------------------------
-- Get unit color
----------------------------------------
function func:GetUnitColor(unit, ThreatPercentageOfLead, status)
    local canAttackUnit = UnitCanAttack("player", unit);
    local iAmTarget = UnitIsUnit(unit .. "target", "player");
    local isPlayer = UnitIsPlayer(unit);
    local isPet = UnitIsOtherPlayersPet(unit);
    local isTapped = UnitIsTapDenied(unit);
    local _, englishClass = UnitClass(unit);
    local classColor = RAID_CLASS_COLORS[englishClass];
    local r,g,b = UnitSelectionColor(unit, true);

    ThreatPercentageOfLead = ThreatPercentageOfLead or UnitThreatPercentageOfLead("player", unit);
    status = status or UnitThreatSituation("player", unit);

    local function getLighterColor(value, r,g,b)
        local percentage = 200 - value;
        percentage = math.min(100, math.max(0, percentage))

        local function addPercentage(number, percentage)
            local result = number + (percentage / 150);
            result = math.min(1, math.max(0, result))

            return result;
        end

        return addPercentage(r, percentage), addPercentage(g, percentage), addPercentage(b, percentage);
    end

    local function getDefault()
        if isPlayer then
            if canAttackUnit then
                if Config.HealthBarClassColorsEnemy then
                    return classColor.r, classColor.g, classColor.b;
                else
                    return r, g, b;
                end
            else
                if Config.HealthBarClassColorsFriendly then
                    return classColor.r, classColor.g, classColor.b;
                else
                    return r, g, b;
                end
            end
        elseif canAttackUnit and isTapped then
            return 0.9, 0.9, 0.9;
        else
            return r, g, b;
        end
    end

    if canAttackUnit then
        if isPlayer or isPet then
            return getDefault();
        else
            if status == 2 or status == 3 then
                if ThreatPercentageOfLead == 0 then
                    return Config.ThreatAggroColor.r, Config.ThreatAggroColor.g, Config.ThreatAggroColor.b;
                else
                    return getLighterColor(ThreatPercentageOfLead, Config.ThreatAggroColor.r, Config.ThreatAggroColor.g, Config.ThreatAggroColor.b);
                end
            elseif status == 1 or (ThreatPercentageOfLead and ThreatPercentageOfLead > Config.ThreatWarningThreshold) then
                return Config.ThreatWarningColor.r, Config.ThreatWarningColor.g, Config.ThreatWarningColor.b;
            elseif GetPartyAssignment("MainTank", "player", true) and func:OtherTank(unit) then
                return Config.ThreatOtherTankColor.r, Config.ThreatOtherTankColor.g, Config.ThreatOtherTankColor.b;
            else
                return getDefault();
            end
        end
    else
        return getDefault();
    end
end

----------------------------------------
-- Update colors
----------------------------------------
function func:Update_Colors(unit)
    local color = data.colors.border;

    local function work(unitFrame, unit)
        local r,g,b = func:GetUnitColor(unit);
        local Rs,Gs,Bs = UnitSelectionColor(unit, true);
        local _, englishClass = UnitClass(unit);
        local classColor = RAID_CLASS_COLORS[englishClass];
        local target = UnitIsUnit(unit, "target");

        if UnitIsEnemy(unit, "player") and (UnitIsPlayer(unit) or UnitIsOtherPlayersPet(unit)) then
            if UnitIsPVP(unit) or UnitIsPVPFreeForAll(unit) then
                r,g,b = Rs, Gs, Bs;
            else
                r,g,b = color.r, color.g, color.b;
            end
        elseif UnitIsFriend(unit, "player") and (UnitIsPlayer(unit) or UnitIsOtherPlayersPet(unit)) then
            if UnitIsPVP(unit) or UnitIsPVPFreeForAll(unit) then
                r,g,b = Rs, Gs, Bs;
            else
                r,g,b = color.r, color.g, color.b;
            end
        else
            r,g,b = color.r, color.g, color.b;
        end

        -- Coloring name and guild
        if UnitIsEnemy(unit, "player") and UnitIsTapDenied(unit) then
            unitFrame.name:SetTextColor(0.5, 0.5, 0.5);
            unitFrame.guild:SetTextColor(0.5, 0.5, 0.5);
        else
            if Config.FriendlyClassColorNamesAndGuild and UnitIsFriend(unit, "player") and UnitIsPlayer(unit) then
                unitFrame.name:SetTextColor(classColor.r, classColor.g, classColor.b);
                unitFrame.guild:SetTextColor(classColor.r, classColor.g, classColor.b);
            elseif Config.EnemyClassColorNamesAndGuild and UnitIsEnemy(unit, "player") and UnitIsPlayer(unit) then
                unitFrame.name:SetTextColor(classColor.r, classColor.g, classColor.b);
                unitFrame.guild:SetTextColor(classColor.r, classColor.g, classColor.b);
            else
                unitFrame.name:SetTextColor(Rs, Gs, Bs);
                unitFrame.guild:SetTextColor(Rs, Gs, Bs);
            end
        end

        -- Coloring borders
        if UnitIsEnemy(unit, "player") and (UnitIsPlayer(unit) or UnitIsOtherPlayersPet(unit)) and (UnitIsPVP(unit) or UnitIsPVPFreeForAll(unit)) then
            unitFrame.portrait.border:SetVertexColor(Rs, Gs, Bs);
            unitFrame.healthbar.border:SetVertexColor(Rs, Gs, Bs);
            unitFrame.level.border:SetVertexColor(Rs, Gs, Bs);
            unitFrame.powerbar.border:SetVertexColor(Rs, Gs, Bs);
            unitFrame.threatPercentage.border:SetVertexColor(Rs, Gs, Bs);
        else
            unitFrame.portrait.border:SetVertexColor(r,g,b);
            unitFrame.healthbar.border:SetVertexColor(r,g,b);
            unitFrame.level.border:SetVertexColor(r,g,b);
            unitFrame.powerbar.border:SetVertexColor(r,g,b);
            unitFrame.threatPercentage.border:SetVertexColor(r,g,b);
        end

        -- Fade
        if Config.FadeUnselected then
            if not UnitExists("target") then
                unitFrame:SetAlpha(1);
            elseif target then
                unitFrame:SetAlpha(1);
            else
                unitFrame:SetAlpha(Config.FadeIntensity);
            end
        else
            unitFrame:SetAlpha(1);
        end

        -- Coloring healthbar background
        unitFrame.healthbar.background:SetColorTexture(0.1 + (r / 7), 0.1 + (g / 7), 0.1 + (b / 7), 0.85);
    end

    if unit then
        local nameplate = C_NamePlate.GetNamePlateForUnit(unit);

        if nameplate then
            work(nameplate.unitFrame, unit);
        end
    else
        local nameplates = C_NamePlate.GetNamePlates();

        if nameplates then
            for k,v in pairs(nameplates) do
                if k then
                    if v.unitFrame.unit then
                        work(v.unitFrame, v.unitFrame.unit);
                    end
                end
            end
        end
    end
end

----------------------------------------
-- Update Quests
----------------------------------------
function func:Update_quests(unit)
    local function work(unit)
        local TooltipData = C_TooltipInfo.GetUnit(unit);

        local function getQuestProgress()
            local count = 0;
            local pattern1 = "(%d+)/(%d+)";
            local pattern2 = "(%d+)%%";
            local PatternThreat = "(%d+)%%%s*Threat";

            for k,v in pairs(TooltipData) do
                if k == "lines" then
                    for k,v in ipairs(v) do
                        if k and v.leftText then
                            local match1, match2 = v.leftText:match(pattern1);
                            local percentage = v.leftText:match(pattern2);
                            local threat = v.leftText:match(PatternThreat);


                            if match1 and match2 then
                                if match1 ~= match2 then
                                    count = count + 1;
                                end
                            elseif percentage and not threat then
                                if tonumber(percentage) < 100 then
                                    count = count + 1;
                                end
                            end
                        end
                    end
                end
            end

            if count > 0 then
                return true;
            end
        end

        if TooltipData then
            local nameplate = C_NamePlate.GetNamePlateForUnit(unit);

            if nameplate then
                nameplate.unitFrame.quest:SetShown(Config.QuestMark and getQuestProgress());
            end
        end
    end

    if data.isRetail then
        if unit then
            work(unit);
        else
            local nameplates = C_NamePlate.GetNamePlates();

            if nameplates then
                for k,v in pairs(nameplates) do
                    if k and v.unitFrame.unit then
                        work(v.unitFrame.unit);
                    end
                end
            end
        end
    end
end

----------------------------------------
-- Update health
----------------------------------------
function func:Update_Health(unit)
    if unit then
        local healthMax = UnitHealthMax(unit);
        local health = UnitHealth(unit);
        local healthPercent = string.format("%.0f", (health/healthMax)*100) .. "%";
        local percentageAsMainValue = Config.PercentageAsMainValue and Config.NumericValue and Config.Percentage;
        local player = UnitIsPlayer(unit);
        local otherPlayersPet = UnitIsOtherPlayersPet(unit);
        local hp = AbbreviateNumbers(health);
        local showSecondary = true;

        if UnitIsUnit(unit, "player") then
            local nameplate = data.nameplate;

            if nameplate then
                nameplate.healthMain:SetText(
                    percentageAsMainValue and healthPercent
                    or Config.NumericValue and hp
                    or Config.Percentage and healthPercent
                    or ""
                );
                nameplate.healthSecondary:SetText(percentageAsMainValue and hp or healthPercent);

                nameplate.healthMain:SetShown(Config.NumericValue or Config.Percentage);
                nameplate.healthSecondary:SetShown(Config.NumericValue and Config.Percentage);

                -- Total health
                data.nameplate.healthTotal:SetText(AbbreviateNumbers(healthMax));

                -- Updating Health bar
                nameplate.healthbar:SetMinMaxValues(0, healthMax);
                nameplate.healthbar:SetValue(health);

                -- Toggling spark
                func:ToggleSpark(health, healthMax, nameplate.healthbarSpark);
            end
        else
            local nameplate = C_NamePlate.GetNamePlateForUnit(unit);

            if data.isClassic then
                if (not player and not otherPlayersPet) or UnitPlayerOrPetInParty(unit) then
                    showSecondary = true;
                    hp = AbbreviateNumbers(health);
                else
                    showSecondary = false ;
                    hp = health .. "%";
                end
            end

            if nameplate then
                local unitFrame = nameplate.unitFrame;

                unitFrame.healthMain:SetText(
                    percentageAsMainValue and healthPercent
                    or Config.NumericValue and hp
                    or Config.Percentage and healthPercent
                    or ""
                );
                unitFrame.healthSecondary:SetText(
                    percentageAsMainValue and hp or healthPercent
                );

                unitFrame.healthMain:SetShown(Config.NumericValue or Config.Percentage);
                unitFrame.healthSecondary:SetShown(Config.NumericValue and Config.Percentage and showSecondary);

                -- Updating Health bar
                unitFrame.healthbar:SetMinMaxValues(0, healthMax);
                unitFrame.healthbar:SetValue(health);

                -- Toggling spark
                func:ToggleSpark(health, healthMax, unitFrame.healthbar.spark);
            end
        end

        func:PredictHeal(unit);
    end

    if not data.isRetail then
        func:ToggleNameplatePersonal();
    end
end

----------------------------------------
-- Update healthbar color
----------------------------------------
function func:Update_healthbar(unit)
    if unit then
        local nameplate = C_NamePlate.GetNamePlateForUnit(unit);

        if nameplate then
            local unitFrame = nameplate.unitFrame;
            local r,g,b = func:GetUnitColor(unit);

            unitFrame.healthbar:SetStatusBarColor(r,g,b);
        end
    end
end

----------------------------------------
-- Heal prediction
----------------------------------------
function func:PredictHeal(unit)
    local healthbar, prediction, missing, heal, predictionSpark;

    if unit then
        if unit == "player" then
            healthbar = data.nameplate.healthbar;
            prediction = data.nameplate.healPrediction;
            predictionSpark = data.nameplate.healPredictionSpark;
            missing = data.nameplate.missing;
            heal = data.nameplate.heal;
        else
            local nameplate = C_NamePlate.GetNamePlateForUnit(unit);

            if nameplate then
                healthbar = nameplate.unitFrame.healthbar;
                prediction = nameplate.unitFrame.healthbar.healPrediction;
                predictionSpark = nameplate.unitFrame.healthbar.healPredictionSpark;
                missing = nameplate.unitFrame.healthbar.healPrediction.missing;
                heal = nameplate.unitFrame.healthbar.healPrediction.heal;
            end
        end

        local healValue = UnitGetIncomingHeals(unit) or heal;

        if healValue and healValue > 0  and healthbar then
            missing = UnitHealthMax(unit) - UnitHealth(unit);
            heal = healValue;

            local missingValue = missing / UnitHealthMax(unit) * healthbar:GetWidth();
            local newValue = heal / UnitHealthMax(unit) * healthbar:GetWidth();

            if newValue > missingValue then
                newValue = missingValue;
            end

            prediction:SetWidth(newValue);
            prediction:SetShown(newValue > 0);
            predictionSpark:SetShown(newValue > 0);
        else
            if prediction then
                prediction:Hide();
            end
            if predictionSpark then
                predictionSpark:Hide();
            end
        end

        missing = UnitHealthMax(unit) - UnitHealth(unit);
        heal = healValue;
    end
end

----------------------------------------
-- Update power
----------------------------------------
function func:Update_Power(unit)
    if unit then
        if unit == "player" then
            local nameplate = data.nameplate;
            local powerMax = UnitPowerMax(unit);
            local power = UnitPower(unit);
            local powerType, powerToken = UnitPowerType(unit);
            local color = PowerBarColor[powerToken];
            local classID = select(3, UnitClass("player"));
            local powerPercent = string.format("%.0f", (power/powerMax)*100) .. "%";

            if nameplate then
                if color then
                    nameplate.powerbar:SetStatusBarColor(color.r, color.g, color.b);
                end

                nameplate.powerbar:SetMinMaxValues(0, powerMax);
                nameplate.powerbar:SetValue(power);

                if powerType == 0 then
                    if Config.PercentageAsMainValue and Config.NumericValue and Config.Percentage then
                        nameplate.powerMain:SetText(powerPercent);
                        nameplate.power:SetText(AbbreviateNumbers(power));
                        nameplate.power:Show();
                        nameplate.powerMain:Show();
                    elseif Config.NumericValue and Config.Percentage then
                        nameplate.powerMain:SetText(AbbreviateNumbers(power));
                        nameplate.power:SetText(powerPercent);
                        nameplate.power:Show();
                        nameplate.powerMain:Show();
                    elseif Config.NumericValue then
                        nameplate.powerMain:SetText(AbbreviateNumbers(power));
                        nameplate.powerMain:SetShown(powerType == 0);
                        nameplate.power:Hide();
                    elseif Config.Percentage then
                        nameplate.powerMain:SetText(powerPercent);
                        nameplate.powerMain:Show();
                        nameplate.power:Hide();
                    else
                        nameplate.powerMain:Hide();
                        nameplate.power:Hide();
                    end
                else
                    nameplate.powerMain:SetText(power);
                    nameplate.power:Hide();
                end

                data.nameplate.powerTotal:SetText(AbbreviateNumbers(powerMax));

                -- Toggling spark
                func:ToggleSpark(power, powerMax, nameplate.powerbarSpark);

                -- Extra bar
                -- For when player is a Druid in a cat or bear form
                if classID == 11 and powerType ~= 0 then
                    local manaMax = UnitPowerMax("player", 0);
                    local mana = UnitPower("player", 0);

                    nameplate.extraBar:SetMinMaxValues(0, manaMax);
                    nameplate.extraBar:SetValue(mana);
                    nameplate.extraBar:SetStatusBarColor(0,0,1);
                    nameplate.extraBar.value:SetText(mana);

                    -- Toggling spark
                    func:ToggleSpark(mana, manaMax, nameplate.extraBar.spark);
                end
            end
        else
            local nameplate = C_NamePlate.GetNamePlateForUnit(unit);

            if nameplate then
                local unitFrame = nameplate.unitFrame;
                local powerMax = UnitPowerMax(unit);
                local power = UnitPower(unit);
                local powerType, powerToken, altR, altG, altB = UnitPowerType(unit);
                local color = PowerBarColor[powerToken];

                -- Show or hide highlight
                if power and powerMax > 0 then -- Powerbar is shown
                    if color then
                        unitFrame.powerbar.statusbar:SetStatusBarColor(color.r, color.g, color.b);
                    end

                    unitFrame.powerbar.statusbar:SetMinMaxValues(0, powerMax);
                    unitFrame.powerbar.statusbar:SetValue(power);
                    unitFrame.powerbar:SetShown(Config.Powerbar);
                    unitFrame.powerbar.border:Show();
                else -- Powerbar is hidden
                    unitFrame.powerbar:Hide();
                    unitFrame.powerbar.spark:Hide();
                    unitFrame.powerbar.border:Hide();
                end

                -- Toggling spark
                func:ToggleSpark(power, powerMax, unitFrame.powerbar.spark);
            end
        end
    end

    if not data.isRetail then
        func:ToggleNameplatePersonal();
    end
end

----------------------------------------
-- Update Extra Bar
----------------------------------------
function func:Update_ExtraBar()
    local nameplate = data.nameplate;
    local classID = select(3, UnitClass("player"));
    local AlternatePowerBar = NamePlateDriverFrame.classNamePlateAlternatePowerBar;

    local function formatValue(value)
        if classID == 13 then
            return func:formatTime(value);
        else
            return math.floor(value);
        end
    end

    if AlternatePowerBar then
        local min, max = AlternatePowerBar:GetMinMaxValues();
        local value = AlternatePowerBar:GetValue();
        local r,g,b = AlternatePowerBar:GetStatusBarColor();

        nameplate.extraBar:SetStatusBarColor(r,g,b);
        nameplate.extraBar:SetMinMaxValues(min, max);
        nameplate.extraBar:SetValue(value);
        nameplate.extraBar.value:SetText(formatValue(value));

        local timeElapsed = 0;
        nameplate.extraBar:SetScript("OnUpdate", function(self, elapsed)
            timeElapsed = timeElapsed + elapsed;

            if timeElapsed > 0.1 then
                local value = formatValue(AlternatePowerBar:GetValue());

                timeElapsed = 0;
                self:SetValue(value);
                self.value:SetText(value);
            end
        end);

        func:ToggleSpark(value, max, nameplate.extraBar.spark);
    end
end

----------------------------------------
-- Updating Class Power
----------------------------------------
function func:Update_ClassPower(unit)
    local player = UnitInVehicle("player") and "vehicle" or "player";

    for _, nameplate in ipairs(C_NamePlate.GetNamePlates(false)) do
        local unitFrame = nameplate.unitFrame;

        if nameplate.unitFrame.unit then
            local comboPoints = GetComboPoints(player, nameplate.unitFrame.unit);

            if comboPoints > 0 then
                for i = 1, comboPoints do
                    if not unitFrame.classPower[i] then
                        unitFrame.classPower[i] = CreateFrame("frame", nil, unitFrame.classPower);
                        unitFrame.classPower[i]:SetSize(14, 14);

                        unitFrame.classPower[i].center = unitFrame.classPower[i]:CreateTexture();
                        unitFrame.classPower[i].center:SetPoint("center");
                        unitFrame.classPower[i].center:SetSize(18, 18);
                        unitFrame.classPower[i].center:SetTexture("Interface\\addons\\ClassicPlatesPlus\\media\\powers\\comboPoints");

                        unitFrame.classPower[i].border = unitFrame.classPower[i]:CreateTexture();
                        unitFrame.classPower[i].border:SetPoint("center");
                        unitFrame.classPower[i].border:SetSize(18, 18);
                        unitFrame.classPower[i].border:SetTexture("Interface\\addons\\ClassicPlatesPlus\\media\\powers\\comboPointsBorder");
                        unitFrame.classPower[i].border:SetVertexColor(data.colors.border.r, data.colors.border.g, data.colors.border.b);
                    end
                end

                for i in ipairs(unitFrame.classPower) do
                    if i == 1 then
                        unitFrame.classPower[i]:SetPoint("center", unitFrame.classPower, "center", -(comboPoints -1) * 7, 0);
                    elseif i > 1 then
                        unitFrame.classPower[i]:SetPoint("left", unitFrame.classPower[i - 1], "right");
                    end

                    unitFrame.classPower[i]:SetShown(i <= comboPoints);
                end
            end

            unitFrame.classPower:SetScript("OnShow", function()
                func:PositionAuras(unitFrame);
            end);
            unitFrame.classPower:SetScript("OnHide", function()
                func:PositionAuras(unitFrame);
            end);

            unitFrame.classPower:SetWidth(18 * comboPoints);
            unitFrame.classPower:SetShown(comboPoints > 0);
        end
    end
end

------------------------------------------
-- Toggle spark for healthbars and powerbars
------------------------------------------
function func:ToggleSpark(value, valueMax, spark)
    if value >= valueMax or value <= 0 then
        spark:Hide();
    else
        spark:Show();
    end
end

----------------------------------------
-- Spell cost
----------------------------------------
function func:SpellCost(unit, spellID)
    --[[if not data.isRetail then
        if UnitIsUnit(unit, "player") then
            local costTable = GetSpellPowerCost(spellID);

            local function cost(cost, costType)
                local powerMax = UnitPowerMax("player", costType);

                if cost > 0 then
                    data.nameplate.powerbarCost:SetWidth(cost / powerMax * data.nameplate.powerbar:GetWidth());
                    data.nameplate.powerbarCost:Show();
                    data.nameplate.powerbarCostSpark:Show();
                end
            end

            if next(costTable) ~= nil then
                for k,v in pairs(costTable) do
                    for k,v in pairs(v) do
                        --print(k,v)
                    end
                end
            end

            if next(costTable) ~= nil then
                if type(costTable[1]["cost"]) == "table" then
                    local costType = costTable[1].cost[1].type;
                    local cost2Type = costTable[1].cost[2].type;

                    if costType == 0 or costType == 1 or costType == 3 then print("1")
                        cost(costTable[1].cost[1].cost, costType);
                    elseif cost2Type == 0 or cost2Type == 1 or cost2Type == 3 then print("2")
                        cost(costTable[1].cost[2].cost, cost2Type);
                    end
                else
                    cost(costTable[1].cost, costTable[1].type);
                end
            end
        end
    end]]
end

----------------------------------------
-- Update portrait
----------------------------------------
function func:Update_Portrait(unit)
    local isEnemy = UnitIsEnemy(unit, "player");
    local isFriend = UnitIsFriend(unit, "player");

    if Config.Portrait then
        if unit then
            local nameplate = C_NamePlate.GetNamePlateForUnit(unit);

            if nameplate then
                local unitFrame = nameplate.unitFrame;

                local function setClassIcon()
                    local _, class = UnitClass(unit);

                    if class then
                        unitFrame.portrait.texture:SetTexture("Interface\\addons\\ClassicPlatesPlus\\media\\classes\\" .. class);
                    end
                end

                if UnitIsPlayer(unit) then
                    if Config.ClassIconsEnemy then
                        if isEnemy then
                            setClassIcon();
                        end
                    else
                        if isEnemy then
                            SetPortraitTexture(unitFrame.portrait.texture, unit);
                        end
                    end

                    if Config.ClassIconsFriendly then
                        if isFriend then
                            setClassIcon();
                        end
                    else
                        if isFriend then
                            SetPortraitTexture(unitFrame.portrait.texture, unit);
                        end
                    end
                else
                    SetPortraitTexture(unitFrame.portrait.texture, unit);
                end
            end
        end
    end
end

----------------------------------------
-- Update name
----------------------------------------
function func:Update_Name(unit)
    if unit then
        local nameplate = C_NamePlate.GetNamePlateForUnit(unit);

        if nameplate then
            local unitFrame = nameplate.unitFrame;
            local name = GetUnitName(unit, false);

            unitFrame.name:SetText(name);
        end
    end
end

----------------------------------------
-- Update guild
----------------------------------------
function func:Update_Guild(unit)
    if unit then
        local nameplate = C_NamePlate.GetNamePlateForUnit(unit);

        if nameplate then
            local unitFrame = nameplate.unitFrame;
            local guildName = GetGuildInfo(unit); -- or "Defenders of Azeroth";

            if guildName then
                unitFrame.guild:SetText("<"..guildName..">");
            end

            unitFrame.guild:SetShown(Config.ShowGuildName and guildName);

            func:Update_NameAndGuildPositions(nameplate);
        end
    end
end

----------------------------------------
-- Update name and guild positions
----------------------------------------
function func:Update_NameAndGuildPositions(nameplate, hook)
    if nameplate then
        local unit = nameplate.namePlateUnitToken;

        if unit then
            local unitFrame = nameplate.unitFrame;

            local function work()
                local portrait = Config.Portrait and 0 or -9;
                local level = Config.ShowLevel and 0 or 9;
                local powerbarToggle = unitFrame.unit and UnitPower(unitFrame.unit) and UnitPowerMax(unitFrame.unit) > 0;
                local DefaultNameY = (unitFrame.threatPercentage:IsShown() or unitFrame.guild:IsShown()) and 0
                    or (Config.ShowGuildName or Config.ThreatPercentage) and not powerbarToggle and -6
                    or (Config.ShowGuildName or Config.ThreatPercentage) and powerbarToggle and -4
                    or not powerbarToggle and -2
                    or powerbarToggle and 0 or -6;
                local x = portrait + level;
                local y = unitFrame.threatPercentage:IsShown() and -17 or -8;
                local anchor = Config.ShowGuildName and unitFrame.guild:IsShown() and unitFrame.guild or unitFrame.name;

                nameplate.UnitFrame.name:ClearAllPoints();
                nameplate.UnitFrame.name:SetPoint("top", 0, DefaultNameY);
                unitFrame.healthbar:ClearAllPoints();
                unitFrame.healthbar:SetPoint("top", anchor, "bottom", x, y);
            end

            local canAttack = UnitCanAttack("player", unit);
            local showParent = UnitIsUnit("target", unit)
                or Config.NamesOnly == 1
                or Config.NamesOnly == 2 and canAttack
                or Config.NamesOnly == 3 and not canAttack
                or Config.NamesOnly == 4 and false

            if not showParent then
                local exclude = Config.NamesOnlyExcludeNPC and not (UnitIsPlayer(unit) or UnitIsOtherPlayersPet(unit))
                             or Config.NamesOnlyExcludeFriends and func:isFriend(unit)
                             or Config.NamesOnlyExcludeGuild   and IsGuildMember(unit)
                             or Config.NamesOnlyExcludeParty   and func:UnitInYourParty(unit)
                             or Config.NamesOnlyExcludeRaid    and UnitPlayerOrPetInRaid(unit)

                if not exclude then
                    nameplate.UnitFrame.name:ClearAllPoints();
                    nameplate.UnitFrame.name:SetPoint("center", nameplate, "center", 0, unitFrame.guild:IsShown() and 8 or 0);
                else
                    work();
                end
            elseif not hook then
                work();
            end
        end
    end
end

----------------------------------------
-- Update level
----------------------------------------
function func:Update_Level(unit)
    if unit then
        local nameplate = C_NamePlate.GetNamePlateForUnit(unit);

        if nameplate then
            local unitFrame = nameplate.unitFrame;
            local effectiveLevel = UnitLevel(unit);
            local color = GetCreatureDifficultyColor(effectiveLevel);

            if effectiveLevel > 0 then
                unitFrame.level.value:SetTextColor(color.r, color.g, color.b);
                unitFrame.level.value:SetText(effectiveLevel);
                unitFrame.level.value:Show();
                unitFrame.level.highLevel:Hide();
            else
                unitFrame.level.value:Hide();
                unitFrame.level.highLevel:Show();
            end
        end
    end
end

----------------------------------------
-- Update classification
----------------------------------------
function func:Update_Classification(unit)
    if unit then
        local nameplate = C_NamePlate.GetNamePlateForUnit(unit);

        if nameplate then
            local unitFrame = nameplate.unitFrame;
            local classification = UnitClassification(unit);

            if Config.Classification and classification and (
                   classification == "rareelite"
                or classification == "elite"
                or classification == "worldboss"
                or classification == "rare"
            ) then
                if Config.Portrait then
                    unitFrame.classification:SetTexture("Interface\\addons\\ClassicPlatesPlus\\media\\classifications\\" .. classification);
                else
                    unitFrame.classification:SetTexture("Interface\\addons\\ClassicPlatesPlus\\media\\classifications\\compact" .. classification);
                end

                unitFrame.classification:Show();
            else
                unitFrame.classification:Hide();
            end
        end
    end
end

----------------------------------------
-- PVP flags
----------------------------------------
function func:Update_PVP_Flag(unit)
    if unit then
        local nameplate = C_NamePlate.GetNamePlateForUnit(unit);

        if nameplate then
            local unitFrame = nameplate.unitFrame;
            local isFreeForAll = UnitIsPVPFreeForAll(unit);
            local flaggedPVP = UnitIsPVP(unit);
            local englishFaction = UnitFactionGroup(unit);

            if isFreeForAll then
                unitFrame.pvp_flag:SetTexture("Interface\\addons\\ClassicPlatesPlus\\media\\icons\\ffa");
            elseif flaggedPVP and englishFaction then
                unitFrame.pvp_flag:SetTexture("Interface\\addons\\ClassicPlatesPlus\\media\\icons\\" .. englishFaction);
            end

            unitFrame.pvp_flag:ClearAllPoints();
            unitFrame.pvp_flag:SetPoint("left", unitFrame.name, "right", -1, englishFaction == "Horde" and -4 or (englishFaction == "Alliance" or isFreeForAll) and -3 or 0);
            unitFrame.pvp_flag:SetShown(Config.ShowFaction and (isFreeForAll or flaggedPVP) and englishFaction);
        end
    end
end

----------------------------------------
-- Unit is Friend
----------------------------------------
function func:isFriend(unit)
    local GUID = UnitGUID(unit);

    if GUID then
        if C_FriendList.IsFriend(GUID) then
            return true;
        end
    end
end

----------------------------------------
-- Fellowship Badge
----------------------------------------
function func:Update_FellowshipBadge(unit)
    local function work(nameplate)
        local unitFrame = nameplate.unitFrame;
        local unit = unitFrame.unit;
        local toggle = false;
        local icon_r, icon_g, icon_b = 1, 0.9, 0.8;
        local badge_r, badge_g, badge_b = 1, 0.9, 0.8;
        local icon = "Interface\\addons\\ClassicPlatesPlus\\media\\icons\\member";

        if unit then
            -- Icon
            if func:isFriend(unit) then
                icon = "Interface\\addons\\ClassicPlatesPlus\\media\\icons\\friend";
            elseif IsGuildMember(unit) then
                icon = "Interface\\addons\\ClassicPlatesPlus\\media\\icons\\guild";
            end

            -- Badge
            if UnitIsGroupLeader(unit) then
                toggle = true;
                badge_r, badge_g, badge_b = data.colors.red.r, data.colors.red.g, data.colors.red.b;
            elseif func:UnitInYourParty(unit) then
                toggle = true;
                badge_r, badge_g, badge_b = data.colors.blue.r, data.colors.blue.g, data.colors.blue.b;
            elseif UnitPlayerOrPetInRaid(unit) then
                toggle = true;
                badge_r, badge_g, badge_b = data.colors.orange.r, data.colors.orange.g, data.colors.orange.b
            elseif IsGuildMember(unit) then
                toggle = true;
                badge_r, badge_g, badge_b = data.colors.green.r, data.colors.green.g, data.colors.green.b;
            elseif C_FriendList.IsFriend(UnitGUID(unit)) then
                toggle = true;
                badge_r, badge_g, badge_b = data.colors.purple.r, data.colors.purple.g, data.colors.purple.b;
            end
        end

        if UnitIsGroupLeader(unit) then
            icon = "Interface\\addons\\ClassicPlatesPlus\\media\\icons\\leader";
        end

        unitFrame.fellowshipBadge.icon:SetTexture(icon);
        unitFrame.fellowshipBadge.icon:SetVertexColor(icon_r, icon_g, icon_b);
        unitFrame.fellowshipBadge.badge:SetTexture("Interface\\addons\\ClassicPlatesPlus\\media\\icons\\badge");
        unitFrame.fellowshipBadge.badge:SetVertexColor(badge_r, badge_g, badge_b);

        unitFrame.fellowshipBadge:SetShown(Config.FellowshipBadge and toggle);
    end

    if unit then
        local nameplate = C_NamePlate.GetNamePlateForUnit(unit);

        if nameplate then
            work(nameplate);
        end
    else
        for _, nameplate in pairs(C_NamePlate.GetNamePlates()) do
            if nameplate then
                work(nameplate);
            end
        end
    end
end

----------------------------------------
-- Assign tanks & members
----------------------------------------
function func:Update_Roster()
    local unit;

    -- Reseting tables
    data.tanks = {};
    data.members = {};

    for i = 1, GetNumGroupMembers() do

        -- Getting unit's IDs
        if IsInRaid() then
            unit = "raid" .. i;
        elseif IsInGroup() then
            unit = "party" .. i;
        end

        if UnitExists(unit) then
            if not UnitIsUnit(unit, "player") then -- Excluding ourselves
                if GetPartyAssignment("MainTank", unit, true) then -- if unit is a tank
                    data.tanks[UnitName(unit)] = UnitName(unit);
                else                                               -- If unit is a member
                    data.members[UnitName(unit)] = UnitName(unit);
                end
            end
        end
    end
end

----------------------------------------
-- Raid target index
----------------------------------------
function func:RaidTargetIndex()
    local nameplates = C_NamePlate.GetNamePlates();

    if nameplates then
        for k,v in pairs(nameplates) do
            if k then
                local raidTarget = v.unitFrame.raidTarget;
                local unit = v.unitFrame.unit;

                if unit then
                    local mark = GetRaidTargetIndex(unit);

                    if mark then
                        local texture;

                            if mark == 1 then texture = "UI-RaidTargetingIcon_1";
                        elseif mark == 2 then texture = "UI-RaidTargetingIcon_2";
                        elseif mark == 3 then texture = "UI-RAIDTARGETINGICON_3";
                        elseif mark == 4 then texture = "UI-RaidTargetingIcon_4";
                        elseif mark == 5 then texture = "UI-RaidTargetingIcon_5";
                        elseif mark == 6 then texture = "UI-RaidTargetingIcon_6";
                        elseif mark == 7 then texture = "UI-RaidTargetingIcon_7";
                        elseif mark == 8 then texture = "UI-RaidTargetingIcon_8";
                        end

                        if texture then
                            raidTarget.markPrev = raidTarget.mark;
                            raidTarget.mark = mark;
                            raidTarget.icon:SetTexture("interface\\TARGETINGFRAME\\" .. texture);
                            raidTarget:Show();

                            local function play()
                                if raidTarget.animation:IsPlaying() then
                                    raidTarget.animation:Restart();
                                else
                                    raidTarget.animation:Play();
                                end
                            end

                            if raidTarget.markPrev ~= raidTarget.mark then
                                play();
                            end
                        end
                    else
                        raidTarget.mark = nil;
                        raidTarget:Hide();
                    end
                end
            end
        end
    end
end