local FlipCard = import "FlipCard"

local text = {
  "You are invited!",
  "To a Playdate playdate <3"
}

local font_paths = {
  [playdate.graphics.font.kVariantNormal] = "Outline_24x32"
}

playdate.display.setRefreshRate(30)

local numbertext = { '1', '2', '3', '4', '5' }
local hellotext = { 'H', 'E', 'L', 'L', 'O' }

local flipCards = {
  FlipCard.new({ '1', 'H' }, false, 10, 10, 80, 105, font_paths, false, 1),
  FlipCard.new({ '2', 'E' }, false, 100, 10, 80, 105, font_paths, false, 1),
  FlipCard.new({ '3', 'L' }, false, 190, 10, 80, 105, font_paths, false, 1),
  FlipCard.new({ '4', 'L' }, false, 55, 125, 80, 105, font_paths, false, 1),
  FlipCard.new({ '5', 'O' }, false, 145, 125, 80, 105, font_paths, false, 1)
}

for i = 1, #flipCards do
  flipCards[i]:init()
end


local selected = 1

function playdate.update()
  playdate.graphics.clear()
  playdate.timer.updateTimers()
  for i = 1, #flipCards do
    flipCards[i]:draw()
  end
end

function playdate.AButtonUp()
  flipCards[selected]:AButtonUp()
end

function playdate.BButtonUp()
  flipCards[selected]:BButtonUp()
end

function playdate.cranked()
  flipCards[selected]:cranked()
end
