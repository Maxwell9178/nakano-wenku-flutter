# NakanoWenku 打包与发布说明

本文件对应第 4 轮「Release APK 打包适配 + Gitee Pages 版本更新」。
所有步骤都在本机完成，不依赖任何云端构建服务。

---

## 一、版本号从哪里来

版本号有三处，必须保持一致：

| 位置 | 作用 |
| --- | --- |
| `pubspec.yaml` 的 `version: 1.0.0+1` | Flutter 侧显示，`AppConstants.versionName/versionCode` 用它 |
| 工程根目录 `version.json` | APP 更新检测直接读取的清单，也是上传到 Gitee Pages 的文件 |
| `android/app/build.gradle` | 直接解析 `version.json` 得到 `versionName` / `versionCode` |

发版时只改前两处：

1. `pubspec.yaml` → `version: 1.0.1+2`
2. `version.json` →

```json
{
  "versionName": "1.0.1",
  "versionCode": 2,
  "changelog": "本次更新：修了阅读进度、优化了书架滑动。",
  "downloadUrl": "https://<你的-pages-域名>/app-release.apk",
  "preRelease": false
}
```

`build.gradle` 会自动读取 `version.json`，不需要再改。

---

## 二、正式签名（可选，但建议）

默认沿用 debug 签名，方便直接在任意机器出包。要换正式签名：

1. 生成 keystore：

```bash
keytool -genkey -v -keystore nakano-release.jks -keyalg RSA \
  -keysize 2048 -validity 10000 -alias nakano
```

2. 工程 `android/key.properties`：

```properties
storePassword=你的密码
keyPassword=你的密码
keyAlias=nakano
storeFile=nakano-release.jks
```

`storeFile` 相对 `android/` 目录；文件不存在时自动回落到 debug 签名，不会中断构建。

> `key.properties` 与 `.jks` 不要提交到公开仓库（`.gitignore` 已忽略）。

---

## 三、打包

```bash
cd NakanoWenku
flutter clean
flutter pub get
flutter build apk --release
```

产物：`build/app/outputs/flutter-apk/app-release.apk`

可选：分架构瘦身包

```bash
flutter build apk --release --split-per-abi
```

产物为 `app-arm64-v8a-release.apk` / `app-armeabi-v7a-release.apk`，
上传哪个就把 `downloadUrl` 指向哪个文件名。

release 构建已开启：R8 代码压缩、资源压缩、`zh/en` 资源裁剪、Impeller 关闭
（毛玻璃 BackdropFilter 在部分 GPU 的 Impeller 下会掉帧，回退 Skia 后稳定）。

---

## 四、版本更新文件放在哪（三种方式，任选其一即可）

APP 的检测顺序是：Gitee Pages → Gitee raw → GitHub raw → jsDelivr → GitHub Releases，
所以下面任一条链路通了，更新检测就能工作。

### 方式 A：推到 GitHub 仓库（当前已生效，无需任何网页操作）

仓库根目录放两个文件，push 到 `main` 分支即可：

| 文件 | 地址 |
| --- | --- |
| `version.json` | `https://raw.githubusercontent.com/Maxwell9178/nakano-wenku-flutter/main/version.json` |
| `dist/app-release.apk` | `https://raw.githubusercontent.com/Maxwell9178/nakano-wenku-flutter/main/dist/app-release.apk` |

发新版只要：替换 `dist/app-release.apk` + 改 `version.json` 的版本号 → `git push`。
raw 会有几分钟 CDN 缓存，属正常。

> 注意：仓库里放 APK 会让 git 历史变大（每个版本 +50MB）。版本多了以后建议改用方式 B。

### 方式 B：GitHub Releases（推荐长期用）

1. 仓库 → Releases → Draft a new release，Tag 例如 `v1.0.1`；
2. 把 `app-release.apk` 拖进附件；
3. 点 Publish。

APP 会走 GitHub Releases 接口读到 `tag_name` 与 `.apk` 附件地址，`downloadUrl` 可以留空。

### 方式 C：Gitee Pages（国内下载最快）

1. Gitee 新建**公开**仓库（如 `nakano-wenku-flutter-pages`），根目录放 `version.json` + `app-release.apk`；
2. 仓库「服务」→「Gitee Pages」→ 分支 `master`、目录 `/` → 启动；
3. 把 Pages 地址写进 `lib/core/constants/app_constants.dart` 的 `updateManifestUrl` / `updateApkUrl`，重新打包。

后续更新：替换两个文件 + 点「部署」。

---
## 五、发布前检查清单

- [ ] `pubspec.yaml` 与 `version.json` 版本号一致
- [ ] `flutter analyze` 无 error
- [ ] 冷启动、书架、阅读、导入、设置、关于页各走一遍
- [ ] 深色 / 浅色模式各看一遍分割线与图标
- [ ] `version.json` 的 `downloadUrl` 指向真实可下载的 APK
- [ ] 新包装到真机验证过：能安装、能覆盖旧版本（签名必须同一把 keystore）

---

## 六、签名说明

`android/app/nakano-wenku.jks` 是本工程的正式签名（别名 `nakano`，密码见 `android/key.properties`，两者都已加入 `.gitignore`）。

**务必自己另存一份备份**：弄丢 keystore 之后就再也不能给用户推"覆盖安装"的更新包，只能让用户卸载重装。

`app/build.gradle` 里三种签名方案全开（v1 JAR / v2 / v3），构建后可用下面的命令核对：

```bash
$env:JAVA_HOME='D:\dev\jdk17'
& "D:\dev\android-sdk\build-tools\<版本>\apksigner.bat" verify --print-certs --verbose `
  build/app/outputs/flutter-apk/app-release.apk
```