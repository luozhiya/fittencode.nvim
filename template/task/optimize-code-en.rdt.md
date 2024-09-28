# Optimize Code

Explain the selected code.

## Template

### Configuration

```json conversation-template
{
  "id": "optimize-code-en",
  "engineVersion": 0,
  "label": "Optimize Code",
  "description": "Optimize the selected code.",
  "tags": ["edit"],
  "header": {
    "title": "Optimize Code ({{location}})",
    "icon": {
      "type": "codicon",
      "value": "edit"
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
    "placeholder": "The code is being optimized",
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
The programming language is {{language}}.
Reduce unnecessary calculations and improve operational efficiency. 
Remove redundant code and keep it clean. 
Add an appropriate error handling mechanism.
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
The code that needs to be optimized is as follows, please keep the syntax type of the code unchanged.

## Selected Code
\`\`\`
{{selectedText}}
\`\`\`

The programming language is {{language}}.
The above code is optimized to reduce unnecessary calculations, remove redundant code, and add appropriate error handling mechanisms.
<|end|>
<|assistant|>
```

### Response Prompt

```template-response
<|system|>
The programming language is {{language}}.
Reduce unnecessary calculations and improve operational efficiency. 
Remove redundant code and keep it clean. 
Add an appropriate error handling mechanism.
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
The code that needs to be optimized is as follows, please keep the syntax type of the code unchanged.

## Selected Code
\`\`\`
{{selectedText}}
\`\`\`

The programming language is {{language}}.
The above code is optimized to reduce unnecessary calculations, remove redundant code, and add appropriate error handling mechanisms.
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
