# Find Bugs

Template to find bugs in the selected code.

## Template

### Configuration

```json conversation-template
{
  "id": "find-bugs-zh-cn",
  "engineVersion": 0,
  "label": "Find bugs",
  "tags": ["debug", "code quality"],
  "description": "Find potential bugs in the selected code.",
  "header": {
    "title": "查找Bug ({{location}})",
    "icon": {
      "type": "codicon",
      "value": "bug"
    }
  },
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
    },
    {
      "name": "language",
      "time": "conversation-start",
      "type": "language",
      "constraints": [{ "type": "text-length", "min": 1 }]
    },
    {
      "name": "location",
      "time": "conversation-start",
      "type": "selected-location-text"
    },
    {
      "name": "firstMessage",
      "time": "message",
      "type": "message",
      "property": "content",
      "index": 0
    },
    {
      "name": "lastMessage",
      "time": "message",
      "type": "message",
      "property": "content",
      "index": -1
    }
  ],
  "initialMessage": {
    "placeholder": "查找Bug中",
    "maxTokens": 1024
  },
  "response": {
    "maxTokens": 1024,
    "stop": ["Bot:", "Developer:"]
  }
}
```

### Initial Message Prompt

```template-initial-message
<|system|>
请完全使用中文回答。
<|end|>
<|user|>
用户给出了以下代码，其编程语言是 {{language}}，文件名是 {{filename}}。

## Selected Code
\`\`\`
{{selectedText}}
\`\`\`

上述的代码可能有什么问题？
只考虑会导致错误行为的缺陷。
<|end|>
<|assistant|>
```

### Response Prompt

```template-response
<|system|>
请完全使用中文回答。
<|end|>
<|user|>
用户给出了以下代码，其编程语言是 {{language}}，文件名是 {{filename}}。

{{#if selectedText}}
## Selected Code
\`\`\`
{{selectedText}}
\`\`\`
{{/if}}

上述的代码可能有什么问题？
只考虑会导致错误行为的缺陷。
<|end|>
<|assistant|>
{{firstMessage}}
<|end|>
{{#each messages}}
{{#if (neq @index 0)}}
{{#if (eq author "bot")}}
<|assistant|>
{{content}}
<|end|>
{{else}}
<|user|>
{{content}}
<|end|>
{{/if}}
{{/if}}
{{/each}}
<|assistant|>
```
