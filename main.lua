function lerp(a,b,t)
  return a * (1-t) + b * t
end

function tablerp(aa, bb, t)
  res = {}
  for i, v in pairs(aa) do
    res[i] = lerp(v, bb[i], t)
  end
  return res
end

function tabsum(aa, bb)
  res = {}
  for i, v in pairs(aa) do
    res[i] = v + bb[i]
  end
  return res
end

function inverseLerp(a, b, x)
  return (x-a)/(b-a)
end

-- Generate a random bright RGB color
local function generateRandomColor()
  local r = math.random(0, 255)
  local g = math.random(0, 255)
  local b = math.random(0, 255)

  -- Ensure the color is bright
  local brightness = (r + g + b) / 3
  if brightness < 128 then
    -- Increase the brightness by adding a random value
    local increase = math.random(0, 127)
    r = math.min(r + increase, 255)
    g = math.min(g + increase, 255)
    b = math.min(b + increase, 255)
  end

  return r, g, b
end

function limit(val, absmax)
  if val > absmax then
    return absbax
  elseif val < -absmax then
    return -absmax
  else
    return val
  end
end

players = {}
grav = 5 -- p/s/s
accelx = 5 -- p/s/s
termvelx = 25
termvely = 50
cooldown_time = 0.2 -- 10 bullets each second

bullets = {}
bullet_speed_x = 9

blips = {}

bgstars = {}
bgstarsnum = 100

  -- waypoint: time, x, y
  -- enriched waypoint: wp + eta + sx + sy
  -- route = (x, y, tstamp), (x, y, tstamp), ...
  -- enemy = wave_id, clock, hitpoints, routetime
  -- wave = enemy_type, route_id, end_clock, number + tdelta + xdelta + ydelta
  -- level = wave, wave, wave

function secondary_circle(t)
  res = {x=1 , y=1, r=0, sx=0, sy=0, kx=0, ky = 0}
  r=0.2
  per = 3
  ug = 2 * math.pi * t / per
  res.x = math.cos(ug) * r
  res.y = math.sin(ug) * r
  res.sx = 1 + math.sin(ug)
  return res
end

function secondary_nop(t)
  res = {x=0 , y=0, r=0, sx=0, sy=0, kx=0, ky = 0}
  return res
end

function route_diag(t)
  wp1 = {x=1 , y=1, r=0, sx=1, sy=1, kx=0, ky = 0}
  wp2 = {x=0 , y=0, r=100, sx=1, sy=1, kx=0, ky = 0}
  current_coord = wp1
  active = false
  if t >=0 and t < 10 then
    active = true
    current_coord = tablerp(wp1, wp2, t/10)
  end
  return active, current_coord
end

function route_diag2(t)
  wp1 = {x=1 , y=0, r=0, sx=1, sy=1, kx=0, ky = 0}
  wp2 = {x=0 , y=1, r=0, sx=1, sy=1, kx=0, ky = 0}
  current_coord = wp1
  active = false
  if t >=0 and t < 10 then
    active = true
    current_coord = tablerp(wp1, wp2, t/10)
  end
  return active, current_coord
end


routes = {}
routes[1] = { route_diag, secondary_circle }
routes[2] = { route_diag2, secondary_nop }
enemy_types = {}

waves = {}
waves[1] = { enemy_type = 3, enemy_count = 5, route_id = 2, dx = 0, dy = 0 , dt = 0.5 }
waves[2] = { enemy_type = 1, enemy_count = 3, route_id = 1, dx = 0, dy = 0 , dt = 0.1 }

function spawn_wave(wave_id)
  active_wave_id = wave_id
  active_wave = waves[wave_id]
  active_wave.enemies = {}
  local dx = 0
  local dy = 0
  local dt = 0
  for i = 1, active_wave.enemy_count do
    local e = {}
    e.hp = enemy_types[ active_wave.enemy_type ].hp
    e.half_width = enemy_types[ active_wave.enemy_type ].half_width
    e.half_height = enemy_types[ active_wave.enemy_type ].half_height

    e.clock = dt
    -- e.coord = routes[active_wave.route_id][1](0) +
    e.dx = dx
    e.dy = dy
    e.color = { love.math.colorFromBytes(generateRandomColor()) }
    table.insert(active_wave.enemies, e)

    dx = dx + active_wave.dx
    dy = dy + active_wave.dy
    dt = dt - active_wave.dt
  end
end

function update_wave(dt)
  enemies_left = 0
  for _, enemy in ipairs(active_wave.enemies) do
    enemy.clock = enemy.clock + dt
    enemy.active, enemy.coord = routes[active_wave.route_id][1](enemy.clock)
    enemy.coord = tabsum(enemy.coord, routes[active_wave.route_id][2](enemy.clock))
    if enemy.active then
      enemy.coord.x = enemy.coord.x * love.graphics.getWidth() + enemy.dx
      enemy.coord.y = enemy.coord.y * love.graphics.getHeight() + enemy.dy
      if enemy.hp > 0 then
        enemies_left = enemies_left + 1
      end

      -- update bullets
      for i, bullet in ipairs(bullets) do
        if math.abs(bullet.x - enemy.coord.x) < enemy.half_width and math.abs(bullet.y - enemy.coord.y) < enemy.half_height then
          bullet.DELETE = true
          enemy.DELETE = true
        end
      end
    end
  end

  -- we're done with wave 1
  if enemies_left == 0 then
    next_wave = active_wave_id + 1
    if next_wave > #waves then
      next_wave = 1
    end
    spawn_wave (next_wave)
  end
end

function draw_wave()
  spr = enemy_types[active_wave.enemy_type].img
  for i, enemy in ipairs(active_wave.enemies) do
    if enemy.active then
      if i == 1 then
        love.graphics.print('Number of bullets: '.. #bullets .. "\nNumber of enemies: " .. #active_wave.enemies)
      end
      love.graphics.setColor(enemy.color)
      love.graphics.draw(spr, enemy.coord.x, enemy.coord.y, enemy.coord.r, enemy.coord.sx, enemy.coord.sy, enemy.half_width, enemy.half_height, enemy.coord.kx, enemy.coord.ky)
      love.graphics.reset()
    end
  end
end

function love.load()
  love.graphics.setDefaultFilter( "nearest" )

  love.window.setMode(0, 0, {fullscreen=true})

  bulletimg = love.graphics.newImage("sprites/fireball.png")
  bulletmid = bulletimg:getWidth() / 2

  -- enemies
  local enemy = {}
  enemy.img = love.graphics.newImage("sprites/enemy1.png")
  enemy.hp = 2
  enemy.half_width = enemy.img:getWidth()/2
  enemy.half_height = enemy.img:getHeight()/2
  table.insert(enemy_types, enemy)

  local enemy = {}
  enemy.img = love.graphics.newImage("sprites/rob-charact.png")
  enemy.hp = 2
  enemy.half_width = enemy.img:getWidth()/2
  enemy.half_height = enemy.img:getHeight()/2
  table.insert(enemy_types, enemy)

  local enemy = {}
  enemy.img = love.graphics.newImage("sprites/enemy-ship.png")
  enemy.hp = 2
  enemy.half_width = enemy.img:getWidth()/2
  enemy.half_height = enemy.img:getHeight()/2
  table.insert(enemy_types, enemy)


  -- stars
  for i = 1, bgstarsnum do
    local star = {}
    star.x = math.random(0, love.graphics.getWidth())
    star.y = math.random(0, love.graphics.getHeight())
    star.sx = math.random(-10, -5)

    table.insert(bgstars, star)
  end

  -- preload all the blips
  -- Retrieve a list of files and directories in the specified directory
  local items = love.filesystem.getDirectoryItems("blips")

  -- Iterate over the items
  for _, item in ipairs(items) do
    local file_path = "blips/" .. item

    -- Check if the item is a file and ends with ".ogg"
    if love.filesystem.getInfo(file_path, "file") and item:match("%.ogg$") then
      blip = love.audio.newSource(file_path, "static")
      table.insert(blips, blip)
    end

    spawn_wave(1)
  end

  local player = {}
  player.x = 200
  player.y = 100
  player.sx = 0
  player.sy = 0
  player.color = { love.math.colorFromBytes(255, 100, 100) }
  player.cooldown_left = 0
  player.control = { left="a", right="d", up = "w", down = "s", fire = "space" }
  player.img = love.graphics.newImage("sprites/chop1.png")

  table.insert(players, player)

  local player = {}
  player.x = 600
  player.y = 200
  player.sx = 0
  player.sy = 0
  player.cooldown_left = 0
  player.color = { love.math.colorFromBytes(255, 255, 255) }
  player.control = { left="left", right="right", up = "up", down = "down", fire = "rctrl" }
  player.img = love.graphics.newImage("sprites/chop2.png")

  table.insert(players, player)

end

function love.update(dt)

  -- stars
  for _, star in ipairs(bgstars) do
    star.x = star.x + star.sx
    if star.x < 0 then
      star.x = love.graphics.getWidth()
      star.y = math.random(0, love.graphics.getHeight())
    end
  end


  -- update bullets
  for i, bullet in ipairs(bullets) do
    bullet.y = bullet.y + bullet.sy
    bullet.x = bullet.x + bullet.sx
    -- screen boundaries
    if bullet.y < 0 or bullet.y > love.graphics.getHeight() or bullet.x < 0 or bullet.x > love.graphics.getWidth() then
      bullet.DELETE = true
    end
  end

  update_wave(dt)

  -- update players
  for i, player in ipairs(players) do
    if love.keyboard.isDown(player.control.left) then
      player.sx = limit(player.sx - accelx * dt, termvelx)
    elseif love.keyboard.isDown(player.control.right) then
      player.sx = limit(player.sx + accelx * dt, termvelx)
    else
      if player.sx > 0 then
        player.sx = player.sx - accelx * dt
        if player.sx < 0 then
          player.sx = 0
        end
      else
        player.sx = player.sx + accelx * dt
        if player.sx > 0 then
          player.sx = 0
        end
      end
    end

    if love.keyboard.isDown(player.control.up) then
      player.sy = limit(player.sy - accelx * dt, termvely)
    elseif love.keyboard.isDown(player.control.down) then
      player.sy = limit(player.sy + accelx * dt, termvely)
    else
      if player.sy > 0 then
        player.sy = player.sy - accelx * dt
        if player.sy < 0 then
          player.sy = 0
        end
      else
        player.sy = player.sy + accelx * dt
        if player.sy > 0 then
          player.sy = 0
        end
      end
    end

    player.y = player.y + player.sy
    player.x = player.x + player.sx

    if love.keyboard.isDown(player.control.fire) and player.cooldown_left <= 0 then
      -- player.sx = limit(player.sx + accelx * dt, termvelx)

      local bullet = {}
      bullet.x = player.x
      bullet.y = player.y
      bullet.sx = player.sx + bullet_speed_x
      bullet.sy = player.sy
      -- bullet.color = player.color
      bullet.color = { love.math.colorFromBytes(generateRandomColor()) }
      table.insert(bullets, bullet)

      player.cooldown_left = cooldown_time

      -- random blip
      local randomIndex = math.random(#blips)
      local randomBlip = blips[randomIndex]
      randomBlip:play()
    end

    -- screen boundaries
    if player.y < 0 or player.y > love.graphics.getHeight() then
      player.sy = -player.sy
    end

    if player.x < 0 or player.x > love.graphics.getWidth() then
      player.sx = -player.sx
    end

    if player.cooldown_left > 0 then
      player.cooldown_left = player.cooldown_left - dt
    end
  end

  -- delete inactives

  for i = #bullets, 1, -1 do
    if bullets[i].DELETE then
      table.remove(bullets, i)
    end
  end

  for i = #active_wave.enemies, 1, -1 do
    if active_wave.enemies[i].DELETE then
      table.remove(active_wave.enemies, i)
    end
  end

end

function love.draw()
  -- set background color to #84C1EE (132, 193, 238)
  local r, g, b = love.math.colorFromBytes(32, 0, 32)
  love.graphics.clear(r, g, b, 1)

  -- love.graphics.print('sx: '.. players[1].sx)

  for _, star in ipairs(bgstars) do
    love.graphics.points(star.x, star.y)
  end

  for _, player in ipairs(players) do
    love.graphics.setColor(player.color)
    love.graphics.draw(player.img, player.x, player.y, 0, 1, 1, player.img:getWidth()/2, player.img:getHeight()/2)
    love.graphics.reset()
  end

  for _, bullet in ipairs(bullets) do
    love.graphics.setColor(bullet.color)
    love.graphics.draw(bulletimg, bullet.x, bullet.y, 0, 1, 1, bulletmid, bulletmid)
    love.graphics.reset()
  end

  draw_wave()
end
