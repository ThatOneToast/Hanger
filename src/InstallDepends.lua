-- Install Dependencies from the requirements.txt file using luarocks

local file = io.open("requirements.txt", "r")
if not file then
    error("Failed to open requirements.txt file.")
end

local dependencies = {}

for line in file:lines() do
    local dependency = line:match("([^%s]+)")
    if dependency then
        dependencies[#dependencies + 1] = dependency
    end
end
file:close()

for _, dependency in ipairs(dependencies) do
    print("Installing dependency: " .. dependency)
    os.execute("luarocks install " .. dependency)
end