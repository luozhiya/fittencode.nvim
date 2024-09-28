# Explain Code

Explain the selected code.

## Template

### Configuration

```json conversation-template
{
  "id": "explain-code-with-context",
  "engineVersion": 0,
  "label": "Explain Code with Context",
  "description": "Explain the selected code in context of all the open files.",
  "tags": ["debug", "understand"],
  "header": {
    "title": "Explain Code ({{location}}) in context",
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
      "name": "lastMessage",
      "time": "message",
      "type": "message",
      "property": "content",
      "index": -1
    }
  ],
  "response": {
    "maxTokens": 2048,
    "stop": ["Bot:", "Developer:"]
  }
}
```

### Response Prompt

```template-response
<|system|>
Continue the conversation below.
Pay special attention to the current developer request.
Write a response that continues the conversation.
Stay focused on current developer request.
Consider the possibility that there might not be a solution.
Ask for clarification if the message does not make sense or more input is needed.
Use the style of a documentation article.
Omit any links.
Include code snippets (using Markdown) and examples where appropriate.
<|end|>
<|user|>
## Code Summary
## Open Files
{{#each openFiles}}
### File: {{name}}
\`\`\`{{language}}
{{content}}
\`\`\`
{{/each}}
<|end|>
<|user|>
Summarize the code below (emphasizing its key functionality).
{{#if selectedText}}
## Selected Code
\`\`\`{{language}}
{{selectedText}}
\`\`\`
{{/if}}
<|end|>
{{#each messages}}
{{#if (eq author "bot")}}
<|assistant|>
{{content}}
<|end|>
{{else}}
<|user|>
{{content}}
<|end|>
{{/if}}
{{/each}}
<|assistant|>
```
