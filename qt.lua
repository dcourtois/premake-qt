

--
-- always include _preload so that the module works even when not embedded.
--
if premake.extensions == nil or premake.extensions.qt == nil then
	include ( "_preload.lua" )
end

--
-- define the qt extension
--
premake.extensions.qt = {

	--
	-- these are private, do not touch
	--
	enabled = false,
	defaultpath = os.getenv("QTDIR") or os.getenv("QT_DIR"),
	major_version = "5"
}

-- include list of modules
-- note: ideally, I would just include the correct version in premake.extensions.qt.enable but for some
--       reason when doing it, it fails with a "cannot open file..." although the working dir and filename
--       are exactly the same as when done from here... so until I find out why, load both.
premake.extensions.qt.modules = {}
include ( "qtmodules.qt5.lua" )
include ( "qtmodules.qt6.lua" )


--
-- Enable Qt for a project. Be carefull, although this is a method, it will enable Qt
-- functionalities only in the current configuration.
--
-- @param major_version
--		This is the major Qt version number used, passed as a string. If omitted, defaults to "5".
--
function premake.extensions.qt.enable(major_version)

	local qt = premake.extensions.qt

	-- store the major version if it was provided
	if major_version ~= nil then
		if qt.modules["qt" .. major_version] ~= nil then
			qt.major_version = major_version
		else
			printf("No modules file found for version \"%s\". Fallback to module files for version \"5\"", major_version)
		end
	end

	-- validate it

	-- enable Qt for the current config
	qtenabled ( true )

	-- setup our overrides if not already done
	if qt.enabled == false then
		qt.enabled = true
		premake.override(premake.oven, "bakeConfig", qt.customBakeConfig)
		premake.override(premake.oven, "addGeneratedFiles", qt.customAddGeneratedFiles)
	end

end


--
-- Get the include, lib and bin paths
--
function premake.extensions.qt.getPaths(cfg)
	-- get the main path
	local qtpath = cfg.qtpath or premake.extensions.qt.defaultpath

	-- return the paths
	return cfg.qtincludepath or (qtpath and qtpath .. "/include"),
		   cfg.qtlibpath     or (qtpath and qtpath .. "/lib"),
		   cfg.qtbinpath     or (qtpath and qtpath .. "/bin")
end


--
-- Get the Qt version number
--
-- @param cfg
--		The input configuration
-- @param includepath
--		The Qt include path
-- @return
--		The Qt version string
--
function premake.extensions.qt.getVersion(cfg, includepath)
	-- get the version number
	local qtversion = cfg.qtversion

	-- if we haven't cached the version and/or the project didn't specify one...
	-- try and work it out
	if qtversion == nil then
		-- pre-5.6 stored the version string in qglobal.h ; post-5.6 in qconfig.h
		local qtheaderpaths = { includepath .. "/QtCore/qconfig.h", includepath .. "/QtCore/qglobal.h" }
		for _, headerpath in ipairs(qtheaderpaths) do

			-- scan the file if it exists
			local file = io.open(headerpath)
			if file ~= nil then

				-- scan to find 'QT_VERSION_STR' and extract the version number
				for line in file:lines() do
					if line:find("QT_VERSION_STR") then
						qtversion = line:sub(line:find("\"")+1, line:find("\"[^\"]*$")-1)
						break
					end
				end

				io.close(file)
			end

			-- if we found the version, break out of the loop
			if qtversion ~=nil then
				break
			end
		end
	end

	return qtversion
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
	return cfg.qtgenerateddir or cfg.objdir
end


--
-- Override the premake.oven.bakeConfig method to configure the configuration object
-- with the Qt module (e.g. add the include directories, the links, etc.)
--
-- @param base
--		The original bakeConfig method.
-- @param wks
--		The current workspace.
-- @param prj
--		The current project.
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
	local modules = qt.modules["qt" .. qt.major_version]

	-- bake
	local config = base(wks, prj, buildcfg, platform, extraFilters)

	-- do nothing if qt is not enabled for this config
	if config.qtenabled ~= true then
		return config
	end

	-- get the needed pathes
	local qtinclude, qtlib, qtbin = qt.getPaths(config)
	if qtinclude == nil or qtlib == nil or qtbin == nil then
		error(
			"Some Qt paths were not found. Ensure that you set the Qt path using\n" ..
			"either 'qtpath' in your project configuration or using the QTDIR or\n" ..
			"QT_DIR environment variable. You can also use the 'qtincludepath',\n" ..
			"'qtlibpath' and 'qtbinpath' individually."
		)
	end

	-- bake paths in the config (in case they were retrieved from the environment variable, they
	-- will not be in the config objects, and we need them in the other baking methods)
	config.qtincludepath	= qtinclude
	config.qtlibpath		= qtlib
	config.qtbinpath		= qtbin

	-- add the includes and libraries directories
	local includedirs = iif(config.qtuseexternalinclude, config.externalincludedirs, config.includedirs)
	table.insert(includedirs, qtinclude)
	table.insert(config.libdirs, qtlib)

	-- get the prefix and suffix
	local prefix	= config.qtprefix or "Qt" .. qt.major_version
	local suffix	= config.qtsuffix or ""

	-- platform specifics
	if _TARGET_OS == "macosx" then

		-- -F set where the frameworks are located, and it's needed for header and libs
		table.insert(config.buildoptions, "-F" .. qtlib)
		table.insert(config.linkoptions, "-F" .. qtlib)

		-- for dynamic libs resolution
		table.insert(config.linkoptions, "-Wl,-rpath," .. qtlib)

	elseif _TARGET_OS == "linux" then

		-- for dynamic libs resolution
		table.insert(config.linkoptions, "-Wl,-rpath," .. qtlib)

	elseif _TARGET_OS == "windows" then

		-- handle the qtmain lib
		if config.qtmain == true then
			if qt.major_version == "6" then
				printf("\"qtmain\" function is deprecated in Qt6, please use the \"entrypoint\" module instead.")
				table.insert(config.qtmodules, "entrypoint")
			else
				table.insert(config.links, "qtmain" .. suffix .. ".lib")
			end
		end

	end

	-- add the modules
	for _, modulename in ipairs(config.qtmodules) do

		-- private modules are indicated by modulename-private
		-- this will implicitly add the associated public module and the private module header path
		if modulename:endswith("-private") then

			-- we need the version for the private header path
			config.qtversion = qt.getVersion(config, qtinclude)
			if config.qtversion == nil then
				error(
					"Cannot add module \"" .. modulename .. "\": unable to determine Qt Version.\n" ..
					"You can explicitly set the version number using 'qtversion' in your project\n" ..
					"configuration."
				)
			end

			-- truncate the "-private"
			modulename = modulename:sub(1, -9)

			-- add the private part of the module
			local module = modules[modulename]
			if module ~= nil then
				local privatepath = path.join(qt.getIncludeDir(config, module), config.qtversion)
				local includedirs = iif(config.qtuseexternalinclude, config.externalincludedirs, config.includedirs)
				table.insert(includedirs, privatepath)
				table.insert(includedirs, path.join(privatepath , module.include))
			end

		end

		-- add the public part of the module
		if modules[modulename] ~= nil then

			local module	= modules[modulename]
			local libname	= prefix .. module.name .. suffix

			-- configure the module
			local includedirs = iif(config.qtuseexternalinclude, config.externalincludedirs, config.includedirs)
			table.insert(includedirs, qt.getIncludeDir(config, module))

			if module.defines ~= nil then
				qt.mergeDefines(config, module.defines)
			end

			if config.kind ~= "StaticLib" then
				if _TARGET_OS == "macosx" then
					table.insert(config.links, path.join(qtlib, module.include .. ".framework"))
				else
					table.insert(config.links, libname)
				end

				-- add additional links
				if module.links ~= nil then
					for _, additionallink in ipairs(module.links) do
						table.insert(config.links, additionallink)
					end
				end
			end
		else
			printf("Unknown module \"%s\" used.", modulename)
		end
	end

	-- return the modified config
	return config

end


--
-- Helper function used to merge args coming from file configs and from the project config.
--
-- @param ...
--		List of tables to merge.
-- @return
--		A list (indexed from 1 to N) of the arguments that were stored in the input tables.
--
function premake.extensions.qt.combineArgs(...)
	local result = {}
	for _, t in ipairs({...}) do
		if type(t) == "table" then
			for _, v in ipairs(t) do
				table.insert(result, v)
			end
		end
	end
	return result
end


--
-- Helper function that is used to add a custom command.
--
-- @note
--		This should not be needed. Using the file config's buildmessage, buildcommands, etc.
--		should work. But for some reason, when doing it like this, gmake2 doesn't get the
--		custom commands, even though the other generators do (at least VS ones and gmake)
--		Since this workaround uses an internal Premake-core field, this helper is used to
--		make future updates easier.
--
-- @param fcfg
--		The file config object on which we want to add the custom command.
-- @param options
--		Custom command options. This should be a table, with the following fields:
--		- message (string)			 : The build message. Mandatory.
--		- commands (table of strings): The build commands. Mandatory.
--		- outputs (table of strings) : The output files. Mandatory.
--		- inputs (table of string)	 : List of files on this this command depends. Optional.
--		- compile (boolean)			 : If true, the outputs of this command will be compiled. Optional (false by default).
--
function premake.extensions.qt.addCustomCommand(fcfg, options)
	local configset = premake.configset
	local field		= premake.field

	-- mandatory stuff
	configset.store(fcfg._cfgset, field.get("buildmessage"),  options.message)
	configset.store(fcfg._cfgset, field.get("buildcommands"), options.commands)
	configset.store(fcfg._cfgset, field.get("buildoutputs"),  options.outputs)

	-- optional ones
	if options["inputs"] ~= nil and #options["inputs"] > 0 then
		configset.store(fcfg._cfgset, field.get("buildinputs"), options["inputs"])
	end
	if options["compile"] == true then
		configset.store(fcfg._cfgset, field.get("compilebuildoutputs"), true)
	end
end


--
-- Override the base premake.oven.addGeneratedFiles method in order to add our
-- custom build rules for special Qt files.
--
-- @param base
--		The base method that we must call.
-- @param wks
--		the workspaces
--
function premake.extensions.qt.customAddGeneratedFiles(base, wks)
	for prj in premake.workspace.eachproject(wks) do
		local files = table.shallowcopy(prj._.files)
		for cfg in premake.project.eachconfig(prj) do
			table.foreachi(files, function(node)
				premake.extensions.qt.customAddFileConfig(node, cfg)
			end)
		end
	end
	base(wks)
end

--
-- Add our custom build rules for special Qt files
--
-- @param node
--		The file configuration object.
-- @param cfg
--		The current configuration that we're adding to the file configuration.
--
function premake.extensions.qt.customAddFileConfig(node, cfg)

	-- do nothing else if Qt is not enabled
	if cfg.qtenabled ~= true then
		return
	end

	-- get the current config
	local config = premake.fileconfig.getconfig(node, cfg)

	-- now filter the files, and depending on their type, add our
	-- custom build rules

	local qt = premake.extensions.qt

	-- ui files
	if qt.isUI(config.abspath) then
		qt.addUICustomBuildRule(config, cfg)

		-- add directory in which the UI headers are generated to the config, if not already.
		local includedir = qt.getGeneratedDir(cfg)
		if table.contains(cfg.includedirs, includedir) == false then
			table.insert(cfg.includedirs, includedir)
		end

	-- resource files
	elseif qt.isQRC(config.abspath) then
		qt.addQRCCustomBuildRule(config, cfg)

	-- translation files
	elseif qt.isTS(config.abspath) then
		qt.addTSCustomBuildRule(config, cfg)

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

	-- build the command
	local command = "\"" .. fcfg.config.qtbinpath .. "/uic\" -o \"" .. path.getrelative(fcfg.project.location, output) .. "\" \"" .. fcfg.relpath.. "\""

	-- if we have custom commands, add them
	table.foreachi(qt.combineArgs(fcfg.config.qtuicargs, fcfg.qtuicargs), function (arg)
		command = command .. " \"" .. arg .. "\""
	end)

	-- add the custom build rule
	qt.addCustomCommand(fcfg, {
		message	 = "Running uic on %{file.name}",
		commands = { command },
		outputs	 = { output },
		inputs	 = { fcfg.abspath }
	})
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
-- Adds the custom build for qrc files.
--
-- @param fcfg
--		The config for a single file.
-- @param cfg
--		The config of the project ?
--
function premake.extensions.qt.addQRCCustomBuildRule(fcfg, cfg)

	local qt = premake.extensions.qt

	-- get the input and output files
	local output = qt.getGeneratedDir(cfg) .. "/qrc_" .. fcfg.basename .. ".cpp"

	-- build the command
	local command = "\"" .. fcfg.config.qtbinpath .. "/rcc\" -name \"" .. fcfg.basename .. "\" -no-compress \"" .. fcfg.relpath .. "\" -o \"" .. path.getrelative(fcfg.project.location, output) .. "\""

	-- if we have custom commands, add them
	table.foreachi(qt.combineArgs(fcfg.config.qtrccargs, fcfg.qtrccargs), function (arg)
		command = command .. " \"" .. arg .. "\""
	end)

	-- get the files embedded on the qrc, to add them as input dependencies :
	-- if we edit a .qml embedded in the qrc, we want the qrc to re-build whenever
	-- we edit the qml file
	local inputs = qt.getQRCDependencies(fcfg)

	-- add the custom build rule
	qt.addCustomCommand(fcfg, {
		message	 = "Running qrc on %{file.name}",
		commands = { command },
		outputs	 = { output },
		inputs	 = inputs,
		compile	 = true
	})
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

	-- ensure the file was correctly opened
	if file ~= nil then
		local qrcdirectory = path.getdirectory(fcfg.abspath)

		-- parse the qrc file to find the files it will embed
		for line in file:lines() do
			-- try to find the <file></file> entries
			local match = string.match(line, "<file>(.+)</file>")
			if match == nil then
				match = string.match(line, "<file%s+[^>]*>(.+)</file>")
			end

			-- if we have one, compute the path of the file, and add it to the dependencies
			-- NOTE: the QRC files are relative to the folder containing the qrc file.
			if match ~= nil then
				table.insert(dependencies, path.join(qrcdirectory, match))
			end
		end

		-- close the qrc file
		io.close(file)
	end

	return dependencies
end


--
-- Checks if a file is a ts file.
--
-- @param filename
--		The file name to check.
-- @return
--		true if the file needs to be run through the lrelease tool, false if not.
--
function premake.extensions.qt.isTS(filename)
	return path.hasextension(filename, { ".ts" })
end


--
-- Adds the custom build for a ts file.
--
-- @param fcfg
--		The config for a single file.
-- @param cfg
--		The config of the project ?
--
function premake.extensions.qt.addTSCustomBuildRule(fcfg, cfg)
	local qt = premake.extensions.qt

	-- create the output file name
	local qtqmgenerateddir	= fcfg.qtqmgenerateddir or fcfg.config.qtqmgenerateddir
	local outputdir			= qtqmgenerateddir or cfg.targetdir
	local output			= path.join(outputdir, fcfg.basename .. ".qm")

	-- create the command
	local command = "\"" .. fcfg.config.qtbinpath .. "/lrelease\" \"" .. fcfg.relpath .. "\""
	command = command .. " -qm \"" .. path.getrelative(fcfg.project.location, output) .. "\""

	-- add additional args
	table.foreachi(qt.combineArgs(cfg.qtlreleaseargs, fcfg.qtlreleaseargs), function (arg)
		command = command .. " \"" .. arg .. "\""
	end)

	-- add the custom build rule
	qt.addCustomCommand(fcfg, {
		message	 = "Running lrelease on %{file.name}",
		commands = { command },
		outputs	 = { output }
	})
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
		if file ~= nil then

			-- scan it to find 'Q_OBJECT' or 'Q_GADGET'
			for line in file:lines() do
				if line:find("^%s*Q_OBJECT%f[^%w_]") or line:find("^%s*Q_GADGET%f[^%w_]") then
					needmoc = true
					break
				end
			end

			io.close(file)
		end
	end

	return needmoc
end


--
-- Adds the custom build for a moc'able file.
--
-- @param fcfg
--		The config for a single file.
-- @param cfg
--		The config of the project ?
--
function premake.extensions.qt.addMOCCustomBuildRule(fcfg, cfg)

	local qt = premake.extensions.qt

	-- get the project's location (to make paths relative to it)
	local projectloc = fcfg.project.location

	-- create the output file name
	local output = qt.getGeneratedDir(cfg) .. "/moc_" .. fcfg.basename .. ".cpp"

	-- create the command
	local command = "\"" .. fcfg.config.qtbinpath .. "/moc\" \"" .. fcfg.relpath .. "\""
	command = command .. " -o \"" .. path.getrelative(projectloc, output) .. "\""

	-- if we have a precompiled header, prepend it
	if fcfg.config.pchheader then
		command = command .. " -b \"" .. fcfg.config.pchheader .. "\""
	end

	-- now create the arguments
	local arguments = ""

	-- append the defines to the arguments
	table.foreachi(qt.combineArgs(fcfg.config.defines, fcfg.defines), function (define)
		arguments = arguments .. " -D" .. define
	end)

	-- append the include directories to the arguments
	table.foreachi(qt.combineArgs(fcfg.config.includedirs, fcfg.includedirs), function (include)
		arguments = arguments .. " -I\"" .. path.getrelative(projectloc, include) .. "\""
	end)

	-- if we have custom commands, add them
	table.foreachi(qt.combineArgs(fcfg.config.qtmocargs, fcfg.qtmocargs), function (arg)
		arguments = arguments .. " \"" .. arg .. "\""
	end)

	-- handle the command line size limit
	command = qt.handleCommandLineSizeLimit(cfg, fcfg, command, arguments)

	-- add the custom build rule
	qt.addCustomCommand(fcfg, {
		message	 = "Running moc on %{file.name}",
		commands = { command },
		outputs	 = { output },
		compile	 = true
	})
end


--
-- Checks if the command line will exceed the given size limit, and will output
-- the arguments to a file if so. The updated command is returned
--
-- @param cfg
--		The configuration object.
-- @param fcfg
--		The file configuration object.
-- @param command
--		The command.
-- @param arguments
--		The arguments.
-- @return
--		The updated command.
--
function premake.extensions.qt.handleCommandLineSizeLimit(cfg, fcfg, command, arguments)

	-- check if we need to output to a file
	local limit = fcfg.config.qtcommandlinesizelimit or iif(_TARGET_OS == "windows", 2047, nil)
	if limit ~= nil and string.len(command) + string.len(arguments) + 1 > limit then
		local qt = premake.extensions.qt

		-- create the argument file name
		local filename = qt.getGeneratedDir(cfg) .. "/moc_" .. fcfg.basename .. ".args"

		-- output the arguments to it
		local file = io.open(filename, "w")
		file:write(arguments)
		io.close(file)

		-- update the command to load this file
		return command .. " @\"" .. filename .. "\""
	end

	-- update the command to include the arguments
	return command .. " " .. arguments

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


--
-- Get the include dir for the given module.
--
-- @param config
--		The current config.
-- @param module
--		The module.
-- @return
--		The include dir.
--
function premake.extensions.qt.getIncludeDir(config, module)

	if _TARGET_OS == "macosx" then
		return path.join(config.qtlibpath, module.include .. ".framework", "Headers")
	else
		return path.join(config.qtincludepath, module.include)
	end

end
