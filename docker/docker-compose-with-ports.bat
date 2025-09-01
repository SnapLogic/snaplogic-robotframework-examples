@echo off
REM Script to load environment variables from .env.ports and run docker-compose

REM Load .env.ports if it exists
if exist .env.ports (
    echo Loading port configuration from .env.ports...
    for /f "tokens=1,2 delims==" %%a in (.env.ports) do (
        if not "%%a"=="" if not "%%b"=="" set %%a=%%b
    )
)

REM Load .env if it exists
if exist .env (
    echo Loading environment configuration from .env...
    for /f "tokens=1,2 delims==" %%a in (.env) do (
        if not "%%a"=="" if not "%%b"=="" set %%a=%%b
    )
)

REM Run docker-compose with all arguments
docker-compose %*
