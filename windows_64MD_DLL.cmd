set VERSION=%1

cd %HOMEPATH%
echo =====[ Getting Depot Tools ]=====
powershell -command "Invoke-WebRequest https://storage.googleapis.com/chrome-infra/depot_tools.zip -O depot_tools.zip"
7z x depot_tools.zip -o*
set PATH=%CD%\depot_tools;%PATH%
set GYP_MSVS_VERSION=2019
set DEPOT_TOOLS_WIN_TOOLCHAIN=0
call gclient

cd depot_tools
call git reset --hard 8d16d4a
cd ..
set DEPOT_TOOLS_UPDATE=0


mkdir v8
cd v8

echo =====[ Fetching V8 ]=====
call fetch v8
cd v8
call git checkout refs/tags/%VERSION%
@REM cd test\test262\data
call git config --system core.longpaths true
@REM call git restore *
@REM cd ..\..\..\
call gclient sync

@REM echo =====[ Patching V8 ]=====
@REM node %GITHUB_WORKSPACE%\CRLF2LF.js %GITHUB_WORKSPACE%\patches\builtins-puerts.patches
@REM call git apply --cached --reject %GITHUB_WORKSPACE%\patches\builtins-puerts.patches
@REM call git checkout -- .

if "%VERSION%"=="9.4.146.24" (
    echo =====[ patch jinja for python3.10+ ]=====
    cd third_party\jinja2
    node %~dp0\node-script\do-gitpatch.js -p %GITHUB_WORKSPACE%\patches\jinja_v9.4.146.24.patch
    cd ..\..
)

echo =====[ Make dynamic_crt ]=====
node %~dp0\node-script\rep.js  build\config\win\BUILD.gn

echo =====[ add ArrayBuffer_New_Without_Stl ]=====
node %~dp0\node-script\add_arraybuffer_new_without_stl.js . %VERSION% %NEW_WRAP%

node %~dp0\node-script\patchs.js . %VERSION%

echo =====[ Building V8 ]=====

:: 根据DEBUG变量设置输出目录
if "%DEBUG%"=="true" (
    set OUTPUT_DIR=out.gn\x64.debug
) else (
    set OUTPUT_DIR=out.gn\x64.release
)

:: 针对不同版本的V8，配置对应的编译参数
if "%VERSION%"=="11.8.172" (
    call gn gen %OUTPUT_DIR% -args="target_os=""win"" target_cpu=""x64"" v8_use_external_startup_data=false v8_enable_i18n_support=false is_debug=%DEBUG% is_clang=false strip_debug_info=%STRIP_DEBUG_INFO% symbol_level=0 v8_enable_pointer_compression=false is_component_build=true v8_enable_maglev=false v8_enable_warnings_as_errors=false treat_warnings_as_errors=false"
)

if "%VERSION%"=="10.6.194" (
    call gn gen %OUTPUT_DIR% -args="target_os=""win"" target_cpu=""x64"" v8_use_external_startup_data=false v8_enable_i18n_support=false is_debug=%DEBUG% is_clang=false strip_debug_info=%STRIP_DEBUG_INFO% symbol_level=0 v8_enable_pointer_compression=false is_component_build=true v8_enable_warnings_as_errors=false treat_warnings_as_errors=false"
)

if "%VERSION%"=="9.4.146.24" (
    call gn gen %OUTPUT_DIR% -args="target_os=""win"" target_cpu=""x64"" v8_use_external_startup_data=false v8_enable_i18n_support=false is_debug=%DEBUG% is_clang=false strip_debug_info=%STRIP_DEBUG_INFO% symbol_level=0 v8_enable_pointer_compression=false v8_enable_warnings_as_errors=false treat_warnings_as_errors=false"
)

call ninja -C %OUTPUT_DIR% -t clean
call ninja -v -C %OUTPUT_DIR% v8

md output\v8\Lib\Win64DLL
copy /Y %OUTPUT_DIR%\v8.dll.lib output\v8\Lib\Win64DLL\
copy /Y %OUTPUT_DIR%\v8_libplatform.dll.lib output\v8\Lib\Win64DLL\
copy /Y %OUTPUT_DIR%\v8.dll output\v8\Lib\Win64DLL\
copy /Y %OUTPUT_DIR%\v8_libbase.dll output\v8\Lib\Win64DLL\
copy /Y %OUTPUT_DIR%\v8_libplatform.dll output\v8\Lib\Win64DLL\

:: 针对不同版本，拷贝相应的第三方库
if "%VERSION%"=="11.8.172" (
    copy /Y %OUTPUT_DIR%\third_party_zlib.dll output\v8\Lib\Win64DLL\
    copy /Y %OUTPUT_DIR%\third_party_zlib.dll.pdb output\v8\Lib\Win64DLL\
    copy /Y %OUTPUT_DIR%\third_party_abseil-cpp_absl.dll output\v8\Lib\Win64DLL\
    copy /Y %OUTPUT_DIR%\third_party_abseil-cpp_absl.dll.pdb output\v8\Lib\Win64DLL\
) else (
    copy /Y %OUTPUT_DIR%\zlib.dll output\v8\Lib\Win64DLL\
    copy /Y %OUTPUT_DIR%\zlib.dll.pdb output\v8\Lib\Win64DLL\
)

copy /Y %OUTPUT_DIR%\v8.dll.pdb output\v8\Lib\Win64DLL\
copy /Y %OUTPUT_DIR%\v8_libbase.dll.pdb output\v8\Lib\Win64DLL\
copy /Y %OUTPUT_DIR%\v8_libplatform.dll.pdb output\v8\Lib\Win64DLL\