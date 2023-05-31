-- FSM - finite state machine

local fsm_meta = {
	gotoState = function(self, state_name, ...)
		local states = rawget(self, "states")
		if state_name=="__current" then
			if next{...} and states[rawget(self, "current_state")].onVisit then
				states[state_name].onVisit(self.main_object, ...)
			end
			return true
		end
		if not state_name or not states[state_name] then
			error("FSM("..self.id..") has no state "..tostring(state_name))
		end
		rawset(self, "current_state", state_name)
		if states[state_name].onVisit then
			states[state_name].onVisit(self.main_object, ...)
		end
		return true
	end,
	next = function(self, ...)
		local states = rawget(self, "states")
		local current_state = rawget(self, "current_state")
		if states[current_state].next_state then
			return self.gotoState(self, states[current_state].next_state, ...)
		end
		if states[current_state].onNext then
			return self.gotoState(self, states[current_state].onNext(self.main_object), ...)
		end
		error("FSM("..self.id..") cannot go to next state: unable determine next state. current state: "..current_state)
	end,
	isState = function(self, state_name)
		if type(state_name)~="string" or not rawget(self, "states")[state_name] then
			error("FSM("..self.id..") cannot check state, state absent or invalid: "..tostring(state_name))
		end
		return rawget(self, "current_state")==state_name
	end
}

local cfg_elements_whitelist = {
	onNext = true,
	next_state = true,
	functions = true,
	onVisit = true,
}

local function validateConfig(id, cfg, main_object)
	if not id or type(id)~="string" and type(id)~="number" then
		error("cannot create FSM: invalid id")
	end
	if not cfg or not next(cfg) then
		error("cannot create FSM("..id.."): config is absent or empty. expect {[state]={next_state=next_state_string or nil, onNext=function or nil}, ...}")
	end
	for k,v in pairs(cfg) do
		if type(v)~="table" then
			error("cannot create FSM("..id.."): config elements must be a table with next_state or onNext (ret next_state, can ret \"__current\") function")
		end
		if not (v.next_state~=nil or v.onNext~=nil) then
			error("FSM("..id..").states["..tostring(k).."] must have next_state or onNext (ret next_state, can ret \"__current\") function")
		end
		for k1,v1 in pairs(v) do
			if not cfg_elements_whitelist[k1] then
				error("cannot create FSM("..id.."): custom functions must be placed at cfg[state].functions, key: "..k1)
			end
		end
	end
	if not main_object or type(main_object)~="table" then
		error("cannot create FSM("..id.."): FSM must contain main object")
	end
end

local function prepareFSMTable(id, cfg, main_object, initial_state)
	local ret = {}
	ret.__id = id
	ret.states = {}
	ret.main_object = main_object
	ret.functions = {}
	ret.__functions_cache = {}
	for k,v in pairs(cfg) do
		ret.states[k] = {next_state = v.next_state, onNext = v.onNext, onVisit = v.onVisit, functions = {}}
		if v.functions then
			for k1,v1 in pairs(v.functions) do
				if type(v1)=="function" then
					ret.functions[k1] = true
					ret.states[k].functions[k1] = v1
				end
			end
		end
	end
	return ret
end

local index_blacklist = {
	main_object = true,
	__id = true,
	states = true,
	functions = true,
	__functions_cache = true,
	current_state = true,
}

local function emptyCallback()
	return false
end

local function FSMIndex(self, k)
	if index_blacklist[k] then
		error("FSM("..self.id..") does not allow index field '"..k.."'")
	end
	if rawget(self, "functions")[k] then
		if not rawget(self,"__functions_cache")[k] then
			rawget(self,"__functions_cache")[k] = function(self, ...)
				if rawget(self, "states")[rawget(self, "current_state")].functions[k] then
					return rawget(self, "states")[rawget(self, "current_state")].functions[k](rawget(self, "main_object"), ...)
				end
				return emptyCallback(rawget(self, "main_object"))
			end
		end
		return rawget(self, "__functions_cache")[k]		
	end
	if fsm_meta[k] then
		return fsm_meta[k]
	end
	if k=="id" then
		return rawget(self, "__id")
	end
	return rawget(self, k)
end

local function FSMNewIndex(self, k, v)
	if index_blacklist[k] then
		error("FSM("..self.id..") does not allow index field '"..k.."'")
	end
	if k=="id" then
		error("id of FSM("..self.id..") is read-only field")
	end
	if k=="add" or k=="addState" then
		error("FSM("..self.id..")states is immutable object, all states must defined at config")
	end
end

local function createFSM(id, main_object, cfg, initial_state)
	validateConfig(id, cfg, main_object)
	local ret = setmetatable(prepareFSMTable(id, cfg, main_object, initial_state), {__index = FSMIndex, __newindex = FSMNewIndex})
	ret:gotoState(initial_state)
	return ret
end

return {
	new = createFSM
}