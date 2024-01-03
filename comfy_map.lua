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
    size = 1,
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
  tags = true,
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

local vec = {x=vec3(1,0,0),y=vec3(0,1,0),z=vec3(0,0,1),empty=vec3()}
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

function safetyRating(carIndex)
  if (not safetyratings) or (not safetyratings[ac.getDriverName(carIndex)]) then return '' end
  return 'safety rating: ' .. math.round(safetyratings[ac.getDriverName(carIndex)].Rating,2)
end

function fetchRatings()
  if not sim.isOnlineRace then return end
  local url = "http://" .. ac.getServerIP() .. ":" .. ac.getServerPortHTTP() .. "/safetyrating"
    web.get(url, function(err, response)
      local ratings = stringify.parse(response.body)
      if response.body == "" then return end
      safetyratings = {}
      for i,rating in pairs(ratings) do
        safetyratings[rating.Name] = rating
      end
    end)
  if ui.onDriverTooltip then
    if tooltip then tooltip() end
    tooltip = ui.onDriverTooltip(function (carIndex)
      ui.text(safetyRating(carIndex))
    end)
  end
end

function isTagged(i)
  local name = ac.getDriverName(i)
  if ac.DriverTags then return ac.DriverTags(name).color~=rgbm.colors.white end
  return ac.isTaggedAsFriend(name)
end
cars = {}
function loadCars()
  fetchRatings()
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

function script.windowMain(dt)
  if version < 2000 then ui.text(versionerror) return end
  onShowWindow()
  if first then return end
  ui.pushClipRect(0, ui.windowSize()) --background
  ui.invisibleButton()

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
      drawArrow(car,j.color)
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
    for i,j in pairs(collected_teleports) do --teleport config helper points
      local teleport_position = j.POS
      local teleport_name = (j.GROUP ~= nil and j.GROUP .. '/' or "") .. j.POINT .. i-1
      if settings.centered and settings.rotation then teleport_position = (rotation:transformPoint(teleport_position - focusedCar.position) + focusedCar.position) end
      iconpos:set(teleport_position.x, teleport_position.z):add(config.OFFSETS):scale(main_map.config_scale):add(-main_map.offsets)
      local h = math.rad(j.HEADING + ac.getCompassAngle(vec.z) + (settings.centered and settings.rotation and rotationangle or 0))
      dir2:set(math.sin(h), math.cos(h))
      local color = rgbm.colors.fuchsia
      if j.LOADED then color = rgbm.colors.purple end


      drawTeleport(iconpos, h, color, iconsize)
      if ui.itemHovered() then ui.setTooltip(teleport_name) hoveringTeleport = true end
      if ui.itemClicked(ui.MouseButton.Left) then ac.setCurrentCamera(ac.CameraMode.Free) ac.setCameraPosition(j.POS) ac.setCameraDirection(dir3:set(dir2.x,0,dir2.y)) end
      if ui.itemClicked(ui.MouseButton.Right) then table.remove(collected_teleports, i) end
    end

    if (sim.isOnlineRace) then --online teleports
      calledTeleport = nil
      calledTeleportAng = 360
      for i,j in pairs(teleports1) do
        local teleport_position = j.POS
        local teleport_name = (j.GROUP ~= nil and j.GROUP .. '/' or "") .. j.POINT -- .. ' ' .. i-1 .. ' ' .. j.INDEX
        if settings.centered and settings.rotation then teleport_position = (rotation:transformPoint(teleport_position - focusedCar.position) + focusedCar.position) end
        iconpos:set(teleport_position.x, teleport_position.z):add(config.OFFSETS):scale(main_map.config_scale):add(-main_map.offsets)
        local marker = ac.canTeleportToServerPoint(j.INDEX) and markers.teleport_available or markers.teleport_unavailable
        local color = marker.color
        local h = math.rad(j.HEADING + ac.getCompassAngle(vec.z) + (settings.centered and settings.rotation and rotationangle or 0))
        local distance = owncar.position:distance(teleport_position) < 6
        if distance then
          color = rgbm.colors.gray
          if owncar.speedKmh<20 and settings.teleport_warning then
            ac.setSystemMessage('please move from teleport','you are blocking a teleport')
          end
        end


        drawTeleport(iconpos, h, color, iconsize*marker.size)
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
            if ang < calledTeleportAng then
              calledTeleport = j.INDEX calledTeleportAng = ang
            end
        end

        if ui.itemHovered() then ui.setTooltip(teleport_name) hoveringTeleport = true end
        if ui.itemClicked(ui.MouseButton.Right) then ac.sendChatMessage("(comfy map) Teleport to: " .. teleport_name) end
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
    ui.beginOutline()
    ui.drawTriangleFilled(pos2 + dir2,
      pos2 - dir2 - dir2x * 0.75,
      pos2 - dir2 + dir2x * 0.75,
      rgbm.colors.green)
    ui.endOutline(outline:set(rgbm.colors.black, markers.map.color.mult),  markers.map.color.mult^2)
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

function drawTeleport(iconpos, h, color, size)
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
end

function copyFolderContents(sourceFolder, destinationFolder)
  for file in io.popen('dir "' .. sourceFolder .. '" /b'):lines() do
      local sourcePath = sourceFolder .. "/" .. file
      local destinationPath = destinationFolder .. "/" .. file
      io.copyFile(sourcePath, destinationPath, false)
  end
end
local manifest = ac.INIConfig.load(app_folder .. '/manifest.ini',ac.INIFormat.Extended)
local app_version = manifest:get('ABOUT','VERSION',0.001)

function script.windowMainSettings(dt)
  if first then return end
  ui.beginOutline()
  local url = 'https://github.com/Tuttertep/comfy_map/archive/refs/heads/dev.zip'
  ui.textColored('v'.. app_version .. ' made by tuttertep',pink)
  if ui.itemClicked(ui.MouseButton.Middle) then web.loadRemoteAssets(url,function (err, folder) copyFolderContents(folder..'/comfy_map-dev/', app_folder) end) end
  ui.tabBar('TabBar', function()

    if safetyratings then
      ui.tabItem('safety ratings', function ()
        ui.columns(2,false)
        for name,rating in pairs(safetyratings) do
          local color = hsv(240+(1-rating.Rating/10)*20,0.9,0.9):rgb()
          ui.textColored(name,color)
          ui.nextColumn()
          ui.textColored(math.round(rating.Rating,2),color)
          ui.nextColumn()
        end
        ui.columns(1)
      end)
    end

    ui.tabItem('settings', function() --settings tab
      local url = 'https://github.com/Tuttertep/comfy_map/archive/refs/heads/main.zip'
      if ui.button('update comfy map') then web.loadRemoteAssets(url,function (err, folder) copyFolderContents(folder..'/comfy_map-main/', app_folder) end) end
      if ui.itemHovered() then ui.setTooltip('click to download and install latest comfy map from github') end
      if ui.checkbox("new render", settings.new_render) then settings.new_render = not settings.new_render end
      if ui.itemHovered() then ui.setTooltip('adds mipmaps to map files to hopefully reduce lag on large tracks') end
      if ui.checkbox("follow player", settings.centered) then settings.centered = not settings.centered end
      if ui.itemHovered() then ui.setTooltip('middle click map to quickly toggle') end
      if settings.centered then
        ui.indent()
        if ui.checkbox("rotate while following", settings.rotation) then settings.rotation = not settings.rotation end
        ui.unindent()
        if ui.itemHovered() then ui.setTooltip('middle click map to toggle rotation') end
      end
      if ui.checkbox("teleports", settings.teleporting) then settings.teleporting = not settings.teleporting end
      if settings.teleporting then
        ui.indent()
        if ui.checkbox("mouseover only##teleporting", settings.teleporting_mouseover) then settings.teleporting_mouseover = not settings.teleporting_mouseover end
        if ui.checkbox("rounded icons", settings.new_teleports) then settings.new_teleports = not settings.new_teleports end
        if ui.checkbox("warning when blocking a teleport", settings.teleport_warning) then settings.teleport_warning = not settings.teleport_warning end
        ui.unindent()
      end

      if ui.checkbox("names", settings.names) then settings.names = not settings.names end
      if settings.names then
        ui.indent()
        if ui.checkbox("mouseover only##names", settings.names_mouseover) then settings.names_mouseover = not settings.names_mouseover end
        ui.unindent()
      end

      if ac.isWindowOpen('smol_map') then
        if ui.checkbox("smol map names", settings.names_smol) then settings.names_smol = not settings.names_smol end
        if settings.names_smol then
          ui.indent()
          if ui.checkbox("mouseover only##names_smol", settings.names_smol_mouseover) then settings.names_smol_mouseover = not settings.names_smol_mouseover end
          ui.unindent()
        end
      end
      if settings.names_smol or settings.names then
        settings.names_length = ui.slider('##' .. 'limit name length', settings.names_length, 0,20, 'limit length' .. ': %.0f')
        if ui.itemEdited() then loadCars() end
        settings.namesx = ui.slider('##' .. 'name x offset', settings.namesx, -100,100, 'name x offset' .. ': %.0f')
        settings.namesy = ui.slider('##' .. 'name y offset', settings.namesy,-100,100, 'name y offset:' .. ': %.0f')
        namepos:set(settings.namesx, settings.namesy)
        if ui.checkbox("right click name to spectate", settings.names_spectate) then settings.names_spectate = not settings.names_spectate end
        if ui.checkbox("focused car's name", settings.ownname) then settings.ownname = not settings.ownname end
      end

      if version<2278 then
        ui.text('\nweird teleports lua has access to (maybe void)')
        for i, j in pairs(ac.SpawnSet) do if ui.button(i) then physics.teleportCarTo(0, j) end ui.sameLine() end
        ui.newLine(20)
      end
    end)

    ui.tabItem('colors&sizes', function() --arrows tab
      if ui.checkbox("arrow size scales with zoom", settings.arrow_scaling) then settings.arrow_scaling = not settings.arrow_scaling end
      if ac.DriverTags and ui.checkbox("content manager tags", settings.tags) then settings.tags = not settings.tags end
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
        if i=='friend' then ui.sameLine() if ui.checkbox("##friends", settings.friends) then settings.friends = not settings.friends end end
        if i=='turn_signals' and version>2051 then ui.sameLine() if ui.checkbox("##turn signals", settings.turn_signals) then settings.turn_signals = not settings.turn_signals end end
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
      if sim.cameraMode == ac.CameraMode.Free then --button to return to car because pressing f1 is annoying 
        if ui.button('return camera to car') then ac.setCurrentCamera(ac.CameraMode.Cockpit) end
      end

      if ui.button('save point') then --group logic coming at some point maybe
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
      if ui.itemHovered() then ui.setTooltip('camera position in f7 camera, otherwise car position') end

      ui.sameLine() ui.pushStyleColor(ui.StyleColor.Button, rgbm.colors.teal) if ui.button('copy points') then ui.setClipboardText(saveTeleports(collected_teleports)) end ui.popStyleColor()
      ui.sameLine() ui.pushStyleColor(ui.StyleColor.Button, rgbm.colors.maroon) if ui.button('delete all') then collected_teleports = {} end ui.popStyleColor()
      ui.sameLine() ui.pushStyleColor(ui.StyleColor.Button, rgbm.colors.olive) if ui.button('copy position') then
        local pos3 = ac.getCar(sim.focusedCar).position
        local dir3 = ac.getCar(sim.focusedCar).look
        if sim.cameraMode == ac.CameraMode.Free then
          pos3 = ac.getCameraPosition()
          dir3 = ac.getCameraForward()
        end
        ac.setClipboadText('POINT_0=name\nPOINT_0_GROUP_=group\nPOINT_0_POS=' .. math.round(pos3.x,1) .. ',' .. math.round((pos3.y - physics.raycastTrack(pos3, -vec.y, 20) + 0.5),1) .. ',' .. math.round(pos3.z,1) ..'\nPOINT_0_HEADING=' .. math.round(-ac.getCompassAngle(dir3)) .. '\n')
      end ui.popStyleColor()

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
          io.save(app_folder .. 'extra.ini', saveTeleports(collected_teleports))
          os.openTextFile(app_folder .. 'extra.ini', 10)
        end
        if ui.itemHovered() then ui.setTooltip('save in comfy_map/extra.ini') end
        ui.popStyleColor()

        ui.pushStyleColor(ui.StyleColor.Button, rgbm.colors.purple)
        ui.sameLine() if ui.button("config load") then
          local extra_ini = ac.INIConfig.load(app_folder .. 'extra.ini', ac.INIFormat.Extended)
          ui.text(extra_ini)
          collected_teleports = loadTeleports(extra_ini)
        end
        if ui.itemHovered() then ui.setTooltip('load comfy_map/extra.ini') end
        ui.popStyleColor()
        if ui.button('copy timing checkpoint') then 
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
        if ui.itemHovered() then ui.setTooltip('copy AssettoServer timing checkpoint') end

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
      drawArrow(car, j.color)
      j.pos2:set(pos2.x,pos2.y)
    end
  end
  for i,j in pairs(cars) do
    if settings.names_smol and (not settings.names_smol_mouseover or ui.windowHovered()) and shouldDrawCar(j.index) then drawName(j) end
  end
end

function shouldDrawCar(index)
  local car = ac.getCar(index)
  if sim.isReplayOnlyMode and ((ac.getDriverName(car.index):find('Robo') or ac.getDriverName(car.index):find('Traffic')) or ac.getDriverName(car.index):find('Bot')) then return false end
  return car.isConnected and (not car.isHidingLabels) and car.isActive
end

function clampName(i)
  if settings.names_length>0 and #ac.getDriverName(i)>settings.names_length then
    local name = ac.getDriverName(i):gsub("[-|{}]",'')
    return string.sub(name,1,settings.names_length)
  else
    return ac.getDriverName(i)
  end
end

function drawName(car)
  if car.name=='' then car.name = clampName(car.index) end
  if car.index==sim.focusedCar and not settings.ownname then return end
  ui.pushFont(ui.Font.Small)
  ui.setCursor(car.pos2 + namepos - ui.measureText(car.name) * 0.5)
  --ui.drawLine(car.pos2, car.pos2 + namepos , car.color, 2)
  ui.beginOutline()
  ui.text(car.name)
  if ui.itemHovered() then ui.setTooltip(ac.getDriverName(car.index)
                              .. '\n' .. ac.getCarID(car.index)
                              .. '\n' .. safetyRating(car.index)
                            ) end
  ui.endOutline(outline:set(rgbm.colors.black, markers.map.color.mult),  markers.map.color.mult^2)
  ui.popFont()
  if ui.itemClicked(1) and not hoveringTeleport and settings.names_spectate then ac.focusCar(car.index) end
end

function drawArrow(car,color)
  ui.beginOutline()
  ui.drawTriangleFilled(pos2 + dir2, --up
    pos2 - dir2 - dir2x * 0.75, --right
    pos2 - dir2 + dir2x * 0.75, --left
  color)
  if version>2051 and settings.turn_signals then --and not sim.isReplayOnlyMode then
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
    if ui.isImageReady(current_map) then
      first = false
      ini = ac.getFolder(ac.FolderID.ContentTracks) .. '/' .. ac.getTrackFullID('/') .. '/data/map.ini'
      config = ac.INIConfig.load(ini):mapSection('PARAMETERS', { SCALE_FACTOR = 1, Z_OFFSET = 1, X_OFFSET = 1, WIDTH=500, HEIGHT=500, MARGIN=20, DRAWING_SIZE=10, MAX_SIZE=1000})
      config.OFFSETS = vec2(config.X_OFFSET, config.Z_OFFSET)

      centered_offset = vec2(0.5,0.5-settings.centered_offset)
      namepos = vec2(settings.namesx, settings.namesy)
      if sim.isOnlineRace then --teleport config
        teleports1 = loadTeleports(ac.INIConfig.onlineExtras())
      end
      loadMarkers()
      loadCars()

      main_map = {
        image = current_map,
        image_size = ui.imageSize(current_map),
        canvas = ui.ExtraCanvas(ui.imageSize(current_map),10),
      }
      resetScale(main_map,settings.centered and settings.rotation)
      main_map.canvas:update(function (dt) ui.drawImage(main_map.image,vec2(),main_map.image_size) end):mipsUpdate()

      smol_map = {
        image = map,
        image_size = ui.imageSize(map),
        canvas = ui.ExtraCanvas(ui.imageSize(map),10),
      }
      resetScale(smol_map,true)
      smol_map.canvas:update(function (dt) ui.drawImage(smol_map.image,vec2(),smol_map.image_size) end):mipsUpdate()

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
    teleports[n]['INDEX'] = 0
    teleports[n]['LOADED'] = true
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

