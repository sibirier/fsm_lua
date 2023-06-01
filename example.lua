local fsm = require("fsm")
local cfg = {
  state_1 = {
    next_state = "state_2", 
    functions = {
      work = function(self, task) -- self is origin object, not cfg and not "obj_1_fsm"
        self:workHard(task)
        return true -- end of work, no work more, return value can be various cause workHard can be continuous
      end
    }
  },
  state_2 = {
    onNext = function(self) return self:ready() and "chill" or "state_1" end,
    onVisit = function(self) print("visit state_2, still work to do: "..self:workRemained()) end,
    functions = {
      onWorkComplete = function(self)
        return self:nextTask()
      end
    },
  },
  chill = {
    next_state = "__current",
    onVisit = function(self) print(tostring(self).." finished work") end
  },
}

local function genTasks(count)
  local ret = {}
  for i=1,count do
    table.insert(ret,i)
  end
  return ret
end

local type_1_meta = {
  start = function(self)
    print(tostring(self).." work started")
    return true
  end,
  workHard = function(self, task)
    print("task ["..task.."] in progress")
  end,
  current_task = 1,
  nextTask = function(self) 
    if self.current_task==#self.tasks then
      self["end"] = true
      return false
    end
    self.current_task = self.current_task + 1
    return true
  end,
  getTask = function(self) return self.tasks[self.current_task] end,
  work = function(self)
    local work_status = self.states:work(self:getTask())
    local ret = self.states:onWorkComplete()
    if work_status then -- task ready state
      self.states:next()
      return true
    end
    if ret then
      self.states:next() -- task complete & closed state, need next work
      return true
    end
    if not work_status and not ret then -- tasks complete and task queue is empty
        self.states:next()
        return false
    end
    return work_status or ret
  end,
  workRemained = function(self)
    return #self.tasks-self.current_task
  end,
  ready = function(self) return self["end"] and true or false end,
}

local function createObj1(name, task_count)
  assert(type(name)=="string" and name~="", "invalid name")
  local ret = {
    tasks = genTasks(task_count),
    name = name,
    current_task = 1,
  }
  ret.states = fsm.new("obj_1_fsm", ret, cfg, "state_1")
  return setmetatable(ret, {__index = type_1_meta, __tostring = function(self) return self.name end})
end

local obj = createObj1("obj_1", 10)
obj:start()
while not obj:ready() do
  obj:work()
end
print()
local obj2 = createObj1("obj_2", 3)
obj2:start()
while obj2:work() do
end
