# Explain Code

Explain the selected code.

## Template

### Configuration

```json conversation-template
{
  "id": "explain-code-zh-cn",
  "engineVersion": 0,
  "label": "Explain Code",
  "description": "Explain the selected code.",
  "tags": ["debug", "understand"],
  "header": {
    "title": "解释代码 ({{location}})",
    "icon": {
      "type": "codicon",
      "value": "book"
    }
  },
  "variables": [
    {
      "name": "openFiles",
      "time": "conversation-start",
      "type": "context"
    },
    {
      "name": "selectedText",
      "time": "conversation-start",
      "type": "selected-text",
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
    "placeholder": "生成代码解释中",
    "maxTokens": 512
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
Summarize the code at a high level (including goal and purpose) with an emphasis on its key functionality.
请完全使用中文回答。
<|end|>
<|user|>
以下是用户的代码上下文，后续询问可能会需要使用。
## Code Summary
## Open Files
{{#each openFiles}}
### File: {{name}}
\`\`\`{{language}}
{{content}}
\`\`\`
{{/each}}
<|end|>
<|assistant|>
了解了，您可以继续输入您的问题。
<|end|>
<|user|>
用户关心的代码内容如下：

## Selected Code
\`\`\`
{{selectedText}}
\`\`\`

逐步分解并详细解释以上代码，然后总结代码（强调其主要功能）。
<|end|>
<|assistant|>
```

### Response Prompt

```template-response
<|system|>
请完全使用中文回答。
<|end|>
<|user|>
以下是用户的代码上下文，后续询问可能会需要使用。
## Code Summary
## Open Files
{{#each openFiles}}
### File: {{name}}
\`\`\`{{language}}
{{content}}
\`\`\`
{{/each}}
<|end|>
<|assistant|>
了解了，您可以继续输入您的问题。
<|end|>
<|user|>
用户关心的代码内容如下：

## Selected Code
\`\`\`
{{selectedText}}
\`\`\`

逐步分解并详细解释以上代码，然后总结代码（强调其主要功能）。
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
