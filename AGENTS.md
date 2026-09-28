# 项目协作指南

## 首要约束

- 本项目是注入 macOS 微信进程的插件，不是独立应用。普通构建也可能修改本机微信：Xcode 的 ShellScript 阶段默认执行 `Rely/install.sh --force --no-install-state`。仅编译验证必须设置 `SOVEXT_SKIP_INSTALL=1`。
- 未经明确授权，不运行安装、卸载、重签名、终止微信或发送真实消息的操作。编译成功不代表宿主运行兼容。
- 修改源代码、配置、文档、依赖或其他受版本控制文件前，先说明范围、文件、实现方式和验证步骤，获得用户明确确认后再写入；范围实质变化需再次确认。只读检查不需要确认。
- 用户明确要求提交时，可检查差异并仅暂存、提交任务相关的现有改动，无须再次确认；不授权额外编辑、推送或改写历史。保留无关改动及未跟踪文件。

## 项目与目录

SovietExtension（苏维埃助手）是面向 Apple Silicon 微信的开源 macOS 插件，使用 Objective-C、Objective-C++ 和 ARM64 汇编，构建产物为 `SovietExtension.framework`。

| 路径 | 用途 |
| --- | --- |
| `README.md` | 功能展示、支持版本、安装和故障恢复说明 |
| `SovietExtension/SovietExtension/` | 插件源码、头文件和 DocC 文档 |
| `SovietExtension/SovietExtension.xcodeproj/` | Xcode 工程和共享 scheme |
| `SovietExtension/Rely/install.sh` | 版本检查、备份、framework 安装和签名流程 |
| `SovietExtension/Rely/uninstall.sh` | 根据安装状态及备份恢复宿主 |
| `SovietExtension/Rely/supported_versions.txt` | 安装器支持的完整版本与 Build 列表 |
| `SovietExtension/Rely/Plugin/` | 已跟踪的预编译 framework，不是源码输出目录 |
| `SovietExtension/Rely/insert_dylib` | 安装器使用的二进制工具 |

不要因日常源码或文档修改而更新预编译产物、签名文件、图片或 Xcode 用户状态文件。

## 检索与初始化

- 根目录存在 `.codegraph/` 时，优先使用 `codegraph explore "符号或问题"`、`codegraph node <符号或文件>`，或对应 MCP 工具定位陌生代码及调用链；明确指定的文件、配置和日志可直接读取。工具不可用时说明后使用文本检索。不自行创建或重建索引。
- 主要消息功能启动入口是 `RevokePatch.mm` 中的 `YMWeChatAntiRevokePatchEntry`（constructor）：启动权限检查 → 加载功能开关 → 多开和消息菜单 → 系统浏览器、自动登录、退群监控、助手菜单、禁止更新、防撤回。
- `StartupPermission.h/.m` 提供启动权限检查；主题相关启动逻辑还应检查 `ThemeHook.mm`，不要假定整个插件只有一个初始化入口。
- `NSObject+MainHook.m` 的 `startHook` 当前基本为空，不应根据文件名把它当作实际启动入口。

## 功能导航

以下文件均位于 `SovietExtension/SovietExtension/`。

| 功能 | 优先阅读 |
| --- | --- |
| 消息防撤回、宿主版本配置、公共补丁和日志能力 | `RevokePatch.mm`、`RevokePatch.h`、`RevokeSettings.h` |
| 本人撤回、保留消息与同步到手机 | `SelfRevokePatch.mm`、`SelfRevokeLedger.h`、`ForwardToSelfPatch.mm` |
| 消息菜单、复读、媒体操作、引用回复 | `MessageMenuPatch.mm`、`MessageRepeatPatch.mm`、`MessageMediaActions.mm`、`QuotedReply.h` |
| 退群监控 | `RevokePatch.mm`、`GroupExitCapture.h`、`GroupExitSubscription.h` |
| 自动登录、阻止更新 | `AutoLogin.mm`、`AntiUpdate.mm` |
| 助手菜单与开关 | `MenuManager.m/.h`、`NSMenu+Action.m`、`NSMenuItem+Action.m` |
| 主题、模糊背景与设置窗口 | `ThemeHook.mm`、`YMColorfulBlurBackgroundView.mm`、`MistyModeSettingsWindowController.m` |
| 侧栏配置、状态及设置窗口 | `SidebarManager.mm`、`SidebarModel.h`、`SidebarSettingsWindowController.m` |
| 侧栏宿主适配、完整性检查与汇编桥接 | `SidebarPatch.mm`、`SidebarRuntime.h`、`SidebarPatchIntegrity.h`、`SidebarOrderHooks.S` |
| Objective-C 方法替换辅助 | `YMSwizzledHelper.m` |

## 实现约定与版本适配

- 保持附近代码的语言及风格：AppKit 界面通常为 `.m`，涉及 C++、原生 ABI 和补丁的实现通常为 `.mm`。工程启用 ARC、GNU C17 和 GNU C++20；不要无故引入新的语言或依赖管理体系。
- 工程使用 `PBXFileSystemSynchronizedRootGroup`。新增源码时先核实同步目录及 target 归属，不机械追加传统 Sources 列表。
- 菜单开关和插件显示版本可从 `MenuManager.h` 查起，默认值和应用行为还需核对对应模块。不要仅修改菜单显示而遗漏实际功能状态。
- `YMApplyFeatureSetting` 的契约要求主线程调用，成功后再保存菜单设置；区分成功、需重启与不可用，失败不能假装已启用。
- 原生对象应遵循既有构造、复制和析构约定。`YMMessageSnapshot` 包含宿主对象存储，不能用普通 `memcpy` 代替原生复制；异步任务须保持对象生命周期。
- 当前支持列表列出 `4.1.10.53 / 268853` 和 `4.1.11.23 / 269079`，README 明确不支持 Intel。以完整版本、Build、架构以及具体模块校验为准，不根据“微信 4.x”推断兼容。
- 扩展适配时核对模块使用的版本配置、镜像 UUID、指令字节、地址转换和 ABI。保留不匹配时跳过的保护，不能仅增加安装白名单或用 `--force` 证明适配成功。
- 不同 Build 的消息发送链路不应随意互相回退；尤其保留现有针对未知版本或 ABI 不匹配的拒绝路径。
- 修改支持范围时同步核对 `supported_versions.txt`、实际运行时配置和 README；明确区分已测试支持与待验证支持。

## 构建与验证

以下命令从仓库根目录执行。需要完整 Xcode 及 macOS SDK；工程当前 deployment target 为 macOS `26.2`，应读取实际配置，不为迁就本地环境擅自降低。

### 只编译，不安装

```bash
xcodebuild -project SovietExtension/SovietExtension.xcodeproj \
  -scheme SovietExtension -configuration Debug \
  -destination 'generic/platform=macOS' \
  -derivedDataPath /tmp/SovietExtension-DerivedData \
  ARCHS=arm64 CODE_SIGNING_ALLOWED=NO SOVEXT_SKIP_INSTALL=1 build
```

该命令用于后续源码验证，不代表已经在所有环境验证通过。Release 检查可替换 configuration，仍必须保留跳过安装设置。不要把 scheme 的 Run 当作无副作用检查：它指向 `/Applications/WeChat.app`。

### 最小静态检查

```bash
bash -n SovietExtension/Rely/install.sh
bash -n SovietExtension/Rely/uninstall.sh
git diff --check
git status --short
```

- 当前已跟踪文件中未发现自动化测试套件或测试 target；不能声称 `xcodebuild test` 已覆盖功能。
- `.gitignore` 包含 `Test/`、`/tests/`、`/work/`、`/frida/`。新增测试或调试材料前检查忽略规则，避免交付文件被悄然忽略；修改忽略规则同样需要批准。
- 文档修改核对路径、符号和命令；源码修改按影响范围进行编译及必要的人工回归。结果报告列明实际执行的检查、失败原因和未验证项。
- 经授权的宿主回归需记录完整微信版本、Build 和架构，检查启动、菜单、相关功能开关、重启后状态及关闭功能后的原生行为。涉及消息发送和群操作时使用明确许可的测试账号及会话。

## 安装、恢复与数据边界

- 安装脚本可能终止微信、申请管理员权限、修改可执行文件、移除隔离属性并重新签名。常规分析和编译不要执行它。
- 手动安装的版本白名单与运行时校验是不同保护层；构建阶段的 `--force` 会跳过安装版本限制，不能替代运行时验证。
- 恢复前核对目标应用、当前 Build、安装状态文件和对应备份。不要随意删除备份，或使用非当前版本备份恢复。
- `Rely/Plugin/` 是仓库分发产物；源码构建成功不表示其中的二进制已更新。只有明确的发布任务才更新它，并验证版本及产物一致性。
- 日志、消息内容和本地宿主数据可能包含私人信息；报告只保留必要证据并脱敏。

## 协作与交付

- 结论以当前源码、配置和可复现结果为准；区分观察结果、推断与未验证项。不把历史 README 示例当作当前环境实测。
- 不为纯文档工作启动微信或安装插件，不为了排查方便移除完整性与版本保护。
- 用户回复跟随当前消息语言；Git 提交信息默认英文，提交前检查完整消息，提交后用 `git log -1 --format=%B` 再次核对，除非用户明确要求其他语言。
- 提交前审查完整差异，仅包含任务相关文件。完成报告简述修改内容、验证结果和剩余限制。
- 本文件的命令不要求仓库依赖 RTK；若当前操作环境另有 RTK 包装规则，应遵循该环境规则执行。
