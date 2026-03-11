# Explain Code

Diagnoses error in vscode and provides a potential fix.

## Template

### Configuration

```json conversation-template
{
  "id": "diagnose-errors-zh-cn",
  "engineVersion": 0,
  "label": "Diagnose Error",
  "tags": ["debug"],
  "description": "Diagnoses error in vscode and provides a potential fix.",
  "header": {
    "title": "诊断错误 ({{errorLocation}})",
    "icon": {
      "type": "codicon",
      "value": "search-fuzzy"
    }
  },
  "variables": [
    {
      "name": "errorMessage",
      "time": "conversation-start",
      "type": "errorMessage"
    },
    {
      "name": "errorLocation",
      "time": "conversation-start",
      "type": "errorLocation"
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
    "placeholder": "诊断错误中",
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
请完全使用中文回答。
<|end|>
<|user|>
{{errorMessage}}

请解释错误原因并提供可能的解决方案。
<|end|>
<|assistant|>
```

### Response Prompt

```template-response
<|system|>
请完全使用中文回答。
<|end|>
<|user|>
{{errorMessage}}

请解释错误原因并提供可能的解决方案。
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
