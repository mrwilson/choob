@ECHO OFF

SETLOCAL ENABLEEXTENSIONS ENABLEDELAYEDEXPANSION
IF "%1"=="" GOTO :syntax

:parse-cmd
IF "%1"=="setup" CALL :do-setup
IF "%1"=="test" CALL :do-test
IF "%1"=="init" CALL :do-init
IF "%1"=="run" CALL :do-run
SHIFT
IF "%1"=="" GOTO :EOF
GOTO :parse-cmd



SET OK=1
IF NOT EXIST bot.conf (
	CALL :no-conf
	EXIT /B 3
)
IF "%OS%"=="Windows_NT" CALL :setup-nt
CALL :load-conf
IF NOT "%OK%"=="1" GOTO :EOF
CALL :load-db
IF NOT "%OK%"=="1" GOTO :EOF
IF "%1"=="test" (
	ECHO ==== OK ====
	ECHO All tests passed OK^^!
	EXIT /B 0
)



REM ==== SYNTAX ====
:syntax
ECHO Sets up and runs the bot.
ECHO.
ECHO GO [SETUP] [TEST] [RUN]
ECHO.
ECHO   SETUP   Configures the environment for running the bot. This involves
ECHO           finding various applications on your computer, which may fail.
ECHO   TEST    Checks that everything is ready to run. This includes basic
ECHO           checking of the bot configuration file.
ECHO   INIT    Configures the first-run information. This replaces any data in
ECHO           the database with the base data, and sets an admin user.
ECHO   RUN     Runs the bot. This is a loop - when the bot quits, it will be
ECHO           recompiled and restarted after a 15 second wait.
GOTO :EOF



REM ==== SETUP ====
:do-setup
ECHO ==== Setting up environment... ====

REM Get Program Files (32bit)...
IF DEFINED ProgFiles32 GOTO :do-setup-progs32-set
SET ProgFiles32=%ProgramFiles%
IF DEFINED ProgramFiles(x86) SET ProgFiles32=%ProgramFiles(x86)%
:do-setup-progs32-set
IF NOT EXIST "%ProgFiles32%" (
	ECHO FATAL ERROR: Cannot find 32bit "Program Files" folder.
	ECHO              You can specify this using the "ProgFiles32" environment
	ECHO              variable.
	GOTO :EOF
)
ECHO Program files 32bit: %ProgFiles32%

REM Get Program Files (64bit)...
IF DEFINED ProgFiles64 GOTO :do-setup-progs64-set
SET ProgFiles64=
IF DEFINED ProgramFiles(x86) SET ProgFiles64=%ProgramFiles%
:do-setup-progs64-set
IF NOT EXIST "%ProgFiles64%" (
	ECHO WARNING:     Cannot find 64bit "Program Files" folder.
	ECHO              You can specify this using the "ProgFiles64" environment
	ECHO              variable.
)
ECHO Program files 64bit: %ProgFiles64%

REM Get Java install...
IF DEFINED JavaHome GOTO :do-setup-java-set
SET JavaHome=

IF EXIST "%ProgFiles32%\Java" SET JavaHome=%ProgFiles32%\Java
IF EXIST "%ProgFiles64%\Java" SET JavaHome=%ProgFiles64%\Java
IF "x%JavaHome%"=="x" (
	ECHO FATAL ERROR: Cannot find Java JDK 1.5 ^(or later^) bin folder.
	ECHO              You can specify this using the "JavaHome" environment
	ECHO              variable. The folder specified must contain "javac.exe".
	GOTO :EOF
)

REM Find JDK v1.5 or later.
FOR /D %%P IN ("%JavaHome%\*") DO (
	SET FullPath=%%P
	SET Folder=%%~nP
	SET Ok=0
	IF "!Folder:~0,3!"=="jdk" (
		IF "!Folder:~3,1!" GTR "1" SET Ok=1
		IF "!Folder:~3,1!" EQU "1" IF "!Folder:~4,1!"=="." IF "!Folder:~5,1!" GEQ "6" SET Ok=1
		IF "!Ok!"=="1" (
			SET JavaHome=!FullPath!
			GOTO :do-setup-java-found
		)
	)
)
:do-setup-java-found
SET JavaHome=%JavaHome%\bin
:do-setup-java-set
IF NOT EXIST "%JavaHome%\javac.exe" (
	ECHO FATAL ERROR: Cannot find Java JDK 1.5 ^(or later^) bin folder.
	ECHO              You can specify this using the "JavaHome" environment
	ECHO              variable. The folder specified must contain "javac.exe".
	GOTO :EOF
)
SET JavaHome=%JavaHome%

ECHO Java JDK home      : %JavaHome%
SET PATH=%JavaHome%;%PATH%

REM Must find MySQL install location!
IF DEFINED MysqlHome GOTO :do-setup-mysql-set
SET MysqlHome=
FOR /R "%ProgFiles64%\MySQL" %%D IN (*.exe) DO (
	SET File=%%~nxD
	IF "!File!"=="mysql.exe" (
		SET MysqlHome=%%~dpD
	)
)
IF NOT EXIST "%MysqlHome%\mysql.exe" (
	FOR /R "%ProgFiles32%\MySQL" %%D IN (*.exe) DO (
		SET File=%%~nxD
		IF "!File!"=="mysql.exe" (
			SET MysqlHome=%%~dpD
		)
	)
)
:do-setup-mysql-set
IF NOT EXIST "%MysqlHome%\mysql.exe" (
	ECHO FATAL ERROR: Cannot find Mysql bin folder.
	ECHO              You can specify this using the "MysqlHome" environment
	ECHO              variable. The folder specified must contain "javac.exe".
	ECHO FATAL ERROR: Cannot find "mysql.exe".
	GOTO :EOF
)
ECHO Mysql folder       : %MysqlHome%

REM Find Cygwin install.
REM IF DEFINED CygwinHome GOTO :do-setup-cygwin-set
REM SET CygwinHome=
REM FOR /R "%ProgFiles32%\Cygwin" %%D IN (*.exe) DO (
REM 	SET File=%%~nxD
REM 	IF "!File!"=="bash.exe" (
REM 		SET CygwinHome=%%~dpD
REM 		GOTO :do-setup-cygwin-set
REM 	)
REM )
REM FOR /R "%SystemDrive%\Cygwin" %%D IN (*.exe) DO (
REM 	SET File=%%~nxD
REM 	IF "!File!"=="bash.exe" (
REM 		SET CygwinHome=%%~dpD
REM 		GOTO :do-setup-cygwin-set
REM 	)
REM )
REM :do-setup-cygwin-set
REM IF NOT EXIST "%CygwinHome%\bash.exe" (
REM 	ECHO FATAL ERROR: Cannot find Cygwin bin folder.
REM 	ECHO              You can specify this using the "CygwinHome" environment
REM 	ECHO              variable. The folder specified must contain "bash.exe".
REM 	ECHO FATAL ERROR: Cannot find "bash.exe".
REM 	GOTO :EOF
REM )
REM ECHO Cygwin folder      : %CygwinHome%
REM SET PATH=%PATH%;%CygwinHome%
GOTO :EOF



REM ==== TEST ====
:do-test
ECHO ==== Testing setup... ====

REM Check for javac in path.
SET JavaC=0
FOR /F "usebackq tokens=1 delims=" %%f IN (`javac 2^>^&1`) DO (
	SET /A JavaC=JavaC + 1
)
IF %JavaC% LSS 4 (
	ECHO FATAL ERROR: Javac is not in the path.
	ECHO              You can fix this by correcting the PATH environment
	ECHO              variable manually, or by running the SETUP mode of GO
	ECHO              as well ^("go setup test"^).
	GOTO :EOF
)
ECHO OK: 'javac' found in path.

REM Check for bash in path.
REM SET Bash=0
REM FOR /F "usebackq tokens=1 delims=" %%f IN (`bash --help 2^>^&1`) DO (
REM 	SET /A Bash=Bash + 1
REM )
REM IF %Bash% LSS 10 (
REM 	ECHO FATAL ERROR: Bash is not in the path.
REM 	ECHO              You can fix this by correcting the PATH environment
REM 	ECHO              variable manually, or by running the SETUP mode of GO
REM 	ECHO              as well ^("go setup test"^).
REM 	GOTO :EOF
REM )
REM ECHO OK: 'bash' found in path.

REM Check bot.conf.
IF NOT EXIST "bot.conf" (
	ECHO FATAL ERROR: No "bot.conf" file found.
	ECHO.
	ECHO You must create a bot configuration file, called "bot.conf", before you
	ECHO can run Choob. There is an example called "bot.conf.example" which may
	ECHO be used to create your own configuration file.
	ECHO.
	ECHO Note: while the mysql login information must be correct, the database
	ECHO need not be pre-created - the initial configuration of the bot, stored in
	ECHO "choob.db", will be imported automatically.
	GOTO :EOF
)
ECHO OK: 'bot.conf' exists.

REM First read config info!
ECHO ==== Validating bot.conf... ====
SET BotName=
SET BotTrigger=
SET DBName=choob
SET DBUser=
SET DBPass=
SET DBHost=
FOR /F "delims== tokens=1,2" %%a IN (bot.conf) DO (
	IF "%%a"=="botName"    SET "BotName=%%b"
	IF "%%a"=="botTrigger" (
		IF "^%%b"=="^!" (
			SET "BotTrigger=^^^%%b"
		) ELSE (
			SET "BotTrigger=%%b"
		)
	)
	IF "%%a"=="database"   SET "DBName=%%b"
	IF "%%a"=="dbUser"     SET "DBUser=%%b"
	IF "%%a"=="dbPass"     SET "DBPass=%%b"
	IF "%%a"=="dbServer"   SET "DBHost=%%b"
)
IF "%BotName%"=="" (
	ECHO FATAL ERROR: No bot name set in "bot.conf".
	GOTO :EOF
)
IF "%BotTrigger%"=="" (
	ECHO FATAL ERROR: No bot trigger ^(command prefix character^) set in "bot.conf".
	GOTO :EOF
)
IF "%DBHost%"=="" (
	ECHO FATAL ERROR: No database server set in "bot.conf".
	GOTO :EOF
)
IF "%DBUser%"=="" (
	ECHO FATAL ERROR: No database username set in "bot.conf".
	GOTO :EOF
)
IF "%DBPass%"=="" (
	ECHO FATAL ERROR: No database password set in "bot.conf".
	GOTO :EOF
)
ECHO Bot name         : "%BotName%"
ECHO Bot trigger char : "%BotTrigger%"
ECHO Database         : "%DBName%"
ECHO Database server  : "%DBHost%"
ECHO Database user    : "%DBUser%"
ECHO Database password: "%DBPass%"
ECHO OK: 'bot.conf' seems valid.

GOTO :EOF



REM ==== INIT ====
:do-init
ECHO ==== Setting up database... ====
REM Import database.
PUSHD ..\db
TYPE choob.db | "%MysqlHome%\mysql.exe" --user="%DBUser%" --password="%DBPass%" "%DBName%" || SET OK=0
IF "%OK%"=="0" (
	ECHO FATAL ERROR: Unable to import "choob.db" into the mysql database.
	ECHO              Check "bot.conf" username and password.
	POPD
	GOTO :EOF
)
ECHO OK: Database "choob.db" imported.
IF EXIST custom.db (
	TYPE custom.db | "%MysqlHome%\mysql.exe" --user="%DBUser%" --password="%DBPass%" "%DBName%" || SET OK=0
	IF "!OK!"=="0" (
		ECHO FATAL ERROR: Unable to import "custom.db" into the mysql database.
		ECHO              Check "bot.conf" username and password.
		POPD
		GOTO :EOF
	)
	ECHO OK: Database "custom.db" imported.
)
POPD

IF NOT DEFINED BotAdminUser GOTO :do-init-no-admin-set

ECHO INSERT INTO UserNodes (NodeID, NodeName, NodeClass) VALUES (1001, "%BotAdminUser%", 1) | "%MysqlHome%\mysql.exe" --user="%DBUser%" --password="%DBPass%" "%DBName%" || SET OK=0
IF "%OK%"=="0" (
	ECHO FATAL ERROR: Failed to update admin user information in the database.
	GOTO :EOF
)
ECHO INSERT INTO UserNodes (NodeID, NodeName, NodeClass) VALUES (1002, "%BotAdminUser%", 0) | "%MysqlHome%\mysql.exe" --user="%DBUser%" --password="%DBPass%" "%DBName%" || SET OK=0
IF "%OK%"=="0" (
	ECHO FATAL ERROR: Failed to update admin user information in the database.
	GOTO :EOF
)
ECHO INSERT INTO GroupMembers (GroupID, MemberID) VALUES (1, 1001) | "%MysqlHome%\mysql.exe" --user="%DBUser%" --password="%DBPass%" "%DBName%" || SET OK=0
IF "%OK%"=="0" (
	ECHO FATAL ERROR: Failed to update admin user information in the database.
	GOTO :EOF
)
ECHO INSERT INTO GroupMembers (GroupID, MemberID) VALUES (1001, 1002) | "%MysqlHome%\mysql.exe" --user="%DBUser%" --password="%DBPass%" "%DBName%" || SET OK=0
IF "%OK%"=="0" (
	ECHO FATAL ERROR: Failed to update admin user information in the database.
	GOTO :EOF
)
ECHO OK: Admin user ^(%BotAdminUser%^) added to database.
GOTO :do-init-done-admin

:do-init-no-admin-set
ECHO INFO: No admin user set, using default permissions data.
ECHO       To specify an admin user for the bot, set the environment variable
ECHO       "BotAdminUser" to the nickname desired.

:do-init-done-admin
GOTO :EOF



REM ==== RUN ====
:do-run
TITLE %BotName%

:do-run-top
ECHO ==== Compiling... ====
CALL compile
IF ERRORLEVEL 1 GOTO :do-run-compile-error
COPY ..\.svn\dir-wcprops svn.data >nul
:do-run-again
ECHO ==== Running... ====
CALL run once
IF "%ERRORLEVEL%"=="0" GOTO :EOF
IF "%ERRORLEVEL%"=="2" (
	ECHO ==== Sleeping... ====
	REM SLEEP 15
	WAITFOR NothingChoob /T 15
	GOTO :do-run-again
)
:do-run-compile-error

ECHO ==== Sleeping... ====
REM SLEEP 15
WAITFOR NothingChoob /T 15
GOTO :do-run-top

GOTO :EOF
