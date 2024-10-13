---@diagnostic disable: undefined-global, undefined-field, missing-parameter, need-check-nil, missing-return, param-type-mismatch, lowercase-global, redundant-value, cast-local-type,duplicate-set-field
--made by tuttertep
--i'm already sorry if you read this because everything below is a disaster 😭

ui.setAsynchronousImagesLoading(true)

local default_colors = stringify{
  you = {
    color = rgbm(0,0.5,0,0.9),
    size = 1,
  },
  friend = {
    color = rgbm(0,0.8,1,0.9),
    size = 1,
  },
  player = {
    color = rgbm(0.5,0,0,0.9),
    size = 1,
  },
  teleport_available = {
    color = rgbm(1,0.5,0.5,1),
    size = 1,
  },
  teleport_unavailable = {
    color = rgbm(0.8,0,0,1),
    size = 1,
  },
  map = {
    color = rgbm(1,1,1,1),
    --size = 1,
  },
  turn_signals = {
    color = rgbm(0,1,0,1),
    size = 0.8,
  },
}

local defaults = {
  centered = false,
  centered_zoom = 0.5,
  centered_offset = 0,
  rotation = true,
  teleporting = true,
  teleporting_mouseover = true,
  new_teleports = true,
  new_render = false,
  teleport_warning = true,
  friends = true,
  namesx = 0,
  namesy = 10,
  names = true,
  names_length = 6,
  names_smol = true,
  names_mouseover = true,
  names_smol_mouseover = false,
  names_spectate = true,
  ownname = false,
  markers = default_colors,
  arrowsize = 13,
  arrowsize_smol = 10,
  arrow_scaling = true,
  turn_signals = true,
  turn_signals_smol = true,
  tags = false,
  main_map_mouseover = false,
  traffic_warnings = true
}
local settings = ac.storage(defaults)

local markers = {}


local function loadMarkers()
    markers = stringify.parse(settings.markers)
    if markers.you==nil then
      markers = stringify.parse(default_colors)
    end
end

local function saveMarkers(m)
  settings.markers = stringify(m)
  loadCars()
end

owncar, focusedCar, sim, uiState  = ac.getCar(0), ac.getCar(0), ac.getSim(), ac.getUI()
local first = true
local app_folder = ac.getFolder(ac.FolderID.ACApps) .. '/lua/comfy_map/'
local version = ac.getPatchVersionCode()
local collected_teleports = {}

local iconpos, iconsize = vec2(), vec2(5, 5)

local vec = {x=vec3(1,0,0),y=vec3(0,1,0),z=vec3(0,0,1),empty=vec3(),empty2=vec2()}
local pos3, dir3, pos2, dir2, dir2x = vec3(), vec3(), vec2(), vec2(), vec2()
local padding = vec2(0, 22)
local outline = rgbm()
local config = {}
local asd1 = nil
local hoveringTeleport = false


local pink = rgbm(1,175/255,1,1)
local function getPlayerColor(i)
  if i==asd1 then
    if ac.setDriverChatNameColor then ac.setDriverChatNameColor(i,pink) end
    return pink,markers.friend.size
  end
  if i == focusedCar.index then return markers.you.color, markers.you.size end
  if settings.friends and ac.isTaggedAsFriend and ac.isTaggedAsFriend(ac.getDriverName(i)) then
    return markers.friend.color, markers.friend.size
  end
  if settings.tags and ac.DriverTags then
    local tags = ac.DriverTags(ac.getDriverName(i))
    if tags.color~=rgbm.colors.white then return tags.color, markers.friend.size end
  end
  return markers.player.color,markers.player.size
end

local function check(i)
  if i==0 or not ac.getCar(i).isConnected then return end
  if ac.DriverTags and ac.DriverTags(ac.getDriverName(i)).color==pink then ac.setDriverChatNameColor(i,nil) end
  if ac.checksumSHA256(ac.getDriverName(i) .. ac.getDriverNationCode(i)) == "dcc7421f81208ff7bcb728822f4c32426aafb9225b7d5a69529eac6c7dfe75d8" then
  --if ac.checksumSHA256(ac.getDriverName(i)) == 'ba4d55af89c1384bfda49eceb29cd73cec50d005008fde79f5e248ba77c71bf5' then
    asd1 = i
  end
end

local function shouldDrawCar(index)
  local car = ac.getCar(index)
  return ((not sim.isReplayOnlyMode) and car.isConnected and (not car.isHidingLabels)) or (sim.isReplayActive and car.isActive)
end


local safetyRatingApi = ac.StructItem.struct and ac.connect({
  ac.StructItem.key("AS_SafetyRating"),
  loaded = ac.StructItem.boolean(),
  ratings = ac.StructItem.array(ac.StructItem.struct({
      rating = ac.StructItem.float(),
      color = ac.StructItem.rgb(),
      rank = ac.StructItem.array(ac.StructItem.char(), 10)
  }), sim.carsCount)
}, true, ac.SharedNamespace.Shared)

local function isTagged(i)
  local name = ac.getDriverName(i)
  if ac.DriverTags then return ac.DriverTags(name).color~=rgbm.colors.white end
  return ac.isTaggedAsFriend and ac.isTaggedAsFriend(name)
end

local cars = {}
local function loadCars()
  cars = {}
  traffic = {}
  asd1 = nil
  for i=0, sim.carsCount-1 do
    check(i)
    if ac.getCar(i).isHidingLabels or (sim.isReplayOnlyMode and ac.getDriverName(i):find('Traffic')) then
      table.insert(traffic,{index = i,name = "",pos2=vec2()})
    else
      table.insert(cars,{index = i,name = "",pos2=vec2()})
    end
  end
  table.sort(cars, function (a,b)
    if a.index*b.index==0 then return b.index==0 end
    if isTagged(a.index) then return false end
    if isTagged(b.index) then return true end
  end)
end

local comfyMainWindow,comfySmolWindow
if ac.accessAppWindow then
  comfyMainWindow = ac.accessAppWindow('IMGUI_LUA_comfy map_main')
  comfySmolWindow = ac.accessAppWindow('IMGUI_LUA_comfy map_smol_map')
  --for i,j in pairs(ac.getAppWindows()) do print(j.name) end --debug
end
local function vec2Inside(point,square) return point.x>-5 and point.y>-5 and point.x<square.x and point.y<square.y end

function script.onShowWindow() --reset window positions
  local screenSize = uiState.windowSize
  if ac.accessAppWindow and not vec2Inside(comfyMainWindow:position(),screenSize) then
    print('main map outside screen' .. ' pos:' .. stringify(comfyMainWindow:position())) comfyMainWindow:move(vec2(10,10))
  end
  if ac.accessAppWindow and not vec2Inside(comfySmolWindow:position(),screenSize) then
    print('smol map outside screen' .. ' pos:' .. stringify(comfySmolWindow:position())) comfySmolWindow:move(vec2(10,10))
  end
end

local warning_timer = 0
local function drawTraffic(map)
  local add_warning = false
  for i=1, #traffic do
    local car = ac.getCar(traffic[i].index)
    if car.isActive and car.speedKmh<50 then
      add_warning = true
      if warning_timer>100 then
        pos3:set(car.position)
        if map.centered and map.rotation then
          pos3 = rotation:transformPoint(car.position - focusedCar.position) + focusedCar.position
        end
        pos2:set(pos3.x, pos3.z):add(config.OFFSETS):scale(map.config_scale):add(-map.offsets)
        ui.beginOutline()
        ui.drawIcon(ui.Icons.Warning,pos2-iconsize*2,pos2+iconsize*2,rgbm.colors.orange)
        ui.endOutline(rgbm.colors.black)
      end
    end
  end
  warning_timer = add_warning and (warning_timer + 1) or 0
end

local manifest = ac.INIConfig.load(app_folder .. '/manifest.ini',ac.INIFormat.Extended)
local app_version = manifest:get('ABOUT','VERSION',0.001)

local function comfyUpdate(branch)
  if branch~='dev' and branch~='main' then return end
  local url = 'https://github.com/Tuttertep/comfy_map/archive/refs/heads/' .. branch .. '.zip'
  web.get(url, function (err, response)
    if err then error(err) end
    local manifest = io.loadFromZip(response.body, 'comfy_map-' .. branch .. '/manifest.ini')
    if not manifest then return print('missing manifest') end

    local version = ac.INIConfig.parse(manifest, ac.INIFormat.Extended):get('ABOUT', 'VERSION', 0)
    if app_version >= version then return print('newer version installed: ' .. app_version .. '>=' .. version) end

    for _, file in ipairs(io.scanZip(response.body)) do
      local content = io.loadFromZip(response.body, file)
      if content then
        if io.save(app_folder .. file:match("/(.*)"), content) then ac.console(file) end
      end
    end
  end)
end

local function coloredButton(name,color,size,tooltip)
  if type(color)=="string" then tooltip = color color = nil end
  if type(size)=="string" then tooltip = size size = nil end
  if color then ui.pushStyleColor(ui.StyleColor.Button, color) end
  local button = ui.button(name,size or vec2())
  if tooltip and ui.itemHovered() then ui.setTooltip(tooltip) end
  if color then ui.popStyleColor() end
  return button
end

local function ccheckbox(name,setting,color,tooltip)
  if type(color)=="string" then tooltip = color color = nil end
  if ui.checkbox(name, settings[setting]) then settings[setting] = not settings[setting] end
  if tooltip and ui.itemHovered() then ui.setTooltip(tooltip) end
end

local function getMapImages()
  local folder = ac.getFolder(ac.FolderID.ContentTracks) .. '/' .. ac.getTrackFullID('/')
  return io.scanDir(folder,'*.png')
end

local function updateCanvas(map)
  if map.scale <=0 then map.scale = settings.centered_zoom end
  if not settings.new_render then return end
  map.canvas:dispose()
  map.canvas = ui.ExtraCanvas(map.image_size*math.clamp(map.scale,0.01,1))
  map.canvas:update(function (dt)
    ui.image(map.image,map.canvas:size())
  end)
end

local function resetScale(map)
  local zoomed = map.centered and map.rotation
  local extra_space = ui.windowSize()*0.01
  map.offsets = -padding - extra_space
  map.image_size = ui.imageSize(map.image) or vec2(config.WIDTH,config.HEIGHT)
  local windowSize = ui.windowSize()-padding-extra_space*2
  map.scale = math.min(windowSize.x / map.image_size.x, windowSize.y / map.image_size.y)
  if zoomed then map.scale = settings.centered_zoom end
  map.size = map.image_size * map.scale
  map.config_scale = map.scale / config.SCALE_FACTOR
  updateCanvas(map)
end

function string:len_utf8()
  local len = 0
  local pos = 1
  while pos <= #self do
      if not (self:byte(pos) >= 128 and self:byte(pos) <= 191) then
          len = len + 1
      end
      pos = pos + 1
  end
  return len
end

function string:clamp_utf8(j)
  local length = 0
  local i = 1
  while i <= #self do
      local byte = self:byte(i)
      local charLength = 1
      if byte < 192 then
        charLength = 1
      elseif byte < 224 then
        charLength = 2
      elseif byte < 240 then
        charLength = 3
      else
        charLength = 4
      end
      if length >= j then
          return self:sub(1, i - 1)
      end
      length = length + 1
      i = i + charLength
  end
  return self
end

local function clampName(i)
  local name = ac.getDriverName(i)
  if settings.names_length<1 or name:len_utf8()<=settings.names_length then return name end
  return name:gsub("[-|(){} ]",''):clamp_utf8(settings.names_length)
end

local function safetyRating(carIndex)
  local ratingV5 = safetyRatingApi and __util.ffistrsafe(safetyRatingApi.ratings[carIndex].rank,10)
  if ratingV5 and ratingV5 ~='' then return ratingV5 end
  return nil
end

local function drawName(car)
  if #car.name==0 then car.name = clampName(car.index) end
  if car.index==sim.focusedCar and not settings.ownname then return end
  ui.pushFont(ui.Font.Small)
  ui.setCursor(car.pos2 + namepos - ui.measureText(car.name) * 0.5)
  --ui.drawLine(car.pos2, car.pos2 + namepos , car.color, 2)
  ui.beginOutline()
  ui.text(car.name)
  if ui.itemHovered() then
    ui.setTooltip(ac.getDriverName(car.index)
       .. '\n' .. ac.getCarID(car.index)
       .. '\n' .. math.round(ac.getCar(car.index).speedKmh,-1) .. ' km/h'
       .. (safetyRating(car.index) and ('\nsafety rating: ' .. safetyRating(car.index)) or '')
    )
  end
  ui.endOutline(outline:set(rgbm.colors.black, markers.map.color.mult),  markers.map.color.mult^2)
  ui.popFont()
  if ui.itemClicked(1) and not hoveringTeleport and settings.names_spectate then ac.focusCar(car.index) end
end

local function drawArrow(car,color,signals)
  ui.beginOutline()
  ui.drawTriangleFilled(pos2 + dir2, --up
    pos2 - dir2 - dir2x * 0.75, --right
    pos2 - dir2 + dir2x * 0.75, --left
  color)
  if version>2051 and signals then
    if car.turningLightsActivePhase then
      dir2:scale(markers.turn_signals.size)
      dir2x:scale(markers.turn_signals.size)
      if car.turningLeftLights then
        ui.drawTriangleFilled(
          pos2 + dir2*0.5 + dir2x * 0.75, --up
          pos2 - dir2*0.5 + dir2x * 0.75, --right
          pos2 + dir2x * 1.5, --left
          markers.turn_signals.color)
      end
      if car.turningRightLights then
        ui.drawTriangleFilled(
          pos2 + dir2*0.5 - dir2x * 0.75, --up
          pos2 - dir2*0.5 - dir2x * 0.75, --right
          pos2 - dir2x * 1.5, --left
          markers.turn_signals.color)
      end
    end
  end
  ui.endOutline(outline:set(rgbm.colors.black, markers.map.color.mult),  markers.map.color.mult^2)
end

local function newMap(file,is_main)
  local map = {
    image = file,
    image_size = ui.imageSize(file),
    canvas = ui.ExtraCanvas(1),
  }
  if is_main then
    setmetatable(map,{
      __index = function(tbl, key)
          if key == "rotation" then return settings.rotation end
          if key == "centered" then return settings.centered end
          return rawget(tbl, key)
      end,
    })
  else
    map.rotation = true
    map.centered = true
  end
  return map
end

local function checkTeleportAvailability(teleport)
  for i=0, sim.carsCount-1 do
    if shouldDrawCar(i) and ac.getCar(i).position:distanceSquared(teleport.POS)<(6^2) then
      return ac.getCar(i):driverName()
    end
  end
end

local function teleportAsText(i,name,group,pos,heading)
  group = group and ('POINT_' .. i .. '_GROUP= ' .. group .. '\n') or ''
  return 'POINT_' .. i .. '= ' .. name .. (name=='name' and (i-1) or '') .. '\n'
      .. 'POINT_' .. i .. '_POS= ' .. math.round(pos.x,1) .. ',' .. math.round(pos.y,1) .. ',' .. math.round(pos.z,1) .. '\n'
      .. 'POINT_' .. i .. '_HEADING= ' .. heading .. '\n'
      .. group
end

local function dir3FromHeading(heading)
    local h = math.rad(heading + ac.getCompassAngle(vec.z))
    return vec3(math.sin(h), 0, math.cos(h))
end

local function headingFromDir3(dir)
    return math.round(-ac.getCompassAngle(dir))
end

local function drawTeleport(j,index)
  local teleport_position = j.POS
  local teleport_name = (j.GROUP and (j.GROUP .. '/') or "") .. j.POINT
  if settings.centered and settings.rotation then teleport_position = (rotation:transformPoint(teleport_position - focusedCar.position) + focusedCar.position) end
  iconpos:set(teleport_position.x, teleport_position.z):add(config.OFFSETS):scale(main_map.config_scale):add(-main_map.offsets)
  local h = math.rad(j.HEADING + ac.getCompassAngle(vec.z) + (settings.centered and settings.rotation and rotationangle or 0))
  local size = iconsize
  local color = rgbm.colors.fuchsia

  if j.LOADED then
    color = rgbm.colors.purple
    if j.ONLINE then
      local marker = ac.canTeleportToServerPoint(j.INDEX) and markers.teleport_available or markers.teleport_unavailable
      color = marker.color
      size = size * marker.size
      local distance = (owncar.position:distance(j.POS) < 6)
      if distance then
        color = rgbm.colors.gray
        if owncar.speedKmh<20 and settings.teleport_warning then
          ac.setSystemMessage('please move from teleport','you are blocking a teleport')
        end
      end
    end
  else teleport_name = teleport_name .. index end

  dir2:set(math.sin(h), math.cos(h))
  if settings.new_teleports then
    ui.beginOutline()
    ui.pathLineTo(iconpos + dir2*size.x*2)
    ui.pathArcTo(iconpos, size.x*0.7, -h, -h-math.pi, 5)
    ui.pathFillConvex(color)
    ui.endOutline(outline:set(rgbm.colors.black, markers.map.color.mult),  markers.map.color.mult^2*1.3)
  else
    ui.beginOutline()
    ui.drawCircleFilled(iconpos, size.x*0.8, color, 10)
    ui.drawLine(iconpos, iconpos + dir2 * size.x*2, color)
    ui.endOutline(outline:set(rgbm.colors.black, markers.map.color.mult),  markers.map.color.mult^2)
  end
  ui.setCursor(iconpos - size)
  ui.dummy(size * 2)
  if j.ONLINE then
    if ui.itemClicked(ui.MouseButton.Right) then
      local link_text = "(comfy map) Teleport to: " .. teleport_name
      local occupied = checkTeleportAvailability(j)
      if occupied then link_text = link_text .. ' (blocked by: @' .. occupied .. ')' end
      ac.sendChatMessage(link_text)
    end
    if ui.itemClicked(ui.MouseButton.Left) and ac.canTeleportToServerPoint(j.INDEX) then --if multiple point overlap, try to guess intended one
      if not calledTeleport then calledTeleport = j.INDEX end --this feature is peak gremlin
      local closest = {distance = 1000000, car = ac.getCar(0)}
      for k = 1, sim.carsCount - 1 do
        local car = ac.getCar(k)
        if shouldDrawCar(k) then
          local distance = car.position:distance(teleport_position)
          if distance < closest.distance then
            closest['car'] = car closest['distance']  = distance
          end
        end
      end
      local ang = math.abs((-closest.car.compass - j.HEADING + 180) % 360 - 180)
      if (math.abs(ang - calledTeleportAng)<20) then
        --calculate if teleport is furthest ahead of clicked
      elseif (ang < calledTeleportAng) then
        calledTeleport = j.INDEX
        calledTeleportAng = ang
      end
    end
  else
    if ui.itemClicked(ui.MouseButton.Left) then ac.setCurrentCamera(ac.CameraMode.Free) ac.setCameraPosition(j.POS) ac.setCameraDirection(dir3:set(dir2.x,0,dir2.y)) end
    if ui.itemClicked(ui.MouseButton.Right) then table.remove(collected_teleports, index) print(index) end
  end
  if ui.itemHovered() then ui.setTooltip(teleport_name) hoveringTeleport = true end
end

local function saveTeleports(collected_teleports)
  local collected_teleports_string = '[TELEPORT_DESTINATIONS]\n'
  for i,j in pairs(collected_teleports) do
    collected_teleports_string = collected_teleports_string .. teleportAsText(i-1,j.POINT,j.GROUP,j.POS,j.HEADING) .. '\n'
  end
  return collected_teleports_string
end

local function loadTeleports(ini,online)
  local teleports, sorted_teleports = {}, {}

  for a, b in ini:iterateValues('TELEPORT_DESTINATIONS', 'POINT') do
    local n = tonumber(b:match('%d+')) + 1

    if teleports[n] == nil then
      for i = #teleports, n do
        if teleports[i] == nil then teleports[i] = {} end
      end
    end

    local suffix = b:match('_(%a+)$')
    if suffix==nil then teleports[n]['POINT'] = ini:get('TELEPORT_DESTINATIONS', b, 'noname' .. n-1)
    elseif suffix == 'POS' then teleports[n]['POS'] = ini:get('TELEPORT_DESTINATIONS', b, vec3())
    elseif suffix == 'HEADING' then teleports[n]['HEADING'] = ini:get('TELEPORT_DESTINATIONS', b, 0)
    elseif suffix == 'GROUP' then teleports[n]['GROUP'] = ini:get('TELEPORT_DESTINATIONS', b, 'group')
    end
    teleports[n]["N"] = n
    teleports[n]['INDEX'] = 0
    teleports[n]['LOADED'] = true
    teleports[n]['ONLINE'] = online
  end

  for i = 1, #teleports do
    if teleports[i]["POINT"] ~= nil then
      teleports[i]['INDEX'] = #sorted_teleports
      if teleports[i].HEADING == nil then teleports[i]['HEADING'] = 0 end
      if teleports[i].POS == nil then teleports[i]['POS'] = vec.empty end
      table.insert(sorted_teleports,teleports[i])
    end
  end
  ac.debug('teleport point count', #sorted_teleports)
  return sorted_teleports
end

local function drawMap(map)
  if map.centered then --center on car and rotate
    map.offsets:set(focusedCar.position.x, focusedCar.position.z):add(config.OFFSETS):scale(map.scale / config.SCALE_FACTOR):add(-ui.windowSize()*centered_offset) --autocenter

    if map.rotation then
      rotationangle = 180 - math.deg(math.atan2(focusedCar.look.x, focusedCar.look.z))
      rotation = mat4x4.rotation(math.rad(rotationangle), vec.y)
      ui.beginRotation()
    end
  end

  ui.beginOutline()
  if settings.new_render then
    ui.drawImage(map.canvas, -map.offsets,  -map.offsets + map.size, markers.map.color) --map image
  else
    ui.drawImage(map.image, -map.offsets, -map.offsets + map.size, markers.map.color) --map image
  end
  ui.endOutline(outline:set(rgbm.colors.black, markers.map.color.mult),  markers.map.color.mult^2)


  if map.centered and map.rotation then ui.endPivotRotation(rotationangle + 90, ui.windowSize()*centered_offset) end

end

local function onShowWindow1() --somehow works?
  if not first then return end
  map_mini = ac.getFolder(ac.FolderID.ContentTracks) .. '\\' .. ac.getTrackFullID('\\') .. '\\map_mini.png'
  map = ac.getFolder(ac.FolderID.ContentTracks) .. '\\' .. ac.getTrackFullID('\\') .. '\\map.png'
  current_map = io.exists(map_mini) and map_mini or  map
  ui.text('map file loading or missing')
  if (not ui.isImageReady(map)) or (not ui.isImageReady(current_map)) then return end
  
  first = false
  ini = ac.getFolder(ac.FolderID.ContentTracks) .. '/' .. ac.getTrackFullID('/') .. '/data/map.ini'
  config = ac.INIConfig.load(ini):mapSection('PARAMETERS', { SCALE_FACTOR = 1, Z_OFFSET = 1, X_OFFSET = 1, WIDTH=500, HEIGHT=500, MARGIN=20, DRAWING_SIZE=10, MAX_SIZE=1000})
  config.OFFSETS = vec2(config.X_OFFSET, config.Z_OFFSET)
  centered_offset = vec2(0.5,0.5-settings.centered_offset)
  namepos = vec2(settings.namesx, settings.namesy)
  if sim.isOnlineRace and ac.INIConfig.onlineExtras then --teleport config
    teleports1 = loadTeleports(ac.INIConfig.onlineExtras(),true)
  end
  loadMarkers()
  loadCars()
  main_map = newMap(current_map, true)
  resetScale(main_map)

  smol_map = newMap(map)
  resetScale(smol_map)
end

ac.onClientConnected( function(i, j) -- reload cars when someone joins to sort friends
  if ac.setDriverChatNameColor then ac.setDriverChatNameColor(i,nil) end
  setTimeout(function () loadCars() end, 5) end)
setTimeout(loadCars, 5)

function script.windowMain(dt)
  if settings.main_map_mouseover and not ui.windowHovered(105) then return end
  if first then onShowWindow1() return end
  ui.pushClipRect(0, ui.windowSize()) --background
  ui.invisibleButton()

  if windowHovered then --zoom&drag&centering&reset
    if ui.mouseWheel()~=0 then
      if (ui.mouseWheel() < 0 and (main_map.size:lengthSquared()>ui.windowSize():lengthSquared()*0.97)) or ui.mouseWheel() > 0 then
        local old = main_map.size
        main_map.scale = main_map.scale * (1 + math.sign(ui.mouseWheel()) * 0.15)
        main_map.size = main_map.image_size * main_map.scale
        main_map.config_scale = main_map.scale / config.SCALE_FACTOR
        main_map.offsets = main_map.offsets + (main_map.size - old) * (main_map.offsets + ui.mouseLocalPos()) / old -- DON'T touch, powered by dark magic
        updateCanvas(main_map)
      else
        if not settings.centered then resetScale(main_map) end
      end
    end
    if ui.mouseClicked(2) then --toggle centering with middle click
      settings.centered = not settings.centered
      resetScale(main_map)
    end
  end

  focusedCar = ac.getCar(sim.focusedCar)

  drawMap(main_map)

  for i=1, #cars do
    local car = ac.getCar(cars[i].index)
    if shouldDrawCar(cars[i].index) then
      cars[i].color, cars[i].size = getPlayerColor(cars[i].index)
      pos3:set(car.position)
      dir3:set(car.look)
      if settings.centered and settings.rotation then
        pos3 = rotation:transformPoint(car.position - focusedCar.position) + focusedCar.position
        dir3 = rotation:transformPoint(car.look)
      end
      pos2:set(pos3.x, pos3.z):add(config.OFFSETS):scale(main_map.config_scale):add(-main_map.offsets)
      dir2:set(dir3.x, dir3.z):scale(settings.arrow_scaling and main_map.scale^0.3 or 1):scale(settings.arrowsize):scale(cars[i].size)
      dir2x:set(dir3.z, -dir3.x):scale(settings.arrow_scaling and main_map.scale^0.3 or 1):scale(settings.arrowsize):scale(cars[i].size)
      --for k=0,3 do ui.drawCircleFilled(vec2.tmp():set(owncar.wheels[k].position.x,owncar.wheels[k].position.z):add(config.OFFSETS):scale(config_scale):sub(offsets),5,rgbm.colors.red) end
      drawArrow(car,cars[i].color,settings.turn_signals)
      cars[i].pos2:set(pos2.x,pos2.y)

    end
  end

  if settings.traffic_warnings then drawTraffic(main_map) end

  for i=1, #cars do
    if shouldDrawCar(cars[i].index) then
      if settings.names and (not settings.names_mouseover or windowHovered) then drawName(cars[i]) end
    end
  end


  if settings.teleporting and (not settings.teleporting_mouseover or windowHovered) then --teleports
    hoveringTeleport = false
    calledTeleport = nil
    calledTeleportAng = 360

    for i,j in pairs(collected_teleports) do --teleport config helper points
      drawTeleport(j,i)
    end
    if sim.isOnlineRace and teleports1 then --online teleports
      for i,j in pairs(teleports1) do
        drawTeleport(j)
      end
      if calledTeleport~=nil then ac.teleportToServerPoint(calledTeleport) end
    end

  end


  if sim.cameraMode == ac.CameraMode.Free then
    pos3 = ac.getCameraPosition()
    dir3 = ac.getCameraForward()
    if settings.centered and settings.rotation then
      pos3 = rotation:transformPoint(pos3 - focusedCar.position) + focusedCar.position
      dir3 = rotation:transformPoint(dir3)
    end
    pos2:set(pos3.x, pos3.z):add(config.OFFSETS):scale(main_map.config_scale):sub(main_map.offsets)
    dir2:set(dir3.x, dir3.z):normalize():scale(settings.arrowsize):scale(settings.arrow_scaling and main_map.scale^0.3 or 1)
    dir2x:set(dir3.z, -dir3.x):normalize():scale(settings.arrowsize):scale(settings.arrow_scaling and main_map.scale^0.3 or 1)
    drawArrow(_,rgbm.colors.green)
  end

  if not (settings.centered and settings.rotation) and ui.keyPressed(ui.Key.Space) and ui.windowHovered() then --freecam teleport
    pos2:set(ui.mouseLocalPos()):add(main_map.offsets):scale(1/main_map.config_scale):sub(config.OFFSETS)

    allow = true
    local raycastheight = 3000
    pos3:set(pos2.x, raycastheight, pos2.y)
    local initialray = physics.raycastTrack(pos3,-vec.y,raycastheight*2)
    if initialray~=-1 and sim.cameraMode == ac.CameraMode.Free then --freecam stuff
      return ac.setCameraPosition(pos3-vec.y*(initialray-3))
    end

    local normalize3Dto2Dto3D = function (vector)
      local temp = vec2(vector.x,vector.z):normalize()
      return vec3(temp.x,0,temp.y)
    end
    local carside = normalize3Dto2Dto3D(owncar.side)
    local carlook = normalize3Dto2Dto3D(owncar.look)
    for i=1, 100 do
      local side = math.random(-owncar.aabbSize.x/2 +owncar.aabbCenter.x,owncar.aabbSize.x/2 +owncar.aabbCenter.x)
      local look = math.random(-owncar.aabbSize.z/2 +owncar.aabbCenter.z,owncar.aabbSize.z/2 +owncar.aabbCenter.z)
      local pos = pos3 + carlook*look + carside*side
      local raycastnormal = vec3()
      local raycast = physics.raycastTrack(pos, -vec.y, raycastheight*2, _, raycastnormal)
      if raycast == -1 or math.abs(raycast-initialray)>0.2 then allow = false
        ui.drawCircleFilled(vec2.tmp():set(pos.x, pos.z):add(config.OFFSETS):scale(main_map.config_scale):sub(main_map.offsets),5,rgbm.colors.red)
      end
    end
    pos3:set(pos2.x, raycastheight-initialray, pos2.y)

    if allow then
      if owncar.physicsAvailable then
        physics.setCarPosition(0,pos3,-owncar.look)
      end
      allow = false
    end
  end


  windowHovered = ui.windowHovered(105) or draggingMap
  if not settings.centered then --window movable while centered
    ui.setCursor() ui.invisibleButton('draggingbutton', ui.windowSize())
    draggingMap = ((ui.mouseDown() and ui.itemHovered()) or draggingMap) and ui.mouseDown()
    if draggingMap then main_map.offsets = main_map.offsets - ui.mouseDelta() end
  end

  ui.popClipRect()
end


function windowSmol(dt)
  if first then onShowWindow1() return end
  ui.invisibleButton()
  if ui.windowHovered() and ui.mouseWheel()~=0 then
    if (ui.mouseWheel() < 0 and (smol_map.size:lengthSquared()>ui.windowSize():lengthSquared()*0.97)) or ui.mouseWheel() > 0 then
      smol_map.scale = smol_map.scale * (1 + 0.1 * ui.mouseWheel())
      smol_map.size = smol_map.image_size*smol_map.scale
      smol_map.config_scale = smol_map.scale/config.SCALE_FACTOR
      updateCanvas(smol_map)
    end
  end
  focusedCar = ac.getCar(sim.focusedCar)

  drawMap(smol_map)

  for i=1, #cars do  --draw stuff on small map
    local car = ac.getCar(cars[i].index)
    if shouldDrawCar(cars[i].index) then
      cars[i].color, cars[i].size = getPlayerColor(cars[i].index)
      pos3:set(rotation:transformPoint(car.position - focusedCar.position) + focusedCar.position)
      dir3:set(rotation:transformPoint(car.look))
      pos2:set(pos3.x, pos3.z):add(config.OFFSETS):scale(smol_map.config_scale):add(-smol_map.offsets)
      dir2:set(dir3.x, dir3.z):scale(settings.arrow_scaling and smol_map.scale^0.3 or 1):scale(settings.arrowsize_smol):scale(cars[i].size)
      dir2x:set(dir3.z, -dir3.x):scale(settings.arrow_scaling and smol_map.scale^0.3 or 1):scale(settings.arrowsize_smol):scale(cars[i].size)
      drawArrow(car, cars[i].color,settings.turn_signals_smol)
      cars[i].pos2:set(pos2.x,pos2.y)
    end
  end
  if settings.traffic_warnings then drawTraffic(smol_map) end
  for i=1, #cars do
    if settings.names_smol and (not settings.names_smol_mouseover or ui.windowHovered()) and shouldDrawCar(cars[i].index) then drawName(cars[i]) end
  end
end

function script.windowMainSettings(dt)
  if first then return end
  ui.beginOutline()
  if not ac.teleportToServerPoint then ui.text('update to csp 1.78 or newer for teleports') end
  ui.textColored('v'.. app_version .. ' made by tuttertep',pink)
  if ui.itemClicked(ui.MouseButton.Middle) and ui.hotkeyCtrl() then comfyUpdate('dev') end -- hidden dev branch button
  ui.tabBar('TabBar', function()

    if profiles then drawProfiles() end

    ui.tabItem('settings', function() --settings tab
      --if coloredButton('update comfy map','click to download and install latest comfy map from github') then comfyUpdate('main') end -- update button
      ccheckbox('new render', 'new_render', 'redraw canvas after zooming to avoid drawing full size image when it is not necessary')
      if ui.itemHovered() and ui.mouseReleased() then updateCanvas(main_map) updateCanvas(smol_map) end -- update canvases if toggled
      ccheckbox("follow player", 'centered', 'middle clicking map also toggles this')
      if settings.centered then
        ui.indent()
        ccheckbox('rotate while following', 'rotation')
        ui.unindent()
      end
      ccheckbox("teleports", 'teleporting','draw teleports on main map')
      if settings.teleporting then
        ui.indent()
        ccheckbox("mouseover only##teleporting", 'teleporting_mouseover')
        ccheckbox("rounded icons", 'new_teleports')
        ccheckbox("warning when blocking a teleport", 'teleport_warning')
        ui.unindent()
      end
      ccheckbox("hide when not hovered", "main_map_mouseover", "hide main map when not hovered")
      ccheckbox("traffic warnings", "traffic_warnings", "warning triangles on stopped or slowed down traffic")
      ccheckbox("main map names", 'names')
      if settings.names then
        ui.indent()
        ccheckbox("mouseover only##names", 'names_mouseover')
        ui.unindent()
      end

      if ac.isWindowOpen('smol_map') then
        ccheckbox("smol map names", 'names_smol')
        if settings.names_smol then
          ui.indent()
          ccheckbox("mouseover only##names_smol", 'names_smol_mouseover')
          ui.unindent()
        end
      end
      if settings.names_smol or settings.names then
        settings.names_length = ui.slider('##' .. 'limit name length', settings.names_length, 0,20, 'limit length' .. ': %.0f')
        if ui.itemEdited() then loadCars() end
        settings.namesx = ui.slider('##' .. 'name x offset', settings.namesx, -100,100, 'name x offset' .. ': %.0f')
        settings.namesy = ui.slider('##' .. 'name y offset', settings.namesy,-100,100, 'name y offset:' .. ': %.0f')
        namepos:set(settings.namesx, settings.namesy)
        ccheckbox("right click name to spectate", 'names_spectate')
        ccheckbox("focused car's name", 'ownname')
      end

      if version<2278 then
        ui.text('\nweird teleports lua has access to (maybe void)')
        for i, j in pairs(ac.SpawnSet) do if ui.button(i) then physics.teleportCarTo(0, j) end ui.sameLine() end
      end
      if ac.tryToTeleportToPits then 
        if coloredButton('teleport to pits',rgbm.colors.green) then ac.tryToTeleportToPits()  end
      end
    end)

    ui.tabItem('colors&sizes', function() --arrows tab
      ccheckbox("arrow size scales with zoom", 'arrow_scaling')
      if ac.DriverTags then ccheckbox("content manager tags", 'tags') end
      settings.centered_offset = ui.slider('##' .. 'centered_offset', settings.centered_offset, -0.5, 0.5, 'smol map offset' .. ': %.2f')
      if ui.itemEdited() then centered_offset:set(0.5,0.5-settings.centered_offset) end
      settings.arrowsize = ui.slider('##' .. 'arrowsize', settings.arrowsize, 5, 50, 'main map arrow size' .. ': %.0f')
      settings.arrowsize_smol = ui.slider('##' .. 'arrowsize_smol', settings.arrowsize_smol, 5, 50, 'smol map arrow size' .. ': %.0f')

      local changed = false
      ui.columns(2,false)
      for i, j in pairs(markers) do
        ui.colorButton(i,j.color, bit.bor(ui.ColorPickerFlags.AlphaBar, ui.ColorPickerFlags.AlphaPreview, ui.ColorPickerFlags.PickerHueBar))
        if ui.itemEdited() then changed = true end
        ui.sameLine() ui.text(i)
        ui.nextColumn()
        if j.size~=nil then
          ui.setNextItemWidth(100)
          j.size = ui.slider('##' .. i .. 'size', j.size, 0,2, 'size' .. ': %.2f')
          if ui.itemEdited() then changed = true end
        end
        if i=='friend' then ui.sameLine() ccheckbox("##friends", 'friends') end
        if i=='turn_signals' and version>2051 then
          ui.sameLine() ccheckbox("##turn signals", 'turn_signals', 'signals on main')
          ui.sameLine() ccheckbox('##turn signals_smol','turn_signals_smol','signals on smol')
        end
        if i=='map' then
          ui.setNextItemWidth(100)
          settings.centered_zoom, changedzoom = ui.slider('##' .. 'zoom', settings.centered_zoom, 0.1, 2, 'zoom' .. ': %.1f')
          if changedzoom then
            smol_map.scale = settings.centered_zoom
            smol_map.size = smol_map.image_size*smol_map.scale
            smol_map.config_scale = smol_map.scale/config.SCALE_FACTOR
            updateCanvas(smol_map)      
          end
        end
        ui.nextColumn()
      end
      ui.columns(1)

      if coloredButton('reset settings',rgbm.colors.maroon) then
        markers = stringify.parse(default_colors)
        for i,j in pairs(defaults) do
          settings[i] = j
        end
        changed = true
      end

      ui.sameLine()
      if coloredButton('reload comfy map') then
        ui.unloadImage(main_map.image)
        ui.unloadImage(smol_map.image)
        ui.unloadImage(map)
        ui.unloadImage(map_mini)
        first = true
        onShowWindow1()
      end

      if changed then
        saveMarkers(markers)
      end
      --  doesn't work yet
      --local mapFile = ui.combo('##mapselection',current_map:match(''),function ()
      --  if not mapFiles then return end
      --  for i,j in pairs(mapFiles) do
      --    if ui.selectable(j) then
      --      current_map = ac.getFolder(ac.FolderID.ContentTracks) .. '\\' .. ac.getTrackFullID('\\') .. '\\' .. j
      --      print(current_map)
      --      main_map = {
      --        image = current_map,
      --        image_size = ui.imageSize(current_map),
      --        canvas = ui.ExtraCanvas(1),
      --      }
      --      print(main_map.image_size)
      --      setTimeout(function ()
      --        resetScale(main_map)
      --      end,1)
      --    end
      --  end
      --end)
      --if ui.itemClicked() then mapFiles = getMapImages() end
      --if ui.itemEdited() then setmapimageaseditedimage = nil end
    end)


    ui.tabItem('teleport config helper', function() --teleport tab

      if coloredButton('save point','camera position in f7 camera, otherwise car position') then --group logic coming at some point maybe
        local pos3 = ac.getCar(sim.focusedCar).position
        local dir3 = ac.getCar(sim.focusedCar).look
        if sim.cameraMode == ac.CameraMode.Free then
          pos3 = ac.getCameraPosition()
          dir3 = ac.getCameraForward()
        end
        table.insert(collected_teleports,
          {
            POINT = 'name',
            GROUP = 'group',
            POS = vec3(math.round(pos3.x,1), math.round((pos3.y - physics.raycastTrack(pos3, -vec.y, 20) + 0.5),1), math.round(pos3.z,1)),
            HEADING = math.round(-ac.getCompassAngle(dir3))
          }
        )
      end

      ui.sameLine() if coloredButton('copy points',rgbm.colors.teal) then ui.setClipboardText(saveTeleports(collected_teleports)) end
      ui.sameLine() if coloredButton('delete all',rgbm.colors.maroon) then collected_teleports = {} end
      ui.sameLine() if coloredButton('copy position',rgbm.colors.olive) then
        local pos3 = ac.getCar(sim.focusedCar).position
        local dir3 = ac.getCar(sim.focusedCar).look
        if sim.cameraMode == ac.CameraMode.Free then
          pos3 = ac.getCameraPosition()
          dir3 = ac.getCameraForward()
        end
        ac.setClipboadText(teleportAsText(0,'name','group',vec3(pos3.x,math.round((pos3.y - physics.raycastTrack(pos3, -vec.y, 20) + 0.5),1),pos3.z),headingFromDir3(dir3)))
      end

        ui.text('count: ' ..  #collected_teleports)
        for i,j in pairs(collected_teleports) do
          if not ((i-1)%5==0) and i>1 then ui.sameLine() end -- wrap lines every 5 teleports i guess?
          coloredButton(j.POINT .. (j.POINT=='name' and (i-1) or ''),j.LOADED and rgbm.colors.purple or rgbm.colors.fuchsia,vec2(70, 20))
          if ui.itemClicked(ui.MouseButton.Left) then ac.setCurrentCamera(ac.CameraMode.Free) ac.setCameraPosition(j.POS) ac.setCameraDirection(dir3FromHeading(j.HEADING)) end
          if ui.itemClicked(ui.MouseButton.Right) then table.remove(collected_teleports, i) end
          if ui.itemHovered() then ui.setTooltip((j.GROUP and (j.GROUP .. '/') or '') .. j.POINT ) end
        end

        if coloredButton("config save",rgbm.colors.teal, 'save teleports to comfy_map/extra.ini') then
          io.save(app_folder .. 'extra.ini', saveTeleports(collected_teleports))
          os.openTextFile(app_folder .. 'extra.ini', 10)
        end

        ui.sameLine() if coloredButton("config load",rgbm.colors.purple, "load teleports from comfy_map/extra.ini") then
          local extra_ini = ac.INIConfig.load(app_folder .. 'extra.ini', ac.INIFormat.Extended)
          local localTeleports = loadTeleports(extra_ini)
          for k,l in pairs(localTeleports) do table.insert(collected_teleports,l) end
        end

        ui.sameLine() if coloredButton("online load",rgbm.colors.purple, "load teleports from the server you're currently on") then
          local localTeleports = loadTeleports(ac.INIConfig.onlineExtras())
          for k,l in pairs(localTeleports) do table.insert(collected_teleports,l) end
        end

        if coloredButton('copy timing checkpoint','copy AssettoServer timing checkpoint') then 
          pos3 = ac.getCameraPosition()
          dir3 = ac.getCameraForward()
          ac.setClipboadText(
            '      - Position: ' ..
            '      { X: '  .. math.round(pos3.x,2) ..
            '      , Y: '  .. math.round(pos3.y,2) ..
            '      , Z: '  .. math.round(pos3.z,2) .. ' }\n'..
            '        Forward: ' ..
            '      { X: '  .. math.round(pos3.x+dir3.x,2) ..
            '      , Y: '  .. math.round(pos3.y+dir3.y,2) ..
            '      , Z: '  .. math.round(pos3.z+dir3.z,2) .. ' }'
          )
        end
        if sim.cameraMode == ac.CameraMode.Free then --button to return to car because pressing f1 is annoying 
          ui.sameLine()
          if coloredButton('return camera to car','f4 also does this') then ac.setCurrentCamera(ac.CameraMode.Cockpit) end
        end

    end)
  end)
  ui.endOutline(rgbm.colors.black)
end
