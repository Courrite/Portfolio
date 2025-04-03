--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MockDataStoreService = {}
MockDataStoreService.__index = MockDataStoreService

local MockDataStore = {}
MockDataStore.__index = MockDataStore

local OrderedMockDataStore = {}
OrderedMockDataStore.__index = OrderedMockDataStore

export type MockDataStoreEntry = {
	key: string,
	value: any
}

export type MockDataStorePage = {
	GetCurrentPage: (self: MockDataStorePage) -> {MockDataStoreEntry}
}

export type MockDataStoreInfo = {
	Name: string,
	Scope: string
}

export type MockDataStore = {
	Name: string,
	Scope: string,
	Data: {[string]: any},

	SetAsync: (self: MockDataStore, key: string, value: any) -> boolean,
	GetAsync: (self: MockDataStore, key: string) -> any,
	RemoveAsync: (self: MockDataStore, key: string) -> any,
	UpdateAsync: (self: MockDataStore, key: string, transformFunction: (any?) -> any?) -> any?
}

export type OrderedMockDataStore = MockDataStore & {
	GetSortedAsync: (
		self: OrderedMockDataStore,
		sortDirection: Enum.SortDirection | "Ascending" | "Descending",
		pageSize: number,
		minValue: number?,
		maxValue: number?
	) -> MockDataStorePage
}

export type MockDataStoreService = {
	DataStores: {[string]: MockDataStore},
	OrderedDataStores: {[string]: OrderedMockDataStore},

	GetDataStore: (self: MockDataStoreService, name: string, scope: string?, options: DataStoreOptions?) -> MockDataStore,
	GetOrderedDataStore: (self: MockDataStoreService, name: string, scope: string?) -> OrderedMockDataStore,
	ListDataStoresAsync: (self: MockDataStoreService, prefix: string?, pageSize: number?, cursor: string?) -> MockDataStorePage
}

local function createDataStoreInfo(name: string, scope: string): Types.MockDataStoreInfo
	return {
		Name = name,
		Scope = scope
	}
end

function MockDataStore.new(name: string, scope: string?): Types.MockDataStore
	local self: Types.MockDataStore = setmetatable({
		Name = name,
		Scope = scope or "global",
		Data = {} :: {[string]: any}
	}, MockDataStore) :: any

	return self
end

function MockDataStore:SetAsync(key: string, value: any): boolean
	self.Data[key] = value
	return true
end

function MockDataStore:GetAsync(key: string): any
	return self.Data[key]
end

function MockDataStore:RemoveAsync(key: string): any
	local value = self.Data[key]
	self.Data[key] = nil
	return value
end

function MockDataStore:UpdateAsync(key: string, transformFunction: (any?) -> any?): any?
	local currentValue = self.Data[key]
	local newValue = transformFunction(currentValue)
	if newValue ~= nil then
		self.Data[key] = newValue
	end
	return newValue
end

function OrderedMockDataStore.new(name: string, scope: string?): Types.OrderedMockDataStore
	return setmetatable(MockDataStore.new(name, scope), OrderedMockDataStore) :: any
end

function OrderedMockDataStore:GetSortedAsync(
	sortDirection: Enum.SortDirection | "Ascending" | "Descending",
	pageSize: number,
	minValue: number?,
	maxValue: number?
): Types.MockDataStorePage
	local entries: {Types.MockDataStoreEntry} = {}

	for key: string, value: any in pairs(self.Data) do
		if type(value) == "number" then
			if (not minValue or value >= minValue) and (not maxValue or value <= maxValue) then
				table.insert(entries, {
					key = key,
					value = value
				})
			end
		end
	end

	local direction: string = if typeof(sortDirection) == "EnumItem"
		then sortDirection.Name
		else sortDirection

	table.sort(entries, function(a: Types.MockDataStoreEntry, b: Types.MockDataStoreEntry)
		if direction == "Descending" then
			return a.value > b.value
		end
		return a.value < b.value
	end)

	return {
		GetCurrentPage = function()
			return entries
		end
	}
end

function MockDataStoreService.new(): Types.MockDataStoreService
	local self: Types.MockDataStoreService = setmetatable({
		DataStores = {} :: {[string]: Types.MockDataStore},
		OrderedDataStores = {} :: {[string]: Types.OrderedMockDataStore}
	}, MockDataStoreService) :: any

	return self
end

function MockDataStoreService:GetDataStore(
	name: string,
	scope: string,
	options: DataStoreOptions?
): Types.MockDataStore
	scope = scope or "global"
	local key: string = name .. ":" .. scope

	if not self.DataStores[key] then
		self.DataStores[key] = MockDataStore.new(name, scope)
	end

	return self.DataStores[key]
end

function MockDataStoreService:GetOrderedDataStore(
	name: string,
	scope: string
): Types.OrderedMockDataStore
	scope = scope or "global"
	local key: string = name .. ":" .. scope

	if not self.OrderedDataStores[key] then
		self.OrderedDataStores[key] = OrderedMockDataStore.new(name, scope)
	end

	return self.OrderedDataStores[key]
end

function MockDataStoreService:ListDataStoresAsync(
	prefix: string?,
	pageSize: number?,
	cursor: string?
): Types.MockDataStorePage
	local results: {Types.MockDataStoreEntry} = {}

	for key: string, store: Types.MockDataStore in pairs(self.DataStores) do
		if not prefix or store.Name:find("^" .. prefix) then
			table.insert(results, {
				key = tostring(store.Name),
				value = 0
			})
		end
	end

	for key: string, store: Types.OrderedMockDataStore in pairs(self.OrderedDataStores) do
		if not prefix or store.Name:find("^" .. prefix) then
			table.insert(results, {
				key = tostring(store.Name),
				value = 0
			})
		end
	end

	return {
		GetCurrentPage = function()
			return results
		end
	}
end

return MockDataStoreService.new()
