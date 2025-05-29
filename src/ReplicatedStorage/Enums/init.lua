local self = setmetatable({}, { __index = Enum })
for _, child in script:GetChildren() do
	if not child:IsA("ModuleScript") then
		continue
	end
	self[child.Name] = require(child)
end
return self
