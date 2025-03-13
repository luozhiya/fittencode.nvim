::date print `09/19/2024 Thu` , convert to `2024/09/19`

@echo off
for /f "tokens=1-3 delims= " %%a in ('date /t') do (
    set full_date=%%a
    set day_of_week=%%c
)

for /f "tokens=1-3 delims=/" %%a in ("%full_date%") do (
    set month=%%a
    set day=%%b
    set year=%%c
)

set short_year=%year:~-4%
echo %short_year%/%month%/%day%

git add .
git commit -m %short_year%/%month%/%day%
git push
