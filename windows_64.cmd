set VERSION=%1
set DEBUG=%2
set NEW_WRAP=%3
if "%DEBUG%" == "true" (
    set STRIP_DEBUG_INFO=false
) else (
    set STRIP_DEBUG_INFO=true
)

echo DEBUG: %DEBUG%
echo STRIP_DEBUG_INFO: %STRIP_DEBUG_INFO%

cd /d %USERPROFILE%
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

if "%VERSION%"=="10.6.194" (
    echo =====[ patch 10.6.194 ]=====
    node %~dp0\node-script\do-gitpatch.js -p %GITHUB_WORKSPACE%\patches\win_msvc_v10.6.194.patch
)

if "%VERSION%"=="11.8.172" (
    echo =====[ patch 10.6.194 ]=====
    node %~dp0\node-script\do-gitpatch.js -p %GITHUB_WORKSPACE%\patches\remove_uchar_include_v11.8.172.patch
    node %~dp0\node-script\do-gitpatch.js -p %GITHUB_WORKSPACE%\patches\win_dll_v11.8.172.patch"
    node %~dp0\node-script\do-gitpatch.js -p %GITHUB_WORKSPACE%\patches\enable_wee8_v11.8.172.patch
)

if "%VERSION%"=="9.4.146.24" (
    echo =====[ patch jinja for python3.10+ ]=====
    cd third_party\jinja2
    node %~dp0\node-script\do-gitpatch.js -p %GITHUB_WORKSPACE%\patches\jinja_v9.4.146.24.patch
    cd ..\..
)

set "CXX_SETTING=is_clang=false use_custom_libcxx=false"

if "%NEW_WRAP%"=="with_new_wrap" (
    echo =====[ wrap new delete ]=====
    set "CXX_SETTING=is_clang=true use_custom_libcxx=true"
)

if "%VERSION%"=="9.4.146.24" (
    set "CXX_SETTING=is_clang=false"
)

echo =====[ add ArrayBuffer_New_Without_Stl ]=====
node %~dp0\node-script\add_arraybuffer_new_without_stl.js . %VERSION% %NEW_WRAP%

node %~dp0\node-script\patchs.js . %VERSION% %NEW_WRAP%

echo =====[ Building V8 ]=====

:: 根据DEBUG变量设置输出目录
if "%DEBUG%"=="true" (
    set OUTPUT_DIR=out.gn\x64.debug
) else (
    set OUTPUT_DIR=out.gn\x64.release
)

:: 针对不同版本的V8，配置对应的编译参数
if "%VERSION%"=="11.8.172" (
    call gn gen %OUTPUT_DIR% -args="target_os=""win"" target_cpu=""x64"" v8_use_external_startup_data=false v8_enable_i18n_support=false is_debug=%DEBUG% v8_static_library=true %CXX_SETTING% strip_debug_info=%STRIP_DEBUG_INFO% symbol_level=0 v8_enable_pointer_compression=false v8_enable_sandbox=false v8_enable_maglev=false v8_enable_webassembly=false v8_enable_system_instrumentation=false v8_enable_warnings_as_errors=false treat_warnings_as_errors=false"
)

if "%VERSION%"=="10.6.194" (
    call gn gen %OUTPUT_DIR% -args="target_os=""win"" target_cpu=""x64"" v8_use_external_startup_data=false v8_enable_i18n_support=false is_debug=%DEBUG% v8_static_library=true %CXX_SETTING% strip_debug_info=%STRIP_DEBUG_INFO% symbol_level=0 v8_enable_pointer_compression=false v8_enable_sandbox=false v8_enable_system_instrumentation=false v8_enable_warnings_as_errors=false treat_warnings_as_errors=false"
)

if "%VERSION%"=="9.4.146.24" (
    call gn gen %OUTPUT_DIR% -args="target_os=""win"" target_cpu=""x64"" v8_use_external_startup_data=false v8_enable_i18n_support=false is_debug=%DEBUG% v8_static_library=true %CXX_SETTING% strip_debug_info=%STRIP_DEBUG_INFO% symbol_level=0 v8_enable_pointer_compression=false v8_enable_system_instrumentation=false v8_enable_warnings_as_errors=false treat_warnings_as_errors=false"
)

:: 清理之前的编译输出
call ninja -C %OUTPUT_DIR% -t clean

:: 开始编译wee8
call ninja -v -C %OUTPUT_DIR% wee8

:: 创建输出目录
md output\v8\Lib\Win64

:: 如果需要使用NEW_WRAP，执行相关操作
if "%NEW_WRAP%"=="with_new_wrap" (
  call %~dp0\rename_symbols_win.cmd x64 output\v8\Lib\Win64\
)

:: 复制编译生成的库文件到输出目录
copy /Y %OUTPUT_DIR%\obj\wee8.lib output\v8\Lib\Win64\

echo =====[ Copy V8 header ]=====
xcopy include output\v8\Inc\  /s/h/e/k/f/c

:: 创建输出二进制文件目录
md output\v8\Bin\Win64

:: 复制编译生成的可执行文件到输出目录
copy /Y %OUTPUT_DIR%\v8cc.exe output\v8\Bin\Win64\
copy /Y %OUTPUT_DIR%\mksnapshot.exe output\v8\Bin\Win64\
