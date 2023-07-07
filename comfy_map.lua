--made by tuttertep
--i'm already sorry if you read this because everything below is a disaster

ui.setAsynchronousImagesLoading(true)
local default_colors = '0,0.5,0,0.9|0,0,0.5,0.9|0.5,0,0,0.9|1,0.5,0.5,1|0.8,0,0,1|1,1,1,1'
local settings = ac.storage {
  centered = false,
  rotation = true,
  teleporting = true,
  friends = true,
  names = true,
  namesx = 0,
  namesy = 0,
  colors = default_colors,
  arrowsize = 10,
  --names_size = 10,
  names_mouseover = true,
  names_spectate = false
}

local owncar, focusedCar = ac.getCar(0), ac.getCar(0)
local first = true
local versionerror = "requires csp version 1.78 or newer (this message is displayed when the version id is below 2000)"

local namepos = vec2(settings.namesx, settings.namesy)
local colors = {}
local color_names = { 'you', 'friend', 'player', 'teleport_available', 'teleport_unavailable', 'map' }
local function tocolor(string)
  local temp = string:split('|')
  local temp1 = {}
  for i = 1, #temp do
    for a, b, c, d in temp[i]:gmatch('(.+),(.+),(.+),(.+)') do temp1[i] = rgbm(tonumber(a), tonumber(b), tonumber(c), tonumber(d)) end
  end
  for i, k in ipairs(color_names) do
    if temp1[i] == nil then temp1[i] = rgbm.colors.white end
    colors[k] = temp1[i]
  end
  return temp1
end
tocolor(settings.colors)


local pos3, dir3, pos2, dir2, dir2x = vec3(), vec3(), vec2(), vec2(), vec2()
local padding = vec2(30, 50)
local offsets = -padding * 0.5
local asd = {}
local zoomlevel = 1

if ac.getPatchVersionCode() >= 2000 then
  map1 = ac.getFolder(ac.FolderID.ContentTracks) .. '/' .. ac.getTrackFullID('/') .. '/map_mini.png'
  map = ac.getFolder(ac.FolderID.ContentTracks) .. '/' .. ac.getTrackFullID('/') .. '/map.png'
  current_map = map
  if io.exists(map1) then
    current_map = map1
    ui.decodeImage(map1)
  end
  ui.decodeImage(map)
  ini = ac.getFolder(ac.FolderID.ContentTracks) .. '/' .. ac.getTrackFullID('/') .. '/data/map.ini'
  --for a, b in ac.INIConfig.load(ini):serialize():gmatch('([_%a]+)=([-%d.]+)') do asd[a] = tonumber(b) end
  local asdf = ac.INIConfig.load(ini)
  asd['SCALE_FACTOR'] = asdf:get('PARAMETERS','SCALE_FACTOR',1)
  asd['Z_OFFSET'] = asdf:get('PARAMETERS','Z_OFFSET',1)
  asd['X_OFFSET'] = asdf:get('PARAMETERS','X_OFFSET',1)
  config_offset = vec2(asd.X_OFFSET, asd.Z_OFFSET)


  image_size = ui.imageSize(map)
end



function script.windowMain(dt)
  ui.beginOutline()
  ui.pushClipRect(0, ui.windowSize()) --background
  if ac.getPatchVersionCode() < 2000 then ui.text(versionerror) return end
  ui.invisibleButton()

  if first then
    image_size = ui.imageSize(map)
    map_scale = math.min((ui.windowWidth() - padding.x) / image_size.x, (ui.windowHeight() - padding.y) / image_size.y)
    if settings.centered then map_scale = 0.5 end
    config_scale = map_scale / asd.SCALE_FACTOR
    size = image_size * map_scale


    if ac.getSim().isOnlineRace then --teleport config
      onlineExtras = ac.INIConfig.onlineExtras()
      teleports, teleports1 = {}, {}
      for a, b in onlineExtras:iterateValues('TELEPORT_DESTINATIONS', 'POINT') do
        n = tonumber(b:match('%d+')) + 1
        if teleports[n] == nil then
          for i = #teleports + 1, n do
            if teleports[i] == nil then teleports[i] = {} end
          end
        end
        ac.debug('highest index', #teleports)

        if b:match('POS') ~= nil then
          teleports[n]['POS'] = onlineExtras:get('TELEPORT_DESTINATIONS', b, vec3())
        elseif b:match('HEADING') ~= nil then
          teleports[n]['HEADING'] = onlineExtras:get('TELEPORT_DESTINATIONS', b, 0)
        elseif b:match('GROUP') ~= nil then
          teleports[n]['GROUP'] = onlineExtras:get('TELEPORT_DESTINATIONS', b, 'group')
        else
          teleports[n]['POINT'] = onlineExtras:get('TELEPORT_DESTINATIONS', b, 'name')
        end
        teleports[n]["N"] = n
      end

      for i = 1, #teleports do
        if teleports[i]["POINT"] ~= nil then
          teleports1[#teleports1 + 1] = teleports[i]
        end
      end
    end


    if ui.isImageReady(current_map) then
      first = false
    end
  end

  if ui.windowHovered() then --zoom&drag
    if ac.getUI().mouseWheel ~= 0 then
      if (ac.getUI().mouseWheel < 0 and (size.x + padding.x > ui.windowWidth() and size.y + padding.y > ui.windowHeight())) or ac.getUI().mouseWheel > 0 then
        local old = size
        map_scale = map_scale * (1 + ac.getUI().mouseWheel * 0.15)
        size = ui.imageSize(current_map) * map_scale
        config_scale = map_scale / asd.SCALE_FACTOR
        offsets = (offsets + (size - old) * (offsets + ui.mouseLocalPos()) / old)
      else
        offsets = -padding * 0.5
        map_scale = math.min((ui.windowWidth() - padding.x) / image_size.x, (ui.windowHeight() - padding.y) / image_size.y)
        size = ui.imageSize(current_map) * map_scale
        config_scale = map_scale / asd.SCALE_FACTOR
      end
    end
  end

  focusedCar = ac.getCar(ac.getSim().focusedCar)
  if settings.centered then --center on car and rotate
    offsets:set(focusedCar.position.x, focusedCar.position.z):add(config_offset):scale(config_scale):add(-ui.windowSize() / 2) --autocenter

    if settings.rotation then
      rotationangle = 180 - math.deg(math.atan2(focusedCar.look.x, focusedCar.look.z))
      rotation = mat4x4.rotation(math.rad(rotationangle), vec3(0, 1, 0))
      ui.beginRotation()
    end
  end

  ac.perfBegin('map&players')
  ui.drawImage(current_map, -offsets, -offsets + size, colors.map) --map image
  if settings.centered and settings.rotation then ui.endPivotRotation(rotationangle + 90, ui.windowSize() / 2) end

  for i = ac.getSim().carsCount - 1, 0, -1 do --draw stuff on map
    local car = ac.getCar(i)
    if car.isConnected and (not car.isHidingLabels) then
      local pos3 = car.position
      local dir3 = car.look
      if settings.centered and settings.rotation then
        pos3 = rotation:transformPoint(car.position - focusedCar.position) + focusedCar.position
        dir3 = rotation:transformPoint(car.look)
      end
      pos2:set(pos3.x, pos3.z):add(config_offset):scale(config_scale):add(-offsets)
      dir2:set(dir3.x, dir3.z) -- = vec2(dir3.x, dir3.z)
      dir2x:set(dir3.z, -dir3.x)

      color = colors.player
      if settings.friends then
        if ac.isTaggedAsFriend(ac.getDriverName(i)) then color = colors.friend end
      end
      if car == focusedCar then color = colors.you end
      ts = settings.arrowsize
      ui.drawTriangleFilled(pos2 + dir2 * ts,
        pos2 - dir2 * ts - dir2x * ts * 0.75,
        pos2 - dir2 * ts + dir2x * ts * 0.75,
        color)
      if settings.names then
        if not (settings.names_mouseover and not ui.windowHovered()) then
          drawName(i,pos2,color)
        end
      end
    end
  end
  ac.perfEnd('map&players')

  local iconpos, iconsize = vec2(), vec2(5, 5)
  if ui.windowHovered() then --teleports
  if ac.getSim().isOnlineRace and settings.teleporting then
    for i = 1, #teleports1 do
      local teleport_position = teleports1[i].POS
      local teleport_name = (teleports1[i].GROUP ~= nil and teleports1[i].GROUP .. '/' or "") .. teleports1[i].POINT
      if settings.centered and settings.rotation then teleport_position = (rotation:transformPoint(teleport_position - focusedCar.position) + focusedCar.position) end
      iconpos:set(teleport_position.x, teleport_position.z):add(config_offset):scale(config_scale):add(-offsets)
      local color = ac.canTeleportToServerPoint(i - 1) and colors.teleport_available or colors.teleport_unavailable
      ui.drawCircleFilled(iconpos, iconsize.x-1, color, 20)
      if teleports1[i].HEADING ~= nil then
        local h = math.rad(teleports1[i].HEADING + ac.getCompassAngle(vec3(0, 0, 1)))
        local heading = vec2(math.sin(h), math.cos(h))
        ui.drawLine(iconpos, iconpos + heading * 10, color)
      end
      ui.setCursor(iconpos - iconsize)
      ui.dummy(iconsize * 2)
      if ui.itemHovered() then ui.setTooltip(teleport_name) end
      if ui.itemClicked(ui.MouseButton.Right) then ac.sendChatMessage("Teleport to: " .. teleport_name) end
      if ui.itemClicked(ui.MouseButton.Left) then ac.teleportToServerPoint(i - 1) end
    end
  end
  end
  if ac.getSim().cameraMode == ac.CameraMode.Free then --freecam stuff
    pos3 = ac.getCameraPosition()
    dir3 = ac.getCameraForward()
    if settings.centered and settings.rotation then
      pos3 = rotation:transformPoint(pos3 - focusedCar.position) + focusedCar.position
      dir3 = rotation:transformPoint(dir3)
    end
    pos2:set(pos3.x, pos3.z):add(config_offset):scale(config_scale):add(-offsets)
    dir2 = vec2(dir3.x, dir3.z):normalize()
    dir2x:set(dir3.z, -dir3.x):normalize()
    ui.drawTriangleFilled(pos2 + dir2 * ts,
      pos2 - dir2 * ts - dir2x * ts * 0.75,
      pos2 - dir2 * ts + dir2x * ts * 0.75,
      colors.you)
    if ui.keyPressed(ui.Key.Space) and ui.windowHovered() then --freecam teleport
      local camerapos = (ui.mouseLocalPos() + offsets) / config_scale - config_offset
      --if ac.hasTrackSpline() then
      --  local progress = ac.worldCoordinateToTrackProgress(camerapos)
      --  local splinepos = ac.trackProgressToWorldCoordinate(progress)
      --  camerapos:set(splinepos.x, splinepos.z)
      --end
      local raycastheight = 3000
      local raycast = physics.raycastTrack(vec3(camerapos.x, raycastheight, camerapos.y), vec3(0, -1, 0), raycastheight*2)
      local cameraheight = raycastheight - raycast + 3
      if raycast ~= -1 then
        ac.setCurrentCamera(ac.CameraMode.Free)
        ac.setCameraPosition(vec3(camerapos.x, cameraheight, camerapos.y))
      end
    end
  end
  if ui.windowHovered() then
    if ui.mouseClicked(2) then
      if settings.centered then
        offsets = -padding * 0.5
        map_scale = math.min((ui.windowWidth() - padding.x) / image_size.x,
          (ui.windowHeight() - padding.y) / image_size.y)
        size = ui.imageSize(map) * map_scale
        config_scale = map_scale / asd.SCALE_FACTOR
      end
      settings.centered = not settings.centered
    end
  end
  ui.setCursor()
  ui.invisibleButton('asd', ui.windowSize())
  if ui.mouseDown() and ui.itemHovered() then offsets = offsets - ui.mouseDelta() end

  ui.popClipRect()
  ui.endOutline(rgbm(0, 0, 0, colors.map.mult),  colors.map.mult^2)
end

local colorpicker = refbool(false)
local selectedcolor = 'you'
local teleportindex = '0'
function script.windowMainSettings(dt)
  ui.text('made by tuttertep')
  if settings.centered then ui.text('middle click to stop rotation and centering') end
  --ui.text('middle click map to toggle centering')
  if ui.checkbox("teleports", settings.teleporting) then settings.teleporting = not settings.teleporting end
  if ui.checkbox("friends", settings.friends) then settings.friends = not settings.friends end
  if ui.checkbox("names", settings.names) then settings.names = not settings.names end
  if settings.names then
    ui.text('\t')
    ui.sameLine()
    ui.beginGroup()
    if ui.checkbox("only on mouseover", settings.names_mouseover) then settings.names_mouseover = not settings.names_mouseover end
    if ui.checkbox("click to spectate", settings.names_spectate) then settings.names_spectate = not settings.names_spectate end
    if ui.checkbox("rotate while centered", settings.rotation) then settings.rotation = not settings.rotation end
    settings.namesx = ui.slider('##' .. 'name x offset', settings.namesx, -100,100, 'name x offset' .. ': %.0f')
    settings.namesy = ui.slider('##' .. 'name y offset', settings.namesy,-100,100, 'name y offset:' .. ': %.0f')
    --settings.names_size = ui.slider('##' .. 'font size', settings.names_size, 5, 50, 'font size' .. ': %.0f')
    namepos = vec2(settings.namesx, settings.namesy)
    ui.endGroup()
  end



  ui.checkbox('arrow color settings', colorpicker)
  if colorpicker.value then
    ui.text('\t')
    ui.sameLine()
    ui.beginGroup()
    settings.arrowsize = ui.slider('##' .. 'arrow size', settings.arrowsize, 5, 50, 'arrow size' .. ': %.0f')
    ui.colorPicker(selectedcolor, colors[selectedcolor], ui.ColorPickerFlags.AlphaBar)
    local save_color = ''
    for i, j in pairs(color_names) do
      if ui.selectable(j, selectedcolor == j,_, ui.measureText(j)) then selectedcolor = j end
      save_color = save_color .. colors[j].r .. "," .. colors[j].g .. "," .. colors[j].b .. "," .. colors[j].mult .. '|'
    end

    settings.colors = save_color
    if ui.button('reset colors') then
      settings.colors = default_colors
      tocolor(settings.colors)
    end
    ui.endGroup()
  end

  ui.text('\n extra config teleport point helper')
  teleportstuff = 'POINT_' ..
      teleportindex ..
      '= name\nPOINT_' ..
      teleportindex ..
      '_GROUP= group\nPOINT_' ..
      teleportindex ..
      '_POS= ' ..
      math.round(ac.getCameraPosition().x,1) ..
      "," ..
      math.round((ac.getCameraPosition().y - physics.raycastTrack(ac.getCameraPosition(), vec3(0, -1, 0), 20) + 0.5),1)..
      ',' ..
      math.round(ac.getCameraPosition().z,1) ..
      '\nPOINT_' .. teleportindex .. '_HEADING= ' .. math.floor(-ac.getCompassAngle(ac.getCameraForward()))



  ui.button(teleportstuff)
  if ui.itemClicked(1) then teleportindex = teleportindex - 1 end
  if ui.itemClicked(2) then teleportindex = 0 end
  if ui.itemClicked(0) then
    teleportindex = teleportindex + 1
    ui.setClipboardText(teleportstuff)
  end


  ui.text('\nweird teleports lua has access to (maybe void)')
  for i, j in pairs(ac.SpawnSet) do
    if ui.button(i) then physics.teleportCarTo(0, j) end ui.sameLine()
  end





  --WEATHERFX STUFF FOR ADMINS maybe remove before update idk 
  --i know comfy map has literally nothing to do with weather but i found myself using this a lot so i put it here
  
  ui.newLine(20)
  if ac.getSim().isOnlineRace and ac.getSim().isWeatherFXActive then
    ui.text('weather stuff & voting buttons')
    for i= 0, 4 do
      if ui.button('vote ' .. i) then ac.sendChatMessage('/w '..i) end
      if i < 4 then ui.sameLine() end
    end
    if ui.button('check admin privileges') then ac.checkAdminPrivileges() end
      if ac.getSim().isAdmin then --don't bother drawing if not admin
        local weathers = {}
        if settime==nil then settime = ac.getSim().timestamp%86400 end
        if time_multiplier==nil then time_multiplier = ac.getSim().timeMultiplier end
        for i, j in pairs(ac.WeatherType) do weathers[j] = i end
        duration = ui.slider('##duration', duration, 0, 360, 'transition duration: %.0fs')
        id, changed = ui.combo('##weathers', ac.getSim().weatherType, weathers)
        ui.sameLine() ui.text(weathers[ac.getSim().weatherType])
        if changed then ac.sendChatMessage('/setcspweather ' .. id .. ' ' .. duration) end
        settime = ui.slider('##time', settime, 0, 86400, 'right click to set time: ' .. os.dateGlobal("%H:%M", settime))
        local time = os.dateGlobal("%H:%M", settime)
        if ui.itemClicked(1) then ac.sendChatMessage('/settime ' .. time) end
        ui.sameLine() ui.text(os.dateGlobal("%H:%M",ac.getSim().timestamp))
        time_multiplier = ui.slider('##time_multiplier', time_multiplier, 0, 10, 'right click to set multiplier: %.2f')
        if ui.itemClicked(1) then ac.sendChatMessage('/set Server.TimeOfDayMultiplier ' .. math.round(time_multiplier,2)) end
        ui.sameLine() ui.text(ac.getSim().timeMultiplier .. 'x')
      end
  end


end

local offsets1 = vec2()
local smol_zoom = 0.5
function windowSmol(dt)
  if ac.getPatchVersionCode() < 2000 then ui.text(versionerror) return end

  ui.invisibleButton()
  ui.beginOutline()
  if ui.windowHovered() and ui.mouseWheel() then smol_zoom = smol_zoom * (1 + 0.1 * ui.mouseWheel()) end
  focusedCar = ac.getCar(ac.getSim().focusedCar)
  smol_scale = smol_zoom
  size1 = image_size * smol_scale
  offsets1:set(focusedCar.position.x, focusedCar.position.z):add(config_offset):scale(smol_scale / asd.SCALE_FACTOR):add(-ui.windowSize() / 2) --autocenter

  rotationangle = 180 - math.deg(math.atan2(focusedCar.look.x, focusedCar.look.z))
  rotation = mat4x4.rotation(math.rad(rotationangle), vec3(0, 1, 0))
  ui.beginRotation()
  ui.drawImage(map, -offsets1, -offsets1 + size1, colors.map) --map image
  ui.endPivotRotation(rotationangle + 90, ui.windowSize() / 2)
  


  for i = ac.getSim().carsCount - 1, 0, -1 do --draw stuff on small map
    local car = ac.getCar(i)
    if car.isConnected and (not car.isHidingLabels) then
      local pos3 = rotation:transformPoint(car.position - focusedCar.position) + focusedCar.position
      local dir3 = rotation:transformPoint(car.look)
      pos2:set(pos3.x, pos3.z):add(config_offset):scale(smol_scale / asd.SCALE_FACTOR):add(-offsets1)
      dir2:set(dir3.x, dir3.z)
      dir2x:set(dir3.z, -dir3.x)

      color = colors.player
      if settings.friends then
        if ac.isTaggedAsFriend(ac.getDriverName(i)) then color = colors.friend end
      end
      if car == focusedCar then color = colors.you end
      ts = settings.arrowsize * 0.8
      ui.drawTriangleFilled(pos2 + dir2 * ts,
        pos2 - dir2 * ts - dir2x * ts * 0.75,
        pos2 - dir2 * ts + dir2x * ts * 0.75,
        color)
      if settings.names then drawName(i,pos2, color) end
    end
  end
  ui.endOutline(rgbm(0, 0, 0, colors.map.mult), colors.map.mult^2)

end

function drawName(i,pos,color)
    local name = ac.getDriverName(i)
    ui.pushFont(ui.Font.Small)
    ui.setCursor(pos + namepos - ui.measureText(name) * 0.5)
    ui.drawLine(pos, pos + namepos , color, 2)
    --ui.dwriteDrawText(name,settings.names_size,pos + namepos - ui.measureDWriteText(name,settings.names_size) * 0.5,rgbm.colors.white)
    ui.text(name)
    ui.popFont()
    if ui.itemClicked() and settings.names_spectate then ac.focusCar(i) end
end