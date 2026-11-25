@echo off
rem テスト実行バッチ（Windows-31J・CRLF）。RSpec を全件実行し、終了コードを表示する。
setlocal
cd /d "%~dp0"

where ruby >nul 2>nul
if errorlevel 1 (
  echo Rubyが見つかりません。RubyInstaller 3.4 with DevKit を入れてください。
  if not defined ZAIRYU_NO_PAUSE pause
  exit /b 1
)

call bundle exec rspec
set "RSPEC_EXIT=%ERRORLEVEL%"
echo.
echo rspec の終了コード: %RSPEC_EXIT%
if not defined ZAIRYU_NO_PAUSE pause
exit /b %RSPEC_EXIT%
