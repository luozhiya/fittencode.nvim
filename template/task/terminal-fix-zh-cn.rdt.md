# Explain Errors

Analyses error in vscode and provides a solution.

## Template

### Configuration

```json conversation-template
{
  "id": "terminal-fix-zh-cn",
  "engineVersion": 0,
  "label": "Terminal Fix",
  "tags": ["debug"],
  "description": "Analyses error in vscode and provides a solution.",
  "header": {
    "title": "终端分析",
    "icon": {
      "type": "codicon",
      "value": "terminal-bash"
    }
  },
  "variables": [
    {
      "name": "terminalText",
      "time": "conversation-start",
      "type": "terminal-Text"
    },
    {
      "name": "firstMessage",
      "time": "message",
      "type": "message",
      "property": "content",
      "index": 0
    }
  ],
  "initialMessage": {
    "placeholder": "分析中...",
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
终端显示的信息如下，请解释原因并提供可能的解决方案。

{{terminalText}}
<|end|>
<|assistant|>
```

### Response Prompt

```template-response
<|system|>
请完全使用中文回答。
<|end|>
<|user|>
终端显示的信息如下，请解释原因并提供可能的解决方案。

{{terminalText}}
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
