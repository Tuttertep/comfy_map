--made by tuttertep
--i'm already sorry if you read this because everything below is a disaster

ui.setAsynchronousImagesLoading(true)
local default_colors = '0,0.5,0,0.9|0,0,0.5,0.9|0.5,0,0,0.9|1,0.5,0.5,1|0.8,0,0,1|1,1,1,1'
local settings = ac.storage {
  centered = false,
  rotation = true,
  teleporting = true,
  teleporting_mouseover = true,
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
local collected_teleports = {}
local colorpicker = refbool(false)
local selectedcolor = 'you'
--local selectedteleport = {}
local offsets1 = vec2()
local smol_zoom = 0.5


local iconpos, iconsize = vec2(), vec2(5, 5)
local namepos = vec2(settings.namesx, settings.namesy)
local colors = {}
local color_names = { 'you', 'friend', 'player', 'teleport_available', 'teleport_unavailable', 'map' }


function tocolor(string)
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
  local asdf = ac.INIConfig.load(ini)
  asd['SCALE_FACTOR'] = asdf:get('PARAMETERS','SCALE_FACTOR',1)
  asd['Z_OFFSET'] = asdf:get('PARAMETERS','Z_OFFSET',1)
  asd['X_OFFSET'] = asdf:get('PARAMETERS','X_OFFSET',1)
  config_offset = vec2(asd.X_OFFSET, asd.Z_OFFSET)


  image_size = ui.imageSize(map)
end


function script.windowMain(dt)
  onShowWindow()

  ui.beginOutline()
  ui.pushClipRect(0, ui.windowSize()) --background
  if ac.getPatchVersionCode() < 2000 then ui.text(versionerror) return end
  ui.invisibleButton()

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



  ui.drawImage(current_map, -offsets, -offsets + size, colors.map) --map image
  if settings.centered and settings.rotation then ui.endPivotRotation(rotationangle + 90, ui.windowSize() / 2) end



  for i = ac.getSim().carsCount - 1, 0, -1 do --draw cars on map
    local car = ac.getCar(i)
    if car.isConnected and (not car.isHidingLabels) then
      local pos3 = car.position
      local dir3 = car.look
      if settings.centered and settings.rotation then
        pos3 = rotation:transformPoint(car.position - focusedCar.position) + focusedCar.position
        dir3 = rotation:transformPoint(car.look)
      end
      pos2:set(pos3.x, pos3.z):add(config_offset):scale(config_scale):add(-offsets)
      dir2:set(dir3.x, dir3.z)
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
      if settings.names and not (settings.names_mouseover and not ui.windowHovered()) then
          drawName(i,pos2,color)
      end
    end
  end



  if settings.teleporting and not (settings.teleporting_mouseover and not ui.windowHovered()) then --teleports

    if #collected_teleports>0 then --teleport config helper points
      for i,j in pairs(collected_teleports) do
        local teleport_position = j.POS
        local teleport_name = (j.GROUP ~= nil and j.GROUP .. '/' or "") .. j.POINT .. i-1
        if settings.centered and settings.rotation then teleport_position = (rotation:transformPoint(teleport_position - focusedCar.position) + focusedCar.position) end
        iconpos:set(teleport_position.x, teleport_position.z):add(config_offset):scale(config_scale):add(-offsets)
        local h = math.rad(j.HEADING + ac.getCompassAngle(vec3(0, 0, 1)))
        dir2:set(math.sin(h), math.cos(h))
        local color = rgbm.colors.fuchsia
        if j.LOADED then color = rgbm.colors.purple end
        ui.drawLine(iconpos, iconpos + dir2 * 10, color)
        ui.drawCircleFilled(iconpos, iconsize.x-1, color, 20)
        ui.setCursor(iconpos - iconsize)
        ui.dummy(iconsize * 2)
        if ui.itemHovered() then ui.setTooltip(teleport_name) end
        if ui.itemClicked(ui.MouseButton.Left) then ac.setCurrentCamera(ac.CameraMode.Free) ac.setCameraPosition(j.POS) ac.setCameraDirection(vec3(heading.x,0,heading.y)) end
        if ui.itemClicked(ui.MouseButton.Right) then table.remove(collected_teleports, i) end
      end
    end

    if (ac.getSim().isOnlineRace) then
      for i,j in pairs(teleports1) do
        local teleport_position = j.POS
        local teleport_name = (j.GROUP ~= nil and j.GROUP .. '/' or "") .. j.POINT
        if settings.centered and settings.rotation then teleport_position = (rotation:transformPoint(teleport_position - focusedCar.position) + focusedCar.position) end
        iconpos:set(teleport_position.x, teleport_position.z):add(config_offset):scale(config_scale):add(-offsets)
        local color = ac.canTeleportToServerPoint(i - 1) and colors.teleport_available or colors.teleport_unavailable
        ui.drawCircleFilled(iconpos, iconsize.x-1, color, 20)
        if j.HEADING ~= nil then
          local h = math.rad(j.HEADING + ac.getCompassAngle(vec3(0, 0, 1)))
          dir2:set(math.sin(h), math.cos(h))
          ui.drawLine(iconpos, iconpos + dir2 * 10, color)
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
    dir2:set(dir3.x, dir3.z):normalize()
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

  if ui.windowHovered() then --toggle centering with middle click
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

  if not settings.centered then --window movable while centered
    ui.setCursor()
    ui.invisibleButton('asd', ui.windowSize())
    if ui.mouseDown() and ui.itemHovered() then offsets = offsets - ui.mouseDelta() end
  end

  ui.popClipRect()
  ui.endOutline(rgbm(0, 0, 0, colors.map.mult),  colors.map.mult^2)
end


function script.windowMainSettings(dt)
  ui.text('made by tuttertep')


  ui.tabBar('TabBar', function()
    ui.tabItem('settings', function() --settings tab

      if settings.centered then ui.text('middle click map to toggle dragging') end
      if ui.checkbox("rotate while centered", settings.rotation) then settings.rotation = not settings.rotation end

      --ui.text('middle click map to toggle centering')
      if ui.checkbox("teleports", settings.teleporting) then settings.teleporting = not settings.teleporting end
      if settings.teleporting then
        ui.text('\t')
        ui.sameLine()
        if ui.checkbox("only on mouseover##teleporting", settings.teleporting_mouseover) then settings.teleporting_mouseover = not settings.teleporting_mouseover end
      end

      if ui.checkbox("friends", settings.friends) then settings.friends = not settings.friends end
      if ui.checkbox("names", settings.names) then settings.names = not settings.names end
      if settings.names then
        ui.text('\t')
        ui.sameLine()
        ui.beginGroup()
        if ui.checkbox("only on mouseover##names", settings.names_mouseover) then settings.names_mouseover = not settings.names_mouseover end
        if ui.checkbox("right click to spectate", settings.names_spectate) then settings.names_spectate = not settings.names_spectate end
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

      ui.text('\nweird teleports lua has access to (maybe void)')
      for i, j in pairs(ac.SpawnSet) do
        if ui.button(i) then physics.teleportCarTo(0, j) end ui.sameLine()
      end
      ui.newLine(20)

    end)


    ui.tabItem('teleport config', function() --teleport tab
      if ac.getSim().cameraMode == ac.CameraMode.Free then --button to return to car because pressing f1 is annoying 
        if ui.button('return camera to car') then ac.setCurrentCamera(ac.CameraMode.Cockpit) end
      end
      --group logic coming at some point maybe

      if ui.button('save point') then
        local pos3 = ac.getCar(ac.getSim().focusedCar).position
        local dir3 = ac.getCar(ac.getSim().focusedCar).look
        if ac.getSim().cameraMode == ac.CameraMode.Free then
          pos3 = ac.getCameraPosition()
          dir3 = ac.getCameraForward()
        end
        table.insert(collected_teleports,
          {
            POINT = 'name',
            GROUP = 'group',
            POS = vec3(
              math.round(pos3.x,1),
              math.round((pos3.y - physics.raycastTrack(pos3, vec3(0, -1, 0), 20) + 0.5),1),
              math.round(pos3.z,1)
            ),
            HEADING = math.round(-ac.getCompassAngle(dir3))
          }
        )
      end
      if ui.itemHovered() then ui.setTooltip('camera position in f7 camera, otherwise car position') end

      ui.sameLine() ui.pushStyleColor(ui.StyleColor.Button, rgbm.colors.teal) if ui.button('copy points') then ui.setClipboardText(saveTeleports(collected_teleports)) end ui.popStyleColor()
      
      ui.sameLine() ui.pushStyleColor(ui.StyleColor.Button, rgbm.colors.maroon) if ui.button('delete all') then collected_teleports = {} end ui.popStyleColor()

      --local text,typing,enter = ui.inputText('group', pointname, ui.InputTextFlags.Placeholder)

      ui.text('count: ' ..  #collected_teleports)
        for i,j in pairs(collected_teleports) do
          if not ((i-1)%5==0) and i>1 then ui.sameLine() end
          local h = math.rad(j.HEADING + ac.getCompassAngle(vec3(0, 0, 1)))
          local heading = vec3(math.sin(h), 0, math.cos(h))
          if j.LOADED then ui.pushStyleColor(ui.StyleColor.Button, rgbm.colors.purple) else ui.pushStyleColor(ui.StyleColor.Button, rgbm.colors.fuchsia) end
          ui.button(j.POINT .. (j.POINT=='name' and (i-1) or ''), vec2(70, 20))
          ui.popStyleColor()
          if ui.itemClicked(ui.MouseButton.Left) then ac.setCurrentCamera(ac.CameraMode.Free) ac.setCameraPosition(j.POS) ac.setCameraDirection(heading) end
          if ui.itemClicked(ui.MouseButton.Right) then table.remove(collected_teleports, i) end
        end

        ui.newLine(20)
        ui.pushStyleColor(ui.StyleColor.Button, rgbm.colors.teal)
        if ui.button("config save") then
          io.save(ac.getFolder(ac.FolderID.ACApps) .. '/lua/comfy_map/extra.ini', saveTeleports(collected_teleports))
          os.openTextFile(ac.getFolder(ac.FolderID.ACApps) .. '/lua/comfy_map/extra.ini', 10)
        end
        if ui.itemHovered() then ui.setTooltip('save in comfy_map/extra.ini') end
        ui.popStyleColor()

        ui.pushStyleColor(ui.StyleColor.Button, rgbm.colors.purple)
        ui.sameLine() if ui.button("config load") then
          local extra_ini = ac.INIConfig.load(ac.getFolder(ac.FolderID.ACApps) .. '/lua/comfy_map/extra.ini', ac.INIFormat.Extended)
          ui.text(extra_ini)
          collected_teleports = loadTeleports(extra_ini)
        end
        if ui.itemHovered() then ui.setTooltip('load comfy_map/extra.ini') end
        ui.popStyleColor()

    end)
    if ui.itemHovered() then ui.setTooltip('a tool for collecting teleport points for server configs') end
  end)

end

function windowSmol(dt)
  if ac.getPatchVersionCode() < 2000 then ui.text(versionerror) return end
  onShowWindow()
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
      if settings.names and not (settings.names_mouseover and not ui.windowHovered()) then drawName(i,pos2,color) end
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
    if ui.itemClicked(1) and settings.names_spectate then ac.focusCar(i) end
end

function onShowWindow() --somehow works?
  if first then
    image_size = ui.imageSize(map)
    map_scale = math.min((ui.windowWidth() - padding.x) / image_size.x, (ui.windowHeight() - padding.y) / image_size.y)
    if settings.centered then map_scale = 0.5 end
    config_scale = map_scale / asd.SCALE_FACTOR
    size = image_size * map_scale

    if ac.getSim().isOnlineRace then --teleport config
      onlineExtras = ac.INIConfig.onlineExtras()
      teleports1 = loadTeleports(onlineExtras)
    end


    if ui.isImageReady(current_map) then
      first = false
    end
  end
end

function saveTeleports(collected_teleports)
  local collected_teleports_string = '[TELEPORT_DESTINATIONS]\n'
  for i,j in pairs(collected_teleports) do
    collected_teleports_string = collected_teleports_string
      .. 'POINT_' .. i-1 .. '= ' .. j.POINT .. (j.POINT=='name' and (i-1) or '') .. '\n'
      .. 'POINT_' .. i-1 .. '_GROUP= ' .. j.GROUP .. '\n'
      .. 'POINT_' .. i-1 .. '_POS= ' .. math.round(j.POS.x,1) .. ',' .. math.round(j.POS.y,1) .. ',' .. math.round(j.POS.z,1) .. '\n'
      .. 'POINT_' .. i-1 .. '_HEADING= ' .. j.HEADING .. '\n' .. '\n'
  end
  return collected_teleports_string
end

function loadTeleports(ini)
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
    teleports[n]['LOADED'] = true
  end

  for i = 1, #teleports do
    --if teleports[i]["POINT"] ~= nil then sorted_teleports[#sorted_teleports + 1] = teleports[i] end
    if teleports[i]["POINT"] ~= nil then table.insert(sorted_teleports,teleports[i])end
  end
  ac.debug('teleport point count', #sorted_teleports)
  return sorted_teleports
end

