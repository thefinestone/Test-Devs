--V.5 My other applications were declined so I took more time explaining it, so it'd meet the requirements fully. According to the other application's comments.

-- Features I added to show my understanding:
-- 1. Physics based movement: I used Lerp for smoothing and calculated a 'tilt' vector based on velocity so it tilts like a plane when turning.
-- 2. State Management: It uses OOP Controller class to handle character respawning and death cleanup without memory leaks.
-- 3. Dialogue System: A custom typewriter effect that actually pauses at punctuation marks to make the speech feel good and natural.


local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Random = Random.new()

-- I grouped all the variables into this config table. 
-- This separates the data from the logic, which makes it way easier for me to tweak the feel of the confucious orb.
-- Also helps with the movement and animation later without hunting through the math functions, it's just all in one place.
local CONFIG = {
	-- Positioning: I use these offsets relative to the RootPart's CFrame so the orb stays locked to the player's shoulder.
	TargetDistance = 5,
	TargetHeight = 3.5,
	SideOffset = 2,

	-- Movement: I kept LerpSpeed low (0.1) to create a "drag" effect. 
	-- This makes the orb feel like it has weight rather than just snapping instantly to the goal.
	LerpSpeed = 0.1,
	TiltSpeed = 0.1,
	MaxAngle = 20,

	-- Breathing Animation: Used to create that idle hovering sine-wave motion.
	BreathDuration = 2,
	BreathHeight = 0.8,

	-- Text Settings: Controls the pacing of the typewriter effect.
	TypewriterSpeed = 0.03,
	MessageDuration = 4,
	CooldownRange = NumberRange.new(5, 10),

	-- Orb visuals: I set up different colors to give visual feedback based on the orb's velocity state.
	Orb = {
		BaseColor = Color3.fromRGB(255, 255, 255),
		TalkColor = Color3.fromRGB(255, 235, 180),
		SpeedColor = Color3.fromRGB(180, 220, 255),
		SpeedForMaxEffect = 20,
		ColorLerpSpeed = 0.15,
	},

	-- Safety constraints: These prevent the orb from getting lost or taking too long to catch up if the player teleports.
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

-- I set this up using an OOP structure with metatables.
-- This allows me to encapsulate all the state (like IsTalking, Position, and Model references) inside a single object instance.
-- It avoids global variable pollution and makes it safer if I ever need to restart the script or have multiple orbs.
local ConfuciousController = {}
ConfuciousController.__index = ConfuciousController

function ConfuciousController.new()
	local self = setmetatable({}, ConfuciousController)

	-- References to the player logic
	self.Player = Players.LocalPlayer
	self.Character = nil
	self.Root = nil
	self.Humanoid = nil

	-- Visual object references
	self.Model = nil
	self.ModelPrimaryPart = nil
	self.RenderParts = {}
	self.SubtitleLabel = nil

	-- Logic
	self.IsTalking = false
	self.NextTalkTime = tick() + 5
	self.CurrentMessageId = 0 -- I use this ID to handle conditions (stopping old text loops when new ones start).
	self.LastQuoteIndex = nil

	-- Physics
	self.LastPosition = v3(0, 0, 0)
	self.CurrentTilt = v3(0, 0, 0)
	self.Time = 0

	-- Breathing: I used a Vector3Value here instead of a raw variable.
	-- This allows me to use TweenService to handle the smoothing and reversing logic automatically, rather than creating my own logic or something
	-- which is cleaner than calculating math manually inside the RenderStepped loop.
	self.BreathOffsetValue = Instance.new("Vector3Value")
	self.BreathOffsetValue.Value = v3(0, -CONFIG.BreathHeight / 2, 0)

	-- Visual State for color change
	self.TargetOrbColor = CONFIG.Orb.BaseColor
	self.CurrentOrbColor = CONFIG.Orb.BaseColor
	self.ColorState = "Idle"

	-- Connection management: storing connections here lets me disconnect them all at once to prevent memory leaks on cleanup.
	self.Connections = {}

	self.IsDestroyed = false

	return self
end

-- I use this wrapper to track all events. This ensures that if the controller is destroyed,
-- I don't leave any non tracked connections running in the background.
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

-- I need to rebind references whenever the Character is added.
-- The HRP is essential for the math, so I wait for it specifically.
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

	-- I put the model to the player immediately on spawn.
	-- If I didn't do this, the Lerp logic would try to drag the orb from (0,0,0) to the player, which looks choppy.
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

	-- I use a tween to fade the orb out rather than deleting it instantly. 
	-- It provides a more polished user experience during the death state.
	if self.Model and self.ModelPrimaryPart then
		local info = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local goals = { Transparency = 1 }
		for _, part in ipairs(self.RenderParts) do
			TweenService:Create(part, info, goals):Play()
		end
	end

	-- Prevent the orb from trying to talk while the player is dead.
	self.NextTalkTime = math.huge
end

function ConfuciousController:Init()
	self.Character = self.Player.Character or self.Player.CharacterAdded:Wait()
	self:BindToCharacter(self.Character)

	self:SetupInterface()
	self:SpawnModel()

	-- I chose RenderStepped over Heartbeat because the orb's movement needs to update 
	-- every single frame before the camera renders. This prevents the orb from jittering or lagging behind the camera.
	self:AddConnection(RunService.RenderStepped:Connect(function(dt)
		self:Update(dt)
	end))

	self:StartBreathingTween()

	self:AddConnection(self.Player.CharacterAdded:Connect(function(char)
		self:OnCharacterAdded(char)
	end))
end

-- I separated this logic to keep the Init function clean and more controled.
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

-- I cache the model parts into a table once at the start.
-- GetDescendants every frame inside the Update loop would be very expensive and cause lag.
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
	-- I explicitly clean up the old model before creating a new one to prevent 
	-- duplicate models stacking up in Workspace if the function is called twice.
	if self.Model then
		self.Model:Destroy()
		self.Model = nil
		self.ModelPrimaryPart = nil
		self.RenderParts = {}
	end

	local template = script:FindFirstChild("ConfuciousOrb")

	-- Fallback logic: If the model asset is missing, I generate a part via code.
	-- This ensures the script doesn't crash due to missing assets, making it more robust.
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

-- I use an infinite, reversing Tween here. 
-- It's more performant than running math calculations every frame for the breathing effect.
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

	-- I calculate the position using the RootPart's LookVector and RightVector.
	-- This makes sure the orb is always relative to the players, not world coordinates.
	local basePos = self.Root.Position
		- (cfRoot.LookVector * CONFIG.TargetDistance)
		+ (cfRoot.RightVector * CONFIG.SideOffset)
		+ v3(0, CONFIG.TargetHeight, 0)

	-- I add the breathing offset on top of the calculated base position.
	local finalPos = basePos + self.BreathOffsetValue.Value
	return finalPos
end

-- This function creates tilting visualization.
-- I calculate the tilt based on velocity so the orb leans into turns like an airplane.
function ConfuciousController:CalculateTilt(velocity)
	local speed = velocity.Magnitude
	if speed < 0.1 then
		return v3(0, 0, 0)
	end

	local forward = velocity.Unit
	-- I use the Cross Product here to find the vector perpendicular to the movement direction.
	-- This gives me the correct axis to rotate around for the tilt effect.
	local right = forward:Cross(v3(0, 1, 0))

	-- I clamp the angle to prevent it from flinging/spinning at high speeds.
	local tiltAmount = math.clamp(speed / 10, 0, 1) * CONFIG.MaxAngle
	return right * tiltAmount
end

-- This logic handles edge cases where the player teleports or resets.
-- Without this, the Lerp would take a long time to travel across the map. 
-- If the distance is too high, I snap it closer to maintain immersion.
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

	-- I prioritize the "Talking" state for color, then fallback to speed-based coloring.
	if self.IsTalking then
		self.TargetOrbColor = CONFIG.Orb.TalkColor
	else
		-- I interpolate between the Base color and Speed color based on velocity magnitude.
		-- This gives the player visual feedback on how fast they are moving.
		local speedAlpha = math.clamp(speed / CONFIG.Orb.SpeedForMaxEffect, 0, 1)
		local idleColor = CONFIG.Orb.BaseColor
		local fastColor = CONFIG.Orb.SpeedColor
		self.TargetOrbColor = idleColor:Lerp(fastColor, speedAlpha)
	end

	-- I use Lerp on the color property to smooth the transition, preventing jarring color flashes.
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

	-- I use Lerp (Linear Interpolation) to smooth the movement towards the goal position.
	-- This creates a fluid, floating feel rather than a rigid attachment to the player.
	local newPos = currentPos:Lerp(goalPos, CONFIG.LerpSpeed)

	-- I calculate velocity manually here because I'm manipulating CFrame directly.
	-- I need this derived velocity to drive the tilt and color logic.
	local velocity = (newPos - self.LastPosition) / math.max(dt, 1e-3)
	self.LastPosition = newPos

	local targetTilt = self:CalculateTilt(velocity)
	self.CurrentTilt = self.CurrentTilt:Lerp(targetTilt, CONFIG.TiltSpeed)

	-- I combine three rotations: LookAt (to face player), Idle Spin (for life) (Incase you wanna change the shape aswell, makes it cooler), and Tilt (for physics feel).
	local lookCF = CFrame.lookAt(newPos, self.Root.Position)
	local idleSpinAngle = sin(self.Time * 1.2) * rad(5)
	local idleSpinCF = CFrame.Angles(0, idleSpinAngle, 0)
	local bankCF = CFrame.Angles(rad(self.CurrentTilt.X), rad(self.CurrentTilt.Y), rad(self.CurrentTilt.Z))

	self.Model:PivotTo(lookCF * idleSpinCF * bankCF)

	self:UpdateOrbVisuals(velocity, dt)
	self:UpdateQuotes()
end

-- I added logic to ensure we don't pick the same quote twice in a row,
-- which keeps the dialogue feeling fresh.
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

	-- I check the current tick against the NextTalkTime timestamp to handle the cooldown logic.
	if tick() > self.NextTalkTime then
		local txt = self:GetNextQuote()

		-- I use task.spawn so the typewriter text loop runs on a separate thread.
		-- This prevents the text logic from yielding (pausing) the main orb movement loop.
		task.spawn(function()
			self:PlayTypewriterEffect(txt)
		end)

		local cd = math.random(CONFIG.CooldownRange.Min, CONFIG.CooldownRange.Max)
		self.NextTalkTime = tick() + cd
	end
end

-- I increment the CurrentMessageId here. This is a pattern to handle race conditions:
-- if a new message starts, the ID changes, and any old running loops will see the mismatch and stop.
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

	-- This is the typewriter loop that builds the string character by character.
	for i = 1, #text do
		if myMessageId ~= self.CurrentMessageId then
			return
		end

		self.SubtitleLabel.Text = string.sub(text, 1, i)

		local char = string.sub(text, i, i)
		local delay = CONFIG.TypewriterSpeed

		-- I multiply the delay for punctuation to simulate natural speaking pauses.
		if char == "." or char == "," or char == ";" then
			delay = delay * 4
		end

		task.wait(delay)
	end

	if myMessageId ~= self.CurrentMessageId then
		return
	end

	task.wait(CONFIG.MessageDuration)

	-- I used TweenService to fade out the text because it looks much smoother than just setting Text = "".
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
