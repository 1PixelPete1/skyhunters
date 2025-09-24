-- GenerationQueue.luau
-- Queue system for managing expensive generation operations without frame drops

local RunService = game:GetService("RunService")

local GenerationQueue = {}
GenerationQueue.__index = GenerationQueue

function GenerationQueue.new(config)
    local self = setmetatable({}, GenerationQueue)
    
    -- Configuration
    self.config = config or {}
    self.maxOperationsPerFrame = self.config.maxOperationsPerFrame or 5
    self.maxTimePerFrame = self.config.maxTimePerFrame or 0.008  -- 8ms max per frame
    self.priorityLevels = self.config.priorityLevels or 3
    
    -- Queue storage (priority-based)
    self.queues = {}
    for i = 1, self.priorityLevels do
        self.queues[i] = {}
    end
    
    -- State tracking
    self.isProcessing = false
    self.currentPriority = 1
    self.operationCount = 0
    self.frameStartTime = 0
    self.isPaused = false
    
    -- Statistics
    self.stats = {
        totalOperations = 0,
        completedOperations = 0,
        failedOperations = 0,
        averageOperationTime = 0,
        peakQueueSize = 0
    }
    
    -- Operation tracking
    self.operationMap = {}  -- Track operations by ID to prevent duplicates
    
    return self
end

-- Add an operation to the queue
function GenerationQueue:Add(operation, id, priority)
    if self.isPaused then
        warn("[GenerationQueue] Queue is paused, operation not added:", id)
        return false
    end
    
    -- Validate inputs
    if type(operation) ~= "function" then
        error("[GenerationQueue] Operation must be a function")
    end
    
    id = id or tostring(tick())
    priority = math.clamp(priority or 2, 1, self.priorityLevels)
    
    -- Check for duplicate operations
    if self.operationMap[id] then
        warn("[GenerationQueue] Duplicate operation ID, skipping:", id)
        return false
    end
    
    -- Create operation wrapper
    local wrappedOperation = {
        id = id,
        func = operation,
        priority = priority,
        addedTime = tick(),
        attempts = 0,
        maxAttempts = 3
    }
    
    -- Add to appropriate priority queue
    table.insert(self.queues[priority], wrappedOperation)
    self.operationMap[id] = wrappedOperation
    
    -- Update statistics
    self.stats.totalOperations = self.stats.totalOperations + 1
    local currentSize = self:GetQueueSize()
    if currentSize > self.stats.peakQueueSize then
        self.stats.peakQueueSize = currentSize
    end
    
    -- Start processing if not already running
    if not self.isProcessing then
        self:StartProcessing()
    end
    
    return true
end

-- Add multiple operations as a batch
function GenerationQueue:AddBatch(operations, baseid, priority)
    local added = 0
    for i, operation in ipairs(operations) do
        local id = baseid .. "_" .. i
        if self:Add(operation, id, priority) then
            added = added + 1
        end
    end
    return added
end

-- Remove an operation from the queue
function GenerationQueue:Remove(id)
    local operation = self.operationMap[id]
    if not operation then
        return false
    end
    
    -- Find and remove from priority queue
    local queue = self.queues[operation.priority]
    for i, op in ipairs(queue) do
        if op.id == id then
            table.remove(queue, i)
            self.operationMap[id] = nil
            return true
        end
    end
    
    return false
end

-- Start processing the queue
function GenerationQueue:StartProcessing()
    if self.isProcessing or self.isPaused then
        return
    end
    
    self.isProcessing = true
    
    -- Use RunService.Heartbeat for frame-based processing
    self.processConnection = RunService.Heartbeat:Connect(function(deltaTime)
        self:ProcessFrame(deltaTime)
    end)
end

-- Stop processing the queue
function GenerationQueue:StopProcessing()
    if self.processConnection then
        self.processConnection:Disconnect()
        self.processConnection = nil
    end
    self.isProcessing = false
end

-- Process operations for one frame
function GenerationQueue:ProcessFrame(deltaTime)
    if self.isPaused then
        return
    end
    
    self.frameStartTime = tick()
    self.operationCount = 0
    
    -- Process operations from highest to lowest priority
    for priority = 1, self.priorityLevels do
        local queue = self.queues[priority]
        
        while #queue > 0 do
            -- Check frame budget
            local elapsedTime = tick() - self.frameStartTime
            if elapsedTime >= self.maxTimePerFrame or 
               self.operationCount >= self.maxOperationsPerFrame then
                return  -- Frame budget exceeded, continue next frame
            end
            
            -- Get next operation
            local operation = table.remove(queue, 1)
            if operation then
                self.operationMap[operation.id] = nil
                
                -- Execute operation with error handling
                local success, err = self:ExecuteOperation(operation)
                
                if not success and operation.attempts < operation.maxAttempts then
                    -- Retry failed operation
                    operation.attempts = operation.attempts + 1
                    warn(string.format("[GenerationQueue] Operation %s failed (attempt %d/%d): %s", 
                        operation.id, operation.attempts, operation.maxAttempts, tostring(err)))
                    
                    -- Re-add to queue with lower priority
                    local retryPriority = math.min(operation.priority + 1, self.priorityLevels)
                    operation.priority = retryPriority
                    table.insert(self.queues[retryPriority], operation)
                    self.operationMap[operation.id] = operation
                elseif not success then
                    -- Max attempts reached, log failure
                    warn(string.format("[GenerationQueue] Operation %s permanently failed: %s", 
                        operation.id, tostring(err)))
                    self.stats.failedOperations = self.stats.failedOperations + 1
                end
                
                self.operationCount = self.operationCount + 1
            end
        end
    end
    
    -- Stop processing if all queues are empty
    if self:GetQueueSize() == 0 then
        self:StopProcessing()
        
        -- Fire completion callback if set
        if self.onQueueComplete then
            self.onQueueComplete(self.stats)
        end
    end
end

-- Execute a single operation with timing and error handling
function GenerationQueue:ExecuteOperation(operation)
    local startTime = tick()
    
    -- Use pcall for safe execution
    local success, result = pcall(function()
        operation.func()
    end)
    
    local executionTime = tick() - startTime
    
    -- Update statistics
    if success then
        self.stats.completedOperations = self.stats.completedOperations + 1
        
        -- Update average operation time
        local total = self.stats.completedOperations
        local oldAverage = self.stats.averageOperationTime
        self.stats.averageOperationTime = (oldAverage * (total - 1) + executionTime) / total
        
        -- Fire success callback if set
        if self.onOperationComplete then
            self.onOperationComplete(operation.id, executionTime)
        end
    end
    
    return success, result
end

-- Get current queue size
function GenerationQueue:GetQueueSize()
    local size = 0
    for _, queue in ipairs(self.queues) do
        size = size + #queue
    end
    return size
end

-- Get queue sizes by priority
function GenerationQueue:GetQueueSizesByPriority()
    local sizes = {}
    for priority, queue in ipairs(self.queues) do
        sizes[priority] = #queue
    end
    return sizes
end

-- Pause queue processing
function GenerationQueue:Pause()
    self.isPaused = true
    print("[GenerationQueue] Queue paused")
end

-- Resume queue processing
function GenerationQueue:Resume()
    self.isPaused = false
    print("[GenerationQueue] Queue resumed")
    
    if self:GetQueueSize() > 0 and not self.isProcessing then
        self:StartProcessing()
    end
end

-- Clear all queued operations
function GenerationQueue:Clear(priority)
    if priority then
        -- Clear specific priority queue
        self.queues[priority] = {}
    else
        -- Clear all queues
        for i = 1, self.priorityLevels do
            self.queues[i] = {}
        end
        self.operationMap = {}
    end
    
    print("[GenerationQueue] Queue cleared")
end

-- Get current statistics
function GenerationQueue:GetStats()
    return {
        currentQueueSize = self:GetQueueSize(),
        queueSizesByPriority = self:GetQueueSizesByPriority(),
        totalOperations = self.stats.totalOperations,
        completedOperations = self.stats.completedOperations,
        failedOperations = self.stats.failedOperations,
        averageOperationTime = self.stats.averageOperationTime,
        peakQueueSize = self.stats.peakQueueSize,
        isProcessing = self.isProcessing,
        isPaused = self.isPaused
    }
end

-- Set configuration values
function GenerationQueue:SetConfig(config)
    if config.maxOperationsPerFrame then
        self.maxOperationsPerFrame = config.maxOperationsPerFrame
    end
    if config.maxTimePerFrame then
        self.maxTimePerFrame = config.maxTimePerFrame
    end
end

-- Cleanup
function GenerationQueue:Destroy()
    self:StopProcessing()
    self:Clear()
    self.operationMap = {}
    print("[GenerationQueue] Queue destroyed")
end

return GenerationQueue
