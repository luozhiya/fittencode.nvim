# Document Code

Document the selected code.

## Template

### Configuration

````json conversation-template
{
  "id": "document-code-en",
  "engineVersion": 0,
  "label": "Document Code",
  "tags": ["generate", "document"],
  "description": "Document the selected code.",
  "header": {
    "title": "Document Code {{location}}",
    "icon": {
      "type": "codicon",
      "value": "output"
    }
  },
  "variables": [
    {
      "name": "openFiles",
      "time": "conversation-start",
      "type": "context"
    },
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
      "name": "commentSnippet",
      "time": "conversation-start",
      "type": "comment-snippet"
    }
  ],
  "chatInterface": "instruction-refinement",
  "initialMessage": {
    "placeholder": "Documenting selection",
    "maxTokens": 2048,
    "stop": ["```"],
    "completionHandler": {
      "type": "active-editor-diff",
      "botMessage": "Generated documentation."
    }
  },
  "response": {
    "placeholder": "Documenting selection",
    "maxTokens": 2048,
    "stop": ["```"],
    "completionHandler": {
      "type": "active-editor-diff",
      "botMessage": "Generated documentation."
    }
  }
}
````

### Initial Message Prompt

```template-initial-message
<|system|>
Document the code on function/method/class level.
Avoid adding line-by-line comments.
The programming language is {{language}}.
Respond directly to the code without any additional explanation.
Avoid using markdown in your response.
Do not modify the user's code when adding comments.
Do not alter the existing comments in the user's code.
<|end|>
<|user|>
The code that needs comments added is as follows, please maintain the indentation format of this code:
\`\`\`
{{selectedText}}
\`\`\`

{{#if commentSnippet}}
The reference comment style is as follows:
\`\`\`
{{commentSnippet}}
\`\`\`

{{/if}}
Please add comments to the code on function/method/class level.
The programming language is {{language}}.
The filename is {{filename}}.
Avoid using markdown in your response.
Do not modify the code when adding comments.
Avoid adding line-by-line comments.
Refrain from altering or translating any part of the code, especially comments and strings.
<|end|>
<|assistant|>
```

### Response Prompt

```template-response
<|system|>
Document the code on function/method/class level.
Avoid adding line-by-line comments.
The programming language is {{language}}.
The filename is {{filename}}.
Respond directly to the code without any additional explanation.
Avoid using markdown in your response.
Do not modify the user's code when adding comments.
Do not alter the existing comments in the user's code.
<|end|>
<|user|>
The code that needs comments added is as follows, please maintain the indentation format of this code:
\`\`\`
{{selectedText}}
\`\`\`

{{#if commentSnippet}}
The reference comment style is as follows:
\`\`\`
{{commentSnippet}}
\`\`\`

{{/if}}
Please add comments to the code on function/method/class level.
Avoid using markdown in your response.
Do not modify the code when adding comments.
Avoid adding line-by-line comments.
Refrain from altering or translating any part of the code, especially comments and strings.

Consider the following instructions:
{{#each messages}}
{{#if (eq author "user")}}
{{content}}
{{/if}}
{{/each}}
<|end|>
<|assistant|>
```
