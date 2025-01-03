import subprocess

# 定义要执行的 make 命令
make_command = "make -C lua/fittencode/hash"

# 使用 subprocess 执行命令
try:
    result = subprocess.run(make_command, shell=True, check=True, text=True, capture_output=True)
    print("Make command executed successfully:")
    print(result.stdout)
except subprocess.CalledProcessError as e:
    print("Make command failed:")
    print(e.stderr)
