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
  QtRoot = _OPTIONS["qt-root"]
end

print("QtRoot:", QtRoot)

rule "uic"
  display "uic"
  fileextension ".ui"
  buildmessage 'uic -o ../../obj/%{file.basename} %{file.relpath}'
  --buildinputs { "%{file.relpath}" }
  buildoutputs { path.join("obj", "ui_%{file.basename}.h") }
  buildcommands { path.join(QtRoot, "bin", "uic") .. " -o " .. path.join("../../obj", "ui_%{file.basename}.h") .. " %{file.relpath}" }

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

  filter "configurations:*Debug"
    optimize "Off"
    symbols "On"
    defines "DEBUG"
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
    includedirs(path.join(QtRoot, "include", "QtCore"))
    includedirs(path.join(QtRoot, "include", "QtGui"))
    includedirs(path.join(QtRoot, "include", "QtWidgets"))
    defines{"QT_CORE_LIB", "QT_GUI_LIB", "QT_WIDGETS_LIB"}
    links{"Qt6Core", "Qt6Gui", "Qt6Widgets"}

    rules { "uic" }

    filter "files:src/ui/EditorDialog.h"
      buildmessage "moc -o moc_%{file.basename}.cpp %{file.relpath}"
      buildoutputs { path.join(WorkingDir, "obj", "moc_%{file.basename}.cpp") }
      buildcommands { path.join(QtRoot, "bin", "moc") .. " -o " .. path.join("../../obj", "moc_%{file.basename}.cpp") .. " %{file.relpath}" }
      compilebuildoutputs "on"
