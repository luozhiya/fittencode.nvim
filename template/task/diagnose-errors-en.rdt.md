# Explain Code

Diagnoses error in vscode and provides a potential fix.

## Template

### Configuration

```json conversation-template
{
  "id": "diagnose-errors-en",
  "engineVersion": 0,
  "label": "Diagnose Error",
  "tags": ["debug"],
  "description": "Diagnoses error in vscode and provides a potential fix.",
  "header": {
    "title": "Diagnose Error ({{errorLocation}})",
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
    "placeholder": "Diagnosing error",
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
{{errorMessage}}

Please explain the reason for the error and provide possible solutions.
<|end|>
<|assistant|>
```

### Response Prompt

```template-response
<|system|>
Reply same language as the user's input.
<|end|>
<|user|>
{{errorMessage}}

Please explain the reason for the error and provide possible solutions.
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
