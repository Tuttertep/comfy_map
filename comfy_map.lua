---@diagnostic disable: undefined-global, undefined-field, missing-parameter, need-check-nil, missing-return, param-type-mismatch, lowercase-global, redundant-value, cast-local-type,duplicate-set-field
--made by tuttertep
--i'm already sorry if you read this because everything below is a disaster 😭

ui.setAsynchronousImagesLoading(true)
local default_colors = '0,0.5,0,0.9|0,0,0.5,0.9|0.5,0,0,0.9|1,0.5,0.5,1|0.8,0,0,1|1,1,1,1|0,1,0,1'
local settings = ac.storage {
  centered = false,
  rotation = true,
  teleporting = true,
  teleporting_mouseover = true,
  friends = true,
  namesx = 0,
  namesy = 0,
  names = true,
  names_smol = true,
  names_mouseover = true,
  names_smol_mouseover = true,
  names_spectate = false,
  ownnname = false,
  colors = default_colors,
  test = false,
  arrowsize = 10,
  arrow_scaling = true,
  turn_signals = true,
  tags = false,
}

--people have complained about ac.storage so looked into ini just in case
--local config_defaults = {
--  options = {
--    centered = false,
--    rotation = true,
--    teleporting = true,
--    teleporting_mouseover = true,
--    friends = true,
--    namesx = 0,
--    namesy = 0,
--    names = true,
--    names_smol = true,
--    names_mouseover = true,
--    names_smol_mouseover = true,
--    names_spectate = false,
--    ownnname = false,
--    colors = default_colors,
--    test = false,
--    arrowsize = 10,
--    arrow_scaling = true,
--    turn_signals = true,
--    tags = false,
--    },
--  colors = {
--    you = rgbm(0, 0.5, 0, 0.9),
--    friend = rgbm(0, 0, 0.5, 0.9),
--    player = rgbm(0.5, 0, 0, 0.9),
--    teleport_available = rgbm(1, 0.5, 0.5, 1),
--    teleport_unavailable = rgbm(0.8, 0, 0, 1),
--    map = rgbm(1, 1, 1, 1)
--  }
--}
--local config = ac.INIConfig.load(ac.getFolder(ac.FolderID.ACApps) .. '/lua/comfy_map/config.ini', ac.INIFormat.Extended)
--local settings1 = config:mapConfig(config_defaults)



local owncar, focusedCar = ac.getCar(0), ac.getCar(0)
local first = true
local versionerror = "requires csp version 1.78 or newer (this message is displayed when the version id is below 2000)"
local version = ac.getPatchVersionCode()
local collected_teleports = {}
local selectedcolor = 'you'

local iconpos, iconsize = vec2(), vec2(5, 5)
local namepos = vec2(settings.namesx, settings.namesy)
local colors = {}
local color_names = { 'you', 'friend', 'player', 'teleport_available', 'teleport_unavailable', 'map', 'turn_signals' }

function tocolor(string)
  local temp = string:split('|')
  local temp1 = {}
  for i = 1, #temp do
    temp1[i] = rgbm.new(vec4.new(temp[i]))
  end
  for i, k in ipairs(color_names) do
    if temp1[i] == nil then temp1[i] = rgbm.colors.lime end
    colors[k] = temp1[i]
  end
  return temp1
end

tocolor(settings.colors)

local vec = {x=vec3(1,0,0),y=vec3(0,1,0),z=vec3(0,0,1),empty=vec3()}
local pos3, dir3, pos2, dir2, dir2x = vec3(), vec3(), vec2(), vec2(), vec2()
local padding = vec2(30, 50)
local outline = rgbm()
local offsets = -padding * 0.5
local asd = {}
local asd1 = nil

if version >= 2000 then
  map1 = ac.getFolder(ac.FolderID.ContentTracks) .. '/' .. ac.getTrackFullID('/') .. '/map_mini.png'
  map = ac.getFolder(ac.FolderID.ContentTracks) .. '/' .. ac.getTrackFullID('/') .. '/map.png'
  current_map = map
  if io.exists(map1) then
    current_map = map1
    ui.decodeImage(current_map)
  end
  ui.decodeImage(map)
  ini = ac.getFolder(ac.FolderID.ContentTracks) .. '/' .. ac.getTrackFullID('/') .. '/data/map.ini'
  asd = ac.INIConfig.load(ini):mapSection('PARAMETERS', { SCALE_FACTOR = 1, Z_OFFSET = 1, X_OFFSET = 1, WIDTH=500, HEIGHT=500, MARGIN=20, DRAWING_SIZE=10, MAX_SIZE=1000})
  config_offset = vec2(asd.X_OFFSET, asd.Z_OFFSET)

  image_size = ui.imageSize(map)
end


function script.windowMain(dt)
  if version < 2000 then ui.text(versionerror) return end
  onShowWindow()
  if first then return end
  ui.pushClipRect(0, ui.windowSize()) --background
  ui.invisibleButton()

  if ui.windowHovered() then --zoom&drag&centering&reset
    if ac.getUI().mouseWheel ~= 0 then
      if (ac.getUI().mouseWheel < 0 and ((size+padding)>ui.windowSize())) or ac.getUI().mouseWheel > 0 then
        local old = size
        map_scale = map_scale * (1 + math.sign(ac.getUI().mouseWheel) * 0.15)
        size = ui.imageSize(current_map) * map_scale
        config_scale = map_scale / asd.SCALE_FACTOR
        offsets = (offsets + (size - old) * (offsets + ui.mouseLocalPos()) / old) -- DON'T touch, powered by dark magic
      else
        offsets = -padding * 0.5
        map_scale = math.min((ui.windowWidth() - padding.x) / image_size.x, (ui.windowHeight() - padding.y) / image_size.y)
        size = ui.imageSize(current_map) * map_scale
        config_scale = map_scale / asd.SCALE_FACTOR
      end
    end
    if ui.mouseClicked(2) then --toggle centering with middle click
      if settings.centered then
        offsets = -padding * 0.5
        map_scale = math.min((ui.windowWidth() - padding.x) / image_size.x, (ui.windowHeight() - padding.y) / image_size.y)
        size = ui.imageSize(map) * map_scale
        config_scale = map_scale / asd.SCALE_FACTOR
      end
      settings.centered = not settings.centered
    end
  end

  focusedCar = ac.getCar(ac.getSim().focusedCar)

  if settings.centered then --center on car and rotate
    offsets:set(focusedCar.position.x, focusedCar.position.z):add(config_offset):scale(config_scale):add(-ui.windowSize() / 2) --autocenter

    if settings.rotation then
      rotationangle = 180 - math.deg(math.atan2(focusedCar.look.x, focusedCar.look.z))
      rotation = mat4x4.rotation(math.rad(rotationangle), vec.y)
      ui.beginRotation()
    end
  end

  ac.debug('map_scale',map_scale)
  ui.beginOutline()
  ui.drawImage(current_map, -offsets, -offsets + size, colors.map) --map image
  ui.endOutline(outline:set(rgbm.colors.black, colors.map.mult),  colors.map.mult^2)


  if settings.centered and settings.rotation then ui.endPivotRotation(rotationangle + 90, ui.windowSize() / 2) end



  for i = ac.getSim().carsCount - 1, 0, -1 do --draw cars on map
    local car = ac.getCar(i)
    if shouldDrawCar(car) then
      pos3:set(car.position)
      dir3:set(car.look)
      if settings.centered and settings.rotation then
        pos3 = rotation:transformPoint(car.position - focusedCar.position) + focusedCar.position
        dir3 = rotation:transformPoint(car.look)
      end
      pos2:set(pos3.x, pos3.z):add(config_offset):scale(config_scale):add(-offsets)
      dir2:set(dir3.x, dir3.z):scale(settings.arrowsize):scale(settings.arrow_scaling and map_scale^0.3 or 1)
      dir2x:set(dir3.z, -dir3.x):scale(settings.arrowsize):scale(settings.arrow_scaling and map_scale^0.3 or 1)

      color = getPlayerColor(i)

      drawArrow(car,color)
      if settings.names and not (settings.names_mouseover and not ui.windowHovered()) then
          drawName(i,color)
      end
    end
  end


  ui.beginOutline()
  if settings.teleporting and not (settings.teleporting_mouseover and not ui.windowHovered()) then --teleports

    for i,j in pairs(collected_teleports) do --teleport config helper points
      local teleport_position = j.POS
      local teleport_name = (j.GROUP ~= nil and j.GROUP .. '/' or "") .. j.POINT .. i-1
      if settings.centered and settings.rotation then teleport_position = (rotation:transformPoint(teleport_position - focusedCar.position) + focusedCar.position) end
      iconpos:set(teleport_position.x, teleport_position.z):add(config_offset):scale(config_scale):add(-offsets)
      local h = math.rad(j.HEADING + ac.getCompassAngle(vec.z) + (settings.centered and settings.rotation and rotationangle or 0))
      dir2:set(math.sin(h), math.cos(h))
      local color = rgbm.colors.fuchsia
      if j.LOADED then color = rgbm.colors.purple end
      ui.drawLine(iconpos, iconpos + dir2 * 10, color)
      ui.drawCircleFilled(iconpos, iconsize.x-1, color, 20)
      ui.setCursor(iconpos - iconsize)
      ui.dummy(iconsize * 2)
      if ui.itemHovered() then ui.setTooltip(teleport_name) end
      if ui.itemClicked(ui.MouseButton.Left) then ac.setCurrentCamera(ac.CameraMode.Free) ac.setCameraPosition(j.POS) ac.setCameraDirection(dir3:set(dir2.x,0,dir2.y)) end
      if ui.itemClicked(ui.MouseButton.Right) then table.remove(collected_teleports, i) end
    end

    if (ac.getSim().isOnlineRace) then --online teleports
      calledTeleport = nil
      calledTeleportAng = 360
      for i,j in pairs(teleports1) do
        local teleport_position = j.POS
        local teleport_name = (j.GROUP ~= nil and j.GROUP .. '/' or "") .. j.POINT -- .. ' ' .. i-1 .. ' ' .. j.INDEX
        if settings.centered and settings.rotation then teleport_position = (rotation:transformPoint(teleport_position - focusedCar.position) + focusedCar.position) end
        iconpos:set(teleport_position.x, teleport_position.z):add(config_offset):scale(config_scale):add(-offsets)
        local color = ac.canTeleportToServerPoint(i - 1) and colors.teleport_available or colors.teleport_unavailable
        ui.drawCircleFilled(iconpos, iconsize.x-1, color, 20)
        local h = math.rad(j.HEADING + ac.getCompassAngle(vec.z) + (settings.centered and settings.rotation and rotationangle or 0))
        dir2:set(math.sin(h), math.cos(h))
        ui.drawLine(iconpos, iconpos + dir2 * 10, color)

        ui.setCursor(iconpos - iconsize)
        ui.dummy(iconsize * 2)
        if ui.itemClicked(ui.MouseButton.Left) and ac.canTeleportToServerPoint(j.INDEX) then --if multiple point overlap, try to guess intended one
          if not calledTeleport then calledTeleport = j.INDEX end --this feature is peak gremlin
          local closest = {distance = 1000000, car = ac.getCar(0)}
          for k = 1, ac.getSim().carsCount - 1 do
            local car = ac.getCar(k)
            if shouldDrawCar(car) then
              local distance = car.position:distance(teleport_position)
              if distance < closest.distance then
                closest['car'] = car closest['distance']  = distance
              end
            end
          end
          local ang = math.abs((-closest.car.compass - j.HEADING + 180) % 360 - 180)
          if ang < calledTeleportAng then
            calledTeleport = j.INDEX calledTeleportAng = ang
          end
        end

        if ui.itemHovered() then ui.setTooltip(teleport_name) end
        if ui.itemClicked(ui.MouseButton.Right) then ac.sendChatMessage("Teleport to: " .. teleport_name) end
      end
      if calledTeleport~=nil then ac.teleportToServerPoint(calledTeleport) ac.debug('teleported','id:' .. calledTeleport .. ' ang:' .. calledTeleportAng) end
    end

  end


  if ac.getSim().cameraMode == ac.CameraMode.Free then --freecam stuff
    pos3 = ac.getCameraPosition()
    dir3 = ac.getCameraForward()
    if settings.centered and settings.rotation then
      pos3 = rotation:transformPoint(pos3 - focusedCar.position) + focusedCar.position
      dir3 = rotation:transformPoint(dir3)
    end
    pos2:set(pos3.x, pos3.z):add(config_offset):scale(config_scale):sub(offsets)
    dir2:set(dir3.x, dir3.z):normalize():scale(settings.arrowsize):scale(settings.arrow_scaling and map_scale^0.3 or 1)
    dir2x:set(dir3.z, -dir3.x):normalize():scale(settings.arrowsize):scale(settings.arrow_scaling and map_scale^0.3 or 1)
    ui.drawTriangleFilled(pos2 + dir2,
      pos2 - dir2 - dir2x * 0.75,
      pos2 - dir2 + dir2x * 0.75,
      colors.you)
    if ui.keyPressed(ui.Key.Space) and ui.windowHovered() then --freecam teleport
      pos2:set(ui.mouseLocalPos()):add(offsets):scale(1/config_scale):sub(config_offset)
      local raycastheight = 3000
      local raycast = physics.raycastTrack(pos3:set(pos2.x, raycastheight, pos2.y), -vec.y, raycastheight*2)
      local cameraheight = raycastheight - raycast + 3
      if raycast ~= -1 then
        ac.setCurrentCamera(ac.CameraMode.Free)
        ac.setCameraPosition(pos3:set(pos2.x, cameraheight, pos2.y))
      end
    end
  end
  ui.endOutline(outline:set(rgbm.colors.black, colors.map.mult),  colors.map.mult^2)

  if not settings.centered then --window movable while centered
    ui.setCursor()
    ui.invisibleButton('asd', ui.windowSize())
    if ui.mouseDown() and ui.itemHovered() then offsets = offsets - ui.mouseDelta() end
  end
  ui.popClipRect()
end

function script.windowMainSettings(dt)
  if first then return end
  ui.text('made by tuttertep')


  ui.tabBar('TabBar', function()

    ui.tabItem('settings', function() --settings tab

      if settings.centered then ui.text('middle click map to toggle dragging') end
      if ui.checkbox("rotate while centered", settings.rotation) then settings.rotation = not settings.rotation end

      --ui.text('middle click map to toggle centering')
      if ui.checkbox("teleports", settings.teleporting) then settings.teleporting = not settings.teleporting end
      if settings.teleporting then
        ui.indent()
        if ui.checkbox("mouseover only##teleporting", settings.teleporting_mouseover) then settings.teleporting_mouseover = not settings.teleporting_mouseover end
        ui.unindent()
      end



      if ui.checkbox("names", settings.names) then settings.names = not settings.names end
      if settings.names then
        ui.indent()
        if ui.checkbox("mouseover only##names", settings.names_mouseover) then settings.names_mouseover = not settings.names_mouseover end
        ui.unindent()
      end

      if ac.isWindowOpen('smol_map') then
        if ui.checkbox("smol names", settings.names_smol) then settings.names_smol = not settings.names_smol end
        if settings.names_smol then
          ui.indent()
          if ui.checkbox("mouseover only##names_smol", settings.names_smol_mouseover) then settings.names_smol_mouseover = not settings.names_smol_mouseover end
          ui.unindent()
        end
      end

      if ui.checkbox("right click name to spectate", settings.names_spectate) then settings.names_spectate = not settings.names_spectate end
      if ui.checkbox("focused car's name", settings.ownnname) then settings.ownnname = not settings.ownnname end
      settings.namesx = ui.slider('##' .. 'name x offset', settings.namesx, -100,100, 'name x offset' .. ': %.0f')
      settings.namesy = ui.slider('##' .. 'name y offset', settings.namesy,-100,100, 'name y offset:' .. ': %.0f')
      namepos:set(settings.namesx, settings.namesy)
      --if ui.checkbox("test", settings.test) then settings.test = not settings.test end


      if version<2278 then
        ui.text('\nweird teleports lua has access to (maybe void)')
        for i, j in pairs(ac.SpawnSet) do
          if ui.button(i) then physics.teleportCarTo(0, j) end ui.sameLine()
        end
        ui.newLine(20)
      end

      --if ui.button('reload map') then ui.text(ui.unloadImage(map)) ui.text(ui.unloadImage(map1)) end

    end)

    ui.tabItem('map arrows', function() --arrows tab
      if version>2051 then
        if ui.checkbox("turn signals", settings.turn_signals) then settings.turn_signals = not settings.turn_signals end
      end
      if ui.checkbox("arrow size scales with zoom", settings.arrow_scaling) then settings.arrow_scaling = not settings.arrow_scaling end
      if ui.checkbox("friends", settings.friends) then settings.friends = not settings.friends end
      if version>2363 then
        if ui.checkbox("use cm tag colors", settings.tags) then settings.tags = not settings.tags end
      end

      settings.arrowsize = ui.slider('##' .. 'arrow size', settings.arrowsize, 5, 50, 'arrow size' .. ': %.0f')
      ui.colorPicker(selectedcolor, colors[selectedcolor], bit.bor(ui.ColorPickerFlags.AlphaBar, ui.ColorPickerFlags.DisplayHex))
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
    end)

    ui.tabItem('teleport config helper', function() --teleport tab
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
            POS = vec3(math.round(pos3.x,1), math.round((pos3.y - physics.raycastTrack(pos3, -vec.y, 20) + 0.5),1), math.round(pos3.z,1)),
            HEADING = math.round(-ac.getCompassAngle(dir3))
          }
        )
      end
      if ui.itemHovered() then ui.setTooltip('camera position in f7 camera, otherwise car position') end

      ui.sameLine() ui.pushStyleColor(ui.StyleColor.Button, rgbm.colors.teal) if ui.button('copy points') then ui.setClipboardText(saveTeleports(collected_teleports)) end ui.popStyleColor()
      ui.sameLine() ui.pushStyleColor(ui.StyleColor.Button, rgbm.colors.maroon) if ui.button('delete all') then collected_teleports = {} end ui.popStyleColor()
      ui.sameLine() ui.pushStyleColor(ui.StyleColor.Button, rgbm.colors.olive) if ui.button('copy position') then
        local pos3 = ac.getCar(ac.getSim().focusedCar).position
        local dir3 = ac.getCar(ac.getSim().focusedCar).look
        if ac.getSim().cameraMode == ac.CameraMode.Free then
          pos3 = ac.getCameraPosition()
          dir3 = ac.getCameraForward()
        end
        ac.setClipboadText('POINT_0=name\nPOINT_0_GROUP_=group\nPOINT_0_POS=' .. math.round(pos3.x,1) .. ',' .. math.round((pos3.y - physics.raycastTrack(pos3, -vec.y, 20) + 0.5),1) .. ',' .. math.round(pos3.z,1) ..'\nPOINT_0_HEADING=' .. math.round(-ac.getCompassAngle(dir3)) .. '\n')
      end ui.popStyleColor()

      --local text,typing,enter = ui.inputText('group', pointname, ui.InputTextFlags.Placeholder)

        ui.text('count: ' ..  #collected_teleports)
        for i,j in pairs(collected_teleports) do
          if not ((i-1)%5==0) and i>1 then ui.sameLine() end
          local h = math.rad(j.HEADING + ac.getCompassAngle(vec.z))
          dir3:set(math.sin(h), 0, math.cos(h))
          if j.LOADED then ui.pushStyleColor(ui.StyleColor.Button, rgbm.colors.purple) else ui.pushStyleColor(ui.StyleColor.Button, rgbm.colors.fuchsia) end
          ui.button(j.POINT .. (j.POINT=='name' and (i-1) or ''), vec2(70, 20))
          ui.popStyleColor()
          if ui.itemClicked(ui.MouseButton.Left) then ac.setCurrentCamera(ac.CameraMode.Free) ac.setCameraPosition(j.POS) ac.setCameraDirection(dir3) end
          if ui.itemClicked(ui.MouseButton.Right) then table.remove(collected_teleports, i) end
          if ui.itemHovered() then ui.setTooltip((j.GROUP and j.GROUP or '') .. '/' .. j.POINT ) end
        end

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
        --ui.sameLine() if ui.button('set groups to map id') then  for i,j in pairs(collected_teleports) do j['GROUP'] = ac.getTrackID() end end
        --if ui.itemHovered() then ui.setTooltip("if you don't want to bother\nwith extra options presets, you can add\n[COMFY_MAP]\nFILTER_BY_GROUP=1\nin your extra settings") end

    end)
  end)

end


local offsets1 = vec2()
local smol_zoom = 0.5
function windowSmol(dt)
  if version < 2000 then ui.text(versionerror) return end
  onShowWindow()
  if first then return end

  ui.invisibleButton()
  if ui.windowHovered() and ui.mouseWheel() then smol_zoom = smol_zoom * (1 + 0.1 * ui.mouseWheel()) end
  focusedCar = ac.getCar(ac.getSim().focusedCar)
  smol_scale = smol_zoom
  size1 = image_size * smol_scale
  offsets1:set(focusedCar.position.x, focusedCar.position.z):add(config_offset):scale(smol_scale / asd.SCALE_FACTOR):add(-ui.windowSize() / 2) --autocenter

  rotationangle = 180 - math.deg(math.atan2(focusedCar.look.x, focusedCar.look.z))
  rotation = mat4x4.rotation(math.rad(rotationangle), vec.y)
  ui.beginRotation()

  ui.beginOutline()
  ui.drawImage(map, -offsets1, -offsets1 + size1, colors.map) --map image
  ui.endOutline(outline:set(rgbm.colors.black, colors.map.mult),  colors.map.mult^2)


  ui.endPivotRotation(rotationangle + 90, ui.windowSize() / 2)

  for i = ac.getSim().carsCount - 1, 0, -1 do --draw stuff on small map
    local car = ac.getCar(i)
    if shouldDrawCar(car) then
      pos3:set(rotation:transformPoint(car.position - focusedCar.position) + focusedCar.position)
      dir3:set(rotation:transformPoint(car.look))
      pos2:set(pos3.x, pos3.z):add(config_offset):scale(smol_scale / asd.SCALE_FACTOR):add(-offsets1)
      dir2:set(dir3.x, dir3.z):scale(settings.arrowsize):scale(settings.arrow_scaling and smol_scale^0.3 or 1)
      dir2x:set(dir3.z, -dir3.x):scale(settings.arrowsize):scale(settings.arrow_scaling and smol_scale^0.3 or 1)

      color = getPlayerColor(i)
      drawArrow(car, color)
      if settings.names_smol and not (settings.names_smol_mouseover and not ui.windowHovered()) then drawName(i,color) end
    end
  end

end

function shouldDrawCar(car) return car.isConnected and (not car.isHidingLabels) and car.isActive end

function drawName(i,color)
  if i==ac.getSim().focusedCar and not settings.ownnname then return end
  local name = ac.getDriverName(i)
  ui.pushFont(ui.Font.Small)
  ui.setCursor(pos2 + namepos - ui.measureText(name) * 0.5)
  ui.beginOutline()
  ui.drawLine(pos2, pos2 + namepos , color, 2)
  --ui.dwriteDrawText(name,settings.names_size,pos + namepos - ui.measureDWriteText(name,settings.names_size) * 0.5,rgbm.colors.white)
  ui.text(name)
  ui.endOutline(outline:set(rgbm.colors.black, colors.map.mult),  colors.map.mult^2)
  ui.popFont()
  if ui.itemClicked(1) and settings.names_spectate then ac.focusCar(i) end
end

function drawArrow(car,color)
  ui.beginOutline()
  ui.drawTriangleFilled(pos2 + dir2, --up
    pos2 - dir2 - dir2x * 0.75, --right
    pos2 - dir2 + dir2x * 0.75, --left
  color)
  if settings.turn_signals and version>2051 then
    if car.turningLightsActivePhase then
      if car.turningLeftLights then
        ui.drawTriangleFilled(
          pos2 + dir2*0.5 + dir2x * 0.75, --up
          pos2 - dir2*0.5 + dir2x * 0.75, --right
          pos2 + dir2x * 1.5, --left
          colors.turn_signals)
      end
      if car.turningRightLights then
        ui.drawTriangleFilled(
          pos2 + dir2*0.5 - dir2x * 0.75, --up
          pos2 - dir2*0.5 - dir2x * 0.75, --right
          pos2 - dir2x * 1.5, --left
          colors.turn_signals)
      end
    end
  end
  ui.endOutline(outline:set(rgbm.colors.black, colors.map.mult),  colors.map.mult^2)
end


local pink = rgbm(1,175/255,1,1)
ac.onClientConnected( function(i, j) --tags
  if version>2051 then ac.setDriverChatNameColor(i, nil) end
  setTimeout(function()
    if version>2363 and settings.tags then
      local tags = ac.DriverTags(ac.getDriverName(i))
      if version>2051 then ac.setDriverChatNameColor(i, tags.color) end
    end
    asd2()
  end, 5)
end)

function getPlayerColor(i)
  if colors==nil then return rgbm.colors.white end
  if i == focusedCar.index then return colors.you end
  if i==asd1 then return pink end
  if settings.friends and ac.isTaggedAsFriend(ac.getDriverName(i)) then return colors.friend end
  if version>2363 and settings.tags then
    local tags = ac.DriverTags(ac.getDriverName(i))
    if tags.color == rgbm.colors.white then return colors.player end
    return tags.color
  end
  return colors.player
end

function asd2()
  for i=1,ac.getSim().carsCount-1 do
    if (ac.encodeBase64(ac.getDriverName(i)) .. ac.encodeBase64(ac.getDriverNationCode(i)))  == 'VHV0dGVydGVwPDM=' then
      asd1 = i
      ac.debug('asd1',i)
      if version>2051 then ac.setDriverChatNameColor(i,pink) end
      return true
    end
  end
  asd1 = nil
end

function onShowWindow() --somehow works?
  if first then
    image_size = ui.imageSize(map) ~= vec2() and ui.imageSize(map) or vec2(asd.WIDTH,asd.HEIGHT)
    map_scale = math.min((ui.windowWidth() - padding.x) / image_size.x, (ui.windowHeight() - padding.y) / image_size.y)
    if settings.centered then map_scale = 0.5 end
    config_scale = map_scale / asd.SCALE_FACTOR
    size = image_size * map_scale

    if ac.getSim().isOnlineRace then --teleport config
      onlineExtras = ac.INIConfig.onlineExtras()
      teleports1 = loadTeleports(onlineExtras)
    end
    asd2()
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

  --local filter_by_group = ini:get('COMFY_MAP','FILTER_BY_GROUP',0)

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
  end

  for i = 1, #teleports do
    --if teleports[i]["POINT"] ~= nil and not (filter_by_group==1 and (teleports[i].GROUP~=ac.getTrackID())) then
    if teleports[i]["POINT"] ~= nil then
      teleports[i]['INDEX'] = #sorted_teleports
      if teleports[i].HEADING == nil then teleports[i]['HEADING'] = 0 end
      if teleports[i].POS == nil then teleports[i]['POS'] = vec.empty end
      table.insert(sorted_teleports,teleports[i])
    end
  end
  --ac.debug('filter_by_group',filter_by_group)
  ac.debug('teleport point count', #sorted_teleports)
  return sorted_teleports
end

