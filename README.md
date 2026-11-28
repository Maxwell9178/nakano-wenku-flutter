# NakanoWenku

> 一个完全离线的本地电子书阅读器 · Android
> 不用登录、不联网也能读书：导入即入库，所有数据只存在你自己的手机里。

![Flutter](https://img.shields.io/badge/Flutter-3.50-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.14-0175C2?logo=dart&logoColor=white)
![Android](https://img.shields.io/badge/Android-API%2024%2B-3DDC84?logo=android&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-lightgrey)

**官网 / 下载页：<https://maxwell9178.github.io/nakano-wenku-flutter/>**

---

## 这是什么

NakanoWenku 是一个用 Flutter 写的**纯本地、纯离线**电子书阅读器。

它没有账号体系、没有云端书架、不会上传任何一行文字。你把书导进来，它就帮你把书摆在一个 3D 圆环书架上，按你喜欢的方式排版、翻页、摘抄、记书签，然后把这些数据全都留在手机存储里。

- **完全离线**：除「检查更新」外，App 不发起任何网络请求
- **数据本地**：书籍、进度、书签、摘抄、阅读时长全部存在本机
- **单一备份方式**：`.wkarchive` 数据包，自己导出、自己保存
- **无广告、无追踪、无后台服务**

---

## 功能

### 导入

| 格式 | 处理方式 |
| --- | --- |
| EPUB | 解析 OPF + spine，按章节顺序取正文 |
| TXT / MD | 自动识别编码（UTF-8 / UTF-16），按「第 N 章」「Chapter N」等标题切章，没有标题就按长度切 |
| DOCX | 解压读取 `word/document.xml`，去标签后切章 |
| ZIP | 解包后逐个解析包内的书籍文件，支持多卷 |
| CBX / CBZ | 漫画包：解压图片并按文件名自然排序，按页阅读 |
| PDF / DOC | 只做扫描与提示，不做正文解析 |

- 导入支持多选，可从「导入」页直接选文件，也可以扫描手机存储里的书籍
- 多卷自动识别，三种入库方式：**分卷单独入库 / 全部合并为一本 / 自选合并**
- 每本书自动分配 `NW-XXXX` 编号（0001–9999），编号独立存储，不与会拼进书名
- 支持给一次导入打分组标签，之后可在搜索里按分组筛选

### 书架

- 3D 圆环书架：书本 13° 倾斜、滑动时抬升、两侧带透视缩放，**可无限循环滑动**
- 底部页码 `<0001/0020>` 跟随居中书本变化
- 信息区展示当前书封面、书名、作者、进度、状态
- 标签筛选条 + 纯文字列表，标题过长自动换行，不截断

### 阅读

- 两种翻页：**滚动阅读**（默认）与**左右分页**，分页模式严格左右翻页，不会有上下滑动残留
- 三种翻页动画：滑动 / 淡入 / 无动画
- 排版全部可调：字号、行距、段落间距、左右与上下页边距
- 背景：纯黑 / 纯白 / 淡黄 / 深蓝四种内置，支持导入自己的图片，并可调节压暗程度
- 进度按 1% 显示，续读会回到**上次读到的具体位置**，而不是章节开头
- 章节末提示、全书读完卡片（可保存到相册）
- 选中文字 → 复制；长按空白 → 阅读菜单（目录 / 摘抄这一段 / 阅读设置 / 添加书签 / 沉浸模式）
- 沉浸模式底部一条极细的液态玻璃名言条，进入时从本地名言库随机一条，不随点击变化
- 漫画阅读：上下翻页、单页 / 双页切换、双指缩放

### 记录

- **书签**：记录章节 + 位置 + 备注，可跳回、可删除；「我的 → 书签库」汇总全部书籍的书签
- **摘抄**：按章节保存段落，独立成库
- **阅读时长**：进入阅读页开始计时，切后台或退出即停止累加，按书统计
- **阅读榜单**：搜索页空态展示累计时长前三
- **兴趣雷达**：六维（文学 / 热血 / 科幻 / 恋爱 / 运动 / 悬疑），按「标签 × 阅读时长」加权统计
- **阅读打卡**：当天读满 1 分钟即算打卡，日历视图

### 数据

- `.wkarchive` 导出 / 导入：书籍、章节、封面、书签、摘抄、进度、阅读时长、标签权重、导入站点、设置，一个包带走
- 导入支持**覆盖**与**合并**两种策略
- 删除账号需两次确认，删除本机全部数据

---

## 技术

### 技术栈

- **框架**：Flutter 3.50 / Dart 3.14
- **平台**：Android only，`minSdk 24`，`compileSdk / targetSdk 36`
- **状态管理**：`provider` + `ChangeNotifier`
- **本地存储**：`shared_preferences`（结构化数据走 JSON 序列化）+ 应用私有目录（章节、封面、背景、字体、漫画图片）
- **文件选择**：`file_picker`
- **压缩包**：`archive`（EPUB / DOCX / ZIP / CBX 全部手写解析，不依赖第三方阅读引擎）
- **相册保存**：`gal`
- **外链跳转**：`url_launcher`
- **无其他运行时依赖**：没有 Firebase、没有崩溃上报、没有统计 SDK

### 目录结构

```
lib/
├── core/
│   ├── constants/      # 应用常量、存储键
│   ├── models/         # Book / Chapter / Bookmark / Excerpt / 阅读偏好 / 版本信息
│   ├── routing/        # 路由表、软转场
│   ├── services/       # 解析、导入、仓库、备份、更新、字体、词典
│   ├── settings/       # 全局设置控制器（主题 / 玻璃 / 字体 / 帧率）
│   ├── theme/          # 颜色、主题、字体与排版范式
│   ├── utils/          # 顶部提示条、图片选择等
│   └── widgets/        # 液态玻璃、毛玻璃、网格背景、滑块、对话框等公共组件
└── features/
    ├── splash/         # 开屏
    ├── onboarding/     # 首次初始化（建本地账号 / 导入备份）
    ├── home/           # 底部导航外壳
    ├── bookshelf/      # 3D 书架
    ├── book_detail/    # 详情、编辑、分享卡
    ├── import/         # 导入、扫描、多卷策略、快捷站点
    ├── reader/         # 阅读页、目录、摘抄、设置面板
    ├── comic/          # 漫画阅读
    ├── bookmarks/      # 书签库
    ├── search/         # 搜索 + 阅读榜单
    ├── profile/        # 我的、打卡日历、书目列表
    └── settings/       # 设置、版本、文档页、关于作者
```

### 几个实现细节

**解析器**：`BookParser` 是唯一解析入口，按扩展名分派。EPUB 走 `container.xml → OPF → spine` 顺序取 XHTML，再清洗成纯文本；TXT 用严格 UTF-8 解码，失败回落 latin1（不做 GBK 猜测，避免乱码更严重）；章节切分先试标题正则，识别不到就按 6000 字长度切。

**书内数据结构**：每本书的章节单独存成一个 `NW-XXXX.json`，正文不塞进书架索引，避免书架列表读取时把几十兆正文全load 进内存。封面同理独立成文件。

**进度与续读**：滚动模式下进度 = `pixels / maxScrollExtent`，直接写入书籍记录（900ms 防抖）。续读时按保存的比例反推滚动偏移，等首帧布局完成后再 `jumpTo`，所以能落在具体那段文字上而不是章节开头。

**编号分配**：从 0001 开始找**最小空号**，不会因为删过书就跳到几百号。

**玻璃材质**：`LiquidGlass` 完全用 `BackdropFilter` + 多层渐变 + `CustomPainter` 手绘边缘与弧形高光堆出来，没有用任何第三方模糊库。模糊与透明度是两条全局参数，所有卡片、弹窗、导航栏共用同一份规格。

**备份包**：`.wkarchive` 就是一个 zip，里面 `info.json` 汇总全部结构化数据、`avatar.png` 放头像、`books/` 与 `chapters/` 放书与正文。导入时 `verify: true` 校验完整性，缺失文件逐个容错，不会因为一本书损坏就整包失败。

**更新检测**：四路清单源（Gitee raw / Gitee Pages / GitHub raw / jsDelivr）**并行发起**，9 秒总超时，拿到结果立刻返回；全部失败才回落到 GitHub Releases API。只有检测成功才写入 7 天冷却，离线下次启动会自动重试。

**更新安装**：确认更新后由 App 自己把 APK 下到 `cache/updates/`，再用 `open_filex` 交给系统安装器（需要 `REQUEST_INSTALL_PACKAGES`）；这条路失败才回落浏览器下载页，避免「检测到新版但装不上」。

### 构建

```bash
# 环境：Flutter 3.50+、JDK 17、Android SDK 36
flutter pub get
flutter build apk --release
# 产物：build/app/outputs/flutter-apk/app-release.apk
```

签名配置放在 `android/key.properties`（不入库）：

```properties
storePassword=****
keyPassword=****
keyAlias=nakano
storeFile=nakano-wenku.jks
```

没有这个文件时会退回 debug 签名，方便自己编译试玩。发布流程与版本号规则见 [RELEASE.md](RELEASE.md)。

---

## 数据存放位置

| 内容 | 位置 |
| --- | --- |
| 书籍索引、进度、书签、摘抄、设置 | `SharedPreferences`（键前缀 `nw.`） |
| 章节正文、封面 | 应用私有目录 `library/chapters`、`library/covers` |
| 自定义背景、字体 | `library/backgrounds`、`fonts` |
| 漫画解包图片 | `library/comics/comic_<时间戳>` |
| 导出包 | 用户自选路径（`.wkarchive`） |

卸载 App 会一并删除以上全部内容，**请先用 `.wkarchive` 导出备份**。

---

## 下载

最新版本在 [Releases](https://github.com/Maxwell9178/nakano-wenku-flutter/releases/latest) 下载 `app-release.apk`，直接安装即可（Android 7.0 及以上）。

## 更新日志

### 1.0.3

- 阅读页正文下方的黄色线条移除（背景网格改中性灰，正文强制无下划线）
- 「我的 → 数据与备份」两张卡片改为严格等宽等高并整体居中
- 阅读页侧边栏删除「上一章 / 下一章」，只保留 阅读设置 / 摘抄 / 目录
- 左右分页模式重做：点左右两侧翻页，页内不再上下滑动
- 新增总书签库（我的 → 书签库），汇总全部书籍书签，可跳转可删除
- 版本更新支持直接下载并拉起系统安装器
- 选择图片改为调用系统相册（封面、头像、阅读背景）
- 详情页支持点封面查看大图并保存到相册
- 修复阅读进度与当前章节不同步、从目录进入却跳回上次位置

### 1.0.2

- 移除阅读水印、音量键翻页、长按放大镜
- 阅读进度改为 1% 精度，续读回到具体位置
- 液态玻璃与毛玻璃重做，滑块全区间连续生效
- 六维雷达图、网格背景居中、名言固定随机
- 编号不再拼进书名，改为从 0001 顺序分配
- 更新检测四路并行，失败静默

### 1.0.1

- 修复「我的」「阅读页」灰屏（Provider 漏注册）
- 内置思源宋体（NWSerif），大标题统一宋体
- 3D 书架收紧并支持无限循环
- 导入页快捷站点编号修正、新增 GitHub 快捷入口

---

## 关于

作者：**Maxwell9178**
项目：<https://github.com/Maxwell9178/nakano-wenku-flutter>
国内镜像：<https://gitee.com/maxwell9178/nakano-wenku-flutter>
交流群：1126557550

开发过程中使用了 AI 编程助手（DeepSeek Harness）辅助编写与调试，架构、需求与验收由作者本人负责。

如果这个阅读器对你有用，欢迎点个 Star；想请作者喝杯奶茶也随时欢迎 ☕

## 许可

MIT License。书是你自己的，数据也是。
