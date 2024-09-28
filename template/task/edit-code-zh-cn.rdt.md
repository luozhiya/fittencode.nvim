# Edit Code

Generate code using instructions.

## Template

### Configuration

````json conversation-template
{
  "id": "edit-code-zh-cn",
  "engineVersion": 0,
  "label": "Edit Code",
  "tags": ["edit"],
  "description": "Instruct fittencode to edit the code. Creates a diff that you can review.",
  "header": {
    "title": "编辑代码 {{location}}",
    "icon": {
      "type": "codicon",
      "value": "edit"
    }
  },
  "chatInterface": "instruction-refinement",
  "variables": [
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
    }
  ],
  "response": {
    "placeholder": "Generating edit",
    "maxTokens": 1536,
    "stop": ["```"],
    "completionHandler": {
      "type": "active-editor-diff",
      "botMessage": "Generated edit."
    }
  }
}
````

### Response Prompt

```template-response
<|system|>
Please reply directly to the code without any explanation.
Please do not use markdown when replying.
请完全使用中文回答。
<|end|>
<|user|>
当前文件名是{{filename}}.
需要编辑的代码如下，请保持该代码的缩进格式：
\`\`\`
{{selectedText}}
\`\`\`

请根据如下需求，编辑代码：
{{#each messages}}
{{#if (eq author "user")}}
{{content}}
{{/if}}
{{/each}}
<|end|>
<|assistant|>
```
