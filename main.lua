
function lerp(a,b,t)
  return a * (1-t) + b * t
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

  -- route = (x, y, tstamp), (x, y, tstamp), ...
  -- enemy = wave_id, clock, hitpoints, routetime
  -- wave = enemy_type, route_id, end_clock, number + tdelta + xdelta + ydelta
  -- level = wave, wave, wave

routes = {}
routes[1] = {{1, 1 , 0, 5}, {0.5, 0, 5, 7}, {0.5, 0.7, 7, 10}, {0, 1, 10, 10}} -- '^'
enemy_types = {}

waves = {}
waves[1] = { enemy_type = 1, enemy_count = 3, route_id = 1, dx = 0, dy = 0 , dt = 0.1 }

function spawn_wave(wave_id)
  active_wave = waves[wave_id]
  active_wave.end_clock = routes[active_wave.route_id][ #routes[active_wave.route_id] ] [3]
  active_wave.enemies = {}
  local dx = 0
  local dy = 0
  local dt = 0
  for i = 1, active_wave.enemy_count do
    local e = {}
    e.hp = enemy_types[ active_wave.enemy_type ].hp
    e.clock = dt
    e.x = routes[active_wave.route_id][1][1]
    e.y = routes[active_wave.route_id][1][2]
    e.dx = dx
    e.dy = dy
    table.insert(active_wave.enemies, e)

    dx = dx + active_wave.dx
    dy = dy + active_wave.dy
    dt = dt - active_wave.dt
  end
end

function pos_on_route(route_id, t)
  if t < 0 then
    return 0, 0
  end
  for i, wp in ipairs(routes[route_id]) do
    if t >= wp[3] and t < wp[4] then
      -- this is wp1
      ax, ay = wp[1], wp[2]
      nextwp = routes[route_id][i+1]
      bx, by = nextwp[1], nextwp[2]

      x = lerp(ax, bx, inverseLerp(wp[3], nextwp[3], t))
      y = lerp(ay, by, inverseLerp(wp[3], nextwp[3], t))
      return x, y
    end
  end

  return 0.5, 0.5
end

function update_wave(dt)
  enemies_left = 0
  for _, enemy in ipairs(active_wave.enemies) do
    enemy.clock = enemy.clock + dt
    if enemy.clock >= 0 and enemy.clock < active_wave.end_clock then
      enemy.active = true
      enemy.x, enemy.y = pos_on_route(active_wave.route_id, enemy.clock)
      enemy.x = enemy.x * love.graphics.getWidth() + enemy.dx
      enemy.y = enemy.y * love.graphics.getHeight() + enemy.dy
    end

    if enemy.clock < active_wave.end_clock and enemy.hp > 0 then
      enemies_left = enemies_left + 1
    end
  end

  -- we're done with wave 1
  if enemies_left == 0 then
    spawn_wave (1)
  end
end

function draw_wave()
  spr = enemy_types[active_wave.enemy_type].img
  for _, enemy in ipairs(active_wave.enemies) do
    if enemy.active then
      love.graphics.draw(spr, enemy.x, enemy.y,0, 1, 1, spr:getWidth()/2, spr:getHeight()/2)
    end
  end
end

function love.load()
  love.window.setMode(0, 0, {fullscreen=true})


  bulletimg = love.graphics.newImage("sprites/bullet.png")
  bulletmid = bulletimg:getWidth() / 2

  -- enemies
  local enemy = {}
  enemy.img = love.graphics.newImage("sprites/enemy1.png")
  enemy.hp = 2
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

  update_wave(dt)

  -- update bullets
  for i, bullet in ipairs(bullets) do
    bullet.y = bullet.y + bullet.sy
    bullet.x = bullet.x + bullet.sx
    -- screen boundaries
    if bullet.y < 0 or bullet.y > love.graphics.getHeight() then
      bullet.sy = -bullet.sy
    end

    if bullet.x < 0 or bullet.x > love.graphics.getWidth() then
      bullet.sx = -bullet.sx
    end
  end

  -- update players
  for i, player in ipairs(players) do
    if love.keyboard.isDown(player.control.left) then
      player.sx = limit(player.sx - accelx * dt, termvelx)
    end

    if love.keyboard.isDown(player.control.right) then
      player.sx = limit(player.sx + accelx * dt, termvelx)
    end

    if love.keyboard.isDown(player.control.up) then
      player.sy = limit(player.sy - accelx * dt, termvely)
    end

    if love.keyboard.isDown(player.control.down) then
      player.sy = limit(player.sy + accelx * dt, termvely)
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
end

function love.draw()
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
