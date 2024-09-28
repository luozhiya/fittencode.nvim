# Generate Unit Test

Generate unit test cases for the selected code.

## Template

### Configuration

````json conversation-template
{
  "id": "generate-unit-test-zh-cn",
  "engineVersion": 0,
  "label": "Generate Unit Test",
  "tags": ["generate", "test"],
  "description": "Generate a unit test for the selected code.",
  "header": {
    "title": "生成单元测试 ({{location}})",
    "icon": {
      "type": "codicon",
      "value": "beaker"
    }
  },
  "chatInterface": "instruction-refinement",
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
      "name": "frameWork",
      "time": "conversation-start",
      "type": "unit-test-framework"
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
    "placeholder": "Generating Test",
    "maxTokens": 1536,
    "stop": ["```"],
    "completionHandler": {
      "type": "update-temporary-editor",
      "botMessage": "Generated unit test.",
      "language": "{{language}}"
    }
  },
  "response": {
    "placeholder": "Updating Test",
    "maxTokens": 1536,
    "stop": ["```"],
    "completionHandler": {
      "type": "update-temporary-editor",
      "botMessage": "Updated unit test.",
      "language": "{{language}}"
    }
  }
}
````

### Initial Message Prompt

```template-initial-message
<|system|>
Write a unit test that contains test cases for the happy path and for all edge cases.
Please reply directly to the code without any explanation.
Please do not use markdown when replying.
The programming language is {{language}}.
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
Write a unit test for the code below.
{{#if frameWork}}
Use the {{frameWork}} framework.
{{/if}}
Please reply directly to the code without any explanation.

\`\`\`
{{selectedText}}
\`\`\`
<|end|>
<|assistant|>
```

### Response Prompt

```template-response
<|system|>
Rewrite the code below as follows: "{{lastMessage}}"
Please reply directly to the code without any explanation.
Please do not use markdown when replying.
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
Rewrite the code below as follows: "{{lastMessage}}"

\`\`\`
{{temporaryEditorContent}}
\`\`\`
<|end|>
<|assistant|>
```
