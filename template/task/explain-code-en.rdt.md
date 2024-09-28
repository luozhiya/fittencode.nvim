# Explain Code

Explain the selected code.

## Template

### Configuration

```json conversation-template
{
  "id": "explain-code-en",
  "engineVersion": 0,
  "label": "Explain Code",
  "description": "Explain the selected code.",
  "tags": ["debug", "understand"],
  "header": {
    "title": "Explain Code ({{location}})",
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
    "placeholder": "Generating code explanation",
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
<|end|>
<|user|>
Below is the user's code context, which may be needed for subsequent inquiries.
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
Understood, you can continue to enter your question.
<|end|>
<|user|>
Break down and explain the following code in detail step by step, then summarize the code (emphasize its main function).

## Selected Code
\`\`\`
{{selectedText}}
\`\`\`
<|end|>
<|assistant|>
```

### Response Prompt

```template-response
<|system|>
<|end|>
<|user|>
Below is the user's code context, which may be needed for subsequent inquiries.
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
Understood, you can continue to enter your question.
<|end|>
<|user|>
Break down and explain the following code in detail step by step, then summarize the code (emphasize its main function).

## Selected Code
\`\`\`
{{selectedText}}
\`\`\`
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
