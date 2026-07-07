-- video-timeline.yazi

local M = {}

local SCRIPT = os.getenv("HOME") .. "/.config/yazi/plugins/video-timeline.yazi/preview.sh"

-- Tuning knobs
-- The real frame count lives in preview.sh's cache (it varies per video);
-- the offset here just counts up and preview.sh wraps it with modulo.
local SLICE = 100000        -- effectively unbounded
local TICK_SECONDS = 0.05   -- playback clock; effective rate ~10-12fps after overhead
local READ_TIMEOUT_MS = 500 -- child read timeout
local META_COLS = 26        -- metadata sidebar width when placed beside the image
local META_LINES = 6        -- metadata height when placed below the image (narrow panes)

-- --- helpers ---------------------------------------------------------------

local function normalize_offset(skip)
	-- convert any numeric skip into 0..SLICE-1
	local o = tonumber(skip) or 0
	if o < 0 then o = 0 end
	return o % SLICE
end

local function strip_ansi(s)
	s = s:gsub("\27%[[%;%d]*m", "")
	s = s:gsub("\27%[[%;%d]*K", "")
	s = s:gsub("\27%[[%;%d]*%G", "")
	return s
end

local function centered_msg_rect(area, msg_len)
	return ui.Rect({
		x = area.x + math.floor(area.w / 2) - math.floor(msg_len / 2),
		y = area.y + math.floor(area.h / 2),
		w = area.w,
		h = 1,
	})
end

local function show_status(job, area, msg)
	local r = centered_msg_rect(area, #msg)
	ya.preview_widget(job, { ui.Text(msg):area(r) })
end

local function spawn_preview(path, offset, area)
	-- preview.sh supports extra args; it can ignore them.
	local args = {
		"--path", path,
		"--offset", tostring(offset),
		"--topw", tostring(area.w),
		"--toph", tostring(area.h),
	}

	return Command(SCRIPT)
		:arg(args)
		:stdout(Command.PIPED)
		:stderr(Command.PIPED)
		:spawn()
end

local function parse_image_marker(line)
	-- Expected: "__preview__image__path__ /some/path\n"
	if not line:match("^__preview__image__path__") then
		return nil
	end
	return line:match("^__preview__image__path__ (.+)\n")
end

local function should_keep_text(line)
	if line:len() <= 1 then return false end
	if line:match("^__") then return false end
	return true
end

local function read_child_output(job, child, area)
	-- Image is shown against the FULL pane area (not pre-shrunk for text),
	-- so a portrait video can use the pane's entire height. Metadata gets
	-- placed afterwards, beside or below the image (see meta_area_for).
	local meta, errs = {}, {}
	local shown = nil -- actual area the image was drawn in

	while true do
		local line, event = child:read_line_with({ timeout = READ_TIMEOUT_MS })

		if event == 3 then
			-- timeout
			show_status(job, area, "Loading...")
		elseif event == 2 then
			-- EOF
			break
		elseif event == 1 then
			-- stderr
			table.insert(errs, strip_ansi(line))
		elseif event == 0 then
			-- stdout
			local img = parse_image_marker(line)
			if img then
				shown = ya.image_show(Url(img), area)
			else
				if should_keep_text(line) and #meta < 20 then
					table.insert(meta, strip_ansi(line))
				end
			end
		end
	end

	child:start_kill()
	return errs, meta, shown
end

-- Place the metadata text beside the image when there's enough leftover
-- width (common for portrait 9:16 videos, which are height-bound and leave
-- spare columns), otherwise stack it below (narrow panes / wide images).
local function meta_area_for(area, shown)
	if not shown then
		return ui.Rect({
			x = area.x,
			y = area.y + math.max(0, area.h - META_LINES),
			w = area.w,
			h = math.min(META_LINES, area.h),
		})
	end

	local right_gap = area.x + area.w - (shown.x + shown.w)
	if right_gap >= META_COLS + 1 then
		local mx = shown.x + shown.w + 1
		return ui.Rect({ x = mx, y = area.y, w = area.x + area.w - mx, h = area.h })
	end

	local ty = shown.y + shown.h + 1
	local th = area.y + area.h - ty
	if th <= 0 then
		ty = area.y + math.max(0, area.h - META_LINES)
		th = math.min(META_LINES, area.h)
	end
	return ui.Rect({ x = area.x, y = ty, w = area.w, h = th })
end

local function render_text(job, area, errs, meta)
	local out = table.concat(errs, "") .. table.concat(meta, "")
	ya.preview_widget(job, { ui.Text(out):area(area) })
end

local function schedule_next(file_url, offset)
	ya.sleep(TICK_SECONDS)
	ya.emit("peek", {
		tostring((offset + 1) % SLICE),
		only_if = file_url,
	})
end

-- --- yazi hooks ------------------------------------------------------------

function M:peek(job)
	local file = job.file
	local area = job.area

	local offset = normalize_offset(job.skip)
	local file_url = tostring(file.url)

	local child = spawn_preview(file_url, offset, area)
	if not child then
		render_text(job, area, {}, { "Failed to start preview script\n" })
		return
	end

	local errs, meta, shown = read_child_output(job, child, area)

	render_text(job, meta_area_for(area, shown), errs, meta)

	schedule_next(file_url, offset)
end

function M:seek(job)
	-- Scrub-like behavior: only re-peek if the same file is still hovered.
	local h = cx.active.current.hovered
	if not (h and h.url == job.file.url) then
		return
	end

	local next_skip = (tonumber(job.skip) or 0) + (tonumber(job.units) or 0)
	if next_skip < 0 then next_skip = 0 end

	ya.emit("peek", {
		tostring(next_skip),
		only_if = tostring(job.file.url),
	})
end

return M
