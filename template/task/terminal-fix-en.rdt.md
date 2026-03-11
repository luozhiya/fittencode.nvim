# Explain Errors

Analyses error in vscode and provides a solution.

## Template

### Configuration

```json conversation-template
{
  "id": "terminal-fix-en",
  "engineVersion": 0,
  "label": "Terminal Fix",
  "tags": ["debug"],
  "description": "Analyses error in vscode and provides a solution.",
  "header": {
    "title": "Terminal Analyze",
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
    "placeholder": "Analysing...",
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
Reply same language as the user's input.
<|end|>
<|user|>
The terminal displays the following information. Please explain the reason and provide possible solutions.

{{terminalText}}
<|end|>
<|assistant|>
```

### Response Prompt

```template-response
<|system|>
Reply same language as the user's input.
<|end|>
<|user|>
The terminal displays the following information. Please explain the reason and provide possible solutions.

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
