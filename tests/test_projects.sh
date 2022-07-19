#!/bin/bash

options=${@}

rm -Rf project/solution/vs2019
premake5 --file=project/premake5.lua vs2019 $options
if [ $? != 0 ]
then
  echo project" KO"
  exit 1
fi
cd project/solution/vs2019
msbuild.exe Project.sln /property:Configuration=Release && ./bin/app.exe
if [ $? == 0 ]
then
  echo project" OK"
else
  echo project" KO"
  exit 1
fi
exit 0
