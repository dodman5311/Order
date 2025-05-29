local module = {
	timerQueue = {},
}

local RUN_SERVICE = game:GetService("RunService")
local signal = require(script.signal)

local runningTimers = {}

local isPaused = false

local pauseSignal = signal.new()
local resumeSignal = signal.new()

module.wait = function(sec, index)
	local waitTimer = module:new(index or "waitAt_" .. os.clock())
	waitTimer.WaitTime = sec or 0.01
	waitTimer:Run()
	waitTimer.OnEnded:Wait()
	waitTimer:Destroy()
end

module.delay = function(sec, callback, ...)
	local params = ...

	local waitTimer = module:new("delayAt_" .. os.clock())
	waitTimer.WaitTime = sec or 0.01
	waitTimer.Function = function()
		callback(params)
		waitTimer:Destroy()
	end

	waitTimer:Run()
end

module.new = function(self, timerIndex: string | number?, waitTime: number?, Function: () -> any?, ...)
	local queue = self

	local pausedAt = 0

	if not timerIndex then
		timerIndex = #queue + 1
	end

	if queue.timerQueue[timerIndex] then
		return queue.timerQueue[timerIndex]
	end

	local timer = {
		IsRunning = false,
		CallTime = os.clock(),
		WaitTime = waitTime,
		["Function"] = Function,
		Parameters = { ... },
		Condition = nil,

		OnTimerStepped = signal.new(),
	}

	timer.OnPaused = pauseSignal:Connect(function()
		isPaused = true
		pausedAt = os.clock()
	end)

	timer.OnResumed = resumeSignal:Connect(function()
		timer:Delay(os.clock() - pausedAt)
		isPaused = false
	end)

	timer.OnEnded = signal.new()

	function timer:Run()
		if self.IsRunning then
			return
		end

		self.CallTime = os.clock()

		self.IsRunning = true
		table.insert(runningTimers, self)
	end

	function timer:Reset()
		self.CallTime = os.clock()
	end

	function timer:Delay(amount: number)
		self.CallTime += amount
	end

	function timer:Update(index: string, value: any?)
		self[index] = value
	end

	function timer:UpdateFunction(value: any?, ...)
		self["Function"] = value
		self["Parameters"] = ...
	end

	function timer:Cancel()
		if not self.IsRunning then
			return false
		end
		table.remove(runningTimers, table.find(runningTimers, self))
		self.IsRunning = false
		return true
	end

	function timer:Destroy()
		if self.IsRunning then
			table.remove(runningTimers, table.find(runningTimers, self))
			self.IsRunning = false
		end

		self.OnPaused:Disconnect()
		self.OnResumed:Disconnect()

		queue.timerQueue[timerIndex] = nil
	end

	function timer:Complete()
		self.CallTime = -self.WaitTime
	end

	function timer:GetCurrentTime()
		return os.clock() - self.CallTime
	end

	queue.timerQueue[timerIndex] = timer
	return queue.timerQueue[timerIndex]
end

function module:newQueue()
	return {
		timerQueue = {},
		new = module["new"],

		DestroyAll = function(self)
			for _, timer in self.timerQueue do
				if not timer["Destroy"] then
					continue
				end
				timer:Destroy()
			end
		end,

		CancelAll = function(self)
			for _, timer in self.timerQueue do
				if not timer["Cancel"] then
					continue
				end
				timer:Cancel()
			end
		end,

		DoAll = function(self, functionName, ...)
			for _, timer in self.timerQueue do
				if not timer[functionName] then
					continue
				end
				timer[functionName](timer, ...)
			end
		end,

		DoFor = function(self, timers, functionName, ...)
			for _, timerName in timers do
				local timer = self.timerQueue[timerName]

				if not timer or not timer[functionName] then
					continue
				end
				timer[functionName](timer, ...)
			end
		end,
	}
end

function module:getTimer(timerName)
	return self.timerQueue[timerName]
end

RUN_SERVICE.Heartbeat:Connect(function()
	for _, timer in ipairs(runningTimers) do
		if isPaused then
			return
		end

		timer.OnTimerStepped:Fire(os.clock() - timer.CallTime)

		if (os.clock() - timer.CallTime) < timer.WaitTime then
			continue
		end

		table.remove(runningTimers, table.find(runningTimers, timer))
		timer.IsRunning = false

		timer.OnEnded:Fire()

		if not timer.Function then
			continue
		end

		task.spawn(timer.Function, table.unpack(timer.Parameters))
	end
end)

return module
