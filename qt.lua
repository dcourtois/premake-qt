

--
-- always include _preload so that the module works even when not embedded.
--
include ( "_preload.lua" )

--
-- define the qt extension
--
premake.extensions.qt = {
	
	--
	-- these are private, do not touch
	--
	enabled = false,
	defaultPath = os.getenv("QTDIR") or os.getenv("QT_DIR")
}

--
-- include list of modules
--
include ( "qtmodules.lua" )

--
-- Enable Qt for a project. Be carefull, although this is a method, it will enable Qt
-- functionalities only in the current configuration.
--
function premake.extensions.qt.enable()

 	local qt = premake.extensions.qt
 	
 	-- enable Qt for the current config
 	qtenabled ( true )

	-- setup our overrides if not already done
	if qt.enabled == false then
		qt.enabled = true
		premake.override(premake.oven, "bakeFiles", qt.customBakeFiles)
		premake.override(premake.oven, "bakeConfig", qt.customBakeConfig)
		premake.override(premake.fileconfig, "addconfig",  qt.customAddFileConfig)
	end

end

--
-- A small function which will get the generated directory for a given config.
-- If objdir was specified, it will be used. Else, it's the project's location +
-- obj + configuration + platform
--
-- @param cfg
--		The input configuration
--
function premake.extensions.qt.getGeneratedDir(cfg)

	-- check if the user specified a qtgenerateddir
	if cfg.qtgenerateddir ~= nil then
		return cfg.qtgenerateddir
	end

	-- try the objdir, if it's already baked
	if cfg.objdir ~= nil then
		return cfg.objdir
	end

	-- last resort, revert to the default obj path used by premake.
	-- note : this is a bit hacky, but there is no easy "getobjdir(cfg)" method in
	-- premake, thus this piece of code
	dir = path.join(cfg.project.location, "obj")
	if cfg.platform then
		dir = path.join(dir, cfg.platform)
	end
	dir = path.join(dir, cfg.buildcfg)
	return path.getabsolute(dir)

end

--
-- Override the premake.oven.bakeConfig method to configure the configuration object
-- with the Qt module (e.g. add the include directories, the links, etc.)
--
-- @param base
--		The original bakeConfig method.
-- @param prj
--		The current project.
-- @param wks
--		The current workspace.
-- @param buildcfg
--		The current configuration.
-- @param platform
--		The current platform.
-- @param extraFilters
--		Optional additional filters.
-- @return
--		The configuration object.
--
function premake.extensions.qt.customBakeConfig(base, wks, prj, buildcfg, platform, extraFilters)

	local qt = premake.extensions.qt
	local modules = qt.modules

	-- bake
	local config = base(wks, prj, buildcfg, platform, extraFilters)

	-- do nothing if qt is not enabled for this config
	if config.qtenabled ~= true then
		return config
	end

	-- get the installation path
	local qtpath = config.qtpath or qt.defaultPath
	if qtpath == nil then
		error("Qt path is not set. Either use 'qtpath' in your project configuration or set the QTDIR or QT_DIR environment variable.")
	end

	-- bake qtpath in the config (in case it was retrieved from the environment variable, it
	-- will not be in the config objects, and we need it in the other baking methods)
	config.qtpath = qtpath

	-- add the includes and libraries directories
	table.insert(config.includedirs, qtpath .. "/include")
	table.insert(config.libdirs, qtpath .. "/lib")

	-- add the modules
	for _, modulename in ipairs(config.qtmodules) do

		if modules[modulename] ~= nil then

			local module	= modules[modulename]
			local prefix	= config.qtprefix or ""
			local suffix	= config.qtsuffix or ""
			local libname	= prefix .. module.name .. suffix .. ".lib"
			local dllname	= prefix .. module.name .. suffix .. ".dll"

			-- configure the module
			table.insert(config.includedirs, qtpath .. "/include/" .. module.include)
			table.insert(config.links, libname)
			if module.defines ~= nil then
				qt.mergeDefines(config, module.defines)
			end

			-- add additional links
			if module.links ~= nil then
				for _, additionallink in ipairs(module.links) do
					table.insert(config.links, additionallink)
				end
			end
		end
	end

	-- return the modified config
	return config

end

--
-- Override the premake.oven.bakeFiles method to be able to add the Qt generated
-- files to the project.
--
-- @param base
--		The original bakeFiles method.
-- @param prj
--		The current project.
-- @return
--		The table of files.
--
function premake.extensions.qt.customBakeFiles(base, prj)

	local qt		= premake.extensions.qt
	local project	= premake.project

	-- parse the configurations for the project
	for cfg in project.eachconfig(prj) do

		-- ignore this config if Qt is not enabled
		if cfg.qtenabled == true then

			local mocs	    = {}
			local qrc	    = {}
			local objdir    = qt.getGeneratedDir(cfg)

			-- add the objdir as an include path
			table.insert(cfg.includedirs, objdir)

			-- check each file in this configuration
			table.foreachi(cfg.files, function(filename)

				if qt.isQRC(filename) then
					table.insert(qrc, filename)
				elseif qt.needMOC(filename) then
					table.insert(mocs, filename)
				end

			end)

			-- the moc files
			table.foreachi(mocs, function(filename)
				table.insert(cfg.files, objdir .. "/moc_" .. path.getbasename(filename) .. ".cpp")
			end)

			-- the qrc files
			table.foreachi(qrc, function(filename)
				table.insert(cfg.files, objdir .. "/qrc_" .. path.getbasename(filename) .. ".cpp")
			end)

		end
	end

	return base(prj)

end

--
-- Override the base premake.fileconfig.addconfig method in order to add our
-- custom build rules for special Qt files.
--
-- @param base
--		The base method that we must call.
-- @param fcfg
--		The file configuration object.
-- @param cfg
--		The current configuration that we're adding to the file configuration.
--
function premake.extensions.qt.customAddFileConfig(base, fcfg, cfg)

	-- call the base method to add the file config
	base(fcfg, cfg)

	-- do nothing else if Qt is not enabled
	if cfg.qtenabled ~= true then
		return
	end

	-- get the current config
	local config = premake.fileconfig.getconfig(fcfg, cfg)

	-- now filter the files, and depending on their type, add our
	-- custom build rules

	local qt = premake.extensions.qt

	-- ui files
	if qt.isUI(config.abspath) then
		qt.addUICustomBuildRule(config, cfg)

	-- resource files
	elseif qt.isQRC(config.abspath) then
		qt.addQRCCustomBuildRule(config, cfg)

	-- moc files
	elseif qt.needMOC(config.abspath) then
		qt.addMOCCustomBuildRule(config, cfg)

	end

	-- the cpp files generated by the qrc tool can't use precompiled header, so
	-- if we have pch and the file is a Qt generated one, check if it's generated
	-- by qrc to disable pch for it.
	if cfg.pchheader and config.abspath:find(qt.getGeneratedDir(cfg), 1, true) then

		-- the generated dir path might contain special pattern character, so escape them
		local pattern = path.wildcards(qt.getGeneratedDir(cfg))

		-- if it's a qrc generated file, disable pch
		if config.abspath:find(pattern .. "/qrc_.+%.cpp") then
			config.flags.NoPCH = true
		end
	end

end

--
-- Checks if a file is a ui file.
--
-- @param filename
--		The file name to check.
-- @return
--		true if the file needs to be run through the uic tool, false if not.
--
function premake.extensions.qt.isUI(filename)
	return path.hasextension(filename, { ".ui" })
end

--
-- Adds the custom build for ui files.
--
-- @param fcfg
--	  The config for a single file.
-- @param cfg
--    The config of the project ?
--
function premake.extensions.qt.addUICustomBuildRule(fcfg, cfg)

	local qt = premake.extensions.qt

	-- get the output file
	local output = qt.getGeneratedDir(cfg) .. "/ui_" .. fcfg.basename .. ".h"
	output = path.getrelative(fcfg.project.location, output)

	-- build the command
	local command = fcfg.config.qtpath .. "/bin/uic -o \"" .. output .. "\" \"" .. fcfg.relpath.. "\""

	-- if we have custom commands, add them
	if fcfg.config.qtrccargs then
		table.foreachi(fcfg.config.qtuicargs, function (arg)
			command = command .. " \"" .. arg .. "\""
		end)
	end

	-- add the custom build rule
	fcfg.buildmessage	= "Uic'ing " .. fcfg.name
	fcfg.buildcommands	= { command }
	fcfg.buildoutputs	= { output }

end

--
-- Checks if a file is a qrc file.
--
-- @param filename
--		The file name to check.
-- @return
--		true if the file needs to be run through the rcc tool, false if not.
--
function premake.extensions.qt.isQRC(filename)
	return path.hasextension(filename, { ".qrc" })
end

--
-- Adds the custom build for ui files.
--
-- @param fcfg
--	  The config for a single file.
-- @param cfg
--    The config of the project ?
--
function premake.extensions.qt.addQRCCustomBuildRule(fcfg, cfg)

	local qt = premake.extensions.qt

	-- get the input and output files
	local output = qt.getGeneratedDir(cfg) .. "/qrc_" .. fcfg.basename .. ".cpp"
	output = path.getrelative(fcfg.project.location, output)

	-- build the command
	local command = fcfg.config.qtpath .. "/bin/rcc -name \"" .. fcfg.basename .. "\" -no-compress \"" .. fcfg.relpath .. "\" -o \"" .. output .. "\""

	-- if we have custom commands, add them
	if fcfg.config.qtrccargs then
		table.foreachi(fcfg.config.qtrccargs, function (arg)
			command = command .. " \"" .. arg .. "\""
		end)
	end

	-- get the files embedded on the qrc, to add them as input dependencies :
	-- if we edit a .qml embedded in the qrc, we want the qrc to re-build whenever
	-- we edit the qml file
	local inputs = qt.getQRCDependencies(fcfg)

	-- add the custom build rule
	fcfg.buildmessage	= "Rcc'ing " .. fcfg.name
	fcfg.buildcommands	= { command }
	fcfg.buildoutputs	= { output }
	if #inputs > 0 then
		fcfg.buildinputs = inputs
	end

end

--
-- Get the files referenced by a qrc file.
--
-- @param fcfg
--		The configuration of the file
-- @return
--		The list of project relative file names of the dependencies
--
function premake.extensions.qt.getQRCDependencies(fcfg)

	local dependencies = {}
	local file = io.open(fcfg.abspath)
	local qrcdirectory = path.getdirectory(fcfg.abspath)
	local projectdirectory = fcfg.project.location

	-- parse the qrc file to find the files it will embed
	for line in file:lines() do

		-- try to find the <file></file> entries
		local match = string.match(line, "<file>(.+)</file>")
		if match == nil then
			match = string.match(line, "<file%s+[^>]*>(.+)</file>")
		end

		-- if we have one, compute the path of the file, and add it to the dependencies
		-- note : the QRC file are relative to the folder containing the qrc file.
		if match ~= nil then
			table.insert(dependencies, path.getrelative(projectdirectory, qrcdirectory .. "/" .. match))
		end

	end

	-- close the qrc file
	io.close(file)

	return dependencies

end

--
-- Checks if a file needs moc'ing.
--
-- @param filename
--		The file name to check.
-- @return
--		true if the header needs to be run through the moc tool, false if not.
--
function premake.extensions.qt.needMOC(filename)

	local needmoc = false

	-- only handle headers
	if path.iscppheader(filename) then

		-- open the file
		local file = io.open(filename)

		-- scan it to find 'Q_OBJECT'
		for line in file:lines() do
			if line:find("Q_OBJECT") then
				needmoc = true
				break
			end
		end

		io.close(file)
	end

	return needmoc
end

--
-- Adds the custom build for a moc'able file.
--
-- @param fcfg
--	  The config for a single file.
-- @param cfg
--    The config of the project ?
--
function premake.extensions.qt.addMOCCustomBuildRule(fcfg, cfg)

	local qt = premake.extensions.qt

	-- get the project's location (to make paths relative to it)
	local projectloc = fcfg.project.location

	-- create the output file name
	local output = qt.getGeneratedDir(cfg) .. "/moc_" .. fcfg.basename .. ".cpp"
	output = path.getrelative(projectloc, output)

	-- create the moc command
	local command = fcfg.config.qtpath .. "/bin/moc \"" .. fcfg.relpath .. "\" -o \"" .. output .. "\""

	-- if we have a precompiled header, prepend it
	if fcfg.config.pchheader then
		command = command .. " \"-b" .. fcfg.config.pchheader .. "\""
	end

	-- append the defines to the command
	if #fcfg.config.defines > 0 then
		table.foreachi(fcfg.config.defines, function (define)
			command = command .. " -D" .. define
		end)
	end

	-- append the include directories to the command
	if #fcfg.config.includedirs > 0 then
		table.foreachi(fcfg.config.includedirs, function (include)
			command = command .. " -I\"" .. path.getrelative(projectloc, include) .. "\""
		end)
	end

	-- if we have custom commands, add them
	if fcfg.config.qtmocargs then
		table.foreachi(fcfg.config.qtmocargs, function (arg)
			command = command .. " \"" .. arg .. "\""
		end)
	end

	-- add the custom build rule
	fcfg.buildmessage	= "Moc'ing " .. fcfg.name
	fcfg.buildcommands	= { command }
	fcfg.buildoutputs	= { output }

end

--
-- Merge defines into the configuration, taking care of not adding the
-- same define twice.
--
-- @param config
--		The configuration object.
-- @param defines
--		The defines to add.
--
function premake.extensions.qt.mergeDefines(config, defines)

	-- a function which checks if a value is contained in a table.
	local contains = function (t, v)
		for _, d in ipairs(t) do
			if d == v then
				return true
			end
		end
		return false
	end

	-- ensure defines is a table
	if type(defines) ~= "table" then
		defines = { defines }
	end

	-- add each defines
	for _, define in ipairs(defines) do
		if contains(config.defines, define) == false then
			table.insert(config.defines, define)
		end
	end

end
