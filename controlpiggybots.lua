local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local localPlayer = Players.LocalPlayer

local Window = Rayfield:CreateWindow({
	Name = "Control Bots",
	LoadingTitle = "Control Bots",
	LoadingSubtitle = "NPC Controller",
	ConfigurationSaving = { Enabled = false },
	Discord = { Enabled = false },
	KeySystem = false,
})

local ControlTab = Window:CreateTab("Control")

-- */ State /* --
local selectedNPC = nil
local npcMap = {}
local viewingNPC = nil
local controlledNPC = nil
local controlledHum = nil
local controlConnection = nil
local savedNPCWalkSpeed = nil
local savedOwnWalkSpeed = nil
local savedOwnJumpPower = nil
local jumpGui = nil
local playerControls = nil

-- */ Helpers /* --
local function getOwnHumanoid()
	local character = localPlayer.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

-- Roblox's PlayerModule handles keyboard, gamepad, and touch thumbstick input
local function getPlayerControls()
	if playerControls then
		return playerControls
	end
	local ok, controls = pcall(function()
		local playerModule = localPlayer:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 5)
		return require(playerModule):GetControls()
	end)
	if ok then
		playerControls = controls
	end
	return playerControls
end

-- Returns a world-space direction based on the camera, so it works on every input device
local function getMoveDirection()
	local camera = Workspace.CurrentCamera
	local controls = getPlayerControls()
	if not camera or not controls then
		return Vector3.zero
	end

	local move = controls:GetMoveVector()
	local cf = camera.CFrame
	local forward = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
	local right = Vector3.new(cf.RightVector.X, 0, cf.RightVector.Z)
	if forward.Magnitude > 0 then forward = forward.Unit end
	if right.Magnitude > 0 then right = right.Unit end

	-- MoveVector: X is right/left, Z is backward/forward (negative Z is forward)
	local dir = right * move.X - forward * move.Z
	if dir.Magnitude > 1 then
		dir = dir.Unit
	end
	return dir
end

local function getNPCList()
	local names, map = {}, {}
	for _, inst in ipairs(Workspace:GetDescendants()) do
		if inst:IsA("Model") and not Players:GetPlayerFromCharacter(inst) then
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

-- */ Available NPCs (dropdown) /* --
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

-- */ View NPC /* --
local function stopViewing()
	viewingNPC = nil
	local ownHum = getOwnHumanoid()
	if ownHum then
		Workspace.CurrentCamera.CameraSubject = ownHum
	end
end

ControlTab:CreateButton({
	Name = "View NPC",
	Callback = function()
		if controlledNPC then
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
			stopViewing()
			Rayfield:Notify({ Title = "Control Bots", Content = "Camera returned to your character.", Duration = 3 })
		else
			viewingNPC = selectedNPC
			Workspace.CurrentCamera.CameraSubject = hum
			Rayfield:Notify({ Title = "Control Bots", Content = "Now viewing " .. selectedNPC.Name .. ".", Duration = 3 })
		end
	end,
})

-- */ Mobile Jump Button /* --
local function jumpNPC()
	if controlledHum and controlledHum.Parent and controlledHum.Health > 0 then
		controlledHum:ChangeState(Enum.HumanoidStateType.Jumping)
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

	button.Activated:Connect(jumpNPC)

	gui.Parent = localPlayer:WaitForChild("PlayerGui")
	jumpGui = gui
end

-- Keyboard Space still works on PC
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or not controlledNPC then return end
	if input.KeyCode == Enum.KeyCode.Space then
		jumpNPC()
	end
end)

-- */ Control NPC /* --
local function freezeNPCMovement(hum, root)
	-- Cancel any MoveTo the NPC's own AI started
	hum:MoveTo(root.Position)
	savedNPCWalkSpeed = hum.WalkSpeed
end

local function restoreNPCMovement(hum)
	if hum and hum.Parent and savedNPCWalkSpeed then
		hum.WalkSpeed = savedNPCWalkSpeed
	end
	savedNPCWalkSpeed = nil
end

local function stopControl()
	if controlConnection then
		controlConnection:Disconnect()
		controlConnection = nil
	end

	if controlledHum and controlledHum.Parent then
		controlledHum:Move(Vector3.zero, false)
		restoreNPCMovement(controlledHum)
	end

	local ownHum = getOwnHumanoid()
	if ownHum then
		if savedOwnWalkSpeed then ownHum.WalkSpeed = savedOwnWalkSpeed end
		if savedOwnJumpPower then ownHum.JumpPower = savedOwnJumpPower end
		Workspace.CurrentCamera.CameraSubject = ownHum
	end

	if jumpGui then
		jumpGui.Enabled = false
	end

	controlledNPC = nil
	controlledHum = nil
	savedOwnWalkSpeed = nil
	savedOwnJumpPower = nil
end

local function startControl(model)
	local hum = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not hum or not root then return end

	controlledNPC = model
	controlledHum = hum
	viewingNPC = nil

	-- Freeze the NPC's own movement and disable its current pathing
	freezeNPCMovement(hum, root)

	-- Stop your own character from moving while you control the NPC
	local ownHum = getOwnHumanoid()
	if ownHum then
		savedOwnWalkSpeed = ownHum.WalkSpeed
		savedOwnJumpPower = ownHum.JumpPower
		ownHum.WalkSpeed = 0
		ownHum.JumpPower = 0
	end

	createJumpGui()
	jumpGui.Enabled = UserInputService.TouchEnabled

	Workspace.CurrentCamera.CameraSubject = hum

	controlConnection = RunService.RenderStepped:Connect(function()
		if not controlledNPC or not controlledNPC.Parent or not controlledHum or controlledHum.Health <= 0 then
			stopControl()
			return
		end

		-- Re-apply the direction every frame so the NPC follows only your input
		controlledHum:Move(getMoveDirection(), false)
	end)
end

ControlTab:CreateButton({
	Name = "Control NPC",
	Callback = function()
		if controlledNPC then
			stopControl()
			Rayfield:Notify({ Title = "Control Bots", Content = "You released the NPC.", Duration = 3 })
			return
		end
		if not selectedNPC or not selectedNPC.Parent then
			Rayfield:Notify({ Title = "Control Bots", Content = "Select an NPC from the list first.", Duration = 3 })
			return
		end
		startControl(selectedNPC)
		local hint = UserInputService.TouchEnabled and "Use the thumbstick and JUMP button." or "Use WASD and Space."
		Rayfield:Notify({ Title = "Control Bots", Content = "Controlling " .. selectedNPC.Name .. ". " .. hint .. " Press Control NPC again to release.", Duration = 5 })
	end,
})
