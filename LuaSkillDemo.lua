--This was made in under 30 minutes for the Hidden Devs Application, I contributed to over 50M+ in Roblox visits and am trying to get into commissioning in the mean time.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local CONFIG = {
	-- Positioning
	TargetDistance = 5,
	TargetHeight = 3.5,
	SideOffset = 2, 

	-- Movemen
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
	self.Model = nil
	self.SubtitleLabel = nil

	-- Flags
	self.IsTalking = false
	self.NextTalkTime = tick() + 5

	-- Movement State
	self.LastPosition = v3(0,0,0)
	self.CurrentTilt = v3(0,0,0)

	-- Breathing
	self.BreathOffsetValue = Instance.new("Vector3Value") 
	self.BreathOffsetValue.Value = v3(0, -CONFIG.BreathHeight/2, 0)

	return self
end

function ConfuciousController:Init()
	self.Character = self.Player.Character or self.Player.CharacterAdded:Wait()
	self.Root = self.Character:WaitForChild("HumanoidRootPart")

	--Create the Interface
	self:SetupInterface()

	--Spawn the Model
	self:SpawnModel()

	--Start the Loop
	RunService.RenderStepped:Connect(function(dt)
		self:Update(dt)
	end)

	-- Start the Breathing
	self:StartBreathingTween()
end

--This setsup the UI
function ConfuciousController:SetupInterface()
	local playerGui = self.Player:WaitForChild("PlayerGui", 5)
	if not playerGui then return end

	local ConfuciusUI = playerGui:WaitForChild("ConfuciusUI")
	local SubTitle = ConfuciusUI:FindFirstChild("Subtitle")
	self.SubtitleLabel = SubTitle
end

--This puts the orb near you
function ConfuciousController:SpawnModel()
	if self.Model then 
		self.Model:Destroy() 
	end

	-- Look for the model inside the script
	local template = script:FindFirstChild("ConfuciousOrb")

	if not template then 
		-- Fallback incase the model isn't found or doesn't exist, since it's just 1 part it's fine
		local part = Instance.new("Part")
		part.Name = "Head"
		part.Size = v3(1,1,1)
		part.Anchored = true
		part.CanCollide = false
		template = Instance.new("Model")
		template.Name = "ConfuciousOrb"
		part.Parent = template
		template.PrimaryPart = part
	end

	self.Model = template:Clone()
	self.Model.Parent = workspace

	if self.Root then
		local startPos = self.Root.Position + v3(0, 5, 0)
		self.Model:PivotTo(cf(startPos))
		self.LastPosition = startPos
	end
end

--This is for the size tween for the orb
function ConfuciousController:StartBreathingTween()
	local startVal = v3(0, -CONFIG.BreathHeight/2, 0)
	local endVal = v3(0, CONFIG.BreathHeight/2, 0)

	self.BreathOffsetValue.Value = startVal

	local ti = TweenInfo.new(
		CONFIG.BreathDuration,
		Enum.EasingStyle.Sine,
		Enum.EasingDirection.InOut,
		-1, -- Infinite loop
		true
	)

	local tween = TweenService:Create(self.BreathOffsetValue, ti, {Value = endVal})
	tween:Play()
end

function ConfuciousController:GetGoalPosition()
	if not self.Root then return v3() end
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
	if speed < 0.1 then return v3(0,0,0) end

	local forward = velocity.Unit
	local right = forward:Cross(v3(0, 1, 0))

	local tiltAmount = math.clamp(speed / 10, 0, 1) * CONFIG.MaxAngle
	return right * tiltAmount
end

--This is for the positioning
function ConfuciousController:Update(dt)
	if not self.Model or not self.Root or not self.Character.Parent then 
		return 
	end
	local goalPos = self:GetGoalPosition()
	local currentCFrame = self.Model.GetPivot(self.Model)
	local currentPos = currentCFrame.Position

	local newPos = currentPos:Lerp(goalPos, CONFIG.LerpSpeed)

	local velocity = (newPos - self.LastPosition) / dt
	self.LastPosition = newPos

	local targetTilt = self:CalculateTilt(velocity)
	self.CurrentTilt = self.CurrentTilt:Lerp(targetTilt, CONFIG.TiltSpeed)

	--Apply CFrame
	local lookCF = CFrame.lookAt(newPos, self.Root.Position)
	local bankCF = CFrame.Angles(rad(self.CurrentTilt.X), rad(self.CurrentTilt.Y), rad(self.CurrentTilt.Z))

	self.Model:PivotTo(lookCF * bankCF)

	--Check Quotes
	self:UpdateQuotes()
end

--This is for switching the orbs
function ConfuciousController:UpdateQuotes()
	-- Making sure it's not talking already
	if self.IsTalking then return end
	-- CD check

	if tick() > self.NextTalkTime then
		local txt = QUOTES[math.random(1, #QUOTES)]

		task.spawn(function()
			-- play the effect
			self:PlayTypewriterEffect(txt)
		end)
		-- CD

		local cd = math.random(CONFIG.CooldownRange.Min, CONFIG.CooldownRange.Max)
		self.NextTalkTime = tick() + cd
	end
end

--This is for the text fading in and out, and typewriting it
function ConfuciousController:PlayTypewriterEffect(text)
	if not self.SubtitleLabel then return end

	self.IsTalking = true
	self.SubtitleLabel.Text = ""

	-- Always make it visible before typing
	self.SubtitleLabel.TextTransparency = 0
	self.SubtitleLabel.TextStrokeTransparency = 0
	self.SubtitleLabel.UIStroke.Transparency = 0

	-- Typewriter Loop
	for i = 1, #text do
		self.SubtitleLabel.Text = string.sub(text, 1, i)

		local char = string.sub(text, i, i)
		local delay = CONFIG.TypewriterSpeed

		-- Pause when there's punctuations
		if char == "." or char == "," or char == ";" then
			delay = delay * 4
		end

		task.wait(delay)
	end

	task.wait(CONFIG.MessageDuration)

	local fadeInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	local t1 = TweenService:Create(self.SubtitleLabel, fadeInfo, {TextTransparency = 1})
	local t2 = TweenService:Create(self.SubtitleLabel, fadeInfo, {TextStrokeTransparency = 1})
	local t3 = TweenService:Create(self.SubtitleLabel.UIStroke, fadeInfo, {Transparency = 1})

	t1:Play()
	t2:Play()
	t3:Play()

	t1.Completed:Wait()

	task.wait(2)

	self.SubtitleLabel.Text = ""
	self.IsTalking = false
end

local app = ConfuciousController.new()
app:Init()

print("Truth Orb, or Confucious, whatever you might believe in.")
