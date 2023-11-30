import 'CoreLibs/timer'
import 'CoreLibs/easing'
import 'CoreLibs/graphics'

local pd <const>   = playdate
local gfx <const>  = pd.graphics
local geom <const> = pd.geometry
local tmr <const>  = pd.timer

local utils        = import 'utils'


-- ENUMS
--------------------------------------------------------------
local front                  = 1
local back                   = 2
local flipping               = 3
local laying                 = 4
local states                 = { 'front', 'back', 'flipping', 'laying' }

local bottom_or_left_edge_up = 1
local top_or_right_edge_up   = 2

local flip_up_right          = 1
local flip_down_left         = 2
local flip_infinite          = 3


local FlipCard   = {}
FlipCard.__index = FlipCard

function FlipCard.new(text_strings, _rounded, _x, _y, _width, _height, _font_paths, _flip_horizontal, _flip_mode)
  local fc = {}

  fc.x = _x or 10
  fc.y = _y or 10
  fc.width = _width or 380
  fc.height = _height or 220
  fc.center = geom.point.new(fc.x + fc.width / 2, fc.y + fc.height / 2)

  local margin_x = fc.width / 15
  local margin_y = fc.height / 20
  fc.margin = geom.rect.new(fc.x + margin_x, fc.y + margin_y, fc.width - (fc.x + margin_x), fc.height - (fc.y + margin_y))

  fc.state = front
  fc.flip_mode = _flip_mode or flip_up_right
  fc.flipping_direction = fc.flip_mode == flip_infinite and flip_up_right or fc.flip_mode
  fc.side_up = front
  fc.flip_infinite_sensitivity = 12

  fc.text_strings = text_strings
  fc.text_samples = {}
  fc.text_dimensions = {}
  fc.font_paths = _font_paths

  fc.rounded = _rounded or false
  fc.flip_horizontal = _flip_horizontal or false
  fc.selected = true

  fc.crank_change = 0
  fc.crank_angle = 0
  fc.crank_callback = nil
  fc.crank_inactive_timer = nil
  fc.lay_flat_timer = nil
  fc.animate_flip_timer = nil

  -- card_model sits with it's center on 0,0 and is used to calculate transforms
  local rect = geom.rect.new(-fc.width / 2, -fc.height / 2, fc.width, fc.height)
  if fc.rounded then
    fc.card_model = gfx.drawRoundRect(rect, 8)
  else
    fc.card_model = rect:toPolygon()
  end

  fc.card_offset = geom.point.new(
    fc.x - fc.card_model:getPointAt(1).x,
    fc.y - fc.card_model:getPointAt(1).y
  )

  if fc.font_paths ~= nil then
    gfx.setFontFamily(gfx.font.newFamily(fc.font_paths))
  end
  gfx.setImageDrawMode(gfx.kDrawModeNXOR)
  gfx.setLineWidth(4)

  return setmetatable(fc, FlipCard)
end

function FlipCard:init()
  self.crank_inactive_timer = tmr.new(1200, function()
    self:lay_flat()
  end)
  self.crank_inactive_timer.discardOnCompletion = false
  self.crank_inactive_timer:pause()
  self:sample_card_text()
end

-- TODO: do this with playdate.graphics.imageWithText
function FlipCard:sample_card_text()
  gfx.setColor(gfx.kColorBlack)
  for i = 1, 2 do
    local text = self.text_strings[i]

    local w, h = gfx.getTextSize(text)

    local x = self.center.x - (w / 2)
    local y = self.center.y - (h / 2)

    local a, b, c = gfx.drawText(text, x, y)
    -- local w, h, was_truncated = gfx.drawTextInRect(text, self.margin, nil, '-', kTextAlignment.center)
    self.text_samples[i] = gfx.getWorkingImage()
    gfx.clear()
  end
end

function FlipCard:set_selected(is_selected)
  self.selected = is_selected
end

function FlipCard:set_state(state)
  self.state = state
end

function FlipCard:switch_side()
  self.side_up = self.side_up % 2 + 1
end

function FlipCard:draw()
  if self.state == front or self.state == back then
    local p = self.card_model:copy()
    self:draw_card_frame()
    self:draw_card_text()
  end
end

function FlipCard:draw_card_text(_scale, _side_up)
  local side_up = _side_up or self.side_up
  local scale = _scale or 1

  -- print(self.text_samples[side_up]:getSize())

  -- self.text_samples[side_up]:draw(0, 0)

  -- dont draw text when the card is very oblique
  if scale < 0.1 then
    return
  end

  if self.horizontal then
    local x = pd.display.getWidth() * (1 - scale) / 4
    local y = 1
    self.text_samples[side_up]:drawScaled(x, y, scale, 1)
  else
    local x = 1
    local y = pd.display.getHeight() * (1 - scale) / 4
    self.text_samples[side_up]:drawScaled(x, y, 1, scale)
  end
  -- if self.horizontal then
  --   self.text_samples[side_up]:drawRotated(x, y, 0, scale, 1)
  -- else
  --   self.text_samples[side_up]:drawRotated(x, y, 0, 1, scale)
  -- end
end

function FlipCard:draw_card_frame(_progress, _reverse)
  local progress = _progress or 1
  -- first create a transformed (scaled) copy of card_model
  local transform = geom.affineTransform.new()
  transform = self.horizontal and transform:scaledBy(progress, 1) or transform:scaledBy(1, progress)
  local p = transform:transformedPolygon(self.card_model)

  local nw = p:getPointAt(1)
  local ne = p:getPointAt(2)
  local se = p:getPointAt(3)
  local sw = p:getPointAt(4)

  print(nw, ne, se, sw)
  -- then widen or thin opposite ends of the new frame based on flipping direction
  local perspective_effect = 4 * (1 - progress)
  local bottom_growing
  if not self.hasReversed or _reverse then
    bottom_growing = self.flipping_direction == bottom_or_left_edge_up
  else
    bottom_growing = self.flipping_direction == top_or_right_edge_up
  end

  if self.flip_mode == top_or_right_edge_up then
    bottom_growing = not bottom_growing
  end

  if bottom_growing then
    p:setPointAt(1, nw.x + perspective_effect, nw.y)
    p:setPointAt(2, ne.x - perspective_effect, ne.y)
    p:setPointAt(3, se.x + perspective_effect, se.y)
    p:setPointAt(4, sw.x - perspective_effect, sw.y)
  else
    p:setPointAt(1, nw.x + perspective_effect, se.y)
    p:setPointAt(2, ne.x - perspective_effect, sw.y)
    p:setPointAt(3, se.x + perspective_effect, nw.y)
    p:setPointAt(4, sw.x - perspective_effect, ne.y)
  end

  -- then we place our new frame into position
  p:translate(self.card_offset.x, self.card_offset.y)
  print(p)
  gfx.drawPolygon(p)
end

function FlipCard:AButtonUp()
  if self.state ~= flipping then
    self.flipping_direction = self.flip_mode == flip_infinite and flip_up_right or self.flip_mode
    if self.flip_mode == flip_infinite then
      self:animate_flip(false)
    elseif self.state == front then
      self:animate_flip(false)
    end
  end
end

function FlipCard:BButtonUp()
  if self.state ~= flipping then
    self.flipping_direction = self.flip_mode == flip_infinite and top_or_right_edge_up or (self.flip_mode % 2 + 1)
    if self.flip_mode == flip_infinite then
      self:animate_flip(false)
    elseif self.state == back then
      self:animate_flip(false)
    end
  end
end

function FlipCard:cranked()
  local event = self:track_crank_orientation()

  if self.crank_inactive_timer.paused then
    self.crank_inactive_timer:start()
  else
    self.crank_inactive_timer:reset()
    if self.lay_flat_timer then
      self.lay_flat_timer:remove()
    end
  end

  if self.state == flipping then
    local payload = {
      value = self:convert_crank_angle_to_scale()
    }
    -- deal with crank orientation events
    if event ~= nil then
      if event == 180 then
        self.hasReversed = self.flipping_direction == top_or_right_edge_up
        self:switch_side()
      elseif event == -180 then
        self.hasReversed = self.flipping_direction == bottom_or_left_edge_up
        self:switch_side()
      elseif event == 360 then
        -- if we are still cranking past the full turn then keep cranking baby
        if not (self.flip_mode == flip_infinite and self.crank_change < -self.flip_infinite_sensitivity) then
          self.crank_callback.timerEndedCallback()
          return
        end
      elseif event == -360 then
        -- if we do a full turn should we end flipping state and kill the callback?
        -- if we are still cranking past the full turn then keep cranking baby
        if not (self.flip_mode == flip_infinite and self.crank_change > self.flip_infinite_sensitivity) then
          self.crank_callback.timerEndedCallback()
          return
        end
      end
    end
    -- TODO: change cranking to exponential movement, causing a fast flipping movement when the card is near vertical.
    local scale = pd.easingFunctions.inExpo(payload.value * 10, 1, -.99, 10)
    self.crank_callback.updateCallback(payload)
  else
    if self.crank_callback == nil then
      self.crank_callback = {}
    end

    -- if we have just passed 0 cranking forward
    if event == -360 then
      if self.flip_mode == flip_infinite or self.state == front then
        self.flipping_direction = bottom_or_left_edge_up
        self:animate_flip(true, self.crank_callback)
      end
      -- if we have just passed 0 cranking backward
    elseif event == 360 then
      if self.flip_mode == flip_infinite or self.state == back then
        self.flipping_direction = top_or_right_edge_up
        self:animate_flip(true, self.crank_callback)
      end
    end
  end
end

function FlipCard:convert_crank_angle_to_scale()
  local scale
  if self.crank_angle < 180 then
    scale = 1 - self.crank_angle / 180
  else
    scale = (self.crank_angle - 180) / 180
  end
  return scale
end

function FlipCard:animate_flip(is_cranked, crank_callback)
  self:set_state(flipping)
  self.animate_flip_timer = {}
  if not is_cranked then
    self.animate_flip_timer = tmr.new(1500, 1, 0.01, playdate.easingFunctions.inCubic)
    self.animate_flip_timer.reverses = true
    self.animate_flip_timer.reverseEasingFunction = playdate.easingFunctions.outCubic
  else
    self.animate_flip_timer = crank_callback
  end

  self.animate_flip_timer.updateCallback = function(ease_fn)
    if ease_fn.hasReversed and self.hasReversed == nil then
      self.hasReversed = true
      self:switch_side()
    end
    self:draw_card_frame(ease_fn.value)
    self:draw_card_text(ease_fn.value)
  end

  self.animate_flip_timer.timerEndedCallback = function(ease_fn)
    self.animate_flip_timer = nil
    self.hasReversed = nil
    self:set_state(self.side_up)
  end
end

function FlipCard:lay_flat()
  -- self.state = laying
  local start = self:convert_crank_angle_to_scale()

  if start > 0.85 then
    self.lay_flat_timer = tmr.new((1 - start) * 1000, start, 1, pd.easingFunctions.outSine)
  else
    self.lay_flat_timer = tmr.new(1500, start, 1, pd.easingFunctions.outElastic)
    -- self.lay_flat_timer = tmr.new(1500, start, 1, ease_fn)
    self.lay_flat_timer.easingAmplitude = (1 - start) * 0.1
  end

  self.lay_flat_timer.updateCallback = function(ease_fn)
    -- if the value gets higher than 1 we don't to scale back from 1 (the edge of the card overshooting the flat position)
    if ease_fn.value > 1 then
      local v = 2 - ease_fn.value
      self:draw_card_frame(v, true)
      self:draw_card_text(v)
    else
      self:draw_card_frame(ease_fn.value)
      self:draw_card_text(ease_fn.value)
    end
  end
  self.lay_flat_timer.timerEndedCallback = function(ease_fn)
    self:set_state(self.side_up)
  end
end

function FlipCard:track_crank_orientation(hasReversed)
  self.crank_change = playdate.getCrankChange()
  if self.crank_change == 0 then
    return
  end

  local event
  local anglePlus360 = utils.normalizeAngle(self.crank_angle) + 360

  if self.crank_angle < 180 and self.crank_angle + self.crank_change > 180 then
    event = 180
  elseif self.crank_angle > 180 and self.crank_angle + self.crank_change < 180 then
    event = -180
  elseif self.crank_angle <= 360 and self.crank_angle + self.crank_change > 360 then
    event = -360
  elseif self.crank_angle >= 0 and self.crank_angle + self.crank_change < 0 then
    event = 360
  end

  self.crank_angle += self.crank_change
  self.crank_angle = utils.normalizeAngle(self.crank_angle)

  return event
end

return FlipCard
