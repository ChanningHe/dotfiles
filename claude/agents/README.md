# Claude Code Agents

## Library Usage Researcher

Library Usage Researcher 依赖配置
要使用 library-usage-researcher Agent，需要先安装以下两个 MCP（Model Context Protocol）服务：

1. Context7 MCP
用于获取官方文档和 API 规范：

claude mcp add --transport http context7 https://mcp.context7.com/mcp
2. Grep MCP
用于搜索 GitHub 上的真实代码案例：

claude mcp add --transport http grep https://mcp.grep.app
安装验证
安装完成后，可以进入 claude code 后输入下方命令验证是否正确安装： /mcp

确保列表中包含 context7 和 grep 两个服务。

References && License: 
- [kingkongshot/prompts with Apache License](https://github.com/kingkongshot/prompts)