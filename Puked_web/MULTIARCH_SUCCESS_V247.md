# 多架构构建成功说明 (v2.4.7)

## 结果

- **镜像**: `rocky8848/puked-web-allinone:2.4.7` 与 `latest`
- **架构**: ✅ **linux/amd64** (x86_64) + ✅ **linux/arm64** (ARM64)
- **验证**: `docker buildx imagetools inspect rocky8848/puked-web-allinone:2.4.7`

## 第一性原理方案

1. **问题**: buildx 的 docker-container 在拉取/认证时易超时，且不总是走代理。
2. **做法**: 先由 **daemon 预拉取** 两平台基础镜像，再分平台构建、分别推送，最后 **manifest 合并**。
3. **效果**: 预拉取走 Docker Desktop 的代理/网络，构建阶段对基础镜像的依赖已满足，减少构建时外网请求，成功率更高。

## 推荐构建命令

```bash
cd /Users/rocky/Documents/PukedMaster/Puked_web
./build_multiarch_daemon.sh
```

## 脚本流程摘要

1. 预拉取 `node:20-alpine`、`nginx:stable-alpine`（linux/amd64 与 linux/arm64）
2. 构建 `linux/amd64` 并 `--load` 到本地
3. 构建 `linux/arm64` 并 `--load` 到本地
4. 推送 `:2.4.7-amd64`、`:2.4.7-arm64`
5. `docker manifest create` 并 `docker manifest push` 得到 `:2.4.7` 与 `:latest`

## 若遇网络超时

- 在 Docker Desktop 中配置代理（如 ClashX 混合端口 **53785**）：Settings → Resources → Proxies。
- 确保先成功执行脚本中的「预拉取」步骤，再执行构建。
