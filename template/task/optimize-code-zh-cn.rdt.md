# Optimize Code

Explain the selected code.

## Template

### Configuration

```json conversation-template
{
  "id": "optimize-code-zh-cn",
  "engineVersion": 0,
  "label": "Optimize Code",
  "description": "Optimize the selected code.",
  "tags": ["optimize code"],
  "header": {
    "title": "优化代码 ({{location}})",
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
    "placeholder": "代码优化中",
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
请完全使用中文回答。
<|end|>
<|user|>
以下是用户的代码上下文，后续询问可能会需要使用。
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
了解了，您可以继续输入您的问题。
<|end|>
<|user|>
需要优化的代码如下，请保持该代码的语法类型不变。

## Selected Code
\`\`\`
{{selectedText}}
\`\`\`
此代码的编程语言是 {{language}}.
对以上代码进行优化，减少不必要的计算，去除冗余代码，增加适当的错误处理机制。
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
请完全使用中文回答。
<|end|>
<|user|>
以下是用户的代码上下文，后续询问可能会需要使用。
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
了解了，您可以继续输入您的问题。
<|end|>
<|user|>
需要优化的代码如下，请保持该代码的语法类型不变。

## Selected Code
\`\`\`
{{selectedText}}
\`\`\`

此代码的编程语言是 {{language}}.
对以上代码进行优化，减少不必要的计算，去除冗余代码，增加适当的错误处理机制，并保持代码的可读性。
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
