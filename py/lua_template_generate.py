# 加载当前脚本同级目录下的fittencode.py
import json
import os
import sys
import asyncio
import time

# 获取当前脚本的目录
current_dir = os.path.dirname(os.path.abspath(__file__))

# 将当前目录添加到sys.path
sys.path.append(current_dir)

# 加载fittencode.py
import fittencode
import lua_template_refine

# md template in `../template/`
template_dir = os.path.join(current_dir, "../template/")

# lua template in `../lua/template/`
lua_template_dir = os.path.join(current_dir, "../lua/fittencode/template/")

# Delete lua template dir if exists
if os.path.exists(lua_template_dir):
    os.system(f"rm -rf {lua_template_dir}")

fc = fittencode.FittenCode()


async def generate(refs, user):
    response = await fc.chat(refs=refs, user=user)
    return response


def process_response(response):
    lines = response.split("\n")
    lines = [line for line in lines if line.strip()]
    result = ""
    for line in lines:
        try:
            obj = json.loads(line)
            delta = obj.get("delta", "")  # Use .get() to avoid KeyError
            result += delta
        except json.JSONDecodeError as e:
            print(f"JSONDecodeError: {e}")
        except Exception as e:
            print(f"An error occurred: {e}")
    return result


user = """请严格按以下规则，将选择的md转换为lua table,不需要额外的解释文本，转换结果不要放入markdown代码块中：
1. 创建一个 table 对应二级标题 Template， 最后要return这个 `local template`。
2. 新增一个 mata key, 值为：
    2.1 source, markdown文件名，包含后缀；
    2.2 code，markdown一级标题；
    2.3 description，markdown一级标题的正文内容。
3. 把所有的3级标题，作为 template 的一个 key，写到 template的花括号中，且key的名称按snake_case命名。
4. 按代码块的分别处理:
    4.1 对于 configuration key的内容：解析其中的结构转换为 key, 不要加额外的嵌套 table 和list。
    4.2 对于 `initial_message_prompt` 或者 `response_prompt` 的内容，则：将整个内容转为lua 的`[[ ]]`样式的字符串，逐行拼接，切勿做任何格式化与修改，切勿把`#`、`##`等当成标题来解析。
规则完毕，最后请注意Key之间要用逗号分隔。
"""


class Refs:
    def __init__(self):
        self.content = ""
        self.filename = ""
        self.range = "0:0"
        self.selected_text = ""


count = 1


for root, dirs, files in os.walk(template_dir):
    for file in files:
        if file.endswith(".md"):
            print(f"[{count}] > Processing {file}")
            with open(os.path.join(root, file), "r", encoding="utf-8") as f:
                content = f.read()
            content = content.replace("<|", "<| ")
            content = content.replace("|>", " |>")
            refs = Refs()
            refs.content = content
            refs.filename = file
            refs.range = "0:{}".format(len(content.split("\n")))
            refs.selected_text = content
            loop = asyncio.get_event_loop()
            lua_template = loop.run_until_complete(generate(refs=refs, user=user))
            lua_template = process_response(lua_template)
            save_path = os.path.join(
                lua_template_dir,
                root.replace(template_dir, ""),
                file.replace(".rdt.md", ".lua"),
            )
            os.makedirs(os.path.dirname(save_path), exist_ok=True)
            with open(save_path, "w", encoding="utf-8") as f:
                f.write(lua_template)
                print(f"Saved to {save_path}")

            lua_template_refine.refine(save_path)

            print(f"[{count}] > Refined {save_path}")
            count += 1

            time.sleep(1)

            # exit for testing only
            # sys.exit(0)
