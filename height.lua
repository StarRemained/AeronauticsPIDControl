local tothesky = require('tothesky')
local pid = tothesky.pid

local sensor = peripheral.wrap('back')
if sensor == nil then
    printError("sensor not placed")
    return
end
-- 手动输入初始输出值
local function getInitialOutput()
    term.clear()
    term.setCursorPos(1,1)
    print(" PID initail output:(0~15)")
    print("example:3 5 8")
    
    local function readNumber(prompt)
        term.write(prompt)
        local input = read()
        local num = tonumber(input)
        while num == nil or num < 0 or num > 15 or math.floor(num) ~= num do
            term.write("invalid,input must be integer between 0~15 : ")
            input = read()
            num = tonumber(input)
        end
        return num
    end
    
    local out1 = readNumber("right (0~15): ")
    local out2 = readNumber("top (0~15): ")
    local out3 = readNumber("left (0~15): ")
    
    -- 组合值
    return out1 +  out2/15 +  out3 /255
end

-- 获取初始组合值
local initOutput = getInitialOutput()
term.clear()
print("initialzed,initial output = " .. initOutput)
sleep(1)


-- 手动输入初始目标高度
local function getInitialHeight()
    term.clear()
    term.setCursorPos(1,1)
    print("Target height:")
    local input = read()
    local h = tonumber(input)
    while h == nil do
        term.write("invalid,please retry: ")
        input = read()
        h = tonumber(input)
    end
    return h
end

HEIGHT = getInitialHeight()

term.clear()
print("initialzed,initial output = " .. initOutput .. ",target height = " .. HEIGHT)
sleep(1)

-- PID 控制器初始化
local control = pid.createPid(0.05, 0.001, 0.05, 0.1,initOutput)

-- 静态表格框架（一次性绘制）
term.clear()
term.setCursorPos(1, 1)
term.write("+----------------------------------------+")
term.setCursorPos(1, 2)
term.write("|          Height Control System         |")
term.setCursorPos(1, 3)
term.write("+----------------------------------------+")
term.setCursorPos(1, 4)
term.write("| Target Height :                         |")
term.setCursorPos(1, 5)
term.write("| Current Height:                         |")
term.setCursorPos(1, 6)
term.write("| Error         :                         |")
term.setCursorPos(1, 7)
term.write("+----------------------------------------+")
term.setCursorPos(1, 8)
term.write("| Output1 (right) :                       |")
term.setCursorPos(1, 9)
term.write("| Output2 (back)  :                       |")
term.setCursorPos(1, 10)
term.write("| Output3 (left)  :                       |")
term.setCursorPos(1, 11)
term.write("+----------------------------------------+")
term.setCursorPos(1, 12)
term.write("| [C] change target    [E] exit          |")
term.setCursorPos(1, 13)
term.write("+----------------------------------------+")

-- 数值显示位置
local pos = {
    target  = {20, 4},
    current = {20, 5},
    error   = {20, 6},
    out1    = {20, 8},
    out2    = {20, 9},
    out3    = {20, 10}
}

local function writeNumber(x, y, value, formatStr)
    term.setCursorPos(x, y)
    term.write(string.format(formatStr, value))
end

-- 全局标志：是否正在输入（暂停刷新避免冲突）
local inputting = false

-- 修改目标高度函数
local function changeTarget()
    inputting = true
    term.setCursorPos(1, 14)
    term.clearLine()
    term.write("New target height: ")
    term.setCursorPos(19, 14)
    local input = read()
    local newH = tonumber(input)
    if newH then
        HEIGHT = newH
        term.setCursorPos(1, 14)
        term.clearLine()
        term.write("Target set to " .. HEIGHT)
        sleep(0.5)
    else
        term.setCursorPos(1, 14)
        term.clearLine()
        term.write("Invalid number, press any key")
        os.pullEvent("key")
    end
    -- 恢复底部提示区域
    term.setCursorPos(1, 12)
    term.clearLine()
    term.write("| [C] change target    [E] exit          |")
    term.setCursorPos(1, 13)
    term.write("+----------------------------------------+")
    term.setCursorPos(1, 14)
    term.clearLine()
    inputting = false
end

-- 控制循环（高频执行 PID 和界面刷新）
local running = true
local function controlLoop()
    while running do
        if not inputting then
        local current = sensor.getHeight()
        local err = HEIGHT - current
        local output = control:step(err)
		if output > 15 then
			output = 15
		elseif output < 0 then
			output = 0
			end
        out1 = math.floor(output)
        local rem = output - out1
        out2 = math.floor(rem * 15)
        rem = rem * 15 - out2
        out3 = math.floor(rem * 15)
            -- 红石输出
            redstone.setAnalogOutput('right', out1)
            redstone.setAnalogOutput('top', out2)
            redstone.setAnalogOutput('left', out3)

            -- 更新表格数值
            writeNumber(pos.target[1], pos.target[2], HEIGHT, "%8.2f")
            writeNumber(pos.current[1], pos.current[2], current, "%8.2f")
            writeNumber(pos.error[1], pos.error[2], err, "%+8.2f")
            writeNumber(pos.out1[1], pos.out1[2], out1, "%3d")
            writeNumber(pos.out2[1], pos.out2[2], out2, "%3d")
            writeNumber(pos.out3[1], pos.out3[2], out3, "%3d")
        end
        sleep(0.1)
    end
end

-- 按键监听循环（阻塞等待按键）
local function inputHandler()
    while running do
        local event, key = os.pullEvent("key")
        if event == "key" then
            if key == keys.c then          -- 标准 C 键码
                changeTarget()
            elseif key == keys.e then      -- 标准 E 键码
                running = false
                term.setCursorPos(1, 15)
                term.write("Exiting...")
                sleep(0.5)
                return
            end
        end
    end
end

-- 并行运行两个任务
parallel.waitForAny(controlLoop, inputHandler)
term.clear()
term.setCursorPos(1,1)
print("Program stopped.")