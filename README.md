# Trojan 一键安装修复脚本 (Jrohy 版对标)

本仓库提供了一个修复版的 Trojan 安装脚本，解决了原 `Jrohy/trojan` 脚本在安装过程中遇到的 APT 锁占用及 Docker 静态二进制文件下载 404 的问题。

## 快速安装方式

在您的服务器上执行以下命令即可开始安装：

```bash
# 执行修复版 Trojan 安装脚本
bash <(curl -sL https://raw.githubusercontent.com/dujiepeng/trojan_fulll/main/install.sh)
```

## 修复说明
1. **自动清理 APT 锁**：脚本启动时会自动检查并清理 `/var/lib/dpkg/lock-frontend` 等锁定文件。
2. **修复 Docker 下载链接**：预先安装官方稳定的 Docker 静态二进制文件（v27.3.1），避免原脚本中的失效下载路径。
3. **完全兼容**：安装完成后，您依然可以使用 `trojan` 命令及其图形化管理面板。

## 版本信息
- **版本**: v1.1.1
- **更新时间**: 2025-12-24
- **修改人**: Antigravity (AI Assistant)
