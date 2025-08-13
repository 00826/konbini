--!strict

local DatastoreService = game:GetService("DataStoreService")

--- ### Datastore.luau
---
--- pcall-wrapped datastore functions
local Datastore = {}

--- returns `pcall(DatastoreService.GetDataStore, DatastoreService, name, scope, options)`
function Datastore.getstore(name: string, scope: string?, options: DataStoreGetOptions?)
	return pcall(DatastoreService.GetDataStore, DatastoreService, name, scope, options)
end

--- returns `pcall(datastore.GetAsync, datastore, key, getoptions)`
function Datastore.getasync(datastore: DataStore, key: string, getoptions: DataStoreGetOptions?)
	return pcall(datastore.GetAsync, datastore, key, getoptions)
end

--- returns `pcall(datastore.SetAsync, datastore, key, value, userids, datastoresetoptions)`
function Datastore.setasync(datastore: DataStore|OrderedDataStore, key: string, value: any, userids: {number}?, datastoresetoptions: DataStoreSetOptions?)
	return pcall(datastore.SetAsync, datastore, key, value, userids, datastoresetoptions)
end

--- returns `pcall(datastore.UpdateAsync, datastore, key, transform)`
function Datastore.updateasync(datastore: DataStore|OrderedDataStore, key: string, transform: (any, DataStoreKeyInfo) -> (any, {number}?))
	return pcall(datastore.UpdateAsync, datastore, key, transform)
end

--- returns `pcall(datastore.RemoveAsync, datastore, key)`
function Datastore.removeasync(datastore: DataStore|OrderedDataStore, key: string)
	return pcall(datastore.RemoveAsync, datastore, key)
end

--- returns `pcall(DatastoreService.GetOrderedDataStore, DatastoreService, name, scope)`
function Datastore.getordered(name: string, scope: string?)
	return pcall(DatastoreService.GetOrderedDataStore, DatastoreService, name, scope)
end

--- returns `pcall(ordereddatastore.GetSortedAsync, ordereddatastore, ascending, pagesize, minvalue, maxvalue)`
function Datastore.getsortedasync(ordereddatastore: OrderedDataStore, ascending: boolean, pagesize: number, minvalue: number?, maxvalue: number?)
	return pcall(ordereddatastore.GetSortedAsync, ordereddatastore, ascending, pagesize, minvalue, maxvalue)
end

--- returns `pcall(datastorepages.AdvanceToNextPageAsync, datastorepages)`
function Datastore.nextpageasync(datastorepages: DataStorePages)
	return pcall(datastorepages.AdvanceToNextPageAsync, datastorepages)
end

--- returns `pcall(datastorepages.GetCurrentPage, datastorepages)`
function Datastore.getcurrentpage(datastorepages: DataStorePages)
	return pcall(datastorepages.GetCurrentPage, datastorepages)
end

--- returns `DatastoreService:GetRequestBudgetForRequestType(requesttype)`
function Datastore.getrequestbudget(requesttype: Enum.DataStoreRequestType)
	return DatastoreService:GetRequestBudgetForRequestType(requesttype)
end

return Datastore