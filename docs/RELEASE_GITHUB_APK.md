# 发布 APK 到 GitHub Release 步骤

## 版本号说明

- 当前 `Puked/pubspec.yaml` 中版本为 **2.5.0**
- Tag 使用 `v2.5.0`，Release 标题为 **Puked v2.5.0**，APK 文件名为 **Puked-2.5.0.apk**

若需发布其他版本，请先修改 `Puked/pubspec.yaml` 中的 `version`，再在下面命令中替换版本号。

---

## 1. 在项目根目录执行

确保已格式化并确认无编译错误（可选）：

```bash
cd Puked
dart format .
flutter analyze --no-fatal-infos
```

---

## 2. 提交并推送到 main

```bash
cd /path/to/PukedMaster   # 替换为你的仓库根目录
git add -A
git status                 # 确认变更
git commit -m "Release Puked v2.5.0: 算法优化、自动校准、负体验视频、速度延迟优化"
git push origin main
```

---

## 3. 创建 Tag 并推送（触发构建与 Release）

```bash
# 版本号与 pubspec.yaml 保持一致，例如 2.5.0
git tag v2.5.0
git push origin v2.5.0
```

推送 tag 后，**Puked Release** workflow 会：

1. 构建 Release APK  
2. 创建 Release，标题为 **Puked v2.5.0**  
3. 将 **Puked-2.5.0.apk** 上传到该 Release  
4. 使用预设的版本更新说明作为 Release 正文  

在 **Actions** 页选择 “Puked Release” 查看运行状态，在 **Releases** 页可下载 APK。

---

## 4. 工作流说明

- **Puked APK Build**（`puked-apk-build.yml`）：push 到 `main` 且变更在 `Puked/**` 时运行，只上传构建产物为 artifact，不创建 Release。
- **Puked Release**（`puked-release.yml`）：仅在有 tag 推送（如 `v2.5.0`）时运行，构建 APK 并创建 GitHub Release、上传 `Puked-{version}.apk`。Release 流程使用 `--no-fatal-infos --no-fatal-warnings`，以减少因静态检查导致的失败。
