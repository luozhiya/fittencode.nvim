import argparse
import os
import platform
import subprocess
import sys
from pathlib import Path
try:
    from colorama import init, Fore
    init()
except ImportError:
    class FakeColor:
        RED = ''
        RESET = ''
    Fore = FakeColor()

def get_luarocks_env():
    """跨平台获取LuaRocks环境变量"""
    try:
        result = subprocess.check_output(
            "luarocks path --lua-version 5.1 --bin",
            shell=True,
            text=True
        )
        env = os.environ.copy()
        # print(result)
        # env['LUA_PATH'] = env.get('LUA_PATH', '') + ';' + result.strip()
        for line in result.strip().split('\n'):
            if line.startswith('export '):
                # Unix风格环境变量
                var, value = line[7:].split('=', 1)
                value = value.strip('\'"')
                env[var] = value
                if var == 'PATH':
                    env['PATH'] = value + os.pathsep + env['PATH']
            elif line.startswith('SET '):
                # Windows风格环境变量
                # SET "LUA_PATH=C:\Program Files (x86)\LuaRocks\lua\?.lua;C:\Program Files (x86)\LuaRocks\lua\?\init.lua;;C:\Users\luozhiya\AppData\Roaming\luarocks\share\lua\5.1\?.lua;C:\Users\luozhiya\AppData\Roaming\luarocks\share\lua\5.1\?\init.lua;e:\apps\luarocks-3.11.1-win32\win32\lua5.1\share\lua\5.1\?.lua;e:\apps\luarocks-3.11.1-win32\win32\lua5.1\share\lua\5.1\?\init.lua"
                var, value = line[5:].split('=', 1)
                env[var] = value + os.pathsep + env.get(var, '')
        # env['PATH'] = "C:\\Users\\luozhiya\\AppData\\Roaming\\LuaRocks\\share\\lua\\5.1\\busted" + os.pathsep + env['PATH']
        env['LUA_CPATH'] = "C:/Users/luozhiya/AppData/Roaming/luarocks/lib/lua/5.1/?.dll" + os.pathsep + env['LUA_CPATH']
        return env
    except subprocess.CalledProcessError as e:
        print(f"{Fore.RED}Error getting LuaRocks environment: {e}{Fore.RESET}")
        sys.exit(1)

def clean():
    """跨平台清理临时文件"""
    nvim_dir = Path("tests/xdg/local/state/nvim")
    if platform.system() == "Windows":
        # Windows清理命令
        subprocess.run(f"rmdir /s /q {nvim_dir}", shell=True, check=True)
    else:
        # Unix-like系统清理命令
        subprocess.run(f"rm -rf {nvim_dir}/*", shell=True, check=True)

def run_busted(test_type):
    """跨平台运行测试"""
    env = get_luarocks_env()
    cmd = "busted.bat" if platform.system() == "Windows" else "busted"
    try:
        result = subprocess.run(
            f"{cmd} --run {test_type}",
            shell=True,
            check=True,
            env=env,
            capture_output=True,  # 捕获输出
            text=True  # 确保输出是文本格式
        )
        print(result.stdout)  # 打印标准输出
    except subprocess.CalledProcessError as e:
        print(f"{Fore.RED}测试失败: {test_type} (code {e.returncode}){Fore.RESET}")
        print(e.stderr)  # 打印错误输出
        raise

def inline_test():
    """运行inline测试"""
    run_busted("inline")

def chat_test():
    """运行chat测试"""
    run_busted("chat")

def functional_test():
    """运行functional测试"""
    run_busted("functional")

def test():
    """运行所有测试"""
    for test_func in [inline_test, chat_test, functional_test]:
        try:
            test_func()
        except subprocess.CalledProcessError:
            print(f"{Fore.RED}部分测试失败，终止执行{Fore.RESET}")
            sys.exit(1)

def main():
    parser = argparse.ArgumentParser(
        description="跨平台Neovim测试套件运行器",
        formatter_class=argparse.RawTextHelpFormatter
    )

    targets = {
        "clean": clean,
        "inline-test": inline_test,
        "chat-test": chat_test,
        "functional-test": functional_test,
        "test": test
    }

    help_text = "\n".join([
        "clean            - 清理工作区",
        "inline-test      - 运行inline测试",
        "chat-test        - 运行chat测试",
        "functional-test  - 运行functional测试",
        "test             - 运行所有测试"
    ])

    parser.add_argument("target", choices=targets.keys(), help=help_text)

    try:
        args = parser.parse_args()
        targets[args.target]()
    except subprocess.CalledProcessError as e:
        sys.exit(e.returncode)
    except Exception as e:
        print(f"{Fore.RED}未处理的错误: {str(e)}{Fore.RESET}")
        sys.exit(1)

if __name__ == "__main__":
    main()
