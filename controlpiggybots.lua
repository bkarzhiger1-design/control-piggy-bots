-- Control Bots - Rayfield UI Script (PC & Mobile Support)
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
   Name = "Control Bots",
   LoadingTitle = "Control Bots Hub",
   LoadingSubtitle = "Loading interface...",
   ConfigurationSaving = {
      Enabled = false,
   },
   KeySystem = false,
})

local Tab = Window:CreateTab("Control", 4483362458)

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- Load PlayerModule controls for cross-platform (PC + Mobile Thumbstick) support
local PlayerScripts = LocalPlayer:WaitForChild("PlayerScripts")
local PlayerModule = PlayerScripts:WaitForChild("PlayerModule", 5)
local Controls = PlayerModule and require(PlayerModule:WaitForChild("ControlModule"))

local selectedNPC = nil
local controlling = false
local viewing = false
local originalCFrame = nil
local controlConn = nil

local function getNPCs()
    local list = {}
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and obj:FindFirstChildOfClass("Humanoid") then
            local isPlayer = false
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr.Character == obj then
                    isPlayer = true
                    break
                end
            end
            if not isPlayer and obj:FindFirstChild("HumanoidRootPart") then
                table.insert(list, obj.Name)
            end
        end
    end
    if #list == 0 then
        table.insert(list, "No NPCs Found")
    end
    return list
end

local NPCDropdown = Tab:CreateDropdown({
   Name = "Choose NPC",
   Options = getNPCs(),
   CurrentOption = "Choose NPC",
   Flag = "NPCDropdown",
   Callback = function(Option)
      local name = type(Option) == "table" and Option[1] or Option
      for _, obj in ipairs(Workspace:GetDescendants()) do
          if obj:IsA("Model") and obj.Name == name and obj:FindFirstChildOfClass("Humanoid") then
              local isPlr = false
              for _, p in ipairs(Players:GetPlayers()) do
                  if p.Character == obj then isPlr = true break end
              end
              if not isPlr then
                  selectedNPC = obj
                  break
              end
          end
      end
   end,
})

Tab:CreateButton({
   Name = "Refresh NPC List",
   Callback = function()
      NPCDropdown:Refresh(getNPCs())
      Rayfield:Notify({Title = "Refreshed", Content = "NPC list updated!", Duration = 2})
   end,
})

local function teleportToVoid()
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        local hrp = char.HumanoidRootPart
        if not originalCFrame then
            originalCFrame = hrp.CFrame
        end
        hrp.CFrame = CFrame.new(0, -99999, 0)
        hrp.Anchored = true
    end
end

local function restorePlayer()
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        local hrp = char.HumanoidRootPart
        hrp.Anchored = false
        if originalCFrame then
            hrp.CFrame = originalCFrame
            originalCFrame = nil
        end
    end
end

Tab:CreateToggle({
   Name = "Control NPC",
   CurrentValue = false,
   Flag = "ControlToggle",
   Callback = function(Value)
      controlling = Value
      if controlling then
          if not selectedNPC or not selectedNPC.Parent then
              Rayfield:Notify({Title = "Error", Content = "Please select an NPC first!", Duration = 3})
              return
          end
          
          local hrp = selectedNPC:FindFirstChild("HumanoidRootPart")
          if hrp and hrp.Anchored then
              Rayfield:Notify({Title = "Notice", Content = "You cant move this NPC because he anchored", Duration = 4})
              controlling = false
              return
          end
          
          teleportToVoid()
          if selectedNPC:FindFirstChildOfClass("Humanoid") then
              Camera.CameraSubject = selectedNPC:FindFirstChildOfClass("Humanoid")
          end
          
          controlConn = RunService.RenderStepped:Connect(function()
              if selectedNPC and selectedNPC:FindFirstChildOfClass("Humanoid") and selectedNPC:FindFirstChild("HumanoidRootPart") then
                  local hum = selectedNPC:FindFirstChildOfClass("Humanoid")
                  local moveDir = Vector3.new(0, 0, 0)
                  
                  if Controls then
                      local moveVector = Controls:GetMoveVector()
                      local camCF = Camera.CFrame
                      local computedDir = (camCF.RightVector * moveVector.X) + (camCF.LookVector * moveVector.Z)
                      moveDir = Vector3.new(computedDir.X, 0, computedDir.Z)
                  end
                  
                  if moveDir.Magnitude > 0 then
                      hum:Move(moveDir.Unit, true)
                  else
                      hum:Move(Vector3.new(0,0,0), true)
                  end
              end
          end)
      else
          if controlConn then
              controlConn:Disconnect()
              controlConn = nil
          end
          if LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
              Camera.CameraSubject = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
          end
          restorePlayer()
      end
   end,
})

Tab:CreateToggle({
   Name = "View NPC",
   CurrentValue = false,
   Flag = "ViewToggle",
   Callback = function(Value)
      viewing = Value
      if viewing then
          if not selectedNPC or not selectedNPC.Parent then
              Rayfield:Notify({Title = "Error", Content = "Please select an NPC first!", Duration = 3})
              return
          end
          teleportToVoid()
          if selectedNPC:FindFirstChildOfClass("Humanoid") then
              Camera.CameraSubject = selectedNPC:FindFirstChildOfClass("Humanoid")
          end
      else
          if LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
              Camera.CameraSubject = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
          end
          restorePlayer()
      end
   end,
})

Rayfield:LoadConfiguration()
