local isfile = isfile or function(file)
	local suc, res = pcall(function()
		return readfile(file)
	end)
	return suc and res ~= nil and res ~= ''
end
local delfile = delfile or function(file)
	writefile(file, '')
end

local function downloadFile(path, func)
	if not isfile(path) then
		local suc, res = pcall(function()
			return game:HttpGet('https://raw.githubusercontent.com/n7xRqLm4Wk9/fadeware/main/_compiled/'..select(1, path:gsub('fadeware/', '')), true)
		end)
		if not suc or res == '404: Not Found' then
			error(res)
		end
		if path:find('.lua') then
			res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after fadeware updates.\n'..res
		end
		writefile(path, res)
	end
	return (func or readfile)(path)
end

local function wipeFolder(path)
	if not isfolder(path) then return end
	for _, file in listfiles(path) do
		if file:find('loader') then continue end
		if isfile(file) and select(1, readfile(file):find('--This watermark is used to delete the file if its cached, remove it to make the file persist after fadeware updates.')) == 1 then
			delfile(file)
		end
	end
end

for _, folder in {'fadeware', 'fadeware/games', 'fadeware/profiles', 'fadeware/assets', 'fadeware/libraries', 'fadeware/guis'} do
	if not isfolder(folder) then
		makefolder(folder)
	end
end

if not shared.FadeWareDeveloper then
	local _, subbed = pcall(function()
		return game:HttpGet('https://github.com/n7xRqLm4Wk9/fadeware')
	end)
	local commit = subbed:find('currentOid')
	commit = commit and subbed:sub(commit + 13, commit + 52) or nil
	commit = commit and #commit == 40 and commit or 'main'
	if commit == 'main' or (isfile('fadeware/profiles/commit.txt') and readfile('fadeware/profiles/commit.txt') or '') ~= commit then
		wipeFolder('fadeware')
		wipeFolder('fadeware/games')
		wipeFolder('fadeware/guis')
		wipeFolder('fadeware/libraries')
	end
	writefile('fadeware/profiles/commit.txt', commit)
end

return loadstring(downloadFile('fadeware/main.lua'), 'main')()