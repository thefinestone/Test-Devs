--V.0 This was made in under 30 minutes for the Hidden Devs Application, I contributed to over 50M+ in Roblox visits and am trying to get into commissioning in the mean time. 
--V.1 My first application was declined so I spent more time on it, so it'd meet the requirements fully
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Random = Random.new()

local CONFIG = {
	-- Positioning
	TargetDistance = 5,
	TargetHeight = 3.5,
	SideOffset = 2,

	-- Movement
	LerpSpeed = 0.1,
	TiltSpeed = 0.1,
	MaxAngle = 20,

	-- Breathing Animation
	BreathDuration = 2,
	BreathHeight = 0.8,

	-- Text Settings
	TypewriterSpeed = 0.03,
	MessageDuration = 4,
	CooldownRange = NumberRange.new(5, 10),

	-- Orb visuals (extra polish)
	Orb = {
		BaseColor = Color3.fromRGB(255, 255, 255),
		TalkColor = Color3.fromRGB(255, 235, 180),
		SpeedColor = Color3.fromRGB(180, 220, 255),
		SpeedForMaxEffect = 20,
		ColorLerpSpeed = 0.15,
	},

	-- Safety / behavior
	MaxDistanceFromPlayer = 40,
	RecenterDistance = 20,
	RespawnYOffset = 5,
}

--I got these quotes from a confucious website on google
local QUOTES = {
	"Real knowledge is to know the extent of one's ignorance.",
	"It does not matter how slowly you go so long as you do not stop.",
	"The man who moves a mountain begins by carrying away small stones.",
	"When anger rises, think of the consequences.",
	"Study the past if you would define the future.",
	"To see what is right and not to do it is want of courage.",
	"Silence is a true friend who never betrays.",
	"Respect yourself and others will respect you.",
	"The gem cannot be polished without friction, nor man perfected without trials.",
	"Wheresoever you go, go with all your heart.",
}

local min, max, sin, cos, rad = math.min, math.max, math.sin, math.cos, math.rad
local v3, cf = Vector3.new, CFrame.new

--I Setup OOP here
local ConfuciousController = {}
ConfuciousController.__index = ConfuciousController

function ConfuciousController.new()
	local self = setmetatable({}, ConfuciousController)

	-- State
	self.Player = Players.LocalPlayer
	self.Character = nil
	self.Root = nil
	self.Humanoid = nil

	self.Model = nil
	self.ModelPrimaryPart = nil
	self.RenderParts = {}
	self.SubtitleLabel = nil

	-- Flags
	self.IsTalking = false
	self.NextTalkTime = tick() + 5
	self.CurrentMessageId = 0
	self.LastQuoteIndex = nil

	-- Movement State
	self.LastPosition = v3(0, 0, 0)
	self.CurrentTilt = v3(0, 0, 0)
	self.Time = 0

	-- Breathing
	self.BreathOffsetValue = Instance.new("Vector3Value")
	self.BreathOffsetValue.Value = v3(0, -CONFIG.BreathHeight / 2, 0)

	-- Visual State
	self.TargetOrbColor = CONFIG.Orb.BaseColor
	self.CurrentOrbColor = CONFIG.Orb.BaseColor
	self.ColorState = "Idle"

	-- Connections
	self.Connections = {}

	-- Lifetime
	self.IsDestroyed = false

	return self
end

function ConfuciousController:AddConnection(conn)
	if conn then
		table.insert(self.Connections, conn)
	end
	return conn
end

function ConfuciousController:DisconnectAll()
	for i = #self.Connections, 1, -1 do
		local conn = self.Connections[i]
		self.Connections[i] = nil
		if conn and conn.Disconnect then
			conn:Disconnect()
		end
	end
end

function ConfuciousController:BindToCharacter(character)
	self.Character = character
	self.Root = nil
	self.Humanoid = nil

	if not character or not character.Parent then
		return
	end

	self.Root = character:WaitForChild("HumanoidRootPart", 5)
	self.Humanoid = character:FindFirstChildOfClass("Humanoid")

	if self.Humanoid then
		self:AddConnection(self.Humanoid.Died:Connect(function()
			self:OnCharacterDied()
		end))
	end

	if self.Model then
		local startPos = (self.Root and self.Root.Position or v3()) + v3(0, CONFIG.RespawnYOffset, 0)
		self.Model:PivotTo(cf(startPos))
		self.LastPosition = startPos
	end
end

function ConfuciousController:OnCharacterAdded(character)
	self:BindToCharacter(character)
	self:SpawnModel()
end

function ConfuciousController:OnCharacterDied()
	self:CancelCurrentSpeech()

	if self.SubtitleLabel then
		self.SubtitleLabel.Text = ""
	end

	if self.Model and self.ModelPrimaryPart then
		local info = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local goals = { Transparency = 1 }
		for _, part in ipairs(self.RenderParts) do
			TweenService:Create(part, info, goals):Play()
		end
	end

	self.NextTalkTime = math.huge
end

function ConfuciousController:Init()
	self.Character = self.Player.Character or self.Player.CharacterAdded:Wait()
	self:BindToCharacter(self.Character)

	--Create the Interface
	self:SetupInterface()

	--Spawn the Model
	self:SpawnModel()

	--Start the Loop
	self:AddConnection(RunService.RenderStepped:Connect(function(dt)
		self:Update(dt)
	end))

	-- Start the Breathing
	self:StartBreathingTween()

	-- Listen for respawns
	self:AddConnection(self.Player.CharacterAdded:Connect(function(char)
		self:OnCharacterAdded(char)
	end))
end

--This setsup the UI, not really necessary but it is efficient
function ConfuciousController:SetupInterface()
	local playerGui = self.Player:WaitForChild("PlayerGui", 5)
	if not playerGui then
		return
	end

	local ConfuciusUI = playerGui:FindFirstChild("ConfuciusUI")
	if not ConfuciusUI then
		self.SubtitleLabel = nil
		return
	end

	local SubTitle = ConfuciusUI:FindFirstChild("Subtitle")
	self.SubtitleLabel = SubTitle
end

-- Cache parts so we can color + tween nicely
function ConfuciousController:CacheModelParts()
	self.RenderParts = {}

	if not self.Model then
		return
	end

	if self.Model.PrimaryPart then
		self.ModelPrimaryPart = self.Model.PrimaryPart
	else
		self.ModelPrimaryPart = self.Model:FindFirstChildWhichIsA("BasePart", true)
		if self.ModelPrimaryPart then
			self.Model.PrimaryPart = self.ModelPrimaryPart
		end
	end

	for _, descendant in ipairs(self.Model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			table.insert(self.RenderParts, descendant)
		end
	end

	if self.ModelPrimaryPart then
		self.CurrentOrbColor = self.ModelPrimaryPart.Color
		self.TargetOrbColor = self.CurrentOrbColor
	end
end

--This puts the orb near you
function ConfuciousController:SpawnModel()
	if self.Model then
		self.Model:Destroy()
		self.Model = nil
		self.ModelPrimaryPart = nil
		self.RenderParts = {}
	end

	-- Look for the model inside the script
	local template = script:FindFirstChild("ConfuciousOrb")

	if not template then
		-- Fallback incase the model isn't found or doesn't exist, since it's just 1 part it's fine, and just for the hidden devs reader guy
		local part = Instance.new("Part")
		part.Name = "Head"
		part.Size = v3(1.5, 1.5, 1.5)
		part.Anchored = true
		part.CanCollide = false
		part.Material = Enum.Material.Neon
		part.Color = CONFIG.Orb.BaseColor

		template = Instance.new("Model")
		template.Name = "ConfuciousOrb"
		part.Parent = template
		template.PrimaryPart = part
	end

	self.Model = template:Clone()
	self.Model.Parent = Workspace

	self:CacheModelParts()

	if self.Root then
		local startPos = self.Root.Position + v3(0, CONFIG.RespawnYOffset, 0)
		self.Model:PivotTo(cf(startPos))
		self.LastPosition = startPos
	end
end

--This is for the size tween for the orb
function ConfuciousController:StartBreathingTween()
	local startVal = v3(0, -CONFIG.BreathHeight / 2, 0)
	local endVal = v3(0, CONFIG.BreathHeight / 2, 0)

	self.BreathOffsetValue.Value = startVal

	local ti = TweenInfo.new(
		CONFIG.BreathDuration,
		Enum.EasingStyle.Sine,
		Enum.EasingDirection.InOut,
		-1, -- Infinite loop
		true
	)

	local tween = TweenService:Create(self.BreathOffsetValue, ti, { Value = endVal })
	tween:Play()
end

function ConfuciousController:GetGoalPosition()
	if not self.Root then
		return v3()
	end

	-- The cframe for the orb
	local cfRoot = self.Root.CFrame

	local basePos = self.Root.Position
		- (cfRoot.LookVector * CONFIG.TargetDistance)
		+ (cfRoot.RightVector * CONFIG.SideOffset)
		+ v3(0, CONFIG.TargetHeight, 0)

	-- I Added the breathing offset
	local finalPos = basePos + self.BreathOffsetValue.Value
	return finalPos
end

function ConfuciousController:CalculateTilt(velocity)
	local speed = velocity.Magnitude
	if speed < 0.1 then
		return v3(0, 0, 0)
	end

	local forward = velocity.Unit
	local right = forward:Cross(v3(0, 1, 0))

	local tiltAmount = math.clamp(speed / 10, 0, 1) * CONFIG.MaxAngle
	return right * tiltAmount
end

-- Extra: keep orb from drifting too far from the player
function ConfuciousController:ClampToPlayerDistance(position)
	if not self.Root then
		return position
	end

	local rootPos = self.Root.Position
	local offset = position - rootPos
	local dist = offset.Magnitude

	if dist > CONFIG.MaxDistanceFromPlayer then
		local direction = offset.Unit
		local clamped = rootPos + direction * CONFIG.RecenterDistance
		return clamped
	end

	return position
end

-- Visuals: color reacts to speed / talking
function ConfuciousController:UpdateOrbVisuals(velocity, dt)
	if not self.ModelPrimaryPart then
		return
	end

	local speed = velocity.Magnitude

	-- Pick target color based on state
	if self.IsTalking then
		self.TargetOrbColor = CONFIG.Orb.TalkColor
	else
		local speedAlpha = math.clamp(speed / CONFIG.Orb.SpeedForMaxEffect, 0, 1)
		local idleColor = CONFIG.Orb.BaseColor
		local fastColor = CONFIG.Orb.SpeedColor
		self.TargetOrbColor = idleColor:Lerp(fastColor, speedAlpha)
	end

	-- Smoothly lerp to target color
	self.CurrentOrbColor = self.CurrentOrbColor:Lerp(self.TargetOrbColor, CONFIG.Orb.ColorLerpSpeed)

	for _, part in ipairs(self.RenderParts) do
		part.Color = self.CurrentOrbColor
	end
end

--This is for the positioning
function ConfuciousController:Update(dt)
	if self.IsDestroyed then
		return
	end

	if not self.Model or not self.Character or not self.Character.Parent then
		return
	end

	if not self.Root then
		return
	end

	self.Time = self.Time + dt

	local goalPos = self:GetGoalPosition()
	goalPos = self:ClampToPlayerDistance(goalPos)

	local currentCFrame = self.Model:GetPivot()
	local currentPos = currentCFrame.Position

	local newPos = currentPos:Lerp(goalPos, CONFIG.LerpSpeed)

	local velocity = (newPos - self.LastPosition) / math.max(dt, 1e-3)
	self.LastPosition = newPos

	local targetTilt = self:CalculateTilt(velocity)
	self.CurrentTilt = self.CurrentTilt:Lerp(targetTilt, CONFIG.TiltSpeed)

	--Apply CFrame
	local lookCF = CFrame.lookAt(newPos, self.Root.Position)

	-- Small idle spin so it doesn't feel dead
	local idleSpinAngle = sin(self.Time * 1.2) * rad(5)
	local idleSpinCF = CFrame.Angles(0, idleSpinAngle, 0)

	local bankCF = CFrame.Angles(rad(self.CurrentTilt.X), rad(self.CurrentTilt.Y), rad(self.CurrentTilt.Z))

	self.Model:PivotTo(lookCF * idleSpinCF * bankCF)

	-- Update orb visuals to react to speed and speaking
	self:UpdateOrbVisuals(velocity, dt)

	--Check Quotes
	self:UpdateQuotes()
end

-- Get a quote without repeating the last one
function ConfuciousController:GetNextQuote()
	if #QUOTES == 0 then
		return ""
	end

	if #QUOTES == 1 then
		self.LastQuoteIndex = 1
		return QUOTES[1]
	end

	local index = Random:NextInteger(1, #QUOTES)
	if self.LastQuoteIndex and #QUOTES > 1 then
		if index == self.LastQuoteIndex then
			index = (index % #QUOTES) + 1
		end
	end

	self.LastQuoteIndex = index
	return QUOTES[index]
end

--This is for switching the orbs
function ConfuciousController:UpdateQuotes()
	-- Making sure it's not talking already
	if self.IsTalking then
		return
	end

	-- CD check
	if tick() > self.NextTalkTime then
		local txt = self:GetNextQuote()

		task.spawn(function()
			-- play the effect
			self:PlayTypewriterEffect(txt)
		end)

		-- CD
		local cd = math.random(CONFIG.CooldownRange.Min, CONFIG.CooldownRange.Max)
		self.NextTalkTime = tick() + cd
	end
end

function ConfuciousController:CancelCurrentSpeech()
	self.CurrentMessageId = self.CurrentMessageId + 1
	self.IsTalking = false

	if self.SubtitleLabel then
		self.SubtitleLabel.TextTransparency = 1
		self.SubtitleLabel.TextStrokeTransparency = 1
		if self.SubtitleLabel.UIStroke then
			self.SubtitleLabel.UIStroke.Transparency = 1
		end
	end
end

--This is for the text fading in and out, and typewriting it
function ConfuciousController:PlayTypewriterEffect(text)
	if not self.SubtitleLabel then
		return
	end

	self:CancelCurrentSpeech()

	self.IsTalking = true
	self.SubtitleLabel.Text = ""

	-- Always make it visible before typing
	self.SubtitleLabel.TextTransparency = 0
	self.SubtitleLabel.TextStrokeTransparency = 0
	if self.SubtitleLabel.UIStroke then
		self.SubtitleLabel.UIStroke.Transparency = 0
	end

	self.CurrentMessageId = self.CurrentMessageId + 1
	local myMessageId = self.CurrentMessageId

	-- Typewriter Loop
	for i = 1, #text do
		if myMessageId ~= self.CurrentMessageId then
			return
		end

		self.SubtitleLabel.Text = string.sub(text, 1, i)

		local char = string.sub(text, i, i)
		local delay = CONFIG.TypewriterSpeed

		-- Pause when there's punctuations
		if char == "." or char == "," or char == ";" then
			delay = delay * 4
		end

		task.wait(delay)
	end

	if myMessageId ~= self.CurrentMessageId then
		return
	end

	task.wait(CONFIG.MessageDuration)

	local fadeInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	local t1 = TweenService:Create(self.SubtitleLabel, fadeInfo, { TextTransparency = 1 })
	local t2 = TweenService:Create(self.SubtitleLabel, fadeInfo, { TextStrokeTransparency = 1 })
	local t3

	if self.SubtitleLabel.UIStroke then
		t3 = TweenService:Create(self.SubtitleLabel.UIStroke, fadeInfo, { Transparency = 1 })
	end

	t1:Play()
	t2:Play()
	if t3 then
		t3:Play()
	end

	t1.Completed:Wait()

	if myMessageId ~= self.CurrentMessageId then
		return
	end

	task.wait(2)

	self.SubtitleLabel.Text = ""
	self.IsTalking = false
end

function ConfuciousController:Destroy()
	if self.IsDestroyed then
		return
	end

	self.IsDestroyed = true

	self:CancelCurrentSpeech()
	self:DisconnectAll()

	if self.Model then
		self.Model:Destroy()
		self.Model = nil
	end

	if self.BreathOffsetValue then
		self.BreathOffsetValue:Destroy()
		self.BreathOffsetValue = nil
	end
end

local app = ConfuciousController.new()
app:Init()

print("Truth Orb, or Confucious, whatever you might believe in.")
