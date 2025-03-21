# test_runner.py
import subprocess
import argparse
import json
import sys
from pathlib import Path

def run_nvim_test(framework, test_files):
    cmd = ["nvim", "--headless", "-l", framework] + test_files

    try:
        result = subprocess.run(
            cmd,
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=30
        )
        output = result.stdout.strip()
    except subprocess.CalledProcessError as e:
        return parse_result(e.stdout, e.stderr, exit_code=e.returncode)
    except subprocess.TimeoutExpired:
        return {"passed": 0, "failed": 1, "failures": ["Test timeout"]}

    return parse_result(output, result.stderr)

def parse_result(stdout, stderr, exit_code=0):
    try:
        result_lines = [line for line in stdout.split('\n')
                       if line.startswith('TEST_RESULTS:')]
        if not result_lines:
            return {
                "passed": 0,
                "failed": 1,
                "failures": [f"Framework error: No test output detected\n{stderr}"]
            }

        return json.loads(result_lines[-1].split('TEST_RESULTS:')[1])
    except json.JSONDecodeError as e:
        return {
            "passed": 0,
            "failed": 1,
            "failures": [f"JSON解析失败: {str(e)}\n原始输出: {stdout}"]
        }

def main():
    parser = argparse.ArgumentParser(description="Neovim Test Runner")
    parser.add_argument("path", help="Test file/directory")
    parser.add_argument("--framework", default="test_framework.lua",
                       help="Test framework path")
    args = parser.parse_args()

    test_path = Path(args.path)
    if test_path.is_file():
        test_files = [str(test_path)]
    else:
        test_files = [str(p) for p in test_path.rglob("*_spec.lua")]
        if not test_files:
            print("No test files found")
            sys.exit(1)

    print(f"Running {len(test_files)} test files...")
    result = run_nvim_test(args.framework, test_files)

    print(f"\nResults: {result['passed']} passed, {result['failed']} failed")

    if result["failed"] > 0:
        print("\nFailures:")
        for failure in result["failures"]:
            print(f" • {failure}")
        sys.exit(1)

if __name__ == "__main__":
    main()
