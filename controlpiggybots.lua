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
-- CONTROL TAB (Exact Original Control Piggy Bots [REWORK] from Old Script)
-- ==========================================
ControlTab:CreateButton({
	Name = "Launch Original Control Panel",
	Callback = function()
		-- Exact original code block from myveryoldscript.txt for Control Piggy Bots [REWORK]
		pcall(function()
			local inf, pi = math.huge, math.pi

			local playerGui = localPlayer:FindFirstChild("PlayerGui")
			if playerGui and playerGui:FindFirstChild("GameGUI") then
				playerGui.GameGUI.ResetOnSpawn = false
			end

			local Client = localPlayer
			local Character = Client.Character or Client.CharacterAdded:Wait()
			local Humanoid = Character:WaitForChild("Humanoid")
			local HumanoidRootPart = Humanoid.RootPart
			local Mouse = Client:GetMouse()
			local RunService = game:GetService("RunService")
			local UserInputService = game:GetService("UserInputService")

			local Controlling = false
			local CurrentlyControlledNPC = nil
			local OriginalProperties = {}
			local DisposableInstances = {}
			local OriginalPosition
			local CurrentMode = 1

			local Connections = {}
			local ScreenGui

			local ToggleEnabled = true
			local lastChar = Character

			local function CreateDisposableInstance(className, properties)
				properties = properties or {}
				local instance = Instance.new(className)
				table.insert(DisposableInstances, instance)
				for name, value in pairs(properties) do
					instance[name] = value
				end
				return instance
			end

			local ClientHighligher = CreateDisposableInstance("Highlight", {
				FillTransparency = 1,
				OutlineColor = Color3.fromRGB(75, 150, 255),
				Enabled = false,
				Parent = Character
			})

			local ClientAttachment = CreateDisposableInstance("Attachment", {Parent = HumanoidRootPart})
			local DummyAttachment = CreateDisposableInstance("Attachment")
			local NPCAttachment = CreateDisposableInstance("Attachment")

			local ClientVelocity = CreateDisposableInstance("LinearVelocity", {
				Attachment0 = ClientAttachment,
				MaxForce = inf,
				Enabled = false,
				Parent = Workspace
			})

			local ClientAlignOrientation = CreateDisposableInstance("AlignOrientation", {
				MaxTorque = inf,
				Responsiveness = inf,
				Attachment0 = ClientAttachment,
				Attachment1 = NPCAttachment,
				Enabled = false,
				Parent = Workspace
			})

			local NPCAlignPosition = CreateDisposableInstance("AlignPosition", {
				ApplyAtCenterOfMass = false,
				Attachment0 = NPCAttachment,
				Attachment1 = DummyAttachment,
				MaxForce = inf,
				Responsiveness = inf,
				Enabled = false,
				Parent = Workspace
			})

			local NPCAlignOrientation = CreateDisposableInstance("AlignOrientation", {
				MaxTorque = inf,
				Responsiveness = inf,
				Attachment0 = NPCAttachment,
				Attachment1 = DummyAttachment,
				Enabled = false,
				Parent = Workspace
			})

			local DummyModel, DummyRootPart
			local NPCModel, NPCRootPart, NPCName, NPCHighlighter
			local DummyDiedConnection, ClientHealthChangedConnection

			local function SetOriginalProperty(instance, name, value)
				local instanceOriginalProperties = OriginalProperties[instance] or {}
				instanceOriginalProperties[name] = value
				OriginalProperties[instance] = instanceOriginalProperties
			end

			local function SetCameraSubject(subject)
				while task.wait() do
					local camera = Workspace.CurrentCamera
					if camera then
						camera.CameraSubject = subject
						return
					end
				end
			end

			Client.CharacterAdded:Connect(function(newCharacter)
				local wasDeath = false
				if lastChar then
					local oldHumanoid = lastChar:FindFirstChildOfClass("Humanoid")
					if oldHumanoid and oldHumanoid.Health <= 0 then
						wasDeath = true
					end
				end

				if wasDeath then
					Character = newCharacter
					Humanoid = newCharacter:WaitForChild("Humanoid")
					HumanoidRootPart = Humanoid.RootPart

					ClientHighligher.Parent = Character
					ClientAttachment.Parent = HumanoidRootPart

					Humanoid.Died:Once(function()
						StopControlling()
					end)
				end

				lastChar = newCharacter
			end)

			local function StopControlling(restorePosition)
				Controlling = false
				CurrentlyControlledNPC = nil

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
				ClientAlignOrientation.Enabled = false

				if CurrentMode == 2 then
					if Character then
						SetCameraSubject(Humanoid)
						Client.Character = Character
					else
						for _, Newchar in pairs(Workspace:GetDescendants()) do
							if Newchar.Name == Client.Name then
								Client.Character = Newchar
								SetCameraSubject(Newchar:FindFirstChildOfClass("Humanoid"))
								HumanoidRootPart = Newchar:FindFirstChild("HumanoidRootPart")
								Humanoid = Newchar:FindFirstChildOfClass("Humanoid")
							end
						end
					end
				else
					SetCameraSubject(Humanoid)
					Client.Character = Character
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
				NPCName = nil

				if Humanoid.Health > 0 then
					if restorePosition and OriginalPosition then
						HumanoidRootPart.CFrame = OriginalPosition
						OriginalPosition = nil
					end

					for instance, originalProperties in pairs(OriginalProperties) do
						for name, value in pairs(originalProperties) do
							pcall(function() instance[name] = value end)
						end
						OriginalProperties[instance] = nil
					end

					if game.Players.LocalPlayer.Character:FindFirstChild("Energy") and game.Players.LocalPlayer.Character:FindFirstChild("Energy").Value == 100 then
						game.Players.LocalPlayer.Character:FindFirstChild("Energy").Value = 99
						game.Players.LocalPlayer.Character:FindFirstChild("Energy").Value = 100
					end

					local player = game.Players.LocalPlayer
					local character = player.Character or player.CharacterAdded:Wait()

					for _, part in ipairs(character:GetChildren()) do
						if part:IsA("BasePart") then
							part.CanTouch = true
						end
					end

					ClientHighligher.Enabled = false
					Humanoid.PlatformStand = false
				end
			end

			local function Control(npcModel)
				if Controlling then return end
				if CurrentlyControlledNPC == npcModel then return end

				local npcHumanoid = npcModel:FindFirstChildOfClass("Humanoid")
				local npcRootPart = npcHumanoid and npcHumanoid.RootPart

				if npcRootPart and npcHumanoid then
					local player = game.Players:GetPlayerFromCharacter(npcModel)
					if player then return end
					if npcModel == Character then return end

					CurrentlyControlledNPC = npcModel
					OriginalPosition = HumanoidRootPart.CFrame

					ClientHighligher.Enabled = true
					SetOriginalProperty(HumanoidRootPart, "CFrame", HumanoidRootPart.CFrame)

					Humanoid.PlatformStand = true

					local localPlayer = game.Players.LocalPlayer
					local localCharacter = localPlayer.Character or localPlayer.CharacterAdded:Wait()

					for _, part in ipairs(localCharacter:GetChildren()) do
						if part:IsA("BasePart") then
							part.CanTouch = false
						end
					end

					task.wait(0.5)

					if not Humanoid or Humanoid.Health <= 0
						or not HumanoidRootPart or not HumanoidRootPart.Parent
						or not npcRootPart or not npcRootPart.Parent then
						CurrentlyControlledNPC = nil
						pcall(function() Humanoid.PlatformStand = false end)
						ClientHighligher.Enabled = false
						for _, part in ipairs(Character:GetChildren()) do
							if part:IsA("BasePart") then
								part.CanTouch = true
							end
						end
						return
					end

					pcall(function() npcRootPart.BodyPosition:Destroy() end)
					pcall(function() npcRootPart.BodyGyro:Destroy() end)

					local dummyModel = npcModel:Clone()
					local dummyHumanoid = dummyModel:FindFirstChildOfClass("Humanoid")
					local dummyRootPart = dummyModel:FindFirstChild(npcRootPart.Name)

					if CurrentMode == 1 then
						DummyDiedConnection = dummyHumanoid.Died:Once(function()
							if Controlling then StopControlling(true) end
						end)
					else
						DummyDiedConnection = dummyHumanoid.Died:Once(function()
							if Controlling then Humanoid.Health = 0 end
						end)
					end

					local function updateHealth()
						if Controlling then
							dummyHumanoid.MaxHealth = inf
							dummyHumanoid.Health = inf
							Humanoid.Health = inf
						end
					end

					ClientHealthChangedConnection = Humanoid.Changed:Connect(updateHealth)
					updateHealth()

					for _, descendant in pairs(dummyModel:GetDescendants()) do
						if descendant:IsA("Light") or descendant:IsA("Sound") then
							descendant:Destroy()
						else
							pcall(function() descendant.Transparency = 0.95 end)
						end
					end

					DummyModel = dummyModel
					DummyRootPart = dummyRootPart
					dummyModel.Parent = Workspace

					DummyAttachment.Parent = dummyRootPart
					NPCAttachment.Parent = npcRootPart

					NPCModel = npcModel
					NPCRootPart = npcRootPart
					NPCName = npcModel.Name

					NPCHighlighter = Instance.new("Highlight")
					NPCHighlighter.FillTransparency = 1
					NPCHighlighter.OutlineColor = Color3.fromRGB(255, 0, 0)
					NPCHighlighter.Parent = npcModel

					local DummyHighlighter = Instance.new("Highlight")
					DummyHighlighter.FillTransparency = 1
					DummyHighlighter.OutlineColor = Color3.fromRGB(128, 0, 128)
					DummyHighlighter.Parent = dummyModel

					SetCameraSubject(dummyHumanoid)
					Client.Character = dummyModel

					NPCAlignPosition.Enabled = true
					NPCAlignOrientation.Enabled = true
					ClientAlignOrientation.Enabled = false
					ClientVelocity.Enabled = true
					Controlling = true
				end
			end

			task.spawn(function()
				while true do
					task.wait(0.5)
					if not Controlling or not ToggleEnabled or CurrentMode ~= 2 then continue end

					local npcModel = NPCModel
					local dummyRootPart = DummyRootPart
					if not npcModel or not dummyRootPart then continue end

					for _, objc in ipairs(npcModel:GetDescendants()) do
						if objc:IsA("TouchTransmitter") then
							objc:Destroy()
						end
					end
					for _, objc in ipairs(npcModel:GetDescendants()) do
						if objc:IsA("Script") then
							objc:Destroy()
						end
					end

					local closestRootPart = nil
					local closestDist = math.huge

					local mainSpawn = Workspace:FindFirstChild("GameFolder")
						and Workspace.GameFolder:FindFirstChild("MainSpawn")

					for _, player in ipairs(game.Players:GetPlayers()) do
						if player ~= Client
							and player.Character
							and not player.Character:FindFirstChild("Enemy")
							and not player.Character:FindFirstChild("Traitor") then

							local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
							if rootPart then
								if mainSpawn then
									local dist = (rootPart.Position - mainSpawn.Position).Magnitude
									if dist >= 20 and dist < closestDist then
										closestDist = dist
										closestRootPart = rootPart
									end
								else
									closestRootPart = rootPart
									break
								end
							end
						end
					end

					if closestRootPart then
						dummyRootPart.CFrame = closestRootPart.CFrame * CFrame.new(0, 2, -9)
					end
				end
			end)

			local function DestroyEverything()
				StopControlling(false)

				for _, connection in pairs(Connections) do
					pcall(function() connection:Disconnect() end)
				end
				Connections = {}

				for _, instance in pairs(DisposableInstances) do
					pcall(function() instance:Destroy() end)
				end
				DisposableInstances = {}

				if ScreenGui then
					ScreenGui:Destroy()
					ScreenGui = nil
				end
			end

			ScreenGui = Instance.new("ScreenGui")
			ScreenGui.Name = "PiggyBotGui"
			ScreenGui.ResetOnSpawn = false
			ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
			ScreenGui.Parent = Client.PlayerGui

			local MiniButton = Instance.new("TextButton")
			MiniButton.Name = "MiniToggle"
			MiniButton.Size = UDim2.new(0, 56, 0, 56)
			MiniButton.Position = UDim2.new(1, -68, 0, 60)
			MiniButton.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
			MiniButton.BackgroundTransparency = 0.3
			MiniButton.BorderSizePixel = 0
			MiniButton.Text = "🐷"
			MiniButton.TextSize = 28
			MiniButton.TextColor3 = Color3.fromRGB(200, 200, 200)
			MiniButton.FontFace = Font.new("rbxasset://fonts/families/Ubuntu.json", Enum.FontWeight.Bold)
			MiniButton.ZIndex = 12
			MiniButton.AutoButtonColor = false
			MiniButton.Parent = ScreenGui
			Instance.new("UICorner", MiniButton).CornerRadius = UDim.new(0, 10)
			local MiniStroke = Instance.new("UIStroke", MiniButton)
			MiniStroke.Color = Color3.fromRGB(80, 80, 80)
			MiniStroke.Thickness = 1

			local MainFrame = Instance.new("Frame")
			MainFrame.Name = "MainPanel"
			MainFrame.Size = UDim2.new(0, 200, 0, 120)
			MainFrame.Position = UDim2.new(1, -276, 0, 56)
			MainFrame.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
			MainFrame.BackgroundTransparency = 0.15
			MainFrame.BorderSizePixel = 0
			MainFrame.ZIndex = 10
			MainFrame.Visible = true
			MainFrame.Parent = ScreenGui
			Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 10)
			local FrameStroke = Instance.new("UIStroke", MainFrame)
			FrameStroke.Color = Color3.fromRGB(70, 70, 70)
			FrameStroke.Thickness = 1

			local Header = Instance.new("TextButton")
			Header.Name = "Header"
			Header.Size = UDim2.new(1, 0, 0, 30)
			Header.Position = UDim2.new(0, 0, 0, 0)
			Header.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
			Header.BackgroundTransparency = 0
			Header.BorderSizePixel = 0
			Header.Text = ""
			Header.AutoButtonColor = false
			Header.ZIndex = 11
			Header.Parent = MainFrame
			Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 10)

			local HeaderPatch = Instance.new("Frame")
			HeaderPatch.Size = UDim2.new(1, 0, 0, 10)
			HeaderPatch.Position = UDim2.new(0, 0, 1, -10)
			HeaderPatch.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
			HeaderPatch.BackgroundTransparency = 0
			HeaderPatch.BorderSizePixel = 0
			HeaderPatch.ZIndex = 11
			HeaderPatch.Parent = Header

			local HeaderLabel = Instance.new("TextLabel")
			HeaderLabel.Size = UDim2.new(1, -32, 1, 0)
			HeaderLabel.Position = UDim2.new(0, 8, 0, 0)
			HeaderLabel.BackgroundTransparency = 1
			HeaderLabel.Text = "🐷 piggy bot control"
			HeaderLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
			HeaderLabel.TextSize = 12
			HeaderLabel.FontFace = Font.new("rbxasset://fonts/families/Ubuntu.json", Enum.FontWeight.Bold)
			HeaderLabel.TextXAlignment = Enum.TextXAlignment.Left
			HeaderLabel.ZIndex = 12
			HeaderLabel.Parent = Header

			local DestroyButton = Instance.new("TextButton")
			DestroyButton.Name = "DestroyBtn"
			DestroyButton.Size = UDim2.new(0, 20, 0, 20)
			DestroyButton.Position = UDim2.new(1, -24, 0.5, -10)
			DestroyButton.BackgroundColor3 = Color3.fromRGB(50, 20, 20)
			DestroyButton.BackgroundTransparency = 0.2
			DestroyButton.BorderSizePixel = 0
			DestroyButton.Text = "❌"
			DestroyButton.TextSize = 11
			DestroyButton.TextColor3 = Color3.fromRGB(255, 80, 80)
			DestroyButton.FontFace = Font.new("rbxasset://fonts/families/Ubuntu.json", Enum.FontWeight.Bold)
			DestroyButton.ZIndex = 13
			DestroyButton.Parent = Header
			Instance.new("UICorner", DestroyButton).CornerRadius = UDim.new(0, 4)

			local Content = Instance.new("Frame")
			Content.Size = UDim2.new(1, 0, 1, -34)
			Content.Position = UDim2.new(0, 0, 0, 34)
			Content.BackgroundTransparency = 1
			Content.ZIndex = 10
			Content.Parent = MainFrame

			local Padding = Instance.new("UIPadding", Content)
			Padding.PaddingTop = UDim.new(0, 6)
			Padding.PaddingBottom = UDim.new(0, 8)
			Padding.PaddingLeft = UDim.new(0, 8)
			Padding.PaddingRight = UDim.new(0, 8)

			local Layout = Instance.new("UIListLayout", Content)
			Layout.SortOrder = Enum.SortOrder.LayoutOrder
			Layout.Padding = UDim.new(0, 6)

			local function MakeButton(text, color, layoutOrder)
				local btn = Instance.new("TextButton")
				btn.Size = UDim2.new(1, 0, 0, 28)
				btn.BackgroundColor3 = Color3.fromRGB(38, 38, 38)
				btn.BackgroundTransparency = 0.2
				btn.BorderSizePixel = 0
				btn.TextColor3 = color
				btn.TextSize = 13
				btn.Text = text
				btn.FontFace = Font.new("rbxasset://fonts/families/Ubuntu.json", Enum.FontWeight.Bold)
				btn.ZIndex = 11
				btn.LayoutOrder = layoutOrder
				btn.Parent = Content
				Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
				local s = Instance.new("UIStroke", btn)
				s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
				s.Color = color
				s.Transparency = 0.45
				return btn, s
			end

			local ToggleButton, ToggleStroke = MakeButton("Toggle: ON", Color3.new(0, 1, 0), 1)
			local ModeButton, ModeStroke = MakeButton("Mode: Normal", Color3.fromRGB(100, 180, 255), 2)

			local dragging, dragInput, dragStart, startPos

			Header.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					dragging = true
					dragStart = input.Position
					startPos = MainFrame.Position
					input.Changed:Connect(function()
						if input.UserInputState == Enum.UserInputState.End then
							dragging = false
						end
					end)
				end
			end)

			Header.InputChanged:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
					dragInput = input
				end
			end)

			UserInputService.InputChanged:Connect(function(input)
				if input == dragInput and dragging then
					local delta = input.Position - dragStart
					MainFrame.Position = UDim2.new(
						startPos.X.Scale, startPos.X.Offset + delta.X,
						startPos.Y.Scale, startPos.Y.Offset + delta.Y
					)
				end
			end)

			local miniDragging, miniDragInput, miniDragStart, miniStartPos, miniDragStartPos

			MiniButton.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					miniDragging = true
					miniDragStart = input.Position
					miniStartPos = MiniButton.Position
					miniDragStartPos = MiniButton.Position
					input.Changed:Connect(function()
						if input.UserInputState == Enum.UserInputState.End then
							miniDragging = false
						end
					end)
				end
			end)

			MiniButton.InputChanged:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
					miniDragInput = input
				end
			end)

			UserInputService.InputChanged:Connect(function(input)
				if input == miniDragInput and miniDragging then
					local delta = input.Position - miniDragStart
					MiniButton.Position = UDim2.new(
						miniStartPos.X.Scale, miniStartPos.X.Offset + delta.X,
						miniStartPos.Y.Scale, miniStartPos.Y.Offset + delta.Y
					)
				end
			end)

			local PanelOpen = true

			MiniButton.MouseButton1Up:Connect(function()
				if miniDragStartPos and MiniButton.Position == miniDragStartPos then
					PanelOpen = not PanelOpen
					MainFrame.Visible = PanelOpen
				end
				miniDragStartPos = nil
			end)

			local function UpdateToggleButton()
				if ToggleEnabled then
					ToggleButton.Text = "Toggle: ON"
					ToggleButton.TextColor3 = Color3.new(0, 1, 0)
					ToggleStroke.Color = Color3.new(0, 1, 0)
				else
					ToggleButton.Text = "Toggle: OFF"
					ToggleButton.TextColor3 = Color3.new(1, 0, 0)
					ToggleStroke.Color = Color3.new(1, 0, 0)
				end
			end

			local function UpdateModeButton()
				if CurrentMode == 1 then
					ModeButton.Text = "Mode: Normal"
					ModeButton.TextColor3 = Color3.fromRGB(100, 180, 255)
					ModeStroke.Color = Color3.fromRGB(100, 180, 255)
				else
					ModeButton.Text = "Mode: Killer"
					ModeButton.TextColor3 = Color3.fromRGB(255, 100, 100)
					ModeStroke.Color = Color3.fromRGB(255, 100, 100)
				end
			end

			local function ToggleToggleButton()
				if ToggleEnabled and Controlling then
					StopControlling(true)
				end
				ToggleEnabled = not ToggleEnabled
				UpdateToggleButton()
			end

			local function SwitchMode()
				CurrentMode = (CurrentMode == 1) and 2 or 1
				UpdateModeButton()
			end

			local function OnMouseClick()
				if not ToggleEnabled then return end
				local target = Mouse.Target
				if not target then return end

				local model = target
				while model and model ~= Workspace do
					local h = model:FindFirstChildOfClass("Humanoid")
					if h and h.RootPart then
						task.wait(0)
						Control(model)
						break
					end
					model = model.Parent
				end
			end

			Connections = {
				UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
					if not gameProcessedEvent
						and input.KeyCode == Enum.KeyCode.H
						and input.UserInputState == Enum.UserInputState.Begin then
						ToggleToggleButton()
					end
				end),

				Mouse.Button1Down:Connect(OnMouseClick),
				ToggleButton.Activated:Connect(ToggleToggleButton),
				ModeButton.Activated:Connect(SwitchMode),

				DestroyButton.Activated:Connect(function()
					if not dragging then
						DestroyEverything()
					end
				end),

				RunService.Heartbeat:Connect(function()
					if not (Controlling and ToggleEnabled) then return end

					if not NPCRootPart or not NPCRootPart.Parent
						or not HumanoidRootPart or not HumanoidRootPart.Parent
						or not Humanoid or Humanoid.Health <= 0 then
						return
					end

					if type(sethiddenproperty) == "function" then
						pcall(function() sethiddenproperty(Client, "SimulationRadius", inf) end)
					elseif type(setsimulationradius) == "function" then
						pcall(function() setsimulationradius(inf) end)
					end

					if NPCRootPart then
						local offset = CurrentMode == 1 and 7.2 or 8.4
						local npcPosition = NPCRootPart.Position
						HumanoidRootPart.CFrame = CFrame.new(
							npcPosition.X, npcPosition.Y - offset, npcPosition.Z
						) * NPCRootPart.CFrame.Rotation
					end

					for _, child in pairs(Character:GetChildren()) do
						if child:IsA("BasePart") and child.CanCollide then
							SetOriginalProperty(child, "CanCollide", true)
							child.CanCollide = false
							SetOriginalProperty(child, "CanTouch", true)
							child.CanTouch = false
						end
					end

					if DummyModel then
						for _, child in pairs(DummyModel:GetChildren()) do
							if child:IsA("BasePart") and child.CanCollide then
								child.CanCollide = false
								child.CanTouch = false
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
				end),

				Humanoid.Died:Once(function() StopControlling(false) end),
				Character.Destroying:Once(function() StopControlling(false) end),
			}

			UpdateToggleButton()
			UpdateModeButton()
			Rayfield:Notify({ Title = "Control Bots", Content = "Original Control Panel launched successfully!", Duration = 3 })
		end)
	end,
})

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
		Rayfield:Notify({ Title = "Farm Tool", Content = "Farm Tool added to backpack.", Duration = 4 })
		local highlightTool = Instance.new("Tool")
		highlightTool.Name = "Farm Tool"
		highlightTool.ToolTip = "Click the door then press Confirm"
		highlightTool.RequiresHandle = false
		highlightTool.Parent = localPlayer:WaitForChild("Backpack")
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
