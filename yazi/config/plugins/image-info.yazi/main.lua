-- image-info.yazi: show the image with labeled metadata below,
-- matching the video-timeline preview style.

local M = {}

local META_COLS = 26 -- metadata sidebar width when placed beside the image
local META_LINES = 5 -- metadata height when placed below the image (narrow panes)

local function gcd(a, b)
	while b > 0 do
		a, b = b, a % b
	end
	return a
end

local COMMON =
	{ { 16, 9 }, { 9, 16 }, { 4, 3 }, { 3, 4 }, { 3, 2 }, { 2, 3 }, { 5, 4 }, { 4, 5 }, { 1, 1 }, { 21, 9 }, { 9, 21 } }

local function ratio_str(w, h)
	if not w or not h or w <= 0 or h <= 0 then
		return ""
	end
	local g = gcd(w, h)
	local rw, rh = w / g, h / g
	if rw <= 21 and rh <= 21 then
		return string.format("%d:%d", rw, rh)
	end
	for _, c in ipairs(COMMON) do
		local q = (w / h) / (c[1] / c[2])
		if q > 0.985 and q < 1.015 then
			return string.format("≈%d:%d", c[1], c[2])
		end
	end
	return string.format("%.2f:1", w / h)
end

local function human_size(n)
	if not n then
		return "?"
	end
	if n >= 1048576 then
		return string.format("%.1f MiB", n / 1048576)
	end
	if n >= 1024 then
		return string.format("%.0f KiB", n / 1024)
	end
	return string.format("%d B", n)
end

local FORMAT_NAMES = { mjpeg = "jpeg" }

local function probe(path)
	local child = Command("ffprobe")
		:arg({
			"-v", "error",
			"-select_streams", "v:0",
			"-show_entries", "stream=codec_name,width,height",
			"-of", "csv=p=0",
			"--", path,
		})
		:stdout(Command.PIPED)
		:stderr(Command.PIPED)
		:spawn()
	if not child then
		return nil
	end
	local output = child:wait_with_output()
	if not output or not output.status.success then
		return nil
	end
	local codec, w, h = output.stdout:match("([^,]+),(%d+),(%d+)")
	return codec, tonumber(w), tonumber(h)
end

-- Place the metadata text beside the image when there's enough leftover
-- width (common for portrait photos, which are height-bound and leave
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

function M:peek(job)
	local area = job.area

	-- Show against the FULL pane area so a portrait image can use the
	-- pane's entire height; metadata is placed afterwards (see meta_area_for).
	local shown = ya.image_show(job.file.url, area)

	local codec, w, h = probe(tostring(job.file.url))

	local lines = {}
	if w and h then
		lines[#lines + 1] = string.format("分辨率  %dx%d (%s)", w, h, ratio_str(w, h))
	end
	if codec then
		lines[#lines + 1] = string.format("格式    %s", FORMAT_NAMES[codec] or codec)
	end
	lines[#lines + 1] = string.format("大小    %s", human_size(job.file.cha and job.file.cha.len or nil))

	ya.preview_widget(job, { ui.Text(table.concat(lines, "\n")):area(meta_area_for(area, shown)) })
end

function M:seek() end

return M
