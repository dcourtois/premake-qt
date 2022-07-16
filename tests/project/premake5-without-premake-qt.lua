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

if _OPTIONS["qt-root"] ~= nil then
  QtRoot = path.normalize(_OPTIONS["qt-root"])
end

print("QtRoot:", QtRoot)

rule "uic"
  display "uic"
  fileextension ".ui"
  buildmessage 'uic -o obj/ui_%{file.basename}.h %{file.relpath}'
  --buildinputs { "%{file.relpath}" }
  buildoutputs { path.join(LocationDir, "obj", "ui_%{file.basename}.h") }
  buildcommands { path.join(QtRoot, "bin", "uic") .. " -o " .. path.join("obj", "ui_%{file.basename}.h") .. " %{file.relpath}" }

--[[
rule "qrc"
  display "qrc"
  fileextension ".qrc"
  buildmessage 'rcc -o obj/%{file.basename}.cpp %{file.relpath}'
  --buildinputs { "%{file.relpath}" } -- extra dependencies: content of <file>..</file>
  buildoutputs { path.join(LocationDir, "obj", "qrc_%{file.basename}.cpp") }
  buildcommands { path.join(QtRoot, "bin", "rcc") .. " -name %{file.basename} -no-compress %{file.relpath} -o " .. path.join("obj", "qrc_%{file.basename}.cpp") }
  -- compilebuildoutputs "on" -- unsupported
--]]

workspace "Project"
  location ( LocationDir )
  configurations { "Debug", "Release" }

  cppdialect "C++17"
  warnings "Extra"

  objdir(path.join(LocationDir, "obj")) -- premake adds $(configName)/$(AppName)
  targetdir(path.join(LocationDir, "bin"))

  if (QtRoot ~= nil and QtRoot ~= "") then
    externalincludedirs(path.join(QtRoot, "include"))
    libdirs(path.join(QtRoot, "lib"))
  end

  filter "configurations:Debug"
    targetsuffix "d"
    optimize "Off"
    symbols "On"
    defines "DEBUG"
  filter "configurations:Release"
    optimize "On"
    symbols "Off"
    defines "NDEBUG"

  filter "system:windows"
    defines "WIN32"

  filter "toolset:msc*"
    architecture ("x86_64") -- installed qt is for 64 bits
    buildoptions {"/Zc:__cplusplus", "/permissive-" } -- required by Qt6

  filter {}

  startproject "app"
  project "app"
    kind "ConsoleApp"
    targetname("app")
    files {path.join(Root, "src", "**.cpp"), path.join(Root, "src", "**.h"), path.join(Root, "src", "**.ui"), path.join(Root, "data", "**.qrc")}

    includedirs(path.join(Root, "src"))

    includedirs(path.join(LocationDir, "obj")) -- for generated files from ui
    --includedirs(path.join(QtRoot, "include"))
    includedirs(path.join(QtRoot, "include", "QtCore"))
    includedirs(path.join(QtRoot, "include", "QtGui"))
    includedirs(path.join(QtRoot, "include", "QtWidgets"))
    defines{"QT_CORE_LIB", "QT_GUI_LIB", "QT_WIDGETS_LIB"}
    links{"Qt6Core", "Qt6Gui", "Qt6Widgets"}

    rules { "uic" }
    -- rules { "qrc" } -- compilebuildoutputs isn't supported with rules

    filter "files:src/ui/EditorDialog.h"
      buildmessage "moc -o moc_%{file.basename}.cpp %{file.relpath}"
      buildoutputs { path.join(LocationDir, "obj", "moc_%{file.basename}.cpp") }
      buildcommands { path.join(QtRoot, "bin", "moc") .. " -o " .. path.join(LocationDir, "obj", "moc_%{file.basename}.cpp") .. " %{file.relpath}" }
      compilebuildoutputs "on"

    filter "files:**.qrc"
      buildmessage 'rcc -o obj/%{file.basename}.cpp %{file.relpath}'
      --buildinputs { "%{file.relpath}" } -- extra dependencies: content of <file>..</file>
      buildoutputs { path.join(LocationDir, "obj", "qrc_%{file.basename}.cpp") }
      buildcommands { path.join(QtRoot, "bin", "rcc") .. " -name %{file.basename} -no-compress %{file.relpath} -o " .. path.join("obj", "qrc_%{file.basename}.cpp") }
      compilebuildoutputs "on"
