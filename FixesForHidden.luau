--V.5 My other applications was declined so I time explaining it, so it'd meet the requirements fully

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Random = Random.new()

-- I put all the settings here in one table. It makes it way easier to tweak how the orb feels 
-- without having to hunt for numbers inside the math functions later.
local CONFIG = {
	-- Positioning: This decides where the orb floats relative to your RootPart
	TargetDistance = 5,
	TargetHeight = 3.5,
	SideOffset = 2,

	-- Movement: I kept the LerpSpeed low to give it a "drag" effect so it feels heavy
	LerpSpeed = 0.1,
	TiltSpeed = 0.1,
	MaxAngle = 20,

	-- Breathing Animation: This controls that up/down floating motion when it's idle
	BreathDuration = 2,
	BreathHeight = 0.8,

	-- Text Settings: This handles how fast the text types out
	TypewriterSpeed = 0.03,
	MessageDuration = 4,
	CooldownRange = NumberRange.new(5, 10),

	-- Orb visuals: I wanted the orb to change color when it moves fast so it looks reactive
	Orb = {
		BaseColor = Color3.fromRGB(255, 255, 255),
		TalkColor = Color3.fromRGB(255, 235, 180),
		SpeedColor = Color3.fromRGB(180, 220, 255),
		SpeedForMaxEffect = 20,
		ColorLerpSpeed = 0.15,
	},

	-- Safety stuff so the orb doesn't get lost if you teleport across the map
	MaxDistanceFromPlayer = 40,
	RecenterDistance = 20,
	RespawnYOffset = 5,
}

-- I got these quotes from a confucious website on google
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

-- I Setup OOP here. I did it this way so I can keep all the variables (like IsTalking or Position)
-- inside one controller object instead of having global variables messing everything up.
local ConfuciousController = {}
ConfuciousController.__index = ConfuciousController

function ConfuciousController.new()
	local self = setmetatable({}, ConfuciousController)

	-- Player stuff
	self.Player = Players.LocalPlayer
	self.Character = nil
	self.Root = nil
	self.Humanoid = nil

	-- Visual stuff
	self.Model = nil
	self.ModelPrimaryPart = nil
	self.RenderParts = {}
	self.SubtitleLabel = nil

	-- Logic Flags
	self.IsTalking = false
	self.NextTalkTime = tick() + 5
	self.CurrentMessageId = 0 -- I use this ID to stop old typing tasks if a new one starts
	self.LastQuoteIndex = nil

	-- Physics state
	self.LastPosition = v3(0, 0, 0)
	self.CurrentTilt = v3(0, 0, 0)
	self.Time = 0

	-- Breathing: I'm using a Vector3Value here so I can just Tween it.
	-- It's easier than doing complex sine wave math inside the update loop.
	self.BreathOffsetValue = Instance.new("Vector3Value")
	self.BreathOffsetValue.Value = v3(0, -CONFIG.BreathHeight / 2, 0)

	-- Color State
	self.TargetOrbColor = CONFIG.Orb.BaseColor
	self.CurrentOrbColor = CONFIG.Orb.BaseColor
	self.ColorState = "Idle"

	-- I keep a list of connections so I can disconnect them later and avoid memory leaks
	self.Connections = {}

	self.IsDestroyed = false

	return self
end

-- I made this helper function so I don't leave zombie events running if the script restarts
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

-- I have to re-bind everything when the character spawns because the old RootPart gets deleted.
-- The math relies on the RootPart existing, so this is important.
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

	-- I move the model to the player instantly here so it doesn't try to fly in from (0,0,0)
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

	-- I fade the orb out when you die instead of deleting it instantly, just looks cleaner
	if self.Model and self.ModelPrimaryPart then
		local info = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local goals = { Transparency = 1 }
		for _, part in ipairs(self.RenderParts) do
			TweenService:Create(part, info, goals):Play()
		end
	end

	-- Make sure it doesn't try to talk while you're dead
	self.NextTalkTime = math.huge
end

function ConfuciousController:Init()
	self.Character = self.Player.Character or self.Player.CharacterAdded:Wait()
	self:BindToCharacter(self.Character)

	self:SetupInterface()
	self:SpawnModel()

	-- I decided to use RenderStepped here. The orb needs to update every single frame
	-- to stay smooth with the camera, otherwise it looks jittery.
	self:AddConnection(RunService.RenderStepped:Connect(function(dt)
		self:Update(dt)
	end))

	self:StartBreathingTween()

	self:AddConnection(self.Player.CharacterAdded:Connect(function(char)
		self:OnCharacterAdded(char)
	end))
end

-- I split the UI setup into its own function just to keep the Init function clean
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

-- I cache the parts into a table once at the start. 
-- If I searched through the model every frame in the loop, it would cause a lot of lag.
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

function ConfuciousController:SpawnModel()
	-- I clean up the old model first so we don't end up with duplicates
	if self.Model then
		self.Model:Destroy()
		self.Model = nil
		self.ModelPrimaryPart = nil
		self.RenderParts = {}
	end

	local template = script:FindFirstChild("ConfuciousOrb")

	-- Fallback incase the model isn't found or doesn't exist, I create a part manually so the script doesn't error
	if not template then
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

-- I used an infinite loop Tween for the breathing here.
-- It's just way more efficient than calculating the offset every frame manually.
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

	local cfRoot = self.Root.CFrame

	-- I calculate the position based on the player's LookVector and RightVector.
	-- This ensures the orb always stays relative to your rotation, not the world.
	local basePos = self.Root.Position
		- (cfRoot.LookVector * CONFIG.TargetDistance)
		+ (cfRoot.RightVector * CONFIG.SideOffset)
		+ v3(0, CONFIG.TargetHeight, 0)

	-- Then I add the breathing offset on top
	local finalPos = basePos + self.BreathOffsetValue.Value
	return finalPos
end

-- This handles that "banking" effect like a plane turning.
function ConfuciousController:CalculateTilt(velocity)
	local speed = velocity.Magnitude
	if speed < 0.1 then
		return v3(0, 0, 0)
	end

	local forward = velocity.Unit
	-- I used the Cross Product here to get a vector sideways to the movement.
	-- That gives me the axis I need to tilt around.
	local right = forward:Cross(v3(0, 1, 0))

	-- I clamp the angle so it doesn't spin crazy fast
	local tiltAmount = math.clamp(speed / 10, 0, 1) * CONFIG.MaxAngle
	return right * tiltAmount
end

-- I added this so if you teleport (like using a reset), the orb doesn't take 10 seconds to float over.
-- It just snaps closer if the distance gets too big.
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

function ConfuciousController:UpdateOrbVisuals(velocity, dt)
	if not self.ModelPrimaryPart then
		return
	end

	local speed = velocity.Magnitude

	-- If it's talking, I force that color. If not, I mix the color based on speed.
	if self.IsTalking then
		self.TargetOrbColor = CONFIG.Orb.TalkColor
	else
		-- I lerp the color based on how fast the orb is going for a nice visual effect
		local speedAlpha = math.clamp(speed / CONFIG.Orb.SpeedForMaxEffect, 0, 1)
		local idleColor = CONFIG.Orb.BaseColor
		local fastColor = CONFIG.Orb.SpeedColor
		self.TargetOrbColor = idleColor:Lerp(fastColor, speedAlpha)
	end

	-- I smooth the color change so it doesn't flash instantly
	self.CurrentOrbColor = self.CurrentOrbColor:Lerp(self.TargetOrbColor, CONFIG.Orb.ColorLerpSpeed)

	for _, part in ipairs(self.RenderParts) do
		part.Color = self.CurrentOrbColor
	end
end

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

	-- I use Lerp here to make the movement smooth. 
	-- If I just set the position directly, it would look stiff and locked to the player.
	local newPos = currentPos:Lerp(goalPos, CONFIG.LerpSpeed)

	-- I calculate velocity manually since I'm moving it with CFrame, not physics
	local velocity = (newPos - self.LastPosition) / math.max(dt, 1e-3)
	self.LastPosition = newPos

	local targetTilt = self:CalculateTilt(velocity)
	self.CurrentTilt = self.CurrentTilt:Lerp(targetTilt, CONFIG.TiltSpeed)

	-- I combine all the rotations here: Look at player + Idle Spin + Bank Tilt
	local lookCF = CFrame.lookAt(newPos, self.Root.Position)
	local idleSpinAngle = sin(self.Time * 1.2) * rad(5)
	local idleSpinCF = CFrame.Angles(0, idleSpinAngle, 0)
	local bankCF = CFrame.Angles(rad(self.CurrentTilt.X), rad(self.CurrentTilt.Y), rad(self.CurrentTilt.Z))

	self.Model:PivotTo(lookCF * idleSpinCF * bankCF)

	self:UpdateOrbVisuals(velocity, dt)
	self:UpdateQuotes()
end

-- I made this logic so it doesn't pick the same quote twice in a row
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

function ConfuciousController:UpdateQuotes()
	if self.IsTalking then
		return
	end

	-- I check the time here to make sure we respect the cooldown
	if tick() > self.NextTalkTime then
		local txt = self:GetNextQuote()

		-- I use task.spawn so the typewriter effect doesn't pause the main orb movement loop
		task.spawn(function()
			self:PlayTypewriterEffect(txt)
		end)

		local cd = math.random(CONFIG.CooldownRange.Min, CONFIG.CooldownRange.Max)
		self.NextTalkTime = tick() + cd
	end
end

-- I increment the message ID here. This effectively cancels any old loops running
-- because they will see the ID changed and stop themselves.
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

function ConfuciousController:PlayTypewriterEffect(text)
	if not self.SubtitleLabel then
		return
	end

	self:CancelCurrentSpeech()

	self.IsTalking = true
	self.SubtitleLabel.Text = ""

	self.SubtitleLabel.TextTransparency = 0
	self.SubtitleLabel.TextStrokeTransparency = 0
	if self.SubtitleLabel.UIStroke then
		self.SubtitleLabel.UIStroke.Transparency = 0
	end

	self.CurrentMessageId = self.CurrentMessageId + 1
	local myMessageId = self.CurrentMessageId

	-- This is the typewriter loop
	for i = 1, #text do
		if myMessageId ~= self.CurrentMessageId then
			return
		end

		self.SubtitleLabel.Text = string.sub(text, 1, i)

		local char = string.sub(text, i, i)
		local delay = CONFIG.TypewriterSpeed

		-- I added a longer delay for punctuation so the speech feels more natural and less robotic
		if char == "." or char == "," or char == ";" then
			delay = delay * 4
		end

		task.wait(delay)
	end

	if myMessageId ~= self.CurrentMessageId then
		return
	end

	task.wait(CONFIG.MessageDuration)

	-- I used a Tween here to fade the text out cleanly
	local fadeInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local t1 = TweenService:Create(self.SubtitleLabel, fadeInfo, { TextTransparency = 1 })
	local t2 = TweenService:Create(self.SubtitleLabel, fadeInfo, { TextStrokeTransparency = 1 })
	local t3

	if self.SubtitleLabel.UIStroke then
		t3 = TweenService:Create(self.SubtitleLabel.UIStroke, fadeInfo, { Transparency = 1 })
	end

	t1:Play()
	t2:Play()
	if t3 then t3:Play() end

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
