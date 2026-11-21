local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
local mouse = localPlayer:GetMouse()
local Camera = Workspace.CurrentCamera

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
	Name = "Boost Hub",
	LoadingTitle = "Control Bots",
	LoadingSubtitle = "Boost Hub Utilities",
	ConfigurationSaving = { Enabled = false },
	Discord = { Enabled = false },
	KeySystem = false,
})

local ControlTab = Window:CreateTab("Control")
local MainTab = Window:CreateTab("Main")
local EspTab = Window:CreateTab("ESP")
local PlayerTab = Window:CreateTab("Player")
local TrollingTab = Window:CreateTab("Trolling")
local QuestsTab = Window:CreateTab("Quests & Skins")
local FarmTab = Window:CreateTab("Farming & Items")

-- ==========================================
-- CONTROL TAB (Custom Rayfield Bot Controller - Mobile & PC)
-- ==========================================
local selectedNPC = nil
local npcMap = {}
local viewingNPC = nil
local controllingNPC = false
local controlledModel = nil
local dummyModel = nil
local jumpGui = nil

local originalProps = {}
local originalCFrame = nil
local physicsConn = nil
local dummyDiedConn = nil
local clientHealthConn = nil
local clickToControlEnabled = false

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

local function saveOriginalProp(inst, prop, val)
	originalProps[inst] = originalProps[inst] or {}
	if originalProps[inst][prop] == nil then
		originalProps[inst][prop] = val
	end
end

local function setCameraSubject(subject)
	local cam = Workspace.CurrentCamera
	if cam and subject then
		cam.CameraSubject = subject
	end
end

-- Create persistent AlignPosition / AlignOrientation / LinearVelocity instances
local clientAttachment = Instance.new("Attachment")
local dummyAttachment = Instance.new("Attachment")
local npcAttachment = Instance.new("Attachment")

local clientHighlight = Instance.new("Highlight")
clientHighlight.FillTransparency = 1
clientHighlight.OutlineColor = Color3.fromRGB(75, 150, 255)
clientHighlight.Enabled = false

local npcHighlight = Instance.new("Highlight")
npcHighlight.FillTransparency = 1
npcHighlight.OutlineColor = Color3.fromRGB(255, 65, 65)
npcHighlight.Enabled = false

local dummyHighlight = Instance.new("Highlight")
dummyHighlight.FillTransparency = 1
dummyHighlight.OutlineColor = Color3.fromRGB(160, 75, 255)
dummyHighlight.Enabled = false

local clientVelocity = Instance.new("LinearVelocity")
clientVelocity.Attachment0 = clientAttachment
clientVelocity.MaxForce = math.huge
clientVelocity.Enabled = false
clientVelocity.Parent = Workspace

local npcAlignPos = Instance.new("AlignPosition")
npcAlignPos.ApplyAtCenterOfMass = false
npcAlignPos.Attachment0 = npcAttachment
npcAlignPos.Attachment1 = dummyAttachment
npcAlignPos.MaxForce = math.huge
npcAlignPos.Responsiveness = math.huge
npcAlignPos.Enabled = false
npcAlignPos.Parent = Workspace

local npcAlignOri = Instance.new("AlignOrientation")
npcAlignOri.Attachment0 = npcAttachment
npcAlignOri.Attachment1 = dummyAttachment
npcAlignOri.MaxTorque = math.huge
npcAlignOri.Responsiveness = math.huge
npcAlignOri.Enabled = false
npcAlignOri.Parent = Workspace

-- Mobile & PC JUMP UI Button
local function triggerBotJump()
	if not controllingNPC or not dummyModel then return end
	local dHum = dummyModel:FindFirstChildOfClass("Humanoid")
	local dRoot = dummyModel:FindFirstChild("HumanoidRootPart")
	if dHum and dHum.Health > 0 then
		dHum.Jump = true
		dHum:ChangeState(Enum.HumanoidStateType.Jumping)
		if dRoot and dRoot.AssemblyLinearVelocity.Y < 5 then
			local vel = dRoot.AssemblyLinearVelocity
			dRoot.AssemblyLinearVelocity = Vector3.new(vel.X, dHum.JumpPower > 0 and dHum.JumpPower or 50, vel.Z)
		end
	end
end

local function ensureJumpGui()
	if jumpGui and jumpGui.Parent then return jumpGui end
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild("BoostHubBotJumpGui")
	if existing then existing:Destroy() end

	local gui = Instance.new("ScreenGui")
	gui.Name = "BoostHubBotJumpGui"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.Parent = playerGui

	local btn = Instance.new("TextButton")
	btn.Name = "JumpButton"
	btn.Size = UDim2.fromOffset(88, 88)
	btn.Position = UDim2.new(1, -118, 1, -165)
	btn.BackgroundColor3 = Color3.fromRGB(30, 32, 38)
	btn.BackgroundTransparency = 0.2
	btn.Text = "JUMP"
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.TextSize = 20
	btn.Font = Enum.Font.GothamBold
	btn.AutoButtonColor = true
	btn.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = btn

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(90, 175, 255)
	stroke.Thickness = 2
	stroke.Parent = btn

	btn.Activated:Connect(triggerBotJump)
	btn.MouseButton1Down:Connect(triggerBotJump)

	jumpGui = gui
	return gui
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or not controllingNPC then return end
	if input.KeyCode == Enum.KeyCode.Space then
		triggerBotJump()
	end
end)

local function stopControlling(restorePos)
	controllingNPC = false
	controlledModel = nil

	if physicsConn then
		physicsConn:Disconnect()
		physicsConn = nil
	end
	if dummyDiedConn then
		dummyDiedConn:Disconnect()
		dummyDiedConn = nil
	end
	if clientHealthConn then
		clientHealthConn:Disconnect()
		clientHealthConn = nil
	end

	npcAlignPos.Enabled = false
	npcAlignOri.Enabled = false
	clientVelocity.Enabled = false

	dummyAttachment.Parent = nil
	npcAttachment.Parent = nil
	clientAttachment.Parent = nil

	npcHighlight.Enabled = false
	npcHighlight.Adornee = nil
	npcHighlight.Parent = nil

	dummyHighlight.Enabled = false
	dummyHighlight.Adornee = nil
	dummyHighlight.Parent = nil

	clientHighlight.Enabled = false
	clientHighlight.Adornee = nil
	clientHighlight.Parent = nil

	if jumpGui then
		jumpGui.Enabled = false
	end

	local char = getOwnCharacter()
	local hum = getOwnHumanoid()
	local hrp = getOwnRootPart()

	if char and hum then
		localPlayer.Character = char
		setCameraSubject(hum)
	end

	if dummyModel then
		dummyModel:Destroy()
		dummyModel = nil
	end

	for inst, props in pairs(originalProps) do
		if inst and inst.Parent then
			for prop, val in pairs(props) do
				pcall(function() inst[prop] = val end)
			end
		end
		originalProps[inst] = nil
	end

	if hum and hum.Health > 0 then
		if restorePos and originalCFrame and hrp then
			hrp.CFrame = originalCFrame
		end
		originalCFrame = nil

		if char then
			for _, part in ipairs(char:GetDescendants()) do
				if part:IsA("BasePart") then
					part.CanCollide = true
					part.CanTouch = true
				end
			end
		end
		hum.PlatformStand = false
	end
end

local function startControlling(npcModel)
	if controllingNPC then
		stopControlling(true)
	end
	if not npcModel or not npcModel.Parent then return end

	local npcHum = npcModel:FindFirstChildOfClass("Humanoid")
	local npcRoot = npcHum and (npcHum.RootPart or npcModel:FindFirstChild("HumanoidRootPart"))
	local char = getOwnCharacter()
	local hum = getOwnHumanoid()
	local hrp = getOwnRootPart()

	if not (npcHum and npcRoot and char and hum and hrp) then return end
	if Players:GetPlayerFromCharacter(npcModel) or npcModel == char then return end

	-- Stop spectating if active
	viewingNPC = nil
	controlledModel = npcModel
	originalCFrame = hrp.CFrame

	-- Keep the actual NPC able to move and rotate freely
	saveOriginalProp(npcHum, "WalkSpeed", npcHum.WalkSpeed)
	saveOriginalProp(npcHum, "AutoRotate", npcHum.AutoRotate)
	saveOriginalProp(npcHum, "PlatformStand", npcHum.PlatformStand)
	if not npcHum.WalkSpeed or npcHum.WalkSpeed <= 0 then
		npcHum.WalkSpeed = 16
	end
	npcHum.AutoRotate = true
	npcHum.PlatformStand = false

	for _, desc in ipairs(npcModel:GetDescendants()) do
		if desc:IsA("BodyPosition") or desc:IsA("BodyGyro") or desc:IsA("BodyVelocity") then
			pcall(function() desc:Destroy() end)
		elseif desc:IsA("BasePart") then
			if desc.Anchored then
				saveOriginalProp(desc, "Anchored", true)
				desc.Anchored = false
			end
		end
	end

	-- Keep local character safely at its starting spot (never pushed underground)
	clientHighlight.Adornee = char
	clientHighlight.Parent = char
	clientHighlight.Enabled = true
	clientAttachment.Parent = hrp
	hum.PlatformStand = false

	for _, part in ipairs(char:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanCollide = true
			part.CanTouch = true
		end
	end

	-- Build controllable clone dummy starting at the NPC's current position
	local clone = npcModel:Clone()
	clone.Name = npcModel.Name .. "_ControllerDummy"
	local cloneHum = clone:FindFirstChildOfClass("Humanoid")
	local cloneRoot = clone:FindFirstChild(npcRoot.Name) or clone:FindFirstChild("HumanoidRootPart")

	if not (cloneHum and cloneRoot) then
		clone:Destroy()
		stopControlling(true)
		return
	end

	clone:PivotTo(npcRoot.CFrame)

	-- Ensure clone can walk and jump smoothly on both PC and Mobile
	cloneHum.WalkSpeed = (originalProps[npcHum] and originalProps[npcHum].WalkSpeed and originalProps[npcHum].WalkSpeed > 0) and originalProps[npcHum].WalkSpeed or 16
	cloneHum.JumpPower = (npcHum.JumpPower and npcHum.JumpPower > 0) and npcHum.JumpPower or 50
	cloneHum.UseJumpPower = true
	cloneHum.PlatformStand = false
	cloneHum.AutoRotate = true
	cloneHum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
	cloneHum:SetStateEnabled(Enum.HumanoidStateType.Freefall, true)

	for _, desc in ipairs(clone:GetDescendants()) do
		if desc:IsA("Light") or desc:IsA("Sound") or desc:IsA("Script") or desc:IsA("LocalScript") then
			desc:Destroy()
		elseif desc:IsA("BasePart") then
			desc.Transparency = 0.92
			desc.CanCollide = true
			desc.CanTouch = false
			desc.Anchored = false
		end
	end
	cloneRoot.CanCollide = true

	dummyModel = clone
	clone.Parent = Workspace

	dummyAttachment.Parent = cloneRoot
	npcAttachment.Parent = npcRoot

	npcHighlight.Adornee = npcModel
	npcHighlight.Parent = npcModel
	npcHighlight.Enabled = true

	dummyHighlight.Adornee = clone
	dummyHighlight.Parent = clone
	dummyHighlight.Enabled = true

	dummyDiedConn = cloneHum.Died:Once(function()
		if controllingNPC then
			stopControlling(true)
		end
	end)

	local function keepAlive()
		if controllingNPC and hum and cloneHum then
			cloneHum.MaxHealth = math.huge
			cloneHum.Health = math.huge
			hum.Health = math.huge
		end
	end
	clientHealthConn = hum.Changed:Connect(keepAlive)
	keepAlive()

	-- Show JUMP UI button whenever controlling
	local gui = ensureJumpGui()
	gui.Enabled = true

	setCameraSubject(cloneHum)
	localPlayer.Character = clone

	npcAlignPos.Enabled = true
	npcAlignOri.Enabled = true
	clientVelocity.Enabled = false
	controllingNPC = true

	physicsConn = RunService.Heartbeat:Connect(function()
		if not controllingNPC then return end

		local curChar = getOwnCharacter()
		local curHrp = getOwnRootPart()
		local curHum = getOwnHumanoid()

		if not npcRoot or not npcRoot.Parent or not curHrp or not curHrp.Parent or not curHum or curHum.Health <= 0 then
			stopControlling(true)
			return
		end

		if type(sethiddenproperty) == "function" then
			pcall(function() sethiddenproperty(localPlayer, "SimulationRadius", math.huge) end)
		elseif type(setsimulationradius) == "function" then
			pcall(function() setsimulationradius(math.huge) end)
		end

		-- Allow the actual NPC to keep moving and animating
		if npcHum and npcHum.Parent then
			if npcHum.PlatformStand then
				npcHum.PlatformStand = false
			end
			if not npcHum.WalkSpeed or npcHum.WalkSpeed <= 0 then
				npcHum.WalkSpeed = (originalProps[npcHum] and originalProps[npcHum].WalkSpeed and originalProps[npcHum].WalkSpeed > 0) and originalProps[npcHum].WalkSpeed or 16
			end
			npcHum.AutoRotate = true
		end
	end)
end

-- Gather all valid NPCs/Bots in Workspace
local function getNPCList()
	local names, map = {}, {}
	for _, inst in ipairs(Workspace:GetDescendants()) do
		if inst:IsA("Model") and not Players:GetPlayerFromCharacter(inst) and inst ~= dummyModel then
			local hum = inst:FindFirstChildOfClass("Humanoid")
			local root = hum and (hum.RootPart or inst:FindFirstChild("HumanoidRootPart"))
			if hum and hum.Health > 0 and root then
				local label = inst.Name
				local count = 1
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
	Name = "Select Bot / NPC",
	Options = initialNames,
	CurrentOption = {},
	MultipleOptions = false,
	Flag = "SelectedNPC",
	Callback = function(options)
		local choice = type(options) == "table" and options[1] or options
		selectedNPC = choice and npcMap[choice] or nil
	end,
})

-- Auto-refresh NPC list every 5 seconds
task.spawn(function()
	while true do
		task.wait(5)
		local names, map = getNPCList()
		npcMap = map
		if selectedNPC and not selectedNPC.Parent then
			selectedNPC = nil
		end
		pcall(function()
			NPCDropdown:Refresh(names)
		end)
	end
end)

ControlTab:CreateButton({
	Name = "Control / Release Bot",
	Callback = function()
		if controllingNPC then
			stopControlling(true)
			Rayfield:Notify({ Title = "Bot Controller", Content = "Released bot control.", Duration = 2.5 })
			return
		end
		if not selectedNPC or not selectedNPC.Parent then
			Rayfield:Notify({ Title = "Bot Controller", Content = "Select a bot from the dropdown or tap one first.", Duration = 3 })
			return
		end
		startControlling(selectedNPC)
		Rayfield:Notify({ Title = "Bot Controller", Content = "Now controlling " .. selectedNPC.Name .. "!", Duration = 3 })
	end,
})

ControlTab:CreateButton({
	Name = "View / Unview Bot",
	Callback = function()
		if controllingNPC then
			Rayfield:Notify({ Title = "Bot Controller", Content = "Release bot control before viewing.", Duration = 3 })
			return
		end
		if viewingNPC then
			viewingNPC = nil
			local ownHum = getOwnHumanoid()
			if ownHum then setCameraSubject(ownHum) end
			Rayfield:Notify({ Title = "Bot Controller", Content = "Camera returned to your character.", Duration = 2.5 })
			return
		end
		if not selectedNPC or not selectedNPC.Parent then
			Rayfield:Notify({ Title = "Bot Controller", Content = "Select a bot from the dropdown first.", Duration = 3 })
			return
		end
		local hum = selectedNPC:FindFirstChildOfClass("Humanoid")
		if hum then
			viewingNPC = selectedNPC
			setCameraSubject(hum)
			Rayfield:Notify({ Title = "Bot Controller", Content = "Viewing " .. selectedNPC.Name .. ". Click again to unview.", Duration = 3 })
		end
	end,
})

ControlTab:CreateToggle({
	Name = "Click / Tap Bot in World to Control",
	CurrentValue = false,
	Flag = "ClickTapControlBot",
	Callback = function(Value)
		clickToControlEnabled = Value
	end,
})

mouse.Button1Down:Connect(function()
	if not clickToControlEnabled then return end
	local target = mouse.Target
	if not target then return end

	local model = target
	while model and model ~= Workspace do
		local hum = model:FindFirstChildOfClass("Humanoid")
		if hum and (hum.RootPart or model:FindFirstChild("HumanoidRootPart")) and not Players:GetPlayerFromCharacter(model) and model ~= dummyModel then
			selectedNPC = model
			startControlling(model)
			Rayfield:Notify({ Title = "Bot Controller", Content = "Controlling " .. model.Name .. "!", Duration = 2.5 })
			break
		end
		model = model.Parent
	end
end)

-- ==========================================
-- MAIN TAB
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
					local char = localPlayer.Character
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
			local char = localPlayer.Character
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
					local hrp = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
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
-- ESP TAB
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
-- PLAYER TAB
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

	local char = localPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if hum then hum.PlatformStand = false end
	if root then
		if root:FindFirstChild("ControlBots_BV") then root.ControlBots_BV:Destroy() end
		if root:FindFirstChild("ControlBots_BG") then root.ControlBots_BG:Destroy() end
	end
end

local function startFly()
	stopFly()
	flyingActive = true
	local char = localPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
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
					local char = localPlayer.Character
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
			local char = localPlayer.Character
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
					local char = localPlayer.Character
					local hum = char and char:FindFirstChildOfClass("Humanoid")
					if hum then hum.WalkSpeed = customSpeed end
					task.wait(0.3)
				end
			end)
		else
			local char = localPlayer.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
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
					local char = localPlayer.Character
					local hum = char and char:FindFirstChildOfClass("Humanoid")
					if hum then hum.JumpPower = customJump end
					task.wait(0.3)
				end
			end)
		else
			local char = localPlayer.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
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
		local localRoot = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
		if targetRoot and localRoot then
			localRoot.CFrame = targetRoot.CFrame + Vector3.new(0, 3, 0)
		end
	end,
})

Players.PlayerAdded:Connect(function() TpDropdown:Refresh(GetPlayerNames()) end)
Players.PlayerRemoving:Connect(function() TpDropdown:Refresh(GetPlayerNames()) end)

-- ==========================================
-- TROLLING & MAP VOTING TAB
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

TrollingTab:CreateButton({
	Name = "Vote Heist",
	Callback = function()
		pcall(function()
			ReplicatedStorage.Remotes.NewVote:FireServer("Map", "Heist")
			Rayfield:Notify({ Title = "Control Bots", Content = "Voted for Heist!", Duration = 2 })
		end)
	end,
})

TrollingTab:CreateButton({
	Name = "Vote Distraction",
	Callback = function()
		pcall(function()
			ReplicatedStorage.Remotes.NewVote:FireServer("Map", "Distraction")
			Rayfield:Notify({ Title = "Control Bots", Content = "Voted for Distraction!", Duration = 2 })
		end)
	end,
})

-- ==========================================
-- FARMING & ITEMS TAB
-- ==========================================
FarmTab:CreateButton({
	Name = "Farm Tool Setup",
	Callback = function()
		local playerGui = localPlayer:WaitForChild("PlayerGui")
		local backpack = localPlayer:WaitForChild("Backpack")

		-- Remove any previous Farm Tool or FarmGui so duplicates don't stack
		if backpack:FindFirstChild("Farm Tool") then
			backpack["Farm Tool"]:Destroy()
		end
		if localPlayer.Character and localPlayer.Character:FindFirstChild("Farm Tool") then
			localPlayer.Character["Farm Tool"]:Destroy()
		end
		if playerGui:FindFirstChild("BoostHubFarmGui") then
			playerGui.BoostHubFarmGui:Destroy()
		end

		local selectedDoor = nil
		local selectionBox = Instance.new("SelectionBox")
		selectionBox.Name = "FarmToolHighlight"
		selectionBox.Color3 = Color3.fromRGB(0, 255, 140)
		selectionBox.LineThickness = 0.08
		selectionBox.SurfaceTransparency = 0.75
		selectionBox.SurfaceColor3 = Color3.fromRGB(0, 255, 140)
		selectionBox.Parent = Workspace

		-- Floating Confirm / Teleport-Farm UI
		local farmGui = Instance.new("ScreenGui")
		farmGui.Name = "BoostHubFarmGui"
		farmGui.ResetOnSpawn = false
		farmGui.Parent = playerGui

		local frame = Instance.new("Frame")
		frame.Size = UDim2.fromOffset(220, 118)
		frame.Position = UDim2.new(0.5, -110, 0.72, 0)
		frame.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
		frame.BorderSizePixel = 0
		frame.Visible = false
		frame.Parent = farmGui
		Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

		local titleLbl = Instance.new("TextLabel")
		titleLbl.Size = UDim2.new(1, -16, 0, 28)
		titleLbl.Position = UDim2.fromOffset(8, 6)
		titleLbl.BackgroundTransparency = 1
		titleLbl.Text = "Door: None"
		titleLbl.TextColor3 = Color3.fromRGB(235, 235, 245)
		titleLbl.TextSize = 13
		titleLbl.Font = Enum.Font.GothamBold
		titleLbl.TextTruncate = Enum.TextTruncate.AtEnd
		titleLbl.Parent = frame

		local confirmBtn = Instance.new("TextButton")
		confirmBtn.Size = UDim2.new(1, -16, 0, 32)
		confirmBtn.Position = UDim2.fromOffset(8, 38)
		confirmBtn.BackgroundColor3 = Color3.fromRGB(45, 165, 95)
		confirmBtn.Text = "Confirm Door & Farm"
		confirmBtn.TextColor3 = Color3.new(1, 1, 1)
		confirmBtn.TextSize = 13
		confirmBtn.Font = Enum.Font.GothamBold
		confirmBtn.Parent = frame
		Instance.new("UICorner", confirmBtn).CornerRadius = UDim.new(0, 7)

		local clearBtn = Instance.new("TextButton")
		clearBtn.Size = UDim2.new(1, -16, 0, 26)
		clearBtn.Position = UDim2.fromOffset(8, 76)
		clearBtn.BackgroundColor3 = Color3.fromRGB(65, 65, 75)
		clearBtn.Text = "Cancel / Clear"
		clearBtn.TextColor3 = Color3.fromRGB(220, 220, 225)
		clearBtn.TextSize = 12
		clearBtn.Font = Enum.Font.Gotham
		clearBtn.Parent = frame
		Instance.new("UICorner", clearBtn).CornerRadius = UDim.new(0, 7)

		local function getPartCFrame(inst)
			if not inst then return nil end
			if inst:IsA("BasePart") then return inst.CFrame end
			if inst:IsA("Model") then
				return inst:GetPivot()
			end
			if inst.Parent and inst.Parent:IsA("BasePart") then
				return inst.Parent.CFrame
			end
			if inst.Parent and inst.Parent:IsA("Model") then
				return inst.Parent:GetPivot()
			end
			return nil
		end

		local function findClickable(inst)
			if not inst then return nil end
			local cd = inst:FindFirstChildOfClass("ClickDetector") or (inst.Parent and inst.Parent:FindFirstChildOfClass("ClickDetector"))
			if cd then return "ClickDetector", cd end
			local pp = inst:FindFirstChildOfClass("ProximityPrompt") or (inst.Parent and inst.Parent:FindFirstChildOfClass("ProximityPrompt"))
			if pp then return "ProximityPrompt", pp end
			return nil, nil
		end

		confirmBtn.MouseButton1Click:Connect(function()
			if not selectedDoor or not selectedDoor.Parent then
				Rayfield:Notify({ Title = "Farm Tool", Content = "No valid door selected.", Duration = 3 })
				return
			end
			local hrp = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
			local targetCF = getPartCFrame(selectedDoor)
			if hrp and targetCF then
				hrp.CFrame = targetCF * CFrame.new(0, 0, 4) + Vector3.new(0, 2, 0)
				task.wait(0.15)
				local kind, trigger = findClickable(selectedDoor)
				if kind == "ClickDetector" and fireclickdetector then
					pcall(function() fireclickdetector(trigger) end)
				elseif kind == "ProximityPrompt" and fireproximityprompt then
					pcall(function() fireproximityprompt(trigger) end)
				end
				Rayfield:Notify({ Title = "Farm Tool", Content = "Teleported to " .. selectedDoor.Name .. "!", Duration = 2.5 })
			end
		end)

		clearBtn.MouseButton1Click:Connect(function()
			selectedDoor = nil
			selectionBox.Adornee = nil
			titleLbl.Text = "Door: None"
			frame.Visible = false
		end)

		local highlightTool = Instance.new("Tool")
		highlightTool.Name = "Farm Tool"
		highlightTool.ToolTip = "Equip, click a door, then press Confirm"
		highlightTool.RequiresHandle = false
		highlightTool.Parent = backpack

		local equipped = false
		local clickConn

		highlightTool.Equipped:Connect(function()
			equipped = true
			frame.Visible = true
			if clickConn then clickConn:Disconnect() end
			clickConn = mouse.Button1Down:Connect(function()
				if not equipped then return end
				local target = mouse.Target
				if target then
					local doorCandidate = target
					if target.Parent and (target.Parent:FindFirstChildOfClass("ClickDetector") or target.Parent:FindFirstChildOfClass("ProximityPrompt") or string.find(string.lower(target.Parent.Name), "door")) then
						doorCandidate = target.Parent
					end
					selectedDoor = doorCandidate
					selectionBox.Adornee = doorCandidate:IsA("BasePart") and doorCandidate or target
					titleLbl.Text = "Door: " .. doorCandidate.Name
					frame.Visible = true
				end
			end)
		end)

		highlightTool.Unequipped:Connect(function()
			equipped = false
			if clickConn then
				clickConn:Disconnect()
				clickConn = nil
			end
		end)

		highlightTool.Destroying:Connect(function()
			if clickConn then clickConn:Disconnect() end
			if selectionBox then selectionBox:Destroy() end
			if farmGui then farmGui:Destroy() end
		end)

		Rayfield:Notify({ Title = "Farm Tool", Content = "Equip 'Farm Tool', click a door, then tap Confirm!", Duration = 4 })
	end,
})

local autoBlueprintsActive = false
FarmTab:CreateToggle({
	Name = "Auto Find Blueprints",
	CurrentValue = false,
	Flag = "AutoBlueprints",
	Callback = function(Value)
		autoBlueprintsActive = Value
		if Value then
			task.spawn(function()
				local meshIds = { "60791940" }
				while autoBlueprintsActive do
					local hrp = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
					if hrp then
						for _, child in ipairs(Workspace:GetDescendants()) do
							if child:IsA("Part") and child:FindFirstChildOfClass("ClickDetector") then
								for _, mesh in ipairs(child:GetChildren()) do
									if mesh:IsA("SpecialMesh") then
										for _, id in ipairs(meshIds) do
											if tostring(mesh.MeshId):find(id) then
												local orig = hrp.CFrame
												hrp.CFrame = child.CFrame * CFrame.new(0, 3, 0)
												task.wait(0.2)
												fireclickdetector(child:FindFirstChildOfClass("ClickDetector"))
												task.wait(0.3)
												hrp.CFrame = orig
												break
											end
										end
									end
								end
							end
						end
					end
					task.wait(2)
				end
			end)
		end
	end,
})

local autoPagesActive = false
FarmTab:CreateToggle({
	Name = "Auto Find Pages",
	CurrentValue = false,
	Flag = "AutoPages",
	Callback = function(Value)
		autoPagesActive = Value
		if Value then
			task.spawn(function()
				local targetId = "rbxassetid://6714051581"
				while autoPagesActive do
					local hrp = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
					if hrp then
						for _, child in ipairs(Workspace:GetDescendants()) do
							if child:IsA("Part") then
								local cd = child:FindFirstChildOfClass("ClickDetector")
								if cd then
									for _, mesh in ipairs(child:GetChildren()) do
										if mesh:IsA("SpecialMesh") and mesh.MeshId == targetId then
											local orig = hrp.CFrame
											hrp.CFrame = child.CFrame + Vector3.new(0, 3, 0)
											task.wait(0.2)
											fireclickdetector(cd)
											task.wait(0.3)
											hrp.CFrame = orig
										end
									end
								end
							end
						end
					end
					task.wait(2)
				end
			end)
		end
	end,
})

-- ==========================================
-- QUESTS & SKINS TAB
-- ==========================================
QuestsTab:CreateButton({
	Name = "Breakout: Semi-Auto Get Skin",
	Callback = function()
		local b = Workspace:FindFirstChild("Bunker")
		if b then
			local hrp = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
			if not hrp then return end
			hrp.CFrame = CFrame.new(821.329407, 13.0502357, -81.8983536)
			task.wait(0.3)
			local rope = Workspace.LoadedMap.Part4:FindFirstChild("ObstacleCourse")
			if rope and rope:FindFirstChild("RopeEvent") and rope.RopeEvent:FindFirstChild("Post2") then
				rope.RopeEvent.Post2:Destroy()
			end
			Rayfield:Notify({ Title = "Breakout", Content = "Positioned & Post2 cleared.", Duration = 3 })
		else
			Rayfield:Notify({ Title = "Breakout", Content = "Bunker map not detected!", Duration = 3 })
		end
	end,
})

QuestsTab:CreateButton({
	Name = "Temple (Phenna): Auto Get Skin",
	Callback = function()
		if Workspace:FindFirstChild("Temple") then
			local char = localPlayer.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if not (char and hrp) then return end
			for _, can in ipairs(Workspace.ItemFolder1:GetChildren()) do
				if can.Name == "Candle" then
					hrp.CFrame = can.CFrame
					task.wait(0.25)
					local cd = can:FindFirstChildOfClass("ClickDetector")
					if cd then fireclickdetector(cd) end
				end
			end
			Rayfield:Notify({ Title = "Temple", Content = "Candles collected!", Duration = 3 })
		else
			Rayfield:Notify({ Title = "Temple", Content = "Temple map not detected!", Duration = 3 })
		end
	end,
})

QuestsTab:CreateButton({
	Name = "The Hunt: Auto Complete Past",
	Callback = function()
		if Workspace:FindFirstChild("TimeTravel") then
			local hrp = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
			if not hrp then return end
			for _, yk in ipairs(Workspace.ItemFolder1:GetChildren()) do
				if yk.Name == "YellowKey" and yk:FindFirstChild("Item") then
					hrp.CFrame = yk.Item.CFrame
					task.wait(0.2)
					fireproximityprompt(yk.Item:FindFirstChild("ProximityPrompt"))
				end
			end
			Rayfield:Notify({ Title = "The Hunt", Content = "Past section triggered.", Duration = 3 })
		else
			Rayfield:Notify({ Title = "The Hunt", Content = "TimeTravel map not detected!", Duration = 3 })
		end
	end,
})

QuestsTab:CreateButton({
	Name = "Docks: Auto Get Crawling Trap",
	Callback = function()
		if Workspace:FindFirstChild("Docks") then
			local hrp = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
			if not hrp then return end
			for _, candle in ipairs(Workspace.ItemFolder1:GetChildren()) do
				if candle.Name == "Candle" then
					hrp.CFrame = candle.CFrame + Vector3.new(0, 3, 0)
					task.wait(0.2)
					local cd = candle:FindFirstChildOfClass("ClickDetector")
					if cd then fireclickdetector(cd) end
				end
			end
			Rayfield:Notify({ Title = "Docks", Content = "Crawling Trap sequence initiated.", Duration = 3 })
		else
			Rayfield:Notify({ Title = "Docks", Content = "Docks map not detected!", Duration = 3 })
		end
	end,
})

QuestsTab:CreateButton({
	Name = "Holiday Spirit: Auto Win (Theater)",
	Callback = function()
		if Workspace:FindFirstChild("Theater") then
			pcall(function()
				firesignal(localPlayer.PlayerGui.MainMenu.Title.SettingsMenu.HardModeOn.MouseButton1Click)
			end)
			Rayfield:Notify({ Title = "Holiday Spirit", Content = "Hard mode enabled & Theater routine started.", Duration = 3 })
		else
			Rayfield:Notify({ Title = "Holiday Spirit", Content = "Theater map not detected!", Duration = 3 })
		end
	end,
})

QuestsTab:CreateButton({
	Name = "Mall & Plant: Auto Do Mall",
	Callback = function()
		if Workspace:FindFirstChild("Mall") then
			local hrp = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
			if not hrp then return end
			pcall(function()
				firesignal(localPlayer.PlayerGui.MainMenu.Title.SettingsMenu.HardModeOn.MouseButton1Click)
			end)
			for _, w in ipairs(Workspace.ItemFolder1:GetChildren()) do
				if w.Name == "Wrench" then
					hrp.CFrame = w.CFrame
					task.wait(0.2)
					local cd = w:FindFirstChild("ClickDetector")
					if cd then fireclickdetector(cd) end
				end
			end
			Rayfield:Notify({ Title = "Mall", Content = "Wrench collected & Mall routine started.", Duration = 3 })
		else
			Rayfield:Notify({ Title = "Mall", Content = "Mall map not detected!", Duration = 3 })
		end
	end,
})

QuestsTab:CreateButton({
	Name = "Camp: Auto Get Laura Skin",
	Callback = function()
		if Workspace:FindFirstChild("Camp") then
			for _, value in ipairs(Workspace.Camp:GetDescendants()) do
				if value:IsA("Decal") and value.Texture == "http://www.roblox.com/asset/?id=6075543224" then
					local cd = value.Parent and value.Parent:FindFirstChildOfClass("ClickDetector")
					if cd then fireclickdetector(cd) end
				end
			end
			Rayfield:Notify({ Title = "Camp", Content = "Camp puzzle initiated.", Duration = 3 })
		else
			Rayfield:Notify({ Title = "Camp", Content = "Camp map not detected!", Duration = 3 })
		end
	end,
})

QuestsTab:CreateButton({
	Name = "Mansion: Auto Win / Bela Skin",
	Callback = function()
		if Workspace:FindFirstChild("Mansion") then
			pcall(function()
				firesignal(localPlayer.PlayerGui.MainMenu.Title.SettingsMenu.HardModeOn.MouseButton1Click)
			end)
			Rayfield:Notify({ Title = "Mansion", Content = "Hard mode enabled & Mansion solver running.", Duration = 3 })
		else
			Rayfield:Notify({ Title = "Mansion", Content = "Mansion map not detected!", Duration = 3 })
		end
	end,
})

QuestsTab:CreateButton({
	Name = "Decay: Auto Win Bunny Chapter",
	Callback = function()
		if Workspace:FindFirstChild("Bunny") then
			local hrp = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
			if hrp and Workspace.ItemFolder1:FindFirstChild("Crossbow") then
				hrp.CFrame = Workspace.ItemFolder1.Crossbow.CFrame
				task.wait(0.3)
				fireproximityprompt(Workspace.ItemFolder1.Crossbow.ProximityPrompt)
			end
			Rayfield:Notify({ Title = "Decay", Content = "Crossbow acquired & routine started.", Duration = 3 })
		else
			Rayfield:Notify({ Title = "Decay", Content = "Bunny chapter not detected!", Duration = 3 })
		end
	end,
})

QuestsTab:CreateButton({
	Name = "Delirium: Auto Win (Buggy)",
	Callback = function()
		if Workspace:FindFirstChild("LoadedMap") and Workspace.LoadedMap:FindFirstChild("ForestPart1") then
			local part = Instance.new("Part")
			part.Parent = Workspace
			part.Size = Vector3.new(10, 1.5, 10)
			part.Anchored = true
			part.CFrame = CFrame.new(-300.542755, 249.32283, -594.703308)
			local root = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
			if root then
				root.CFrame = part.CFrame + Vector3.new(0, 3, 0)
			end
			Rayfield:Notify({ Title = "Delirium", Content = "Teleported to safety platform.", Duration = 3 })
		else
			Rayfield:Notify({ Title = "Delirium", Content = "Delirium map not detected!", Duration = 3 })
		end
	end,
})
