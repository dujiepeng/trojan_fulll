# Trojan 一键安装修复脚本 (Jrohy 版对标)

本仓库提供了一个修复版的 Trojan 安装脚本，解决了原 `Jrohy/trojan` 脚本在安装过程中遇到的 APT 锁占用及 Docker 静态二进制文件下载 404 的问题。

## 卸载与全量清理

脚本现在支持交互式菜单，您可以运行脚本并选择相应的选项：
- **普通卸载**：停止并删除 Trojan 服务及管理程序，保留 Docker 环境。
- **全量卸载**：彻底删除 Trojan、Docker 容器、Docker 镜像、Docker 二进制文件以及所有相关数据（包括证书）。

运行命令：
```bash
bash <(curl -sL https://raw.githubusercontent.com/dujiepeng/trojan_fulll/main/install.sh)
```
并在菜单中选择 `2` 或 `3`。

## 修复说明
1. **自动清理 APT 锁**：脚本启动时会自动检查并清理 `/var/lib/dpkg/lock-frontend` 等锁定文件。
2. **修复 Docker 下载链接**：预先安装官方稳定的 Docker 静态二进制文件（v27.3.1），避免原脚本中的失效下载路径。
3. **完全兼容**：安装完成后，您依然可以使用 `trojan` 命令及其图形化管理面板。

## 版本信息
- **版本**: v1.1.8
- **更新时间**: 2025-12-24
- **修改人**: Antigravity (AI Assistant)
