--[[

	Rayfield Interface Suite
	by Sirius

	shlex  | Designing + Programming
	iRay   | Programming
	Max    | Programming
	Damian | Programming

]]

if debugX then
	warn('Initialising Rayfield')
end

local function getService(name)
	local service = game:GetService(name)
	return if cloneref then cloneref(service) else service
end

-- Services
local UserInputService = getService("UserInputService")
local TweenService = getService("TweenService")
local Players = getService("Players")
local CoreGui = getService("CoreGui")
local RunService = getService("RunService")
local HttpService = getService("HttpService")
local Workspace = getService("Workspace")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Loads and executes a function hosted on a remote URL. Cancels the request if the requested URL takes too long to respond.
local function loadWithTimeout(url: string, timeout: number?): ...any
	assert(type(url) == "string", "Expected string, got " .. type(url))
	timeout = timeout or 5
	local requestCompleted = false
	local success, result = false, nil

	local requestThread = task.spawn(function()
		local fetchSuccess, fetchResult = pcall(game.HttpGet, game, url)
		if not fetchSuccess or #fetchResult == 0 then
			if #fetchResult == 0 then
				fetchResult = "Empty response"
			end
			success, result = false, fetchResult
			requestCompleted = true
			return
		end
		local content = fetchResult
		local execSuccess, execResult = pcall(function()
			return loadstring(content)()
		end)
		success, result = execSuccess, execResult
		requestCompleted = true
	end)

	local timeoutThread = task.delay(timeout, function()
		if not requestCompleted then
			warn("Request for " .. url .. " timed out after " .. tostring(timeout) .. " seconds")
			task.cancel(requestThread)
			result = "Request timed out"
			requestCompleted = true
		end
	end)

	while not requestCompleted do
		task.wait()
	end
	if coroutine.status(timeoutThread) ~= "dead" then
		task.cancel(timeoutThread)
	end
	if not success then
		warn("Failed to process " .. tostring(url) .. ": " .. tostring(result))
	end
	return if success then result else nil
end

local requestsDisabled = false
local customAssetId = nil
local secureMode = false
if getgenv then
	local ok, result = pcall(function() return getgenv().DISABLE_RAYFIELD_REQUESTS end)
	if ok and result then requestsDisabled = true end
	local ok2, result2 = pcall(function() return getgenv().RAYFIELD_ASSET_ID end)
	if ok2 and type(result2) == "number" then customAssetId = result2 end
	local ok3, result3 = pcall(function() return getgenv().RAYFIELD_SECURE end)
	if ok3 and result3 then secureMode = true end
end

if secureMode then
	local _error = error
	local _assert = assert
	warn = function(...) end
	print = function(...) end
	error = function(_, level) _error("", level) end
	assert = function(v, ...) return _assert(v) end
end

local secureWarnings = {}
local customAssets = {}

local function secureNotify(wType, title, content)
	if secureWarnings[wType] then return end
	secureWarnings[wType] = true
	task.spawn(function()
		while not RayfieldLibrary or not RayfieldLibrary.Notify do task.wait(0.5) end
		RayfieldLibrary:Notify({
			Title = title,
			Content = content,
			Duration = 8,
		})
	end)
end

local InterfaceBuild = 'UU2NX'
local Release = "Build 1.749"
local RayfieldFolder = "Rayfield"
local ConfigurationFolder = RayfieldFolder.."/Configurations"
local ConfigurationExtension = ".rfld"

local settingsTable = {
	General = {
		rayfieldOpen = {Type = 'bind', Value = 'K', Name = 'Rayfield Keybind'},
	},
	System = {
		usageAnalytics = {Type = 'toggle', Value = true, Name = 'Anonymised Analytics'},
	}
}

local overriddenSettings: { [string]: any } = {}
local function overrideSetting(category: string, name: string, value: any)
	overriddenSettings[category .. "." .. name] = value
end

local function getSetting(category: string, name: string): any
	if overriddenSettings[category .. "." .. name] ~= nil then
		return overriddenSettings[category .. "." .. name]
	elseif settingsTable[category][name] ~= nil then
		return settingsTable[category][name].Value
	end
end

if requestsDisabled then
	overrideSetting("System", "usageAnalytics", false)
end

local useStudio = RunService:IsStudio() or false
local settingsCreated = false
local settingsInitialized = false
local prompt = useStudio and require(script.Parent.prompt) or loadWithTimeout('https://raw.githubusercontent.com/SiriusSoftwareLtd/Sirius/refs/heads/request/prompt.lua')

if not prompt and not useStudio then
	warn("Failed to load prompt library, using fallback")
	prompt = { create = function() end }
end

local function callSafely(func, ...)
	if func then
		local success, result = pcall(func, ...)
		if not success then
			warn("Rayfield | Function failed with error: ", result)
			return false
		else
			return result
		end
	end
end

local function ensureFolder(folderPath)
	if isfolder and not callSafely(isfolder, folderPath) then
		callSafely(makefolder, folderPath)
	end
end

local function loadSettings()
	local file = nil
	local success, result = pcall(function()
		if callSafely(isfolder, RayfieldFolder) then
			if callSafely(isfile, RayfieldFolder..'/settings'..ConfigurationExtension) then
				file = callSafely(readfile, RayfieldFolder..'/settings'..ConfigurationExtension)
			end
		end

		if useStudio then
			file = [[{"General":{"rayfieldOpen":{"Value":"K","Type":"bind","Name":"Rayfield Keybind","Element":{"HoldToInteract":false,"Ext":true,"Name":"Rayfield Keybind","Set":null,"CallOnChange":true,"Callback":null,"CurrentKeybind":"K"}}},"System":{"usageAnalytics":{"Value":false,"Type":"toggle","Name":"Anonymised Analytics","Element":{"Ext":true,"Name":"Anonymised Analytics","Set":null,"CurrentValue":false,"Callback":null}}}}]]
		end

		if file then
			local decodeSuccess, decodedFile = pcall(function() return HttpService:JSONDecode(file) end)
			if decodeSuccess then file = decodedFile else file = {} end
		else
			file = {}
		end

		if not settingsCreated then return end

		if next(file) ~= nil then
			for categoryName, categoryTable in file do
				for settingName, setting in categoryTable do
					local default = settingsTable[categoryName] and settingsTable[categoryName][settingName]
					if not default then continue end
					local settingType = typeof(default.Value)
					if not (settingType == typeof(setting.Value)) then continue end
					default.Value = setting.Value
				end
			end
		end

		for categoryName, categoryTable in settingsTable do
			for settingName, setting in categoryTable do
				if setting.Element then
					setting.Element:Set(getSetting(categoryName, settingName))
				end
			end
		end
		settingsInitialized = true
	end)

	if not success then 
		if writefile then
			warn('Rayfield had an issue accessing configuration saving capability.')
		end
	end
end

loadSettings()

-- โหลด Library หลักของ Rayfield เข้ามาทำงานต่อ
local RayfieldLibrary = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = RayfieldLibrary:CreateWindow({
	Name = "BLAZE HUB | Rayfield Edition",
	LoadingTitle = "Blaze Hub is Loading...",
	LoadingSubtitle = "by lads",
	ConfigurationSaving = {
		Enabled = true,
		FolderName = "BlazeHub",
		FileName = "Config"
	},
	KeySystem = false
})

-- สร้าง Tabs ต่างๆ
local MainTab = Window:CreateTab("หน้าหลัก", 4483362458)
local ESPTab = Window:CreateTab("ESP", 4483362458)
local ExeTab = Window:CreateTab("exe ทุกแมพ", 4483362458)
local UniversalScriptTab = Window:CreateTab("script ใช้ได้ทุกแมพ", 4483362458)
local EggMapTab = Window:CreateTab("แมพขโมยใข่", 4483362458)
local BlazeHubTab = Window:CreateTab("สคริปค่าย BlazeHub เท่านั้น", 4483362458)

-- ตัวแปรสถานะฟังก์ชันต่างๆ
local SpeedEnabled = false
local WalkSpeedValue = 32
local JumpEnabled = false
local JumpPowerValue = 100
local InfJumpEnabled = false
local NoclipEnabled = false
local ESPEnabled = false

local DEFAULT_SPEED = 16
local DEFAULT_JUMP = 50

-- ==================== หน้าหลัก (Main Tab) ====================
MainTab:CreateToggle({
	Name = "เปิดใช้งาน วิ่งเร็ว",
	CurrentValue = false,
	Flag = "SpeedToggle",
	Callback = function(v)
		SpeedEnabled = v
		if not v and LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
			LocalPlayer.Character:FindFirstChildOfClass("Humanoid").WalkSpeed = DEFAULT_SPEED
		end
	end,
})

MainTab:CreateInput({
	Name = "ปรับความเร็ววิ่ง (WalkSpeed)",
	CurrentValue = tostring(WalkSpeedValue),
	PlaceholderText = "ใส่ตัวเลขความเร็ว",
	RemoveTextAfterFocusLost = false,
	Flag = "SpeedInput",
	Callback = function(v)
		local num = tonumber(v)
		if num then WalkSpeedValue = num end
	end,
})

MainTab:CreateToggle({
	Name = "เปิดใช้งาน กระโดดสูง",
	CurrentValue = false,
	Flag = "JumpToggle",
	Callback = function(v)
		JumpEnabled = v
		if not v and LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
			LocalPlayer.Character:FindFirstChildOfClass("Humanoid").JumpPower = DEFAULT_JUMP
		end
	end,
})

MainTab:CreateInput({
	Name = "ปรับแรงกระโดด (JumpPower)",
	CurrentValue = tostring(JumpPowerValue),
	PlaceholderText = "ใส่ตัวเลขแรงกระโดด",
	RemoveTextAfterFocusLost = false,
	Flag = "JumpInput",
	Callback = function(v)
		local num = tonumber(v)
		if num then JumpPowerValue = num end
	end,
})

MainTab:CreateToggle({
	Name = "กระโดดไม่จำกัด (Inf Jump)",
	CurrentValue = false,
	Flag = "InfJumpToggle",
	Callback = function(v)
		InfJumpEnabled = v
	end,
})

MainTab:CreateToggle({
	Name = "เดินทะลุสิ่งกีดขวาง (Noclip)",
	CurrentValue = false,
	Flag = "NoclipToggle",
	Callback = function(v)
		NoclipEnabled = v
	end,
})

-- ลูปการทำงานหลัก (WalkSpeed, JumpPower, Noclip, InfJump)
RunService.Heartbeat:Connect(function()
	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")

	if SpeedEnabled and hum then
		hum.WalkSpeed = WalkSpeedValue
	end

	if JumpEnabled and hum then
		hum.UseJumpPower = true
		hum.JumpPower = JumpPowerValue
	end

	if NoclipEnabled and char then
		for _, part in pairs(char:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CanCollide = false
			end
		end
	end
end)

UserInputService.JumpRequest:Connect(function()
	if InfJumpEnabled then
		local char = LocalPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then
			hum:ChangeState(Enum.HumanoidStateType.Jumping)
		end
	end
end)

-- ==================== หน้า ESP ====================
ESPTab:CreateToggle({
	Name = "เปิดใช้งาน ESP มองทะลุ",
	CurrentValue = false,
	Flag = "ESPToggle",
	Callback = function(v)
		ESPEnabled = v
		if not ESPEnabled then
			for _, plr in pairs(Players:GetPlayers()) do
				if plr.Character and plr.Character:FindFirstChild("BlazeHubHighlight") then
					plr.Character.BlazeHubHighlight:Destroy()
				end
			end
		end
	end,
})

RunService.RenderStepped:Connect(function()
	if ESPEnabled then
		for _, plr in pairs(Players:GetPlayers()) do
			if plr ~= LocalPlayer and plr.Character then
				local char = plr.Character
				if not char:FindFirstChild("BlazeHubHighlight") then
					local highlight = Instance.new("Highlight")
					highlight.Name = "BlazeHubHighlight"
					highlight.Adornee = char
					highlight.FillColor = Color3.fromRGB(0, 170, 255)
					highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
					highlight.FillTransparency = 0.5
					highlight.Parent = char
				end
			end
		end
	end
end)

-- ==================== หน้า Exec (รันโค้ดทุกแมพ) ====================
local customCodeInput = '-- วางโค้ด Loadstring หรือ Lua ที่นี่\nprint("Blaze Hub Executed!")'

ExeTab:CreateInput({
	Name = "ช่องใส่โค้ด Lua / Loadstring",
	CurrentValue = customCodeInput,
	PlaceholderText = "พิมพ์โค้ดที่นี่...",
	RemoveTextAfterFocusLost = false,
	Flag = "CustomCodeInput",
	Callback = function(v)
		customCodeInput = v
	end,
})

ExeTab:CreateButton({
	Name = "Execute Script",
	Callback = function()
		local func, err = loadstring(customCodeInput)
		if func then
			pcall(func)
			RayfieldLibrary:Notify({Title = "Blaze Hub", Content = "รัน script แล้วครับ", Duration = 3})
		else
			warn("Script Error: " .. tostring(err))
		end
	end,
})

ExeTab:CreateButton({
	Name = "รัน Infinite Yield (Admin Commands)",
	Callback = function()
		pcall(function()
			loadstring(game:HttpGet('https://rawgithubusercontent.com/EdgeIY/infiniteyield/master/source'))()
			RayfieldLibrary:Notify({Title = "Blaze Hub", Content = "รัน Infinite Yield แล้วครับ", Duration = 3})
		end)
	end,
})

ExeTab:CreateButton({
	Name = "รัน Dex Explorer (ดู UI/Inspect ทุกแมพ)",
	Callback = function()
		pcall(function()
			loadstring(game:HttpGet("https://rawgithubusercontent.com/peyton2465/Dex/master/out.lua"))()
			RayfieldLibrary:Notify({Title = "Blaze Hub", Content = "รัน Dex Explorer แล้วครับ", Duration = 3})
		end)
	end,
})

-- ==================== หน้า Universal Scripts ====================
UniversalScriptTab:CreateButton({
	Name = "รัน PISIT HUB",
	Callback = function()
		local success, err = pcall(function()
			loadstring(game:HttpGet("https://raw.githubusercontent.com/qqe22462-afk/PISIT-HUB/refs/heads/main/RUNLUA.VIP"))()
		end)
		if success then
			RayfieldLibrary:Notify({Title = "Blaze Hub", Content = "รัน PISIT HUB สำเร็จ", Duration = 3})
		else
			warn("ไม่สามารถรันสคริปต์ได้: " .. tostring(err))
		end
	end,
})

UniversalScriptTab:CreateButton({
	Name = "รัน FE ServerHcker X",
	Callback = function()
		local success, err = pcall(function()
			loadstring(game:HttpGet("https://rawscripts.net/raw/UP-Just-a-baseplate.-FE-ServerHcker-X-or-Working-226068"))()
		end)
		if success then
			RayfieldLibrary:Notify({Title = "Blaze Hub", Content = "รัน FE ServerHcker X สำเร็จ", Duration = 3})
		else
			warn("ไม่สามารถรันสคริปต์ได้: " .. tostring(err))
		end
	end,
})

UniversalScriptTab:CreateButton({
	Name = "รัน Akbarshox Fly V3",
	Callback = function()
		local success, err = pcall(function()
			loadstring(game:HttpGet("https://rawscripts.net/raw/Universal-Script-Akbarshox-Fly-V3-190419"))()
		end)
		if success then
			RayfieldLibrary:Notify({Title = "Blaze Hub", Content = "รัน Akbarshox Fly V3 สำเร็จ", Duration = 3})
		else
			warn("ไม่สามารถรันสคริปต์ได้: " .. tostring(err))
		end
	end,
})

-- ==================== หน้า แมพขโมยไข่ ====================
EggMapTab:CreateButton({
	Name = "รัน Steal a Egg Script",
	Callback = function()
		local success, err = pcall(function()
			loadstring(game:HttpGet("https://raw.githubusercontent.com/miirandahub/loader/refs/heads/main/stealaegg"))()
		end)
		if success then
			RayfieldLibrary:Notify({Title = "Blaze Hub", Content = "รัน Steal a Egg สำเร็จ", Duration = 3})
		else
			warn("ไม่สามารถรันสคริปต์ได้: " .. tostring(err))
		end
	end,
})

EggMapTab:CreateButton({
	Name = "รัน Steal a Egg (Luarmor Loader)",
	Callback = function()
		local success, err = pcall(function()
			loadstring(game:HttpGet("https://api.luarmor.net/files/v4/loaders/36107afd3107e8d841f9d1a69e2465d4.lua"))()
		end)
		if success then
			RayfieldLibrary:Notify({Title = "Blaze Hub", Content = "รัน Luarmor Loader สำเร็จ", Duration = 3})
		else
			warn("ไม่สามารถรันสคริปต์ได้: " .. tostring(err))
		end
	end,
})

-- ==================== หน้า BlazeHub Exclusive ====================
BlazeHubTab:CreateButton({
	Name = "รันสคริปต์ BlazeHub Exclusive #1",
	Callback = function()
		local success, err = pcall(function()
			loadstring(game:HttpGet("https://encrypt-x.pages.dev/Scripts?Id=4889003401049"))("4889003401049")
		end)
		if success then
			RayfieldLibrary:Notify({Title = "Blaze Hub", Content = "รัน Exclusive #1 สำเร็จ", Duration = 3})
		else
			warn("ไม่สามารถรันสคริปต์ได้: " .. tostring(err))
		end
	end,
})

BlazeHubTab:CreateButton({
	Name = "สคริปแมพอนิเมะเคสสุดท้าย ของค่าย BlazeHub",
	Callback = function()
		local success, err = pcall(function()
			loadstring(game:HttpGet("https://encrypt-x.pages.dev/Scripts?Id=7373871295903"))("7373871295903")
		end)
		if success then
			RayfieldLibrary:Notify({Title = "Blaze Hub", Content = "รันสำเร็จ", Duration = 3})
		else
			warn("ไม่สามารถรันสคริปต์ได้: " .. tostring(err))
		end
	end,
})

BlazeHubTab:CreateButton({
	Name = "ระบบสุ่มวิน (BlazeHub Exclusive)",
	Callback = function()
		local success, err = pcall(function()
			loadstring(game:HttpGet("https://pastebin.com/raw/mak79MAy"))()
		end)
		if success then
			RayfieldLibrary:Notify({Title = "Blaze Hub", Content = "รันระบบสุ่มวินสำเร็จ", Duration = 3})
		else
			warn("ไม่สามารถรันสคริปต์ได้: " .. tostring(err))
		end
	end,
})

-- =========================================================================
-- ระบบบวกลบวิน, สล็อตวิน (คืนค่าเลขน้อย + เลข 400, 500, 1000 ออกยากที่สุด) + สุ่ม Buff
-- =========================================================================

-- ลบอันเก่าทิ้งก่อนเพื่อป้องกันการซ้อนทับ
if playerGui:FindFirstChild("PlusMinusWinGui") then
    playerGui.PlusMinusWinGui:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PlusMinusWinGui"
screenGui.Parent = playerGui

-- ==========================================
-- ปุ่มเปิด-ปิดแยก 3 ปุ่ม (มุมซ้ายบน)
-- ==========================================
local toggleMainBtn = Instance.new("TextButton")
toggleMainBtn.Size = UDim2.new(0, 50, 0, 40)
toggleMainBtn.Position = UDim2.new(0, 20, 0, 20)
toggleMainBtn.BackgroundColor3 = Color3.fromRGB(46, 213, 115)
toggleMainBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleMainBtn.TextScaled = true
toggleMainBtn.Font = Enum.Font.GothamBold
toggleMainBtn.Text = "Main"
toggleMainBtn.Parent = screenGui

local tmCorner = Instance.new("UICorner")
tmCorner.CornerRadius = UDim.new(0, 8)
tmCorner.Parent = toggleMainBtn

local tmStroke = Instance.new("UIStroke")
tmStroke.Thickness = 2
tmStroke.Color = Color3.fromRGB(255, 255, 255)
tmStroke.Parent = toggleMainBtn

local toggleRouletteBtn = Instance.new("TextButton")
toggleRouletteBtn.Size = UDim2.new(0, 50, 0, 40)
toggleRouletteBtn.Position = UDim2.new(0, 75, 0, 20)
toggleRouletteBtn.BackgroundColor3 = Color3.fromRGB(255, 165, 2)
toggleRouletteBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleRouletteBtn.TextScaled = true
toggleRouletteBtn.Font = Enum.Font.GothamBold
toggleRouletteBtn.Text = "Slot"
toggleRouletteBtn.Parent = screenGui

local trCorner = Instance.new("UICorner")
trCorner.CornerRadius = UDim.new(0, 8)
trCorner.Parent = toggleRouletteBtn

local trStroke = Instance.new("UIStroke")
trStroke.Thickness = 2
trStroke.Color = Color3.fromRGB(255, 255, 255)
trStroke.Parent = toggleRouletteBtn

local toggleBuffBtn = Instance.new("TextButton")
toggleBuffBtn.Size = UDim2.new(0, 50, 0, 40)
toggleBuffBtn.Position = UDim2.new(0, 130, 0, 20)
toggleBuffBtn.BackgroundColor3 = Color3.fromRGB(112, 161, 255)
toggleBuffBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleBuffBtn.TextScaled = true
toggleBuffBtn.Font = Enum.Font.GothamBold
toggleBuffBtn.Text = "Buff"
toggleBuffBtn.Parent = screenGui

local tbCorner = Instance.new("UICorner")
tbCorner.CornerRadius = UDim.new(0, 8)
tbCorner.Parent = toggleBuffBtn

local tbStroke = Instance.new("UIStroke")
tbStroke.Thickness = 2
tbStroke.Color = Color3.fromRGB(255, 255, 255)
tbStroke.Parent = toggleBuffBtn

-- ==========================================
-- 1. UI สุ่มสล็อตวิน (Roulette Frame)
-- ==========================================
local rouletteFrame = Instance.new("Frame")
rouletteFrame.Size = UDim2.new(0, 340, 0, 135)
rouletteFrame.Position = UDim2.new(0, 20, 0.5, -140)
rouletteFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
rouletteFrame.BorderSizePixel = 0
rouletteFrame.Parent = screenGui

local rCorner = Instance.new("UICorner")
rCorner.CornerRadius = UDim.new(0, 12)
rCorner.Parent = rouletteFrame

local rouletteStroke = Instance.new("UIStroke")
rouletteStroke.Thickness = 3
rouletteStroke.Parent = rouletteFrame

-- ==========================================
-- 2. UI สุ่ม Buff (แบบย่อเล็ก)
-- ==========================================
local buffFrame = Instance.new("Frame")
buffFrame.Size = UDim2.new(0, 260, 0, 85)
buffFrame.Position = UDim2.
