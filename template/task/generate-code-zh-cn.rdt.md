# Generate Code

Generate code using instructions.

## Template

### Configuration

````json conversation-template
{
  "id": "generate-code-zh-cn",
  "engineVersion": 0,
  "label": "Generate Code",
  "tags": ["generate"],
  "description": "Generate code using instructions.",
  "header": {
    "title": "生成代码",
    "icon": {
      "type": "codicon",
      "value": "wand"
    }
  },
  "chatInterface": "instruction-refinement",
  "variables": [],
  "response": {
    "placeholder": "Generating code",
    "maxTokens": 2048,
    "stop": ["```"],
    "completionHandler": {
      "type": "update-temporary-editor",
      "botMessage": "Generated code."
    }
  }
}
````

### Response Prompt

```template-response
<|system|>
Generate code for the specification.
Please reply directly to the code without any explanation.
Please do not use markdown when replying.
<|end|>
<|user|>
{{#each messages}}
{{#if (eq author "user")}}
{{content}}
{{/if}}
{{/each}}
<|end|>
<|assistant|>
```
