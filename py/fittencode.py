import aiohttp
import asyncio


def a(text, language):
    # 假设 a 函数的作用是将文本翻译成指定的语言
    # 这里我们简单地返回原始文本作为示例
    return text


# 假设 window.language 是用户输入的语言
window_language = "user_language"


async def post_data(session, url, json_data, headers):
    """Send a POST request using aiohttp.ClientSession."""
    async with session.post(url, json=json_data, headers=headers) as response:
        if response.status == 200:
            data = await response.text()  # Assuming the response is JSON
            return data
        else:
            print(f"Failed to post data. Status code: {response.status}")
            return None


class FittenCode:
    def __init__(self, token_file_path="ft_token"):
        self.api_key = self._load_api_key(token_file_path)
        if not self.api_key:
            raise ValueError("No API key found. Exiting.")

    def _load_api_key(self, file_path):
        try:
            with open(file_path, "r") as file:
                api_key = (
                    file.read().strip()
                )  # remove any leading/trailing whitespace/newlines
                return api_key
        except FileNotFoundError:
            print("Error: File not found. Please make sure the 'ft_token' file exists.")
            return None
        except Exception as e:
            print(f"An error occurred while reading the token: {str(e)}")
            return None

    async def chat(self, refs, user=""):
        url = "https://fc.fittenlab.cn/codeapi/chat?apikey=" + self.api_key

        # inputs0 = (
        #     "<|system|>\n"
        #     + a("Reply same language as the user's input.", window_language)
        #     + " \n<|end|>\n<|user|>\n"
        #     + a(
        #         "The following code is selected by the user, which may be mentioned in the subsequent conversation:",
        #         window_language,
        #     )
        #     + " \n```\n"
        #     + refs
        #     + "\n```\n<|end|>\n<|assistant|>\n"
        #     + a("Understand, you can continue to enter your problem.", window_language)
        #     + " \n<|end|>\n"
        #     + "<|user|>\n"
        #     + user
        #     + "\n"
        #     + "<|end|>\n"
        #     + "<|assistant|>\n"
        # )

        inputs = (
            "<|system|>\n"
            + "Reply English.\n<|end|>\n"
            + "<|user|>\n"
            + "Current file content({}):".format(refs.filename)
            + "\n```\n"
            + "{}".format(refs.content)
            + "\n```\n\n\n"
            + "Selected Text({} {})".format(refs.filename, refs.range)
            + ", please stay focus on the selected text:\n```\n"
            + "{}".format(refs.selected_text)
            + "\n```\n\n\n"
            + "{}".format(user)
            + "\n\n\n<|end|>\n<|assistant|>"
        )

        headers = {
            "Content-Type": "application/json",
        }

        json_data = {
            "inputs": inputs,
            "ft_token": self.api_key,
        }

        async with aiohttp.ClientSession() as session:
            # POST request
            print("Sending data via POST request...")
            post_result = await post_data(session, url, json_data, headers)
            # print(f"POST result: {post_result}\n")
            return post_result


# Example usage:
if __name__ == "__main__":

    async def main():
        fc = FittenCode()
        response = await fc.chat(user="Hello, Why 1+1=2?")
        # print(f"Response status: {response}")

    try:
        # asyncio.run(main())
        loop = asyncio.get_event_loop()
        loop.run_until_complete(main())
    finally:
        print("Done.")
