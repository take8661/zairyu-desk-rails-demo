@echo off
rem Zairyu Desk 起動バッチ（Windows-31J・CRLF）。ダブルクリックで、初回はgem導入・DB作成・デモデータ投入まで自動で行う。
rem 自動検証用：ZAIRYU_NO_PAUSE=1 で pause を省く／ZAIRYU_CHECK_ONLY=1 でサーバー起動直前に終了コード0で終わる。
setlocal
cd /d "%~dp0"

where ruby >nul 2>nul
if errorlevel 1 (
  echo Rubyが見つかりません。RubyInstaller 3.4 with DevKit を入れてください。
  if not defined ZAIRYU_NO_PAUSE pause
  exit /b 1
)

ruby -e "exit(RUBY_VERSION >= '3.2' ? 0 : 1)"
if errorlevel 1 (
  echo Ruby 3.2以上が必要です。
  if not defined ZAIRYU_NO_PAUSE pause
  exit /b 1
)

call bundle check >nul 2>nul
if errorlevel 1 (
  echo gemを導入します。初回は数分かかります。
  call bundle install
  if errorlevel 1 (
    echo bundle install に失敗しました。DevKitが入っていない可能性があります（ridk install）。
    if not defined ZAIRYU_NO_PAUSE pause
    exit /b 1
  )
)

if not exist "storage\development.sqlite3" (
  echo データベースを作成し、デモデータを投入します。
  ruby bin/rails db:setup
) else (
  ruby bin/rails db:migrate
)
if errorlevel 1 (
  echo データベースの準備に失敗しました。上のメッセージを確認してください。
  if not defined ZAIRYU_NO_PAUSE pause
  exit /b 1
)

echo 在留期限と書類の期限チェックを実行します。
ruby bin/rails zairyu:daily
if errorlevel 1 (
  echo 警告：期限チェックに失敗しました。詳細はログを確認してください。起動は続けます。
)

echo.
echo ================================================================
echo  Zairyu Desk（架空のデータによるデモです）
echo  このウィンドウを閉じるとサーバーが止まります。
echo.
echo  ブラウザで http://localhost:3000 を開き、次の架空のアカウントでログインできます。
echo    組織A 管理者   admin@demo-a.example
echo    組織A 担当者   member@demo-a.example
echo    組織B 管理者   admin@demo-b.example
echo  パスワードは README に記載のデモ用の値です（環境変数 DEMO_PASSWORD で変更できます）。
echo ================================================================
echo.

if "%ZAIRYU_CHECK_ONLY%"=="1" (
  echo 確認モードのため、サーバーは起動せずに終了します。
  exit /b 0
)

netstat -ano | findstr ":3000 " | findstr LISTENING >nul
if not errorlevel 1 (
  echo 3000番ポートは既に使用されています。別のプログラムを終了してから、もう一度実行してください。
  if not defined ZAIRYU_NO_PAUSE pause
  exit /b 1
)

start "" cmd /c "timeout /t 4 /nobreak >nul & start http://localhost:3000"
ruby bin/rails server -p 3000 -b 127.0.0.1
if errorlevel 1 (
  echo サーバーが異常終了しました。
  if not defined ZAIRYU_NO_PAUSE pause
  exit /b 1
)
endlocal
