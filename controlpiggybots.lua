local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
local controlRemote = ReplicatedStorage:WaitForChild("ControlBotsRemote")

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
local npcOriginalSpeed = nil
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

-- Camera-relative direction, works on keyboard, gamepad, and touch
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

-- */ Jump (mobile button and keyboard Space) /* --
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

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or not controlledNPC then return end
	if input.KeyCode == Enum.KeyCode.Space then
		jumpNPC()
	end
end)

-- */ Control NPC /* --
local function stopControl()
	if controlConnection then
		controlConnection:Disconnect()
		controlConnection = nil
	end

	if controlledHum and controlledHum.Parent then
		controlledHum:Move(Vector3.zero, false)
		if npcOriginalSpeed then
			controlledHum.WalkSpeed = npcOriginalSpeed
		end
	end

	-- The server moves the player back to their original spot and releases the NPC
	if controlledNPC then
		controlRemote:FireServer("stop", controlledNPC)
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
	npcOriginalSpeed = nil
	savedOwnWalkSpeed = nil
	savedOwnJumpPower = nil
end

local function startControl(model)
	local hum = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not hum or not root then return end

	controlledNPC = model
	controlledHum = hum
	npcOriginalSpeed = hum.WalkSpeed
	viewingNPC = nil

	-- The server takes ownership, moves you under the NPC, and anchors you
	controlRemote:FireServer("start", model)

	-- Cancel the NPC's current path right away
	hum:MoveTo(root.Position)

	-- Stop your own character from moving on the client too
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

	-- Every frame: keep the NPC's speed fixed and apply only your input
	controlConnection = RunService.Heartbeat:Connect(function()
		if not controlledNPC or not controlledNPC.Parent
			or not controlledHum or not controlledHum.Parent
			or controlledHum.Health <= 0 then
			stopControl()
			return
		end

		controlledHum.WalkSpeed = npcOriginalSpeed
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

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- How many studs below the NPC the player is placed (change to 7 or 8 if you prefer)
local UNDER_OFFSET = 7.5

local controlRemote = ReplicatedStorage:FindFirstChild("ControlBotsRemote")
if not controlRemote then
	controlRemote = Instance.new("RemoteEvent")
	controlRemote.Name = "ControlBotsRemote"
	controlRemote.Parent = ReplicatedStorage
end

-- model -> { player, playerRoot, wasAnchored, returnCFrame, connection }
local sessions = {}

local function releaseNPC(model)
	local session = sessions[model]
	if not session then return end
	sessions[model] = nil

	if session.connection then
		session.connection:Disconnect()
	end

	model:SetAttribute("ControlledBy", nil)

	local npcRoot = model:FindFirstChild("HumanoidRootPart")
	if npcRoot then
		pcall(function()
			npcRoot:SetNetworkOwner(nil)
		end)
	end

	-- Put the player back where they were before control started
	local playerRoot = session.playerRoot
	if playerRoot and playerRoot.Parent then
		playerRoot.AssemblyLinearVelocity = Vector3.zero
		playerRoot.AssemblyAngularVelocity = Vector3.zero
		playerRoot.CFrame = session.returnCFrame
		playerRoot.Anchored = session.wasAnchored
	end
end

-- Release any NPC this player is already controlling (one NPC per player)
local function releaseAllForPlayer(player)
	for model, session in pairs(sessions) do
		if session.player == player then
			releaseNPC(model)
		end
	end
end

local function startNPC(player, model)
	if sessions[model] then return end
	releaseAllForPlayer(player)

	local character = player.Character
	local playerRoot = character and character:FindFirstChild("HumanoidRootPart")
	local playerHum = character and character:FindFirstChildOfClass("Humanoid")
	local hum = model:FindFirstChildOfClass("Humanoid")
	local npcRoot = model:FindFirstChild("HumanoidRootPart")

	if not (playerRoot and playerHum and hum and npcRoot) then return end
	if playerHum.Health <= 0 or hum.Health <= 0 then return end

	local session = {
		player = player,
		playerRoot = playerRoot,
		wasAnchored = playerRoot.Anchored,
		returnCFrame = playerRoot.CFrame,
	}
	sessions[model] = session

	model:SetAttribute("ControlledBy", player.UserId)
	pcall(function()
		npcRoot:SetNetworkOwner(player)
	end)
	hum:MoveTo(npcRoot.Position)

	-- Teleport the player under the NPC and anchor them so they stay in place
	playerRoot.AssemblyLinearVelocity = Vector3.zero
	playerRoot.AssemblyAngularVelocity = Vector3.zero
	playerRoot.CFrame = CFrame.new(npcRoot.Position - Vector3.new(0, UNDER_OFFSET, 0))
	playerRoot.Anchored = true

	-- Every frame, keep the player under the NPC as it moves
	session.connection = RunService.Heartbeat:Connect(function()
		if not model.Parent or hum.Health <= 0
			or not player.Parent or not playerRoot.Parent
			or playerHum.Health <= 0 then
			releaseNPC(model)
			return
		end

		playerRoot.CFrame = CFrame.new(npcRoot.Position - Vector3.new(0, UNDER_OFFSET, 0))
	end)
end

controlRemote.OnServerEvent:Connect(function(player, action, model)
	if typeof(model) ~= "Instance" or not model:IsA("Model") then return end
	if Players:GetPlayerFromCharacter(model) then return end

	if action == "start" then
		startNPC(player, model)
	elseif action == "stop" then
		local session = sessions[model]
		if session and session.player == player then
			releaseNPC(model)
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	releaseAllForPlayer(player)
end)
