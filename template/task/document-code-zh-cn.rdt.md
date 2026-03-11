# Document Code

Document the selected code.

## Template

### Configuration

````json conversation-template
{
  "id": "document-code-zh-cn",
  "engineVersion": 0,
  "label": "Document Code",
  "tags": ["generate", "document"],
  "description": "Document the selected code.",
  "header": {
    "title": "生成注释 {{location}}",
    "icon": {
      "type": "codicon",
      "value": "output"
    }
  },
  "variables": [
    {
      "name": "openFiles",
      "time": "conversation-start",
      "type": "context"
    },
    {
      "name": "filename",
      "time": "conversation-start",
      "type": "filename"
    },
    {
      "name": "selectedText",
      "time": "conversation-start",
      "type": "selected-text",
      "constraints": [{ "type": "text-length", "min": 1 }]
    },
    {
      "name": "language",
      "time": "conversation-start",
      "type": "language",
      "constraints": [{ "type": "text-length", "min": 1 }]
    },
    {
      "name": "commentSnippet",
      "time": "conversation-start",
      "type": "comment-snippet"
    }
  ],
  "chatInterface": "instruction-refinement",
  "initialMessage": {
    "placeholder": "Documenting selection",
    "maxTokens": 2048,
    "stop": ["```"],
    "completionHandler": {
      "type": "active-editor-diff",
      "botMessage": "Generated documentation."
    }
  },
  "response": {
    "placeholder": "Documenting selection",
    "maxTokens": 2048,
    "stop": ["```"],
    "completionHandler": {
      "type": "active-editor-diff",
      "botMessage": "Generated documentation."
    }
  }
}
````

### Initial Message Prompt

```template-initial-message
<|system|>
Document the code on function/method/class level in Chinese.
Avoid adding line-by-line comments.
The programming language is {{language}}.
Respond directly to the code without any additional explanation.
Avoid using markdown in your response.
Do not modify the user's code when adding comments.
Do not alter the existing comments in the user's code.
<|end|>
<|user|>
需要添加注释的代码如下，请保持代码的缩进格式：
\`\`\`
{{selectedText}}
\`\`\`

{{#if commentSnippet}}
供参考注释的样式如下：
\`\`\`
{{commentSnippet}}
\`\`\`

{{/if}}
Please add comments to the code on function/method/class level.
此代码的编程语言是 {{language}}.
此代码的文件名是 {{filename}}
在回答中请避免使用 Markdown 格式.
添加注释时避免更改代码，也不要增加或者减少代码.
请不要在每行都添加注释.
请不要更改或者翻译此代码中的任何部分, 尤其是注释和字符串.
<|end|>
<|assistant|>
```

### Response Prompt

```template-response
<|system|>
Document the code on function/method/class level in Chinese.
Avoid adding line-by-line comments.
The programming language is {{language}}.
The filename is {{filename}}.
Respond directly to the code without any additional explanation.
Avoid using markdown in your response.
Do not modify the user's code when adding comments.
Do not alter the existing comments in the user's code.
<|end|>
<|user|>
The code that needs comments added is as follows, please maintain the indentation format of this code:
\`\`\`
{{selectedText}}
\`\`\`

{{#if commentSnippet}}
The reference comment style is as follows:
\`\`\`
{{commentSnippet}}
\`\`\`

{{/if}}
Please add comments to the code on function/method/class level.
此代码的编程语言是 {{language}}.
此代码的文件名是 {{filename}}
在回答中请避免使用 Markdown 格式.
添加注释时避免更改代码.
请不要在每行都添加注释.
请不要更改或者翻译代码中的任何部分, 尤其是注释和字符串.

请遵循以下指令:
{{#each messages}}
{{#if (eq author "user")}}
{{content}}
{{/if}}
{{/each}}
<|end|>
<|assistant|>
```
