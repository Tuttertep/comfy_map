---@diagnostic disable: undefined-global, undefined-field, missing-parameter, need-check-nil, missing-return, param-type-mismatch, lowercase-global, redundant-value, cast-local-type,duplicate-set-field
--made by tuttertep
--i'm already sorry if you read this because everything below is a disaster 😭

--local gcSmooth = 0
--local gcRuns = 0
--local gcLast = 0
--function runGC()
--  local before = collectgarbage('count')
--  collectgarbage()
--  gcSmooth = math.applyLag(gcSmooth, before - collectgarbage('count'), gcRuns < 50 and 0.9 or 0.995, 0.05)
--  gcRuns = gcRuns + 1
--  gcLast = math.floor(gcSmooth * 100) / 100
--end
--function printGC()
--  ac.debug("Runtime | collectgarbage", gcLast .. " KB")
--end

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
  new_render = true,
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
}
local settings = ac.storage(defaults)

local markers = {}


function loadMarkers()
    markers = stringify.parse(settings.markers)
    if markers.you==nil then
      markers = stringify.parse(default_colors)
    end
end

function saveMarkers(m)
  settings.markers = stringify(m)
  loadCars()
end

local owncar, focusedCar, sim = ac.getCar(0), ac.getCar(0), ac.getSim()
local first = true
local versionerror = "requires csp version 1.78 or newer (this message is displayed when the version id is below 2000)"
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
function getPlayerColor(i)
  if i==asd1 then
    if ac.setDriverChatNameColor then ac.setDriverChatNameColor(i,pink) end
    return pink,markers.friend.size
  end
  if i == focusedCar.index then return markers.you.color, markers.you.size end
  if settings.friends and ac.isTaggedAsFriend(ac.getDriverName(i)) then return markers.friend.color, markers.friend.size end
  if ac.DriverTags and settings.tags then
    local tags = ac.DriverTags(ac.getDriverName(i))
    if tags.color~=rgbm.colors.white then return tags.color, markers.friend.size end
  end
  return markers.player.color,markers.player.size
end

local margin = vec2(5,6)
local marginx,marginy = vec2(margin.x,0),vec2(0,margin.y)
function check(i)
  if i==0 then return end
  if ac.DriverTags and ac.DriverTags(ac.getDriverName(i)).color==pink then ac.setDriverChatNameColor(i,nil) end
  if (ac.encodeBase64(ac.getDriverName(i)) .. ac.encodeBase64(ac.getDriverNationCode(i)))  == 'VHV0dGVydGVwPDM=' then
    asd1 = i
    if ui.onDriverNameTag then
      nametag = ui.onDriverNameTag(false,_, function (car)
        if car.index==asd1  then
          ui.drawRectFilled(vec2.tmp():set(0,0),ui.windowSize(),pink*0.6)
          ui.drawRectFilled(margin,ui.windowSize()-margin,rgbm.colors.black)
          ui.drawQuadFilled(margin,(ui.windowSize())*vec2.tmp():set(0.08,0)+margin,(ui.windowSize()*vec2.tmp():set(0.05,1))+marginx-marginy,(ui.windowSize()*vec2.tmp():set(0,1))+marginx-marginy,pink)
          ui.drawQuadFilled(margin,(ui.windowSize())*vec2.tmp():set(0.05,0)+margin,(ui.windowSize()*vec2.tmp():set(0.02,1))+marginx-marginy,(ui.windowSize()*vec2.tmp():set(0,1))+marginx-marginy,rgbm.colors.purple)
          ui.pushFont(ui.Font.Title)
          ui.setCursor(ui.windowSize()*vec2.tmp():set(0.11,0.05))
          ui.text(ac.getDriverName(car.index))
          ui.setCursor(ui.windowSize()*vec2.tmp():set(0.88,0)+marginy)
          --ui.image("icon.png",vec2(50,50))
          ui.text('❤')
          ui.popFont()
        end
      end)
    end
  end
end

function shouldDrawCar(index)
  local car = ac.getCar(index)
  return car.isConnected and (not car.isHidingLabels) and car.isActive
end

function isTagged(i)
  local name = ac.getDriverName(i)
  if ac.DriverTags then return ac.DriverTags(name).color~=rgbm.colors.white end
  return ac.isTaggedAsFriend(name)
end
cars = {}
function loadCars()
  cars = {}
  asd1 = nil
  if nametag then nametag() end
  for i=0, sim.carsCount-1 do
    check(i)
    table.insert(cars,{index = i,name = "",pos2=vec2()})
  end
  table.sort(cars, function (a,b)
    if a.index*b.index==0 then return b.index==0 end
    if isTagged(a.index) then return false end
    if isTagged(b.index) then return true end
  end)
end

if ac.accessAppWindow then
  comfyMainWindow = ac.accessAppWindow('IMGUI_LUA_comfy map_main')
  comfySmolWindow = ac.accessAppWindow('IMGUI_LUA_comfy map_smol_map')
  --for i,j in pairs(ac.getAppWindows()) do print(j.name) end --debug
end
function vec2Inside(point,square) return point.x>0 and point.y>0 and point.x<square.x and point.y<square.y end

function script.windowMain(dt)
  if version < 2000 then ui.text(versionerror) return end
  onShowWindow()
  if first then return end
  local windowPos = ui.windowPos()
  local screenSize = ac.getUI().windowSize
  if ac.accessAppWindow and not vec2Inside(windowPos,screenSize) then
    comfyMainWindow:move(vec2(100,100))
  end
  ui.pushClipRect(0, ui.windowSize()) --background
  ui.invisibleButton()

  --runGC()
  --printGC()
  if windowHovered then --zoom&drag&centering&reset
    if ac.getUI().mouseWheel ~= 0 then
      if (ac.getUI().mouseWheel < 0 and (main_map.size>ui.windowSize()*0.97)) or ac.getUI().mouseWheel > 0 then
        local old = main_map.size
        main_map.scale = main_map.scale * (1 + math.sign(ac.getUI().mouseWheel) * 0.15)
        main_map.size = main_map.image_size * main_map.scale
        main_map.config_scale = main_map.scale / config.SCALE_FACTOR
        main_map.offsets = main_map.offsets + (main_map.size - old) * (main_map.offsets + ui.mouseLocalPos()) / old -- DON'T touch, powered by dark magic
      else
        resetScale(main_map)
      end
    end
    if ui.mouseClicked(2) then --toggle centering with middle click
      if settings.centered then resetScale(main_map) end
      settings.centered = not settings.centered
    end
  end

  focusedCar = ac.getCar(sim.focusedCar)

  drawMap(main_map, settings.centered, settings.rotation)

  for i,j in pairs(cars) do
    local car = ac.getCar(j.index)
    if shouldDrawCar(j.index) then
      j.color, j.size = getPlayerColor(j.index)
      pos3:set(car.position)
      dir3:set(car.look)
      if settings.centered and settings.rotation then
        pos3 = rotation:transformPoint(car.position - focusedCar.position) + focusedCar.position
        dir3 = rotation:transformPoint(car.look)
      end
      pos2:set(pos3.x, pos3.z):add(config.OFFSETS):scale(main_map.config_scale):add(-main_map.offsets)
      dir2:set(dir3.x, dir3.z):scale(settings.arrow_scaling and main_map.scale^0.3 or 1):scale(settings.arrowsize):scale(j.size)
      dir2x:set(dir3.z, -dir3.x):scale(settings.arrow_scaling and main_map.scale^0.3 or 1):scale(settings.arrowsize):scale(j.size)
      --for k=0,3 do ui.drawCircleFilled(vec2.tmp():set(owncar.wheels[k].position.x,owncar.wheels[k].position.z):add(config.OFFSETS):scale(config_scale):sub(offsets),5,rgbm.colors.red) end
      drawArrow(car,j.color,settings.turn_signals)
      j.pos2:set(pos2.x,pos2.y)

    end
  end
  for i,j in pairs(cars) do
    if shouldDrawCar(j.index) then
      if settings.names and (not settings.names_mouseover or windowHovered) then drawName(j) end
    end
  end


  if settings.teleporting and (not settings.teleporting_mouseover or windowHovered) then --teleports
    hoveringTeleport = false
    calledTeleport = nil
    calledTeleportAng = 360

    for i,j in pairs(collected_teleports) do --teleport config helper points
      drawTeleport(j,i)
    end
    if (sim.isOnlineRace) then --online teleports
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
    pos3:set(pos2.x, raycastheight-initialray+3, pos2.y)

    if allow then
      if sim.cameraMode == ac.CameraMode.Free then --freecam stuff
        ac.setCameraPosition(pos3)
      elseif owncar.physicsAvailable then
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


function checkTeleportAvailability(teleport)
  for i=0, sim.carsCount-1 do
    if ac.getCar(i).position:distance(teleport.POS)<6 then
      return ac.getCar(i):driverName()
    end
  end
end

function teleportAsText(i,name,group,pos,heading)
  group = group and ('POINT_' .. i .. '_GROUP= ' .. group .. '\n') or ''
  return 'POINT_' .. i .. '= ' .. name .. (name=='name' and (i-1) or '') .. '\n'
      .. 'POINT_' .. i .. '_POS= ' .. math.round(pos.x,1) .. ',' .. math.round(pos.y,1) .. ',' .. math.round(pos.z,1) .. '\n'
      .. 'POINT_' .. i .. '_HEADING= ' .. heading .. '\n'
      .. group
end

function dir3FromHeading(heading)
    local h = math.rad(heading + ac.getCompassAngle(vec.z))
    return vec3(math.sin(h), 0, math.cos(h))
end

function headingFromDir3(dir)
    return math.round(-ac.getCompassAngle(dir))
end

function drawTeleport(j,index)
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
    local link_text = "(comfy map) Teleport to: " .. teleport_name
    local occupied = checkTeleportAvailability(j)
    if occupied then link_text = link_text .. ' (blocked by: @' .. occupied .. ')' end
    if ui.itemClicked(ui.MouseButton.Right) then ac.sendChatMessage(link_text) end
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

local manifest = ac.INIConfig.load(app_folder .. '/manifest.ini',ac.INIFormat.Extended)
local app_version = manifest:get('ABOUT','VERSION',0.001)

function comfyUpdate(branch)
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

function coloredButton(name,color,size,tooltip)
  if type(color)=="string" then tooltip = color color = nil end
  if type(size)=="string" then tooltip = size size = nil end
  if color then ui.pushStyleColor(ui.StyleColor.Button, color) end
  local button = ui.button(name,size or vec2())
  if tooltip and ui.itemHovered() then ui.setTooltip(tooltip) end
  if color then ui.popStyleColor() end
  return button
end

function ccheckbox(name,setting,color,tooltip)
  if type(color)=="string" then tooltip = color color = nil end
  if ui.checkbox(name, settings[setting]) then settings[setting] = not settings[setting] end
  if tooltip and ui.itemHovered() then ui.setTooltip(tooltip) end
end

function script.windowMainSettings(dt)
  if first then return end
  ui.beginOutline()
  ui.textColored('v'.. app_version .. ' made by tuttertep',pink)
  if ui.itemClicked(ui.MouseButton.Middle) and ui.hotkeyCtrl() then comfyUpdate('dev') end -- hidden dev branch button
  ui.tabBar('TabBar', function()

    ui.tabItem('settings', function() --settings tab
      if coloredButton('update comfy map','click to download and install latest comfy map from github') then comfyUpdate('main') end -- update button
      ccheckbox('new render', 'new_render', 'adds mipmaps to map files to hopefully reduce lag on large tracks')
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

      ccheckbox("names", 'names')
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
          ui.setNextItemWidth(120)
          j.size = ui.slider('##' .. i .. 'size', j.size, 0,2, 'size' .. ': %.2f')
          if ui.itemEdited() then changed = true end
        end
        if i=='friend' then ui.sameLine() ccheckbox("##friends", 'friends') end
        if i=='turn_signals' and version>2051 then ui.sameLine() ccheckbox("##turn signals", 'turn_signals', 'signals on main') ui.sameLine() ccheckbox('##turn signals_smol','turn_signals_smol','signals on smol') end
        if i=='map' then
          ui.setNextItemWidth(120)
          settings.centered_zoom, changedzoom = ui.slider('##' .. 'default zoom', settings.centered_zoom, 0.1, 2, 'default zoom' .. ': %.1f')
          if changedzoom then smol_map.scale = settings.centered_zoom end
        end
        ui.nextColumn()
      end

      if ui.button('reset settings') then
        markers = stringify.parse(default_colors)
        for i,j in pairs(defaults) do
          settings[i] = j
        end
        changed = true
      end
      ui.columns(1)

      if changed then
        saveMarkers(markers)
      end
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
          if ui.button('return camera to car') then ac.setCurrentCamera(ac.CameraMode.Cockpit) end
        end

    end)
  end)
  ui.endOutline(rgbm.colors.black)
end

function resetScale(map,zoomed)
  local extra_space = ui.windowSize()*0.01
  map.offsets = -padding - extra_space
  map.image_size = ui.imageSize(map.image) or vec2(config.WIDTH,config.HEIGHT)
  local windowSize = ui.windowSize()-padding-extra_space*2
  map.scale = math.min(windowSize.x / map.image_size.x, windowSize.y / map.image_size.y)
  if zoomed then map.scale = settings.centered_zoom end
  map.size = map.image_size * map.scale
  map.config_scale = map.scale / config.SCALE_FACTOR

end


function drawMap(map,centered,rotate)
  if centered then --center on car and rotate
    map.offsets:set(focusedCar.position.x, focusedCar.position.z):add(config.OFFSETS):scale(map.scale / config.SCALE_FACTOR):add(-ui.windowSize()*centered_offset) --autocenter

    if rotate then
      rotationangle = 180 - math.deg(math.atan2(focusedCar.look.x, focusedCar.look.z))
      rotation = mat4x4.rotation(math.rad(rotationangle), vec.y)
      ui.beginRotation()
    end
  end

  ui.beginOutline()
  if settings.new_render then
    ui.drawImage(map.canvas, -map.offsets, -map.offsets + map.size, markers.map.color) --map image
  else
    ui.drawImage(map.image, -map.offsets, -map.offsets + map.size, markers.map.color) --map image
  end
  ui.endOutline(outline:set(rgbm.colors.black, markers.map.color.mult),  markers.map.color.mult^2)


  if centered and rotate then ui.endPivotRotation(rotationangle + 90, ui.windowSize()*centered_offset) end

end

function windowSmol(dt)
  if version < 2000 then ui.text(versionerror) return end
  onShowWindow()
  if first then return end

  local windowPos = ui.windowPos()
  local screenSize = ac.getUI().windowSize
  if ac.accessAppWindow and not vec2Inside(windowPos,screenSize) then
    comfySmolWindow:move(vec2(100,100))
  end

  ui.invisibleButton()
  if ui.windowHovered() and ui.mouseWheel() then
    smol_map.scale = smol_map.scale * (1 + 0.1 * ui.mouseWheel())
    smol_map.size = smol_map.image_size*smol_map.scale
  end
  focusedCar = ac.getCar(sim.focusedCar)

  drawMap(smol_map,true,true)

  for i,j in pairs(cars) do  --draw stuff on small map
    local car = ac.getCar(j.index)
    if shouldDrawCar(j.index) then
      j.color, j.size = getPlayerColor(j.index)
      pos3:set(rotation:transformPoint(car.position - focusedCar.position) + focusedCar.position)
      dir3:set(rotation:transformPoint(car.look))
      pos2:set(pos3.x, pos3.z):add(config.OFFSETS):scale(smol_map.scale / config.SCALE_FACTOR):add(-smol_map.offsets)
      dir2:set(dir3.x, dir3.z):scale(settings.arrow_scaling and smol_map.scale^0.3 or 1):scale(settings.arrowsize_smol):scale(j.size)
      dir2x:set(dir3.z, -dir3.x):scale(settings.arrow_scaling and smol_map.scale^0.3 or 1):scale(settings.arrowsize_smol):scale(j.size)
      drawArrow(car, j.color,settings.turn_signals_smol)
      j.pos2:set(pos2.x,pos2.y)
    end
  end
  for i,j in pairs(cars) do
    if settings.names_smol and (not settings.names_smol_mouseover or ui.windowHovered()) and shouldDrawCar(j.index) then drawName(j) end
  end
end

function clampName(i)
  if settings.names_length>0 and #ac.getDriverName(i)>settings.names_length then
    local name = ac.getDriverName(i):gsub("[-|(){}]",'')
    return string.sub(name,1,settings.names_length)
  else
    return ac.getDriverName(i)
  end
end

function drawName(car)
  if #car.name==0 then car.name = clampName(car.index) end
  if car.index==sim.focusedCar and not settings.ownname then return end
  ui.pushFont(ui.Font.Small)
  ui.setCursor(car.pos2 + namepos - ui.measureText(car.name) * 0.5)
  --ui.drawLine(car.pos2, car.pos2 + namepos , car.color, 2)
  ui.beginOutline()
  ui.text(car.name)
  if ui.itemHovered() then ui.setTooltip(ac.getDriverName(car.index)
                              .. '\n' .. ac.getCarID(car.index)
                              .. '\n' .. math.round(ac.getCar(car.index).speedKmh,-1) .. ' km/h'
                            ) end
  ui.endOutline(outline:set(rgbm.colors.black, markers.map.color.mult),  markers.map.color.mult^2)
  ui.popFont()
  if ui.itemClicked(1) and not hoveringTeleport and settings.names_spectate then ac.focusCar(car.index) end
end

function drawArrow(car,color,signals)
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

function onShowWindow() --somehow works?
  if first then
    if version < 2000 then return end
    map_mini = ac.getFolder(ac.FolderID.ContentTracks) .. '/' .. ac.getTrackFullID('/') .. '/map_mini.png'
    map = ac.getFolder(ac.FolderID.ContentTracks) .. '/' .. ac.getTrackFullID('/') .. '/map.png'
    ui.decodeImage(map_mini)
    ui.decodeImage(map)
    current_map = io.exists(map_mini) and map_mini or  map
    ui.text('map file loading or missing')
    if (not io.exists(map_mini) and ui.isImageReady(map)) or (io.exists(map_mini) and ui.isImageReady(map_mini) and ui.isImageReady(map) ) then
      first = false
      ini = ac.getFolder(ac.FolderID.ContentTracks) .. '/' .. ac.getTrackFullID('/') .. '/data/map.ini'
      config = ac.INIConfig.load(ini):mapSection('PARAMETERS', { SCALE_FACTOR = 1, Z_OFFSET = 1, X_OFFSET = 1, WIDTH=500, HEIGHT=500, MARGIN=20, DRAWING_SIZE=10, MAX_SIZE=1000})
      config.OFFSETS = vec2(config.X_OFFSET, config.Z_OFFSET)

      centered_offset = vec2(0.5,0.5-settings.centered_offset)
      namepos = vec2(settings.namesx, settings.namesy)
      if sim.isOnlineRace then --teleport config
        teleports1 = loadTeleports(ac.INIConfig.onlineExtras(),true)
      end
      loadMarkers()
      loadCars()

      main_map = {
        image = current_map,
        image_size = ui.imageSize(current_map),
        canvas = ui.ExtraCanvas(ui.imageSize(current_map),10),
      }
      resetScale(main_map,settings.centered and settings.rotation)
      main_map.canvas:update(function (dt)
        --ui.beginOutline()
        ui.drawImage(main_map.image,vec2(),main_map.image_size)
        --ui.endOutline(rgbm.colors.black)
        --local ref = ac.emptySceneReference()
        --local meshes = ac.findMeshes('geo_saku_08_01')
        --ac.debug('asd',meshes)
        --for i=1, #meshes do
        --  meshes:at(i,ref)
        --  local pos = ref:getPosition()-- + ref:getParent():getPosition()
        --  print(ref:makeIntersectionWith())
        --  vec2.tmp():set(pos.x, pos.z):add(config.OFFSETS):scale(1/config.SCALE_FACTOR)
        --  ui.drawCircleFilled(vec2.tmp(),500,rgbm.colors.green)
        --end
        --if ac.hasTrackSpline() then
        --  for i=0,1,0.001 do
        --    local start_line = ac.trackProgressToWorldCoordinate(i)
        --    vec2.tmp():set(start_line.x, start_line.z):add(config.OFFSETS):scale(1/config.SCALE_FACTOR)
        --    ui.drawCircleFilled(vec2.tmp(),10,rgbm.colors.red)
        --  end
        --  --owncar.pitTransform.position
        --  local start_line = ac.trackProgressToWorldCoordinate(0)
        --  local start_line1 = start_line + (ac.trackProgressToWorldCoordinate(0.01) - start_line):normalize()*10
        --  iconpos:set(start_line.x, start_line.z):add(config.OFFSETS):scale(1/config.SCALE_FACTOR)
        --  vec2.tmp():set(start_line1.x, start_line1.z):add(config.OFFSETS):scale(1/config.SCALE_FACTOR)
        --  ui.beginOutline()
        --  ui.drawLine(iconpos,vec2.tmp(),rgbm.colors.cyan,30)
        --  ui.endOutline(rgbm.colors.black)
        --end
      end)
      smol_map = {
        image = map,
        image_size = ui.imageSize(map),
        canvas = ui.ExtraCanvas(ui.imageSize(map),10),
      }
      resetScale(smol_map,true)
      smol_map.canvas:update(function (dt) ui.drawImage(smol_map.image,vec2(),smol_map.image_size) end)
    end
  end
end

ac.onClientConnected( function(i, j) -- reload cars when someone joins to sort friends
  setTimeout(function ()
    if ac.setDriverChatNameColor then ac.setDriverChatNameColor(i,nil) end
    loadCars() end, 5)
end)
setTimeout(function () loadCars() end, 5)

function saveTeleports(collected_teleports)
  local collected_teleports_string = '[TELEPORT_DESTINATIONS]\n'
  for i,j in pairs(collected_teleports) do
    collected_teleports_string = collected_teleports_string .. teleportAsText(i-1,j.POINT,j.GROUP,j.POS,j.HEADING) .. '\n'
  end
  return collected_teleports_string
end

function loadTeleports(ini,online)
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

