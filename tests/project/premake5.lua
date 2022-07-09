local Root = path.getabsolute(".") .. "/"  -- getabsolute remove trailling /

newoption {
  trigger = "qt-root",
  value = "path",
  description = "path of qt root (contains lib/libQt5Core.a include/Qt5Core bin)"
}

if (_ACTION == nil) then
  return
end

local LocationDir = path.join(Root, "solution", _ACTION)
local qt = premake.extensions.qt

if _OPTIONS["qt-root"] ~= nil then
  QtRoot = _OPTIONS["qt-root"]
end

print("QtRoot:", QtRoot)

workspace "Project"
  location ( LocationDir )
  configurations { "Debug", "Release" }

  cppdialect "C++17"
  warnings "Extra"

  objdir(path.join(LocationDir, "obj")) -- premake adds $(configName)/$(AppName)
  targetdir(path.join(LocationDir, "bin"))

  qt.enable()

  if (QtRoot ~= nil and QtRoot ~= "") then
    qtpath(QtRoot)
  end
  qtprefix "Qt6"

  filter "configurations:*Debug"
    optimize "Off"
    symbols "On"
    defines "DEBUG"
    qtsuffix "d"

  filter "configurations:*Release"
    optimize "On"
    symbols "Off"
    defines "NDEBUG"

  filter "system:windows"
    defines "WIN32"

  filter "toolset:msc*"
    architecture ("x86_64") -- installed qt is for 64 bits
    buildoptions {"/Zc:__cplusplus", "/permissive-" }-- required by Qt

  filter {}

  startproject "app"
  project "app"
    kind "ConsoleApp"
    targetname("app")
    files {path.join(Root, "src", "**.cpp"), path.join(Root, "src", "**.h"), path.join(Root, "src", "**.ui")}

    includedirs(path.join(Root, "src"))

    includedirs("obj") -- for generated files from ui

    qtmodules { "core", "gui", "widgets" }
