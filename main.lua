local settings = require("settings")

local assets = {}
local tileSize = settings.tileSize
local gridWidth = settings.gridWidth
local gridHeight = settings.gridHeight
local canvas = {width = gridWidth * tileSize, height = gridHeight * tileSize}
local grid = {}
local selectedTile = 1
local showMenu = true
local isErasing = false

local tools = {"brush", "eraser", "bucket", "line", "rectangle"}
local selectedTool = "brush"
local startX, startY = nil, nil

local camera = {
    x = 0, y = 0, scale = 1,
    minScale = 0.1, maxScale = 2
}

function love.load()
    love.window.setMode(1024, 768, {resizable=false, vsync=true})
    love.window.setTitle(settings.NAME .. " - " .. settings.VERSION)
    loadAssets()
end

function love.update(dt)
    if not showMenu then
        updateCamera(dt)
        if love.mouse.isDown(1) then
            local x = math.floor((love.mouse.getX() / camera.scale + camera.x) / tileSize) + 1
            local y = math.floor((love.mouse.getY() / camera.scale + camera.y) / tileSize) + 1
            if x >= 1 and x <= gridWidth and y >= 1 and y <= gridHeight then
                if selectedTool == "eraser" then
                    applyEraser(x, y)
                elseif selectedTool == "brush" then
                    grid[y] = grid[y] or {}
                    grid[y][x] = selectedTile
                end
            end
        end
    end
end

function updateCamera(dt)
    local speed = 500 * dt / camera.scale
    if love.keyboard.isDown("w") then camera.y = camera.y - speed end
    if love.keyboard.isDown("s") then camera.y = camera.y + speed end
    if love.keyboard.isDown("a") then camera.x = camera.x - speed end
    if love.keyboard.isDown("d") then camera.x = camera.x + speed end
end

function loadAssets()
    for _, filename in ipairs(settings.assets) do
        local path = "assets/" .. filename
        local image = love.graphics.newImage(path)
        table.insert(assets, image)
    end
end

function love.draw()
    if showMenu then
        drawMenu()
    else
        love.graphics.push()
        love.graphics.scale(camera.scale)
        love.graphics.translate(-camera.x, -camera.y)
        drawGrid()
        love.graphics.pop()
        drawPalette()
        drawTools()
        drawInfo()
    end
end

function drawMenu()
    love.graphics.printf("LevelMaker", 0, 300, love.graphics.getWidth(), "center")
    love.graphics.printf("Press Enter to start", 0, 350, love.graphics.getWidth(), "center")
end

function drawGrid()
    local startX = math.max(1, math.floor(camera.x / tileSize) + 1)
    local startY = math.max(1, math.floor(camera.y / tileSize) + 1)
    local endX = math.min(gridWidth, math.ceil((camera.x + love.graphics.getWidth() / camera.scale) / tileSize))
    local endY = math.min(gridHeight, math.ceil((camera.y + love.graphics.getHeight() / camera.scale) / tileSize))

    love.graphics.setColor(0.8, 0.8, 0.8, 0.5)
    for y = startY, endY do
        love.graphics.line((startX - 1) * tileSize, (y - 1) * tileSize, (endX - 1) * tileSize, (y - 1) * tileSize)
    end
    for x = startX, endX do
        love.graphics.line((x - 1) * tileSize, (startY - 1) * tileSize, (x - 1) * tileSize, (endY - 1) * tileSize)
    end

    for y = startY, endY do
        for x = startX, endX do
            if grid[y] and grid[y][x] and assets[grid[y][x]] then
                local asset = assets[grid[y][x]]
                love.graphics.setColor(1, 1, 1)
                love.graphics.draw(asset, (x - 1) * tileSize, (y - 1) * tileSize, 0, tileSize / asset:getWidth(), tileSize / asset:getHeight())
            end
        end
    end
end

function drawPalette()
    love.graphics.setColor(0.2, 0.2, 0.2, 1)
    love.graphics.rectangle("fill", 0, love.graphics.getHeight() - 100, love.graphics.getWidth(), 100)
    
    for i, asset in ipairs(assets) do
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(asset, (i-1)*50, love.graphics.getHeight() - 95, 0, 45/asset:getWidth(), 45/asset:getHeight())
        if i == selectedTile and selectedTool == "brush" then
            love.graphics.setColor(1, 1, 0)
            love.graphics.rectangle("line", (i-1)*50, love.graphics.getHeight() - 95, 45, 45)
        end
    end
end

function drawTools()
    love.graphics.setColor(0.2, 0.2, 0.2, 1)
    love.graphics.rectangle("fill", love.graphics.getWidth() - 100, 0, 100, love.graphics.getHeight())
    
    for i, tool in ipairs(tools) do
        local y = (i - 1) * 50 + 10
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(tool, love.graphics.getWidth() - 90, y)
        if tool == selectedTool then
            love.graphics.setColor(1, 1, 0)
            love.graphics.rectangle("line", love.graphics.getWidth() - 100, y - 5, 100, 45)
        end
    end
end

function drawInfo()
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Current tool: " .. selectedTool .. (selectedTool == "brush" and " (Tile " .. selectedTile .. ")" or ""), 10, 10)
    love.graphics.print("S - Save, L - Load", 10, 30)
    love.graphics.print("ESC - Back to menu", 10, 50)
end

function love.wheelmoved(x, y)
    if not showMenu then
        local mouseX = love.mouse.getX() / camera.scale + camera.x
        local mouseY = love.mouse.getY() / camera.scale + camera.y

        if y > 0 then
            camera.scale = math.min(camera.scale * 1.1, camera.maxScale)
        elseif y < 0 then
            camera.scale = math.max(camera.scale / 1.1, camera.minScale)
        end

        camera.x = mouseX - love.mouse.getX() / camera.scale
        camera.y = mouseY - love.mouse.getY() / camera.scale
    end
end

function love.keypressed(key)
    if showMenu and key == "return" then
        showMenu = false
        grid = {}
    elseif not showMenu then
        if key == "p" then saveLevel()
        elseif key == "l" then loadLevel()
        elseif key == "escape" then showMenu = true
        elseif key == "1" then selectedTool = "brush"
        elseif key == "2" then selectedTool = "eraser"
        elseif key == "3" then selectedTool = "bucket"
        elseif key == "4" then selectedTool = "line"
        elseif key == "5" then selectedTool = "rectangle"
        end
    end
end

function love.mousepressed(x, y, button)
    if not showMenu then
        -- Преобразование координат мыши в координаты сетки
        local tileX = math.floor((x / camera.scale + camera.x) / tileSize) + 1
        local tileY = math.floor((y / camera.scale + camera.y) / tileSize) + 1

        -- Ограничение координат, чтобы они не выходили за границы сетки
        tileX = math.max(1, math.min(tileX, gridWidth))
        tileY = math.max(1, math.min(tileY, gridHeight))

        if y > love.graphics.getHeight() - 100 then
            local index = math.floor(x / 50) + 1
            if index <= #assets then
                selectedTile = index
                selectedTool = "brush"
            elseif index == #assets + 1 then
                selectedTool = "eraser"
            end
        elseif x > love.graphics.getWidth() - 100 then
            local toolIndex = math.floor(y / 50) + 1
            if toolIndex >= 1 and toolIndex <= #tools then
                selectedTool = tools[toolIndex]
            end
        else
            -- Применение инструмента на выбранных координатах
            if selectedTool == "brush" then
                applyBrush(tileX, tileY)
            elseif selectedTool == "eraser" then
                applyEraser(tileX, tileY)
            elseif selectedTool == "bucket" then
                applyBucket(tileX, tileY)
            elseif selectedTool == "line" then
                startX, startY = tileX, tileY
            elseif selectedTool == "rectangle" then
                startX, startY = tileX, tileY
            end
        end
    end
end

function love.mousereleased(x, y, button)
    if not showMenu then
        -- Преобразование координат мыши в координаты сетки
        local tileX = math.floor((x / camera.scale + camera.x) / tileSize) + 1
        local tileY = math.floor((y / camera.scale + camera.y) / tileSize) + 1

        -- Ограничение координат, чтобы они не выходили за границы сетки
        tileX = math.max(1, math.min(tileX, gridWidth))
        tileY = math.max(1, math.min(tileY, gridHeight))

        if selectedTool == "line" and startX and startY then
            drawLine(startX, startY, tileX, tileY)
            startX, startY = nil, nil
        elseif selectedTool == "rectangle" and startX and startY then
            drawRectangle(startX, startY, tileX, tileY)
            startX, startY = nil, nil
        end
    end
end

function saveLevel()
    local data = gridWidth .. "," .. gridHeight .. "\n"
    for y = 1, gridHeight do
        for x = 1, gridWidth do
            data = data .. (grid[y] and grid[y][x] or 0) .. ","
        end
        data = data .. "\n"
    end
    
    local file = io.open("level.txt", "w")
    if file then
        file:write(data)
        file:close()
        print("Уровень сохранен в директории проекта")
    else
        print("Не удалось сохранить уровень")
    end
end

function loadLevel()
    local file = io.open("level.txt", "r")
    if file then
        local data = file:read("*all")
        file:close()
        
        local lines = {}
        for line in data:gmatch("[^\n]+") do
            table.insert(lines, line)
        end
        
        local dimensions = lines[1]:gmatch("[^,]+")
        gridWidth = tonumber(dimensions())
        gridHeight = tonumber(dimensions())
        canvas.width = gridWidth * tileSize
        canvas.height = gridHeight * tileSize
        
        grid = {}
        for y = 1, #lines - 1 do
            grid[y] = {}
            local x = 1
            for tile in lines[y+1]:gmatch("[^,]+") do
                local tileValue = tonumber(tile)
                if tileValue ~= 0 then
                    grid[y][x] = tileValue
                end
                x = x + 1
            end
        end
        print("Уровень загружен из директории проекта")
    else
        print("Не удалось загрузить уровень")
    end
end

function applyBrush(x, y)
    if x >= 1 and x <= gridWidth and y >= 1 and y <= gridHeight then
        grid[y] = grid[y] or {}
        grid[y][x] = selectedTile
    end
end

function applyEraser(x, y)
    if x >= 1 and x <= gridWidth and y >= 1 and y <= gridHeight then
        if grid[y] then
            grid[y][x] = nil
        end
    end
end

function applyBucket(x, y)
    if x >= 1 and x <= gridWidth and y >= 1 and y <= gridHeight then
        local targetTile = grid[y] and grid[y][x]
        if targetTile ~= selectedTile then
            floodFill(x, y, targetTile, selectedTile)
        end
    end
end

function floodFill(x, y, targetTile, replacementTile)
    if x < 1 or x > gridWidth or y < 1 or y > gridHeight then return end
    if grid[y] and grid[y][x] == targetTile then
        grid[y][x] = replacementTile
        floodFill(x + 1, y, targetTile, replacementTile)
        floodFill(x - 1, y, targetTile, replacementTile)
        floodFill(x, y + 1, targetTile, replacementTile)
        floodFill(x, y - 1, targetTile, replacementTile)
    end
end

function drawLine(x1, y1, x2, y2)
    -- Ограничение координат
    x1 = math.max(1, math.min(x1, gridWidth))
    y1 = math.max(1, math.min(y1, gridHeight))
    x2 = math.max(1, math.min(x2, gridWidth))
    y2 = math.max(1, math.min(y2, gridHeight))

    local dx = math.abs(x2 - x1)
    local dy = math.abs(y2 - y1)
    local sx = x1 < x2 and 1 or -1
    local sy = y1 < y2 and 1 or -1
    local err = dx - dy

    while true do
        applyBrush(x1, y1)
        if x1 == x2 and y1 == y2 then break end
        local e2 = 2 * err
        if e2 > -dy then
            err = err - dy
            x1 = x1 + sx
        end
        if e2 < dx then
            err = err + dx
            y1 = y1 + sy
        end
    end
end

function drawRectangle(x1, y1, x2, y2)
    -- Ограничение координат
    local left = math.max(1, math.min(math.min(x1, x2), gridWidth))
    local right = math.max(1, math.min(math.max(x1, x2), gridWidth))
    local top = math.max(1, math.min(math.min(y1, y2), gridHeight))
    local bottom = math.max(1, math.min(math.max(y1, y2), gridHeight))
    
    for x = left, right do
        applyBrush(x, top)
        applyBrush(x, bottom)
    end
    for y = top, bottom do
        applyBrush(left, y)
        applyBrush(right, y)
    end
end
