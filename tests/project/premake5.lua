-- require( "premake-qt/qt.lua" ) -- either in current script or in premake-system.lua

local Root = path.getabsolute(".") .. "/"  -- getabsolute remove trailling /

-- option to allow to provide qt path from command line
newoption {
  trigger = "qt-root",
  value = "path",
  description = "path of qt root (contains lib/libQt5Core.a include/Qt5Core bin)"
}

if (_ACTION == nil) then
  return
end

local LocationDir = path.join(Root, "solution", _ACTION)


-- this line is optional, but it avoids writting premake.extensions.qt to
-- call the plugin's methods.
local qt = premake.extensions.qt

if _OPTIONS["qt-root"] ~= nil then
  QtRoot = path.normalize(_OPTIONS["qt-root"])
end

workspace "Project"
  -- regular options (unrelated to premake-qt)
  location ( LocationDir )
  configurations { "Debug", "Release" }

  cppdialect "C++17"
  warnings "Extra"

  objdir(path.join(LocationDir, "obj")) -- premake adds $(configName)/$(AppName)
  targetdir(path.join(LocationDir, "bin"))

  -- this function enables Qt (for current config, so actually whole solution)
  qt.enable()

  if (QtRoot ~= nil and QtRoot ~= "") then
  -- Setup the path where Qt include and lib folders are found.
    qtpath(QtRoot)
  end
  -- Specify a prefix used by the libs, (so generally Qt4, Qt5 or Qt6)
  qtprefix "Qt6"

  -- Debug configuration
  filter "configurations:Debug"
    -- This one is only used when linking against debug or custom versions of Qt.
    -- For instance, in debug, the libs are suffixed with a `d`.
    qtsuffix "d"
    -- regular options (unrelated to premake-qt)
    targetsuffix "d"
    optimize "Off"
    symbols "On"
    defines "DEBUG"

  -- Release configuration
  filter "configurations:Release"
    -- regular options (unrelated to premake-qt)
    optimize "On"
    symbols "Off"
    defines "NDEBUG"

  -- Windows configuration (unrelated to premake-qt)
  filter "system:windows"
    defines "WIN32"

  -- visual studio configuration (unrelated to premake-qt)
  filter "toolset:msc*"
    architecture ("x86_64") -- installed qt is for 64 bits
    buildoptions {"/Zc:__cplusplus", "/permissive-" } -- required by Qt6

  -- Reset configuration
  filter {}

  -- testing project
  project "app"
    kind "ConsoleApp"
    targetname("app")
    -- source files
    files {path.join(Root, "src", "**.cpp"),  -- regular files 
           path.join(Root, "src", "**.h"),    -- regular files (might contain Q_OBJECT) 
           path.join(Root, "src", "**.ui"),   -- specific qt files 
           path.join(Root, "data", "**.qrc")} -- specific qt files 

    includedirs(path.join(Root, "src"))

    -- qt modules used in current configuration
    qtmodules { "core", "gui", "widgets" }
