# Find Bugs

Template to find bugs in the selected code.

## Template

### Configuration

```json conversation-template
{
  "id": "find-bugs-en",
  "engineVersion": 0,
  "label": "Find bugs",
  "tags": ["debug", "code quality"],
  "description": "Find potential bugs in the selected code.",
  "header": {
    "title": "Find Bugs ({{location}})",
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
    "placeholder": "Finding bugs",
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
<|end|>
<|user|>
The programming language is {{language}}.
The filename is {{filename}}.

## Selected Code
\`\`\`
{{selectedText}}
\`\`\`
What potential issues could the above code have?
Only consider defects that would lead to erroneous behavior.
<|end|>
<|assistant|>
```

### Response Prompt

```template-response
<|system|>
<|end|>
<|user|>
The programming language is {{language}}.

{{#if selectedText}}
## Selected Code
\`\`\`
{{selectedText}}
\`\`\`
What potential issues could the above code have?
Only consider defects that would lead to erroneous behavior.
{{/if}}
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
