--!strict
-- FILM SHEET (Studio only: a tool for whoever builds the films; never runs in a live game). A film's shots,
-- photographed while it plays and laid out as a contact sheet afterwards, so the whole film can be checked by eye in a
-- screenshot or two (owner, 29 Oct: "sometimes the camera just pans to the ground or just some useless thing": every
-- shot gets looked at before he sees it).
--   Workspace attribute FilmSheet = true (2 frames a shot) or a number (1-4 frames a shot), set before a film starts:
--     each shot (every client/Film.run) is photographed (CaptureService) at evenly spaced points through it. When the
--     film ends the frames show in a grid, 12 to a page, each labelled "#shot  Script:line  k  film time"; Right / a
--     click on the sheet turns the page, Left goes back, Escape closes it. Set the attribute FilmSheetShow (any value)
--     to bring the sheet up mid-film. Each frame is printed to the Output too: "[FilmSheet] #3 Intro:415 k0.50 12.3s".
--   Workspace attribute FilmHold = seconds: instead of photographing, the film holds still that long at each of those
--     points ("[FilmSheet] HOLD ..." in the Output), for an outside screenshot tool.
--   Workspace attribute PlayFilm = "opening", "clash", "ending" or "credits": plays that film (as the DEV panel's
--     buttons do) a moment later, so a test tool can start one without clicking through the panel.
-- It works by wrapping Film.run (the films call it through the module table), so the films need no changes.
local CaptureService = game:GetService("CaptureService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Film = require(script.Parent.Film)

local FilmSheet = {}

type Shot = { id: string?, label: string, failed: boolean? }

local frames: { Shot } = {}
local shotNo = 0
local shown = false -- (the sheet of these frames has been shown: the next film starts a new one)
local sheet: ScreenGui? = nil
local page = 1
local COLS, ROWS = 4, 3

local function perShot(): number?
	local v = workspace:GetAttribute("FilmSheet")
	if v == true then
		return 2
	elseif type(v) == "number" and v >= 1 then
		return math.clamp(math.floor(v), 1, 4)
	end
	return nil
end

local function holdTime(): number?
	local v = workspace:GetAttribute("FilmHold")
	return if type(v) == "number" and v > 0 then v else nil
end

-- "Intro:415": the script and line the shot's function was written at
local function where(fn: any): string
	local ok, src, line = pcall(debug.info, fn, "sl")
	if ok and type(src) == "string" then
		return (string.match(src, "([%w_]+)$") or src) .. ":" .. tostring(line)
	end
	return "?"
end

local function snap(label: string)
	local entry: Shot = { id = nil, label = label }
	table.insert(frames, entry)
	print("[FilmSheet] " .. label)
	local ok, err = pcall(function()
		CaptureService:CaptureScreenshot(function(id: any)
			entry.id = tostring(id)
		end)
	end)
	if not ok then
		entry.failed = true
		warn("[FilmSheet] capture failed: " .. tostring(err))
	end
end

local function closeSheet()
	if sheet then
		sheet:Destroy()
		sheet = nil
	end
end

local function draw()
	local gui = sheet
	if not gui then
		return
	end
	local grid = gui:FindFirstChild("Grid") :: Frame
	grid:ClearAllChildren()
	local per = COLS * ROWS
	local pages = math.max(1, math.ceil(#frames / per))
	page = math.clamp(page, 1, pages)
	local title = gui:FindFirstChild("Title") :: TextLabel
	title.Text = string.format("FILM SHEET  page %d / %d  (%d frames)   click or Right: next   Left: back   Esc: close", page, pages, #frames)
	for i = 1, per do
		local f = frames[(page - 1) * per + i]
		if not f then
			break
		end
		local col, row = (i - 1) % COLS, (i - 1) // COLS
		local cell = Instance.new("ImageLabel")
		cell.Name = "Frame" .. i
		cell.BackgroundColor3 = Color3.new(0, 0, 0)
		cell.BorderSizePixel = 0
		cell.Size = UDim2.new(1 / COLS, -6, 1 / ROWS, -6)
		cell.Position = UDim2.new(col / COLS, 3, row / ROWS, 3)
		cell.ScaleType = Enum.ScaleType.Fit
		cell.Image = f.id or ""
		cell.Parent = grid
		local t = Instance.new("TextLabel")
		t.BackgroundColor3 = Color3.new(0, 0, 0)
		t.BackgroundTransparency = 0.35
		t.BorderSizePixel = 0
		t.Size = UDim2.new(1, 0, 0, 20)
		t.Position = UDim2.new(0, 0, 1, -20)
		t.Font = Enum.Font.Code
		t.TextSize = 15
		t.TextColor3 = Color3.new(1, 1, 0.6)
		t.TextXAlignment = Enum.TextXAlignment.Left
		t.Text = " " .. f.label .. (if f.failed then "  (NO CAPTURE)" elseif not f.id then "  (waiting)" else "")
		t.Parent = cell
	end
end

local function showSheet()
	closeSheet()
	if #frames == 0 then
		return
	end
	local pg = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not pg then
		return
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "FilmSheet"
	gui.DisplayOrder = 10000
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.None
	local bg = Instance.new("TextButton")
	bg.Name = "Back"
	bg.AutoButtonColor = false
	bg.Text = ""
	bg.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
	bg.BorderSizePixel = 0
	bg.Size = UDim2.fromScale(1, 1)
	bg.Parent = gui
	bg.Activated:Connect(function()
		page += 1
		if page > math.ceil(#frames / (COLS * ROWS)) then
			page = 1
		end
		draw()
	end)
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 28)
	title.Font = Enum.Font.Code
	title.TextSize = 18
	title.TextColor3 = Color3.new(1, 1, 1)
	title.Parent = gui
	local grid = Instance.new("Frame")
	grid.Name = "Grid"
	grid.BackgroundTransparency = 1
	grid.Position = UDim2.fromOffset(0, 28)
	grid.Size = UDim2.new(1, 0, 1, -28)
	grid.Parent = gui
	gui.Parent = pg
	sheet = gui
	shown = true
	page = 1
	draw()
	-- the last photos may still be on their way
	task.delay(1, draw)
end

if RunService:IsStudio() then
	local run = Film.run
	Film.run = function(len: number, fn: any, opts: any): boolean
		local per = perShot()
		local hold = holdTime()
		if not per and not hold then
			return run(len, fn, opts)
		end
		if shown then
			-- a new film: a new sheet (an ending's parts, credits and teaser, all go on one)
			shown = false
			closeSheet()
			table.clear(frames)
			shotNo = 0
		end
		shotNo += 1
		local no = shotNo
		local at = where(fn)
		local n = per or 2
		local points = {}
		for i = 1, n do
			points[i] = if n == 1 then 0.5 else 0.08 + (i - 1) / (n - 1) * 0.84
		end
		local nextI = 1
		local function shot(k: number, t: number): (CFrame, number, Vector3?)
			local cf, fov, focus = fn(k, t)
			if nextI <= #points and k >= points[nextI] then
				local p = points[nextI]
				nextI += 1
				local label = string.format("#%d %s k%.2f %.1fs", no, at, p, Film.now())
				if hold then
					print("[FilmSheet] HOLD " .. label)
					Film.freeze(hold)
				else
					snap(label)
				end
			end
			return cf, fov, focus
		end
		return run(len, shot, opts)
	end

	local was = false
	RunService.Heartbeat:Connect(function()
		local now = Film.playing
		if was and not now and #frames > 0 and perShot() then
			-- (unless the next part of the same film starts straight after)
			task.delay(1.2, function()
				if not Film.playing and not shown then
					showSheet()
				end
			end)
		end
		was = now
	end)
	workspace:GetAttributeChangedSignal("PlayFilm"):Connect(function()
		local which = workspace:GetAttribute("PlayFilm")
		if type(which) ~= "string" or which == "" then
			return
		end
		-- (a moment later: a test tool that set the attribute has let go of the game by then)
		task.delay(1.5, function()
			workspace:SetAttribute("PlayFilm", nil)
			if which == "opening" or which == "clash" then
				require(script.Parent:FindFirstChild("Intro") :: ModuleScript).preview(if which == "clash" then "glitch" else nil)
			elseif which == "ending" or which == "credits" then
				require(script.Parent:FindFirstChild("Ending") :: ModuleScript).preview(if which == "credits" then "credits" else nil)
			end
		end)
	end)
	workspace:GetAttributeChangedSignal("FilmSheetShow"):Connect(function()
		if workspace:GetAttribute("FilmSheetShow") ~= nil then
			showSheet()
		end
	end)
	UserInputService.InputBegan:Connect(function(input: InputObject)
		if not sheet then
			return
		end
		if input.KeyCode == Enum.KeyCode.Right then
			page += 1
			draw()
		elseif input.KeyCode == Enum.KeyCode.Left then
			page -= 1
			draw()
		elseif input.KeyCode == Enum.KeyCode.Escape then
			closeSheet()
		end
	end)
end

-- (for the DEV panel or a test: show the sheet of the last film now)
FilmSheet.show = showSheet

return FilmSheet
