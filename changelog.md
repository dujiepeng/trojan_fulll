# Changelog

## [1.1.2] - 2025-12-24
### 修复
- 修复 `install.sh` 中 `acme.sh` 安装失败的问题。通过在调用安装脚本前切换到 `/tmp` 目录，解决了 `cp` 命令由于找不到源文件导致的安装中断。

### 修改人
- Antigravity (AI Assistant)
