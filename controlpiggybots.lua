local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local localPlayer = Players.LocalPlayer
local mouse = localPlayer:GetMouse()
local Camera = Workspace.CurrentCamera
local UNDER_OFFSET = 11

-- Setup Humanoid & SimulationRadius
local function setupHumanoid(character)
	local humanoid = character:WaitForChild("Humanoid")
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
end

localPlayer.CharacterAdded:Connect(setupHumanoid)
if localPlayer.Character then
	setupHumanoid(localPlayer.Character)
end

if type(sethiddenproperty) == "function" then
	pcall(function() sethiddenproperty(localPlayer, "SimulationRadius", math.huge) end)
elseif type(setsimulationradius) == "function" then
	pcall(function() setsimulationradius(math.huge) end)
end

-- Normalize ItemFolder for Piggy features
local itemFolder = Workspace:FindFirstChild("ItemFolder") or Workspace:FindFirstChild("ItemFolder1")
if not itemFolder then
	for _, child in pairs(Workspace:GetChildren()) do
		if string.match(child.Name, "%d") then
			itemFolder = child
			break
		end
	end
end
if itemFolder then
	itemFolder.Name = "ItemFolder1"
end

-- Create Rayfield Window
local Window = Rayfield:CreateWindow({
	Name = "Control Bots",
	LoadingTitle = "Control Bots",
	LoadingSubtitle = "NPC Controller & Utilities",
	ConfigurationSaving = { Enabled = false },
	Discord = { Enabled = false },
	KeySystem = false,
})

local ControlTab = Window:CreateTab("Control")
local MainTab = Window:CreateTab("Main")
local EspTab = Window:CreateTab("ESP")
local PlayerTab = Window:CreateTab("Player")
local TrollingTab = Window:CreateTab("Trolling")

-- ==========================================
-- CONTROL TAB (Combined Physics Control + Legacy Mode + View NPC)
-- ==========================================
local selectedNPC = nil
local npcMap = {}
local viewingNPC = nil
local jumpGui = nil
local playerControls = nil

-- Physics / Dummy Clone State
local Controlling = false
local CurrentlyControlledNPC = nil
local OriginalProperties = {}
local DisposableInstances = {}
local OriginalPosition = nil
local ControlMode = "Normal" -- "Normal" or "Killer"
local ClickToControlEnabled = false

local DummyModel, DummyRootPart = nil, nil
local NPCModel, NPCRootPart, NPCHighlighter = nil, nil, nil
local DummyDiedConnection, ClientHealthChangedConnection = nil, nil
local PhysicsHeartbeatConn = nil

local function getOwnCharacter()
	return localPlayer.Character
end

local function getOwnHumanoid()
	local char = getOwnCharacter()
	return char and char:FindFirstChildOfClass("Humanoid")
end

local function getOwnRootPart()
	local char = getOwnCharacter()
	return char and char:FindFirstChild("HumanoidRootPart")
end

local function CreateDisposableInstance(className, properties)
	properties = properties or {}
	local instance = Instance.new(className)
	table.insert(DisposableInstances, instance)
	for name, value in pairs(properties) do
		instance[name] = value
	end
	return instance
end

local ClientHighlighter = CreateDisposableInstance("Highlight", {
	FillTransparency = 1,
	OutlineColor = Color3.fromRGB(75, 150, 255),
	Enabled = false,
})

local ClientAttachment = CreateDisposableInstance("Attachment")
local DummyAttachment = CreateDisposableInstance("Attachment")
local NPCAttachment = CreateDisposableInstance("Attachment")

local ClientVelocity = CreateDisposableInstance("LinearVelocity", {
	Attachment0 = ClientAttachment,
	MaxForce = math.huge,
	Enabled = false,
	Parent = Workspace,
})

local NPCAlignPosition = CreateDisposableInstance("AlignPosition", {
	ApplyAtCenterOfMass = false,
	Attachment0 = NPCAttachment,
	Attachment1 = DummyAttachment,
	MaxForce = math.huge,
	Responsiveness = math.huge,
	Enabled = false,
	Parent = Workspace,
})

local NPCAlignOrientation = CreateDisposableInstance("AlignOrientation", {
	MaxTorque = math.huge,
	Responsiveness = math.huge,
	Attachment0 = NPCAttachment,
	Attachment1 = DummyAttachment,
	Enabled = false,
	Parent = Workspace,
})

local function SetOriginalProperty(instance, name, value)
	local instanceOriginalProperties = OriginalProperties[instance] or {}
	if instanceOriginalProperties[name] == nil then
		instanceOriginalProperties[name] = value
	end
	OriginalProperties[instance] = instanceOriginalProperties
end

local function SetCameraSubject(subject)
	local camera = Workspace.CurrentCamera
	if camera and subject then
		camera.CameraSubject = subject
	end
end

local function jumpControlledNPC()
	if DummyModel then
		local dHum = DummyModel:FindFirstChildOfClass("Humanoid")
		if dHum and dHum.Health > 0 then
			dHum:ChangeState(Enum.HumanoidStateType.Jumping)
		end
	end
end

local function createJumpGui()
	if jumpGui then return end

	local gui = Instance.new("ScreenGui")
	gui.Name = "ControlBotsJump"
	gui.ResetOnSpawn = false
	gui.Enabled = false

	local button = Instance.new("TextButton")
	button.Size = UDim2.fromOffset(90, 90)
	button.Position = UDim2.new(1, -120, 1, -170)
	button.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	button.BackgroundTransparency = 0.3
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Text = "JUMP"
	button.TextScaled = true
	button.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = button

	button.Activated:Connect(jumpControlledNPC)

	gui.Parent = localPlayer:WaitForChild("PlayerGui")
	jumpGui = gui
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or not Controlling then return end
	if input.KeyCode == Enum.KeyCode.Space then
		jumpControlledNPC()
	end
end)

local function StopControlling(restorePosition)
	Controlling = false
	CurrentlyControlledNPC = nil

	if PhysicsHeartbeatConn then
		PhysicsHeartbeatConn:Disconnect()
		PhysicsHeartbeatConn = nil
	end

	if ClientHealthChangedConnection then
		ClientHealthChangedConnection:Disconnect()
		ClientHealthChangedConnection = nil
	end

	if DummyDiedConnection then
		DummyDiedConnection:Disconnect()
		DummyDiedConnection = nil
	end

	NPCAlignPosition.Enabled = false
	NPCAlignOrientation.Enabled = false
	ClientVelocity.Enabled = false

	local char = getOwnCharacter()
	local hum = getOwnHumanoid()
	local hrp = getOwnRootPart()

	if char and hum then
		localPlayer.Character = char
		SetCameraSubject(hum)
	end

	DummyAttachment.Parent = nil
	NPCAttachment.Parent = nil

	if DummyModel then
		DummyModel:Destroy()
		DummyModel = nil
	end
	DummyRootPart = nil

	if NPCHighlighter then
		NPCHighlighter:Destroy()
		NPCHighlighter = nil
	end

	NPCModel = nil
	NPCRootPart = nil

	if jumpGui then
		jumpGui.Enabled = false
	end

	if hum and hum.Health > 0 then
		if restorePosition and OriginalPosition and hrp then
			hrp.CFrame = OriginalPosition
			OriginalPosition = nil
		end

		for instance, originalProperties in pairs(OriginalProperties) do
			if instance and instance.Parent then
				for name, value in pairs(originalProperties) do
					pcall(function() instance[name] = value end)
				end
			end
			OriginalProperties[instance] = nil
		end

		if char then
			for _, part in ipairs(char:GetChildren()) do
				if part:IsA("BasePart") then
					part.CanTouch = true
					part.CanCollide = true
				end
			end
		end

		ClientHighlighter.Enabled = false
		hum.PlatformStand = false
	end
end

local function StartControlling(npcModel)
	if Controlling then
		StopControlling(true)
	end
	if not npcModel or not npcModel.Parent then return end

	local npcHumanoid = npcModel:FindFirstChildOfClass("Humanoid")
	local npcRootPart = npcHumanoid and (npcHumanoid.RootPart or npcModel:FindFirstChild("HumanoidRootPart"))
	local char = getOwnCharacter()
	local hum = getOwnHumanoid()
	local hrp = getOwnRootPart()

	if not (npcRootPart and npcHumanoid and char and hum and hrp) then return end
	if Players:GetPlayerFromCharacter(npcModel) or npcModel == char then return end

	viewingNPC = nil
	CurrentlyControlledNPC = npcModel
	OriginalPosition = hrp.CFrame

	ClientHighlighter.Parent = char
	ClientHighlighter.Enabled = true
	ClientAttachment.Parent = hrp
	SetOriginalProperty(hrp, "CFrame", hrp.CFrame)

	hum.PlatformStand = true

	for _, part in ipairs(char:GetChildren()) do
		if part:IsA("BasePart") then
			part.CanTouch = false
			part.CanCollide = false
		end
	end

	pcall(function() npcRootPart.BodyPosition:Destroy() end)
	pcall(function() npcRootPart.BodyGyro:Destroy() end)

	local dummyModel = npcModel:Clone()
	local dummyHumanoid = dummyModel:FindFirstChildOfClass("Humanoid")
	local dummyRootPart = dummyModel:FindFirstChild(npcRootPart.Name) or dummyModel:FindFirstChild("HumanoidRootPart")

	if not dummyHumanoid or not dummyRootPart then
		hum.PlatformStand = false
		ClientHighlighter.Enabled = false
		CurrentlyControlledNPC = nil
		return
	end

	if ControlMode == "Normal" then
		DummyDiedConnection = dummyHumanoid.Died:Once(function()
			if Controlling then StopControlling(true) end
		end)
	else
		DummyDiedConnection = dummyHumanoid.Died:Once(function()
			if Controlling and hum then hum.Health = 0 end
		end)
	end

	local function updateHealth()
		if Controlling and hum and dummyHumanoid then
			dummyHumanoid.MaxHealth = math.huge
			dummyHumanoid.Health = math.huge
			hum.Health = math.huge
		end
	end

	ClientHealthChangedConnection = hum.Changed:Connect(updateHealth)
	updateHealth()

	for _, descendant in pairs(dummyModel:GetDescendants()) do
		if descendant:IsA("Light") or descendant:IsA("Sound") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Transparency = 0.95
			descendant.CanCollide = false
			descendant.CanTouch = false
		end
	end

	DummyModel = dummyModel
	DummyRootPart = dummyRootPart
	dummyModel.Parent = Workspace

	DummyAttachment.Parent = dummyRootPart
	NPCAttachment.Parent = npcRootPart

	NPCModel = npcModel
	NPCRootPart = npcRootPart

	NPCHighlighter = Instance.new("Highlight")
	NPCHighlighter.FillTransparency = 1
	NPCHighlighter.OutlineColor = Color3.fromRGB(255, 0, 0)
	NPCHighlighter.Parent = npcModel

	local DummyHighlighter = Instance.new("Highlight")
	DummyHighlighter.FillTransparency = 1
	DummyHighlighter.OutlineColor = Color3.fromRGB(128, 0, 128)
	DummyHighlighter.Parent = dummyModel

	createJumpGui()
	jumpGui.Enabled = UserInputService.TouchEnabled

	SetCameraSubject(dummyHumanoid)
	localPlayer.Character = dummyModel

	NPCAlignPosition.Enabled = true
	NPCAlignOrientation.Enabled = true
	ClientVelocity.Enabled = true
	Controlling = true

	-- Heartbeat loop: keeps SimulationRadius maxed & anchors/positions your player 11 studs under the NPC
	PhysicsHeartbeatConn = RunService.Heartbeat:Connect(function()
		if not Controlling then return end

		local currentChar = getOwnCharacter()
		local currentHrp = getOwnRootPart()
		local currentHum = getOwnHumanoid()

		if not NPCRootPart or not NPCRootPart.Parent
			or not currentHrp or not currentHrp.Parent
			or not currentHum or currentHum.Health <= 0 then
			StopControlling(true)
			return
		end

		if type(sethiddenproperty) == "function" then
			pcall(function() sethiddenproperty(localPlayer, "SimulationRadius", math.huge) end)
		elseif type(setsimulationradius) == "function" then
			pcall(function() setsimulationradius(math.huge) end)
		end

		-- Teleport actual player 11 studs underneath the NPC
		local npcPos = NPCRootPart.Position
		currentHrp.CFrame = CFrame.new(npcPos.X, npcPos.Y - UNDER_OFFSET, npcPos.Z) * NPCRootPart.CFrame.Rotation

		if currentChar then
			for _, child in pairs(currentChar:GetChildren()) do
				if child:IsA("BasePart") then
					if child.CanCollide then
						SetOriginalProperty(child, "CanCollide", true)
						child.CanCollide = false
					end
					if child.CanTouch then
						SetOriginalProperty(child, "CanTouch", true)
						child.CanTouch = false
					end
				end
			end
		end

		if NPCModel then
			for _, child in pairs(NPCModel:GetChildren()) do
				if child:IsA("BasePart") and child.CanCollide then
					SetOriginalProperty(child, "CanCollide", true)
					child.CanCollide = false
				end
			end
		end
	end)
end

-- Killer Mode Loop (auto-targets nearest survivor when Mode == "Killer")
task.spawn(function()
	while true do
		task.wait(0.5)
		if not Controlling or ControlMode ~= "Killer" then continue end
		if not NPCModel or not DummyRootPart then continue end

		for _, objc in ipairs(NPCModel:GetDescendants()) do
			if objc:IsA("TouchTransmitter") or objc:IsA("Script") then
				objc:Destroy()
			end
		end

		local closestRootPart = nil
		local closestDist = math.huge
		local mainSpawn = Workspace:FindFirstChild("GameFolder") and Workspace.GameFolder:FindFirstChild("MainSpawn")

		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= localPlayer and plr.Character
				and not plr.Character:FindFirstChild("Enemy")
				and not plr.Character:FindFirstChild("Traitor") then
				local rPart = plr.Character:FindFirstChild("HumanoidRootPart")
				if rPart then
					if mainSpawn then
						local dist = (rPart.Position - mainSpawn.Position).Magnitude
						if dist >= 20 and dist < closestDist then
							closestDist = dist
							closestRootPart = rPart
						end
					else
						closestRootPart = rPart
						break
					end
				end
			end
		end

		if closestRootPart then
			DummyRootPart.CFrame = closestRootPart.CFrame * CFrame.new(0, 2, -9)
		end
	end
end)

-- NPC List & Dropdown
local function getNPCList()
	local names, map = {}, {}
	for _, inst in ipairs(Workspace:GetDescendants()) do
		if inst:IsA("Model") and not Players:GetPlayerFromCharacter(inst) and inst ~= DummyModel then
			local hum = inst:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 and inst:FindFirstChild("HumanoidRootPart") then
				local label, count = inst.Name, 1
				while map[label] do
					count += 1
					label = inst.Name .. " (" .. count .. ")"
				end
				map[label] = inst
				table.insert(names, label)
			end
		end
	end
	table.sort(names)
	return names, map
end

local initialNames, initialMap = getNPCList()
npcMap = initialMap

local NPCDropdown = ControlTab:CreateDropdown({
	Name = "Available NPCs",
	Options = initialNames,
	CurrentOption = {},
	MultipleOptions = false,
	Flag = "AvailableNPCs",
	Callback = function(options)
		local choice = type(options) == "table" and options[1] or options
		selectedNPC = choice and npcMap[choice] or nil
	end,
})

local lastSignature = table.concat(initialNames, "|")
task.spawn(function()
	while true do
		task.wait(2)
		local names, map = getNPCList()
		npcMap = map
		if selectedNPC and not selectedNPC.Parent then
			selectedNPC = nil
		end
		local signature = table.concat(names, "|")
		if signature ~= lastSignature then
			lastSignature = signature
			NPCDropdown:Refresh(names)
		end
	end
end)

ControlTab:CreateButton({
	Name = "View NPC",
	Callback = function()
		if Controlling then
			Rayfield:Notify({ Title = "Control Bots", Content = "Release the NPC you are controlling first.", Duration = 3 })
			return
		end
		if not selectedNPC or not selectedNPC.Parent then
			Rayfield:Notify({ Title = "Control Bots", Content = "Select an NPC from the list first.", Duration = 3 })
			return
		end
		local hum = selectedNPC:FindFirstChildOfClass("Humanoid")
		if not hum then return end

		if viewingNPC == selectedNPC then
			viewingNPC = nil
			local ownHum = getOwnHumanoid()
			if ownHum then Workspace.CurrentCamera.CameraSubject = ownHum end
			Rayfield:Notify({ Title = "Control Bots", Content = "Camera returned to your character.", Duration = 3 })
		else
			viewingNPC = selectedNPC
			Workspace.CurrentCamera.CameraSubject = hum
			Rayfield:Notify({ Title = "Control Bots", Content = "Now viewing " .. selectedNPC.Name .. ".", Duration = 3 })
		end
	end,
})

ControlTab:CreateButton({
	Name = "Control Selected NPC",
	Callback = function()
		if Controlling then
			StopControlling(true)
			Rayfield:Notify({ Title = "Control Bots", Content = "You released the NPC.", Duration = 3 })
			return
		end
		if not selectedNPC or not selectedNPC.Parent then
			Rayfield:Notify({ Title = "Control Bots", Content = "Select an NPC from the list first.", Duration = 3 })
			return
		end
		StartControlling(selectedNPC)
		local hint = UserInputService.TouchEnabled and "Use the thumbstick and JUMP button." or "Use WASD and Space."
		Rayfield:Notify({ Title = "Control Bots", Content = "Controlling " .. selectedNPC.Name .. " (" .. ControlMode .. " Mode). " .. hint, Duration = 5 })
	end,
})

ControlTab:CreateDropdown({
	Name = "Control Mode",
	Options = { "Normal", "Killer" },
	CurrentOption = { "Normal" },
	MultipleOptions = false,
	Flag = "ControlMode",
	Callback = function(options)
		local choice = type(options) == "table" and options[1] or options
		ControlMode = choice or "Normal"
		Rayfield:Notify({ Title = "Control Bots", Content = "Control Mode set to: " .. ControlMode, Duration = 2 })
	end,
})

ControlTab:CreateToggle({
	Name = "Click/Tap NPC to Control (Old Method)",
	CurrentValue = false,
	Flag = "ClickToControl",
	Callback = function(Value)
		ClickToControlEnabled = Value
	end,
})

mouse.Button1Down:Connect(function()
	if not ClickToControlEnabled then return end
	local target = mouse.Target
	if not target then return end

	local model = target
	while model and model ~= Workspace do
		local h = model:FindFirstChildOfClass("Humanoid")
		if h and (h.RootPart or model:FindFirstChild("HumanoidRootPart")) and not Players:GetPlayerFromCharacter(model) then
			StartControlling(model)
			Rayfield:Notify({ Title = "Control Bots", Content = "Controlling " .. model.Name .. " via Click/Tap.", Duration = 3 })
			break
		end
		model = model.Parent
	end
end)

-- ==========================================
-- MAIN TAB (From Old Script)
-- ==========================================
local godMode1Active = false
MainTab:CreateToggle({
	Name = "God Mode (Piggy Bots Only)",
	CurrentValue = false,
	Flag = "GodModeBots",
	Callback = function(Value)
		godMode1Active = Value
		if Value then
			task.spawn(function()
				while godMode1Active do
					for _, obj in ipairs(Workspace:GetDescendants()) do
						if obj:FindFirstChild("Enemy") and obj:FindFirstChild("HumanoidRootPart") and not obj:FindFirstChild("ToolRequired") then
							for _, er in ipairs(obj:GetDescendants()) do
								if er:IsA("TouchTransmitter") then
									er:Destroy()
								end
							end
						end
					end
					task.wait(1)
				end
			end)
		end
	end,
})

local godMode2Active = false
MainTab:CreateToggle({
	Name = "God Mode 2 (Objects Only)",
	CurrentValue = false,
	Flag = "GodModeObjects",
	Callback = function(Value)
		godMode2Active = Value
		if Value then
			task.spawn(function()
				while godMode2Active do
					local char = getOwnCharacter()
					if char then
						for _, part in ipairs(char:GetChildren()) do
							if part:IsA("BasePart") then
								part.CanTouch = false
							end
						end
					end
					task.wait(1)
				end
			end)
		else
			local char = getOwnCharacter()
			if char then
				for _, part in ipairs(char:GetChildren()) do
					if part:IsA("BasePart") then
						part.CanTouch = true
					end
				end
			end
		end
	end,
})

local disableTrapsActive = false
MainTab:CreateToggle({
	Name = "Disable Traps",
	CurrentValue = false,
	Flag = "DisableTraps",
	Callback = function(Value)
		disableTrapsActive = Value
		if Value then
			task.spawn(function()
				while disableTrapsActive do
					local folder = Workspace:FindFirstChild("ItemFolder1")
					if folder then
						for _, item in pairs(folder:GetDescendants()) do
							if string.find(item.Name, "Trap") then
								for _, descendant in pairs(item:GetDescendants()) do
									if descendant:IsA("TouchTransmitter") then
										descendant:Destroy()
									end
								end
							end
						end
					end
					task.wait(0.5)
				end
			end)
		end
	end,
})

local disableCollisionActive = false
MainTab:CreateToggle({
	Name = "Disable Vent Crouch Blocker",
	CurrentValue = false,
	Flag = "DisableCrouchBlocker",
	Callback = function(Value)
		disableCollisionActive = Value
		if Value then
			task.spawn(function()
				while disableCollisionActive do
					local hrp = getOwnRootPart()
					if hrp and hrp:FindFirstChild("CrouchBlocker") then
						hrp:FindFirstChild("CrouchBlocker"):Destroy()
					end
					task.wait(2)
				end
			end)
		end
	end,
})

-- ==========================================
-- ESP TAB (From Old Script)
-- ==========================================
local piggyEspActive = false
EspTab:CreateToggle({
	Name = "Piggy ESP",
	CurrentValue = false,
	Flag = "PiggyESP",
	Callback = function(Value)
		piggyEspActive = Value
		if Value then
			task.spawn(function()
				while piggyEspActive do
					for _, obj in ipairs(Workspace:GetDescendants()) do
						if obj:FindFirstChild("Enemy") and obj:FindFirstChild("HumanoidRootPart") and not obj:FindFirstChild("CHICKEN2") and not obj:FindFirstChild("ToolRequired") and obj ~= localPlayer.Character then
							local old = obj:FindFirstChildOfClass("Highlight")
							if old and old.Name ~= "CHICKEN2" then old:Destroy() end

							local highlight = Instance.new("Highlight")
							highlight.Adornee = obj
							highlight.Name = "CHICKEN2"
							highlight.FillTransparency = 0.5
							highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
							highlight.OutlineTransparency = 0.5
							highlight.FillColor = (obj.Parent and obj.Parent.Name == "PiggyNPC") and Color3.fromRGB(0, 0, 255) or Color3.fromRGB(255, 0, 0)
							highlight.Parent = obj
						end
					end
					task.wait(1.5)
				end
			end)
		else
			for _, obj in ipairs(Workspace:GetDescendants()) do
				if obj.Name == "CHICKEN2" then
					obj:Destroy()
				end
			end
		end
	end,
})

local survivorsEspActive = false
EspTab:CreateToggle({
	Name = "Survivors ESP",
	CurrentValue = false,
	Flag = "SurvivorsESP",
	Callback = function(Value)
		survivorsEspActive = Value
		if Value then
			task.spawn(function()
				while survivorsEspActive do
					local mainSpawn = Workspace:FindFirstChild("GameFolder") and Workspace.GameFolder:FindFirstChild("MainSpawn")
					for _, plr in ipairs(Players:GetPlayers()) do
						local char = plr.Character
						if plr ~= localPlayer and char and not char:FindFirstChild("Enemy") and not char:FindFirstChild("Traitor") then
							local hrp = char:FindFirstChild("HumanoidRootPart")
							local existing = char:FindFirstChild("SurvivorESP_HL")
							if hrp then
								local dist = mainSpawn and (hrp.Position - mainSpawn.Position).Magnitude or 999
								if dist >= 20 then
									if not existing then
										local highlight = Instance.new("Highlight")
										highlight.Name = "SurvivorESP_HL"
										highlight.FillColor = Color3.fromRGB(0, 255, 255)
										highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
										highlight.Parent = char
									end
								elseif existing then
									existing:Destroy()
								end
							end
						end
					end
					task.wait(1)
				end
			end)
		else
			for _, plr in ipairs(Players:GetPlayers()) do
				if plr.Character and plr.Character:FindFirstChild("SurvivorESP_HL") then
					plr.Character.SurvivorESP_HL:Destroy()
				end
			end
		end
	end,
})

local itemsEspActive = false
EspTab:CreateToggle({
	Name = "Items ESP",
	CurrentValue = false,
	Flag = "ItemsESP",
	Callback = function(Value)
		itemsEspActive = Value
		if Value then
			task.spawn(function()
				while itemsEspActive do
					local folder = Workspace:FindFirstChild("ItemFolder1")
					if folder then
						for _, item in pairs(folder:GetChildren()) do
							if item:IsA("BasePart") and item.Transparency ~= 1 and (item:FindFirstChildOfClass("ClickDetector") or item:FindFirstChildOfClass("ProximityPrompt")) then
								if not item:FindFirstChild("CHICKENOA2") or not item:FindFirstChild("CHICKENOA") then
									local billboard = Instance.new("BillboardGui")
									billboard.Size = UDim2.new(4, 0, 1.5, 0)
									billboard.AlwaysOnTop = true
									billboard.Adornee = item
									billboard.StudsOffset = Vector3.new(0, 3, 0)
									billboard.MaxDistance = 1000
									billboard.Name = "CHICKENOA2"
									billboard.Parent = item

									local textLabel = Instance.new("TextLabel")
									textLabel.Text = string.match(item.Name, "%d") and "Item" or item.Name
									textLabel.Size = UDim2.new(1, 0, 1, 0)
									textLabel.BackgroundTransparency = 1
									textLabel.Font = Enum.Font.SourceSansBold
									textLabel.TextColor3 = Color3.new(1, 1, 1)
									textLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
									textLabel.TextStrokeTransparency = 0.5
									textLabel.TextScaled = true
									textLabel.Parent = billboard

									local highlight = Instance.new("Highlight")
									highlight.Name = "CHICKENOA"
									local emitter = item:FindFirstChildOfClass("ParticleEmitter")
									highlight.FillColor = emitter and emitter.Color.Keypoints[1].Value or Color3.fromRGB(0, 255, 0)
									highlight.OutlineColor = Color3.new(1, 1, 1)
									highlight.FillTransparency = 0.6
									highlight.OutlineTransparency = 0.3
									highlight.Adornee = item
									highlight.Parent = item
								end
							end
						end
					end
					task.wait(1)
				end
			end)
		else
			local folder = Workspace:FindFirstChild("ItemFolder1")
			if folder then
				for _, item in pairs(folder:GetDescendants()) do
					if item.Name == "CHICKENOA" or item.Name == "CHICKENOA2" then
						item:Destroy()
					end
				end
			end
		end
	end,
})

local friendlyEspActive = false
EspTab:CreateToggle({
	Name = "Friendly Bots ESP",
	CurrentValue = false,
	Flag = "FriendlyBotsESP",
	Callback = function(Value)
		friendlyEspActive = Value
		if Value then
			task.spawn(function()
				while friendlyEspActive do
					for _, obj in ipairs(Workspace:GetDescendants()) do
						if obj:FindFirstChild("Enemy") and obj:FindFirstChild("HumanoidRootPart") and obj:FindFirstChild("ToolRequired") and not obj:FindFirstChild("CHICKEN") then
							local highlight = Instance.new("Highlight")
							highlight.Adornee = obj
							highlight.Name = "CHICKEN"
							highlight.FillColor = Color3.fromRGB(0, 255, 0)
							highlight.FillTransparency = 0.5
							highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
							highlight.OutlineTransparency = 0.5
							highlight.Parent = obj
						end
					end
					task.wait(1.5)
				end
			end)
		else
			for _, obj in ipairs(Workspace:GetDescendants()) do
				if obj.Name == "CHICKEN" then
					obj:Destroy()
				end
			end
		end
	end,
})

-- ==========================================
-- PLAYER TAB (From Old Script)
-- ==========================================
local IsOnMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local flyingActive = false
local flySpeed = 50
local flyKeyDown, flyKeyUp, mflyConn

local function stopFly()
	flyingActive = false
	if flyKeyDown then flyKeyDown:Disconnect() flyKeyDown = nil end
	if flyKeyUp then flyKeyUp:Disconnect() flyKeyUp = nil end
	if mflyConn then mflyConn:Disconnect() mflyConn = nil end

	local char = getOwnCharacter()
	local hum = getOwnHumanoid()
	local root = getOwnRootPart()
	if hum then hum.PlatformStand = false end
	if root then
		if root:FindFirstChild("ControlBots_BV") then root.ControlBots_BV:Destroy() end
		if root:FindFirstChild("ControlBots_BG") then root.ControlBots_BG:Destroy() end
	end
end

local function startFly()
	stopFly()
	flyingActive = true
	local char = getOwnCharacter()
	local root = getOwnRootPart()
	local hum = getOwnHumanoid()
	if not (char and root and hum) then return end

	local bv = Instance.new("BodyVelocity")
	bv.Name = "ControlBots_BV"
	bv.MaxForce = Vector3.new(9e9, 9e9, 9e9)
	bv.Velocity = Vector3.zero
	bv.Parent = root

	local bg = Instance.new("BodyGyro")
	bg.Name = "ControlBots_BG"
	bg.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
	bg.P = 9e4
	bg.CFrame = root.CFrame
	bg.Parent = root

	if IsOnMobile then
		local controlModule
		pcall(function()
			controlModule = require(localPlayer.PlayerScripts:WaitForChild("PlayerModule"):WaitForChild("ControlModule"))
		end)
		mflyConn = RunService.RenderStepped:Connect(function()
			if not flyingActive or not root.Parent then return end
			local cam = Workspace.CurrentCamera
			hum.PlatformStand = true
			bg.CFrame = cam.CFrame
			local dir = controlModule and controlModule:GetMoveVector() or Vector3.zero
			bv.Velocity = (cam.CFrame.RightVector * (dir.X * flySpeed)) - (cam.CFrame.LookVector * (dir.Z * flySpeed))
		end)
	else
		local keys = { F = 0, B = 0, L = 0, R = 0 }
		flyKeyDown = mouse.KeyDown:Connect(function(k)
			k = k:lower()
			if k == "w" then keys.F = 1
			elseif k == "s" then keys.B = -1
			elseif k == "a" then keys.L = -1
			elseif k == "d" then keys.R = 1 end
		end)
		flyKeyUp = mouse.KeyUp:Connect(function(k)
			k = k:lower()
			if k == "w" then keys.F = 0
			elseif k == "s" then keys.B = 0
			elseif k == "a" then keys.L = 0
			elseif k == "d" then keys.R = 0 end
		end)
		mflyConn = RunService.RenderStepped:Connect(function()
			if not flyingActive or not root.Parent then return end
			local cam = Workspace.CurrentCamera
			hum.PlatformStand = true
			bg.CFrame = cam.CFrame
			bv.Velocity = (cam.CFrame.LookVector * (keys.F + keys.B) * flySpeed) + (cam.CFrame.RightVector * (keys.L + keys.R) * flySpeed)
		end)
	end
end

PlayerTab:CreateToggle({
	Name = "Fly (PC & Mobile)",
	CurrentValue = false,
	Flag = "FlyToggle",
	Callback = function(Value)
		if Value then startFly() else stopFly() end
	end,
})

local noclipActive = false
PlayerTab:CreateToggle({
	Name = "Noclip",
	CurrentValue = false,
	Flag = "NoclipToggle",
	Callback = function(Value)
		noclipActive = Value
		if Value then
			task.spawn(function()
				while noclipActive do
					local char = getOwnCharacter()
					if char then
						for _, child in pairs(char:GetDescendants()) do
							if child:IsA("BasePart") then
								child.CanCollide = false
							end
						end
					end
					task.wait(0.2)
				end
			end)
		else
			local char = getOwnCharacter()
			if char then
				for _, child in pairs(char:GetDescendants()) do
					if (child.Name == "Torso" or child.Name == "HumanoidRootPart" or child.Name == "UpperTorso") then
						child.CanCollide = true
					end
				end
			end
		end
	end,
})

local customSpeed = 24
local speedToggleActive = false
PlayerTab:CreateSlider({
	Name = "WalkSpeed Amount",
	Range = { 16, 150 },
	Increment = 1,
	Suffix = " Speed",
	CurrentValue = 24,
	Flag = "WalkSpeedSlider",
	Callback = function(Value)
		customSpeed = Value
	end,
})

PlayerTab:CreateToggle({
	Name = "Enable Custom WalkSpeed",
	CurrentValue = false,
	Flag = "WalkSpeedToggle",
	Callback = function(Value)
		speedToggleActive = Value
		if Value then
			task.spawn(function()
				while speedToggleActive do
					local hum = getOwnHumanoid()
					if hum then hum.WalkSpeed = customSpeed end
					task.wait(0.3)
				end
			end)
		else
			local hum = getOwnHumanoid()
			if hum then hum.WalkSpeed = 16 end
		end
	end,
})

local customJump = 70
local jumpToggleActive = false
PlayerTab:CreateSlider({
	Name = "JumpPower Amount",
	Range = { 50, 250 },
	Increment = 5,
	Suffix = " Jump",
	CurrentValue = 70,
	Flag = "JumpPowerSlider",
	Callback = function(Value)
		customJump = Value
	end,
})

PlayerTab:CreateToggle({
	Name = "Enable Custom JumpPower",
	CurrentValue = false,
	Flag = "JumpPowerToggle",
	Callback = function(Value)
		jumpToggleActive = Value
		if Value then
			task.spawn(function()
				while jumpToggleActive do
					local hum = getOwnHumanoid()
					if hum then hum.JumpPower = customJump end
					task.wait(0.3)
				end
			end)
		else
			local hum = getOwnHumanoid()
			if hum then hum.JumpPower = 50 end
		end
	end,
})

local function GetPlayerNames()
	local names = {}
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= localPlayer then
			table.insert(names, plr.Name)
		end
	end
	return names
end

local TpDropdown = PlayerTab:CreateDropdown({
	Name = "Teleport to Player",
	Options = GetPlayerNames(),
	CurrentOption = {},
	MultipleOptions = false,
	Flag = "TeleportPlayer",
	Callback = function(options)
		local selectedName = type(options) == "table" and options[1] or options
		if not selectedName then return end
		local targetPlr = Players:FindFirstChild(selectedName)
		local targetRoot = targetPlr and targetPlr.Character and targetPlr.Character:FindFirstChild("HumanoidRootPart")
		local localRoot = getOwnRootPart()
		if targetRoot and localRoot then
			localRoot.CFrame = targetRoot.CFrame + Vector3.new(0, 3, 0)
		end
	end,
})

Players.PlayerAdded:Connect(function() TpDropdown:Refresh(GetPlayerNames()) end)
Players.PlayerRemoving:Connect(function() TpDropdown:Refresh(GetPlayerNames()) end)

-- ==========================================
-- TROLLING TAB (From Old Script)
-- ==========================================
TrollingTab:CreateButton({
	Name = "Kill Piggy (FE)",
	Callback = function()
		local piggyFolder = Workspace:FindFirstChild("PiggyNPC")
		local model = piggyFolder and piggyFolder:FindFirstChildOfClass("Model")
		if model and model.Name ~= "Prototype" then
			local hum = model:FindFirstChildOfClass("Humanoid")
			local rPart = model:FindFirstChild("HumanoidRootPart")
			if hum and rPart then
				for _, v in ipairs(model:GetChildren()) do
					if v:IsA("BasePart") then v.CanCollide = false end
				end
				rPart.Anchored = false
				hum.PlatformStand = true
				local bv = Instance.new("BodyVelocity")
				bv.Velocity = Vector3.new(0, -1000, 0)
				bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
				bv.P = math.huge
				bv.Parent = rPart
				Rayfield:Notify({ Title = "Control Bots", Content = "Sent Piggy into the void!", Duration = 3 })
			end
		else
			Rayfield:Notify({ Title = "Control Bots", Content = "No valid Piggy bot found.", Duration = 3 })
		end
	end,
})

local spinBotsActive = false
TrollingTab:CreateToggle({
	Name = "Spin Piggy Bots",
	CurrentValue = false,
	Flag = "SpinBots",
	Callback = function(Value)
		spinBotsActive = Value
		if Value then
			task.spawn(function()
				while spinBotsActive do
					for _, obj in ipairs(Workspace:GetDescendants()) do
						if obj:FindFirstChild("Enemy") and not obj:FindFirstChild("ToolRequired") and obj ~= localPlayer.Character then
							local hrp = obj:FindFirstChild("HumanoidRootPart")
							if hrp and not hrp:FindFirstChild("Spinning") then
								local spin = Instance.new("BodyAngularVelocity")
								spin.Name = "Spinning"
								spin.MaxTorque = Vector3.new(0, math.huge, 0)
								spin.AngularVelocity = Vector3.new(0, 35, 0)
								spin.Parent = hrp
							end
						end
					end
					task.wait(1.5)
				end
			end)
		else
			for _, obj in ipairs(Workspace:GetDescendants()) do
				if obj.Name == "Spinning" and obj:IsA("BodyAngularVelocity") then
					obj:Destroy()
				end
			end
		end
	end,
})

local spamDoorsActive = false
TrollingTab:CreateToggle({
	Name = "Spam Open Doors",
	CurrentValue = false,
	Flag = "SpamDoors",
	Callback = function(Value)
		spamDoorsActive = Value
		if Value then
			task.spawn(function()
				while spamDoorsActive do
					local foundSound = false
					for _, descendant in ipairs(Workspace:GetDescendants()) do
						if descendant:IsA("Sound") and descendant.SoundId == "rbxassetid://320946744" then
							local cd = descendant.Parent and descendant.Parent:FindFirstChildOfClass("ClickDetector")
							if cd and fireclickdetector then
								fireclickdetector(cd)
								foundSound = true
							end
						end
					end
					if not foundSound then
						for _, descendant in ipairs(Workspace:GetDescendants()) do
							if descendant:IsA("RemoteEvent") and descendant.Parent then
								local cd = descendant.Parent:FindFirstChildOfClass("ClickDetector")
								local wc = descendant.Parent:FindFirstChildOfClass("WeldConstraint")
								if cd and wc and fireclickdetector then
									fireclickdetector(cd)
								end
							end
						end
					end
					task.wait(0.5)
				end
			end)
		end
	end,
})
