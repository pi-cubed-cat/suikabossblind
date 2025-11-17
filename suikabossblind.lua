local window_width, window_height = love.window.getMode()

function suika_load()
  do_suika = false
  love.physics.setMeter(64) --the height of a meter our worlds will be 64px
  suikaworld = love.physics.newWorld(0, 9.81*64, true) --create a suikaworld for the bodies to exist in with horizontal gravity of 0 and vertical gravity of 9.81
  suikaworld:setCallbacks(beginContact)

  objects = {} -- table to hold all our physical objects

  indicator = { --drop indicator
    x = window_width/2,
    y = window_height*3/4 - 600
  }
  box_width = 400 --default: 400
  num_balls = 0
  drop_buffer = false
  next_rank = math.random(1,5)
  next_rank_queue = {math.random(1,5), math.random(1,5), math.random(1,5)}
  do_merging = true
  drop_wait_time = 0
  suika_score = 0
  suika_gameover = false

  --ground
  objects.ground = {}
  objects.ground.body = love.physics.newBody(suikaworld, window_width/2, window_height*3/4) --remember, the shape (the rectangle we create next) anchors to the body from its center, so we have to move it to (650/2, 650-50/2)
  objects.ground.shape = love.physics.newRectangleShape(box_width, 25) --make a rectangle with a width of arg1 and a height of arg2
  objects.ground.fixture = love.physics.newFixture(objects.ground.body, objects.ground.shape) --attach shape to body

  --leftwall  
  objects.leftwall = {}
  objects.leftwall.body = love.physics.newBody(suikaworld, window_width/2 - (box_width/2 + 12.5), window_height*3/4 - 475/2)
  objects.leftwall.shape = love.physics.newRectangleShape(25, 500)
  objects.leftwall.fixture = love.physics.newFixture(objects.leftwall.body, objects.leftwall.shape)

  --rightwall  
  objects.rightwall = {}
  objects.rightwall.body = love.physics.newBody(suikaworld, window_width/2 + (box_width/2 + 12.5), window_height*3/4 - 475/2) 
  objects.rightwall.shape = love.physics.newRectangleShape(25, 500)
  objects.rightwall.fixture = love.physics.newFixture(objects.rightwall.body, objects.rightwall.shape)

  --ball
  objects.balls = {}

  --initial graphics setup
  --love.graphics.setBackgroundColor(0.41, 0.53, 0.97) --set the background color to a nice blue
  --love.window.setMode(650, 650) --set the window dimensions to 650 by 650 with no fullscreen, vsync on, and no antialiasing
  Ball = Object:extend()

  function disable_suika()
    do_suika = false
  end

  function suika()
    do_suika = true
  end

  function reset_suika()
    suika_score = 0
    suika_gameover = false
    for i = #objects.balls, 1, -1 do
      objects.balls[i].body:destroy()
      table.remove(objects.balls, i)
    end
    next_rank = math.random(1,5)
    next_rank_queue = {math.random(1,5), math.random(1,5), math.random(1,5)}
  end

  function Ball:init(x,y,fixed_rank)
    self.body = love.physics.newBody(suikaworld, x, y, "dynamic")
    self.rank = fixed_rank or next_rank
    self.shape = love.physics.newCircleShape( 10*self.rank)
    self.fixture = love.physics.newFixture(self.body, self.shape, 1)
    self.fixture:setRestitution(0.1)
    self.fixture:setUserData(self)
    self.merge_target = nil
    self.remove = false
  end

end

  function beginContact(a, b, coll)
    local x, y = coll:getNormal()
    local objA = a:getUserData()
    local objB = b:getUserData()

    if objA and objB and objA.rank and objB.rank then
      if objA.rank == objB.rank and not objA.merge_target and not objB.merge_target and not objA.dont_prod then
        objA.merge_target = objB
        objB.merge_target = objA
        objB.dont_prod = true
        --objA.body:applyForce(x, y*1000*(objA.rank))
        --objB.body:applyForce(-x, -y*1000*(objB.rank))
      elseif objA.body:getY() + objA.rank * 10 < window_height*3/4 - 500 + 12.5 then
        suika_gameover = true
        if G.GAME.blind and G.GAME.blind.config.blind.key == 'bl_suikabb_melon' then
          G.E_MANAGER:add_event(Event({
              trigger = "immediate",
              func = function()
                G.STATE = G.STATES.HAND_PLAYED
                G.STATE_COMPLETE = true
                end_round()
                return true
              end,
          }))
        end
      end
    end
  end

function update_suika(dt)
  drop_wait_time = drop_wait_time + dt
  if not suika_gameover then
    suikaworld:update(dt) --this puts the suikaworld into motion
  end
  if love.keyboard.isDown("right") then --press the right arrow key to push the ball to the right
    indicator.x = indicator.x + 200 * dt
    if indicator.x > window_width/2 + box_width/2 then
      indicator.x = window_width/2 + box_width/2
    end
  end
  if love.keyboard.isDown("left") then --press the left arrow key to push the ball to the left
    indicator.x = indicator.x - 200 * dt
    if indicator.x < window_width/2 - box_width/2 then
      indicator.x = window_width/2 - box_width/2
    end
  end
  if love.keyboard.isDown("down") and drop_buffer == false and drop_wait_time > 0.8 then --press the up arrow key to set the ball in the air
    num_balls = num_balls + 1
    drop_buffer = true 
    drop_wait_time = 0
    if -1*next_rank*10 + indicator.x < window_width/2 - box_width/2 + 12.5 then
      indicator.x = next_rank*10 + window_width/2 - (box_width/2 - 5)
    elseif next_rank*10 + indicator.x > window_width/2 + box_width/2 - 12.5 then
      indicator.x = -1*next_rank*10 + window_width/2 + (box_width/2 - 5)
    end
    table.insert(objects.balls, Ball(indicator.x, indicator.y))
    indicator.x = indicator.x + (math.random() + 0.5) / 50
    next_rank = next_rank_queue[1]
    table.remove(next_rank_queue, 1)
    next_rank_queue[#next_rank_queue+1] = math.random(1,5)
    --objects.ball.body:setLinearVelocity(0, 0) --we must set the velocity to zero to prevent a potentially large velocity generated by the change in position
  elseif not love.keyboard.isDown("up") then
    drop_buffer = false
  end

  for k, v in ipairs(objects.balls) do
    if v.merge_target then
      --v.shape = nil
      --v.merge_target.shape = nil
      v.fixture:setMask(1)
      v.merge_target.fixture:setMask(1)
      local delta_x, delta_y = (v.body:getX() - v.merge_target.body:getX()), (v.body:getY() - v.merge_target.body:getY())
      local distance = math.sqrt( ( delta_x )^2 + ( delta_y )^2 )
      if distance > 15*math.sqrt(v.rank) then
        local angle = math.atan2(delta_y, delta_x)
        v.body:setLinearVelocity(
          -50000 * dt * math.cos(angle),
          -50000 * dt * math.sin(angle)
        )
      else
        if v.dont_prod then -- only one of the balls creates a new ball
          if v.rank + 1 <= 6 then
            play_sound('multhit1', math.random()*0.2 + 0.9, 1 )
          else
            play_sound('multhit2', math.random()*0.2 + 0.9, 1 )
          end
          
          suika_score = suika_score + v.rank ^ 2
          table.insert(objects.balls, Ball(v.body:getX(), v.body:getY(), v.rank + 1))
          v.merge_target.remove = true
          v.remove = true
          if v.rank + 1 == 11 and G.GAME.blind and G.GAME.blind.config.blind.key == 'bl_suikabb_melon' then
            G.GAME.chips = G.GAME.blind.chips
            G.E_MANAGER:add_event(Event({
                trigger = "immediate",
                func = function()
                  G.STATE = G.STATES.HAND_PLAYED
                  G.STATE_COMPLETE = true
                  end_round()
                  return true
                end,
            }))
          end
        else
          v.merge_target.remove = true
          v.remove = true
        end
      end
    end
  end

    -- remove balls safely
  for i = #objects.balls, 1, -1 do
    if objects.balls[i].remove then
      objects.balls[i].body:destroy()
      table.remove(objects.balls, i)
    end
  end
end

function rank_colour(rank)
  if rank == 1 then
    return 1,0,0
  elseif rank == 2 then
    return 1,0.5,0
  elseif rank == 3 then
    return 1,1,0
  elseif rank == 4 then
    return 0.5,1,0
  elseif rank == 5 then
    return 0,1,0
  elseif rank == 6 then
    return 0,1,0.5
  elseif rank == 7 then
    return 0,1,1
  elseif rank == 8 then
    return 0,0.5,1
  elseif rank == 9 then
    return 0,0,1
  elseif rank == 10 then
    return 0.5,0,1
  elseif rank == 11 then
    return 1,0,1
  else
    return 1,0,0.5
  end
end

function draw_suika()
  love.graphics.setColor(25/255., 34/255, 37/255, 0.8) --bg
  love.graphics.rectangle("fill", window_width/2 - box_width/2, window_height*3/4 - 500+12.5, box_width + 200, 500)
  
  love.graphics.setColor(1, 1, 1, 0.5) --indicator
  love.graphics.rectangle("fill", indicator.x-next_rank*10, indicator.y-next_rank*10, 2*next_rank*10, 600+next_rank*10)

  love.graphics.setColor(1, 1, 1) --scoreboard
  love.graphics.printf("Score: "..suika_score, window_width/2 + box_width/2 + 112.5 -1.3*98, window_height*3/4 - 450+12.5-10.5, 200, "center", 0, 1.3)

  love.graphics.setColor(53/255, 75/255, 79/255) --ground
  love.graphics.polygon("fill", objects.ground.body:getWorldPoints(objects.ground.shape:getPoints())) --draw a "filled in" polygon using the ground's coordinates
  love.graphics.polygon("fill", objects.leftwall.body:getWorldPoints(objects.leftwall.shape:getPoints()))
  love.graphics.polygon("fill", objects.rightwall.body:getWorldPoints(objects.rightwall.shape:getPoints()))

  for k,v in ipairs(next_rank_queue) do --queue
    local n_r, n_g, n_b = rank_colour(v) 
    love.graphics.setColor(n_r/2, n_g/2, n_b/2)
    love.graphics.circle("fill", window_width/2 + box_width/2 + 112.5, (window_height*3/4 - 450+12.5 + k*125), v*10+2)
    love.graphics.setColor(n_r, n_g, n_b)
    love.graphics.circle("fill", window_width/2 + box_width/2 + 112.5, (window_height*3/4 - 450+12.5 + k*125), v*10)
    love.graphics.setColor(n_r/2, n_g/2, n_b/2)
    love.graphics.printf(v, window_width/2 + box_width/2 + 112.5-98, (window_height*3/4 - 450+12.5 + k*125)-10.5, 200, "center")
  end

  for k, v in ipairs(objects.balls) do --fallen balls
    if v.rank then
      local r_r, r_g, r_b = rank_colour(v.rank)
      love.graphics.setColor(r_r/2, r_g/2, r_b/2)
      love.graphics.circle("fill", v.body:getX(), v.body:getY(), v.rank*10+2)
      love.graphics.setColor(r_r, r_g, r_b)
      love.graphics.circle("fill", v.body:getX(), v.body:getY(), v.rank*10)
      love.graphics.setColor(r_r/2, r_g/2, r_b/2)
      love.graphics.printf(v.rank, v.body:getX()-98, v.body:getY()-10.5, 200, "center")
    end
  end
  
  local n_r, n_g, n_b = rank_colour(next_rank) --next
  love.graphics.setColor(n_r/2, n_g/2, n_b/2, drop_wait_time > 0.8 and 1 or 0.5)
  love.graphics.circle("fill", indicator.x, indicator.y, next_rank*10+2)
  love.graphics.setColor(n_r, n_g, n_b, drop_wait_time > 0.8 and 1 or 0.5)
  love.graphics.circle("fill", indicator.x, indicator.y, next_rank*10)
  love.graphics.setColor(n_r/2, n_g/2, n_b/2, drop_wait_time > 0.8 and 1 or 0.5)
  love.graphics.printf(next_rank, indicator.x-98, indicator.y-10.5, 200, "center")

end

SMODS.Atlas({
    key = 'suikablind',
    path = 'blinds.png',
    atlas_table = 'ANIMATION_ATLAS',
    frames = 21,
    px = 34,
    py = 34
})

suikaconfig = SMODS.current_mod.config

SMODS.current_mod.config_tab = function()
    return {
      n = G.UIT.ROOT,
      config = {
        align = "cl",
        padding = 0.05,
        colour = G.C.CLEAR,
      },
      nodes = {
        create_toggle({
            label = "Enable Boss Blind (requires restart)",
            ref_table = suikaconfig,
            ref_value = "enablebossblind",
        }),
      },
    }
end

if suikaconfig.enablebossblind then
    -- The Melon
    SMODS.Blind {
        key = "melon",
        loc_txt = {
            name = 'The Melon',
            text = {
                "Extra large blind,",
                "or play a minigame!"
            }
        },
        dollars = 6,
        mult = 4,
        pos = { x = 0, y = 0 },
        atlas = 'suikablind',
        boss = { min = 1 },
        boss_colour = HEX("50bf7c"),
        calculate = function(self, blind, context)
            if context.setting_blind then
                suika()
                reset_suika()
            end
        end,
        disable = function(self)
            G.GAME.blind.chips = G.GAME.blind.chips / 2
            G.GAME.blind.chip_text = number_format(G.GAME.blind.chips)
        end,
        defeat = function(self)
            disable_suika()
        end
    }

    G.FUNCS.suikabb_button = function(e)	-- wtf is this talisman check? [[Fixed it! -Math]] ty for fix
      if do_suika then
        e.config.colour = G.C.GREEN
        e.config.button = 'enable_or_disable_suika'
      else
        e.config.colour = G.C.GREEN
        e.config.button = 'enable_or_disable_suika'
      end
    end

    G.FUNCS.enable_or_disable_suika = function(e)
      if not do_suika then
        suika()
        if suika_gameover then
          reset_suika()
        end
      else
        if not suika_gameover then
          disable_suika()
        else
          reset_suika()
        end
      end
    end

end

--[[function G.UIDEF.suika_ui()
  local t = {n=G.UIT.ROOT, config = {align = 'cl', colour = G.C.CLEAR}, nodes={
            UIBox_dyn_container({
                {n=G.UIT.R, config={align = "cm", padding = 0.1, emboss = 0.05, r = 0.1, colour = G.C.DYN_UI.BOSS_MAIN}, nodes={

                    {n=G.UIT.C, config={align = "cm", padding = 0.2, r=0.2, colour = G.C.L_BLACK, emboss = 0.05, minw = 8.2}, nodes={
                      {n=G.UIT.R, config={id = "plinking_area", align = "cm", colour = G.C.BLACK, }, nodes={

                        {n=G.UIT.R, config={id = "plinking_area", align = "tm", colour = G.C.BLACK, padding = 0., minw = 7., minh = 5.8}, nodes={
                          -- Area for the plinko minigame
                        }},

                      }},
                    }},

                }
              },
              
              }, false)
        }}
    return t
end]]