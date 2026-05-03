local tothesky = require('tothesky')
local pid = tothesky.pid

local sensor = peripheral.wrap('top')
if sensor == nil then
    printError("sensor not placed")
    return
end

-- 可修改的目标角度
Angle = 0.0

-- PID 控制器初始化
local control = pid.createPid(0.1, 0.005, 1.0, 0.1,0)

-- 静态表格框架（一次性绘制）
term.clear()
term.setCursorPos(1, 1)
term.write("+----------------------------------------+")
term.setCursorPos(1, 2)
term.write("|         Airship Balance System         |")
term.setCursorPos(1, 3)
term.write("+----------------------------------------+")
term.setCursorPos(1, 4)
term.write("| Target Z Angle :                         |")
term.setCursorPos(1, 5)
term.write("| Current Z Angle:                         |")
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
term.write("| Output3 (bottom)  :                       |")
term.setCursorPos(1, 12)
term.write("+----------------------------------------+")
term.setCursorPos(1, 13)
term.write("| [C] change target    [E] exit          |")
term.setCursorPos(1, 14)
term.write("+----------------------------------------+")

-- 数值显示位置
local pos = {
    target  = {20, 4},
    current = {20, 5},
    error   = {20, 6},
    out1    = {20, 8},
    out2    = {20, 9},
    out3    = {20, 10},
	out4	= {20, 11}
}

local function writeNumber(x, y, value, formatStr)
    term.setCursorPos(x, y)
    term.write(string.format(formatStr, value))
end

-- 全局标志：是否正在输入（暂停刷新避免冲突）
local inputting = false

-- 修改目标角度函数
local function changeTarget()
    inputting = true
    term.setCursorPos(1, 15)
    term.clearLine()
    term.write("New target angle: ")
    term.setCursorPos(19, 15)
    local input = read()
    local newH = tonumber(input)
    if newH then
        Angle = newH
        term.setCursorPos(1, 15)
        term.clearLine()
        term.write("Target set to " .. Angle)
        sleep(0.5)
    else
        term.setCursorPos(1, 15)
        term.clearLine()
        term.write("Invalid number, press any key")
        os.pullEvent("key")
    end
    -- 恢复底部提示区域
    term.setCursorPos(1, 13)
    term.clearLine()
    term.write("| [C] change target    [E] exit          |")
    term.setCursorPos(1, 14)
    term.write("+----------------------------------------+")
    term.setCursorPos(1, 15)
    term.clearLine()
    inputting = false
end

-- 控制循环（高频执行 PID 和界面刷新）
local running = true
local function controlLoop()
    while running do
        if not inputting then
        local current = sensor.getAngles()
        local err = Angle - current[2]
        local df = control:step(err)
		if df > 7.5 then
			df = 7.5
		elseif df < -7.5 then
			df = -7.5
			end
        df1 = math.floor(df)
        local rem = df - df1
        df2 = math.floor(rem * 15)
		out1 = 7 + df1 / 2
		out2 = 7 + df2 / 2
		out3 = 7 - df1 / 2
		out4 = 7 - df2 / 2
            -- 红石输出
            redstone.setAnalogOutput('right', out1)
            redstone.setAnalogOutput('back', out2)
            redstone.setAnalogOutput('left', out3)
			redstone.setAnalogOutput('bottom', out3)
            -- 更新表格数值
            writeNumber(pos.target[1], pos.target[2], Angle, "%8.2f")
            writeNumber(pos.current[1], pos.current[2], current[2], "%8.2f")
            writeNumber(pos.error[1], pos.error[2], err, "%+8.2f")
            writeNumber(pos.out1[1], pos.out1[2], out1, "%3d")
            writeNumber(pos.out2[1], pos.out2[2], out2, "%3d")
            writeNumber(pos.out3[1], pos.out3[2], out3, "%3d")
			writeNumber(pos.out4[1], pos.out4[2], out4, "%3d")
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