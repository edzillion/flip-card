local Utils = {}

Utils.normalizeAngle = function(a)
  if a >= 360 then a = a - 360 end
  if a < 0 then a = a + 360 end
  return a
end

return Utils
