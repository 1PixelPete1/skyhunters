--!strict

-- Simple min-heap keyed by expiresAt for timer queue.

export type Item = { key: string, expiresAt: number }

local MinHeap = {}
MinHeap.__index = MinHeap

function MinHeap.new()
    local self = setmetatable({
        data = {} :: { Item },
        indexByKey = {} :: { [string]: number },
    }, MinHeap)
    return self
end

local function less(a: Item, b: Item): boolean
    return a.expiresAt < b.expiresAt
end

local function swap(self, i: number, j: number)
    self.data[i], self.data[j] = self.data[j], self.data[i]
    self.indexByKey[self.data[i].key] = i
    self.indexByKey[self.data[j].key] = j
end

local function bubbleUp(self, idx: number)
    while idx > 1 do
        local parent = math.floor(idx / 2)
        if less(self.data[idx], self.data[parent]) then
            swap(self, idx, parent)
            idx = parent
        else
            break
        end
    end
end

local function bubbleDown(self, idx: number)
    local n = #self.data
    while true do
        local left = idx * 2
        local right = left + 1
        local smallest = idx
        if left <= n and less(self.data[left], self.data[smallest]) then
            smallest = left
        end
        if right <= n and less(self.data[right], self.data[smallest]) then
            smallest = right
        end
        if smallest ~= idx then
            swap(self, idx, smallest)
            idx = smallest
        else
            break
        end
    end
end

function MinHeap:insertOrDecreaseKey(key: string, expiresAt: number)
    local idx = self.indexByKey[key]
    if idx then
        self.data[idx].expiresAt = expiresAt
        bubbleUp(self, idx)
    else
        table.insert(self.data, { key = key, expiresAt = expiresAt })
        local newIdx = #self.data
        self.indexByKey[key] = newIdx
        bubbleUp(self, newIdx)
    end
end

function MinHeap:peek(): Item?
    return self.data[1]
end

function MinHeap:pop(): Item?
    local n = #self.data
    if n == 0 then return nil end
    local root = self.data[1]
    self.indexByKey[root.key] = nil
    if n == 1 then
        self.data[1] = nil :: any
        return root
    end
    self.data[1] = self.data[n]
    self.indexByKey[self.data[1].key] = 1
    self.data[n] = nil :: any
    bubbleDown(self, 1)
    return root
end

return MinHeap

