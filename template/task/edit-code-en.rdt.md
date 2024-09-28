# Edit Code

Generate code using instructions.

## Template

### Configuration

````json conversation-template
{
  "id": "edit-code-en",
  "engineVersion": 0,
  "label": "Edit Code",
  "tags": ["edit"],
  "description": "Instruct fittencode to edit the code. Creates a diff that you can review.",
  "header": {
    "title": "Edit Code {{location}}",
    "icon": {
      "type": "codicon",
      "value": "edit"
    }
  },
  "chatInterface": "instruction-refinement",
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
    }
  ],
  "response": {
    "placeholder": "Generating edit",
    "maxTokens": 1536,
    "stop": ["```"],
    "completionHandler": {
      "type": "active-editor-diff",
      "botMessage": "Generated edit."
    }
  }
}
````

### Response Prompt

```template-response
<|system|>
Please reply directly to the code without any explanation.
Please do not use markdown when replying.
<|end|>
<|user|>
The filename is {{filename}}.
The code that needs to be edited is as follows, please maintain the indentation format of this code:
\`\`\`
{{selectedText}}
\`\`\`

Please edit the code according to the following requirements:
{{#each messages}}
{{#if (eq author "user")}}
{{content}}
{{/if}}
{{/each}}
<|end|>
<|assistant|>
```
