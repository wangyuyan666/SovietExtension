<p align="center">
  <img src="./3.1.png" width="900" alt="SovietExtension Banner" />
</p>

<h1 align="center">SovietExtension 苏维埃助手</h1>

<p align="center">
  For 开源共产主义，For 理想主义。<br/>
  免费的，抽象的，令人愉快的 Mac 微信插件。
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS-lightgrey.svg" />
  <img src="https://img.shields.io/badge/Apple%20Silicon-M%20Chip-brightgreen.svg" />
  <img src="https://img.shields.io/badge/WeChat-4.0%2B-07C160.svg" />
  <a href="LICENSE">
    <img src="https://img.shields.io/github/license/fstudio/clangbuilder.svg" />
  </a>
  <a href="https://996.icu">
    <img src="https://img.shields.io/badge/link-996.icu-red.svg" />
  </a>
</p>

---

## Effect / 效果展示
> 自定义**殺馬特**效果速度、大小、强度，殺馬特or高级感全凭各位自己手艺，我更喜欢殺馬特而已。

> 🔞→嗳丄了祢℡ωǒ…吥徻↘後悔∵╭→很嗳﹎∩ 答应 ↘永逺┈⊕┈与∩ì.在∟┅ ↑起❤️
<p align="center">
  <img src="./colorful1.gif" width="1000" alt="SovietExtension Effect 1" />
</p>

<p align="center">
  <img src="./1.8.png" width="1000" alt="SovietExtension Effect 1" />
</p>

<p align="center">
  <img src="./1.9.png" width="1000" alt="SovietExtension Effect 2" />
</p>

<p align="center">
  <img src="./2.2.png" width="1000" alt="SovietExtension Effect 3" />
</p>

<p align="center">
  <img src="./4.1.png" width="1000" alt="SovietExtension Effect 2" />
</p>

<p align="center">
  <img src="https://star-history.dera.page/svg?repos=MustangYM/SovietExtension&type=Date" width="600" alt="SovietExtension Effect 3" />
</p>

---

## Supported Version / 支持版本

> **睁大眼睛看：目前只支持下表列出的 Apple Silicon / M 芯片版本。**
> 本人没有 Intel 机器，无法开发和测试 Intel 版本，所以 Intel 版目前无效。
> 微信 4.x QT 化之后逆向起来比较麻烦，其他版本随缘适配。
> 代码已完全开源，可自行查看，爱你。

请注意：[微信官网](https://mac.weixin.qq.com/) 显示的大版本号可能一致，但实际小版本和 Build 号可能不同。
使用前请务必核对完整版本号和 Build 号。

| 微信版本      | Build 号 | Apple Silicon / M 芯片 | Intel | 下载地址                                                                        | 说明                       |
| --------- | ------: | :------------------: | :---: | --------------------------------------------------------------------------- | ------------------------ |
| 4.1.11.23 |  269079 |         ✅ 支持         | ❌ 不支持 | [Github 归档](https://github.com/zsbai/wechat-versions/releases/tag/4.1.11.23)           | [1.1.2](https://github.com/MustangYM/SovietExtension/releases/tag/1.1.2) 已测试 |
| 4.1.10.53 |  268853 |         ✅ 支持         | ❌ 不支持 | [微信官网](https://weixin.qq.com/updates?platform=mac&version=4.1.10)           | 截止 2026-06-19，我在官网下载到的版本 |

> 不在表格中的版本暂不保证可用。
> 即使大版本看起来一样，只要 Build 号不同，也可能无法使用。

[wechat-versions历史版本下载](https://github.com/zsbai/wechat-versions/releases)
---

## Install / 安装

### 1. 先打开一次微信

如果是刚安装的微信，请先手动打开一次微信，然后再安装插件。

否则安装完成后，可能会提示：

```text
“xxx” 已损坏，无法打开。
```

### 2. 执行安装脚本

进入 `Rely` 文件夹，执行 `install.sh`：

```bash
cd SovietExtension/Rely
sh install.sh
```

或者直接执行完整路径：

```bash
sh /Users/mustangym/SovietExtension/SovietExtension/Rely/install.sh
```

安装后打开微信，如出现权限提示，请按引导完成授权。

安装过程示例：

```text
mustangym@macdeMacBook-Pro Rely % sh /Users/mustangym/SovietExtension/SovietExtension/Rely/install.sh

==============================
 Install SovietExtension
==============================

APP_PATH=/Applications/WeChat.app
PLUGIN_SRC_PATH=/Users/mustangym/SovietExtension/SovietExtension/Rely/Plugin/SovietExtension.framework
FRAMEWORK_DST_PATH=/Applications/WeChat.app/Contents/MacOS/SovietExtension.framework
INSERT_DYLIB_PATH=/Users/mustangym/SovietExtension/SovietExtension/Rely/insert_dylib
SUPPORTED_FILE=/Users/mustangym/SovietExtension/SovietExtension/Rely/supported_versions.txt
LOAD_DYLIB_PATH=@executable_path/SovietExtension.framework/SovietExtension

👉 [INFO] Detected WeChat version / 检测到微信版本:
    CFBundleShortVersionString: 4.1.9
    CFBundleVersion:            268602

✅ [OK] Version supported / 版本检查通过
    Supported Display Version: 4.1.9.58
    Matched Rule:              4.1.9.58|4.1.9|268602|Tested on Mac WeChat 4.1.9.58

...省略一万句...

👉 [INFO] Verify code signature / 检查签名...
⚠️  [WARN] Code signature verification failed, but app may still run for debugging / 签名验证未完全通过，但调试运行不一定受影响

==============================
✅ SovietExtension installed successfully
✅ SovietExtension 安装完成
==============================

Run WeChat and watch log / 启动微信并查看日志：
  rm -f /tmp/YMWeChatAntiRevokePatch.log
  open -a WeChat
  tail -f /tmp/YMWeChatAntiRevokePatch.log

Uninstall / 卸载：
  /Users/mustangym/SovietExtension/SovietExtension/Rely/uninstall.sh
```

---

## AI Analysis / AI 分析使用说明

AI 分析可对主动选中的一条普通文本消息生成简短分析和回复建议。建议仅供参考，**不会自动发送消息**；需要自行核对、复制并粘贴到目标会话。

> 当前 AI 消息右键入口适配 Apple Silicon 微信 **4.1.11.23 / Build 269079**，并受宿主镜像与指令校验保护。上方插件支持表不代表每个版本都支持 AI 分析；不要据此推断 4.1.10.53 或其他 Build 可用。
> 请使用包含 AI 功能的插件构建。源码中已有功能，不代表旧版安装包或仓库预编译 framework 已包含该功能。

### 1. 配置 AI 接口

在微信顶部菜单栏选择 **「苏维埃助手」 > 「AI 设置…」**，填写接口协议、Base URL、模型 ID 和 API Key，然后点击「保存」。分析窗口中也可打开「AI 设置…」。

支持以下接口协议：

* **OpenAI Responses**：目标服务必须支持 Responses API，插件会在 Base URL 后追加 `/responses`。
* **OpenAI 兼容（Chat Completions）**：适用于提供兼容接口的服务，插件会追加 `/chat/completions`；兼容名称不代表所有服务或模型都能使用。
* **DeepSeek**：固定使用 `https://api.deepseek.com`，请求地址为 `https://api.deepseek.com/chat/completions`，并在请求中关闭思考。

填写时注意：

* **Base URL** 必须是 HTTPS API 根地址，并包含服务所需的版本路径。例如服务要求 `/v1` 时填写 `https://HOST/v1`，不要填写完整的 `/responses` 或 `/chat/completions` 地址，也不要附带账号密码、查询参数或片段。`HOST` 是占位符，请替换成实际服务域名。
* **模型 ID** 需填写目标服务中当前账号可用、支持 JSON 输出的文本模型 ID，不是模型显示名称。插件不提供统一的默认模型，也不自动查询模型列表。
* **API Key** 需使用对应服务的 API 凭据。先确认地址，再填写密钥；编辑 Base URL 会清空尚未保存的密钥输入。
* 设置窗口会显示最终请求地址，请核对协议、域名和路径后再保存。保存设置不会发起分析请求。

API Key 保存在 macOS 钥匙串中，按**接口协议和 Base URL**隔离。密钥栏留空保存时，只保留当前协议与地址已有的密钥，不会沿用其他地址的密钥；新地址需填写对应密钥。可通过「删除当前地址密钥…」移除该地址的凭据。微信更新或重签名后，钥匙串可能要求重新授权。

### 2. 分析消息与复制回复

1. 在聊天中右键点击一条**普通文本消息**，选择「AI 分析」。窗口会显示本次选中的正文、所选话术和上传目标，并开始分析流程。
2. 首次使用，或重新保存接口设置后，会弹出上传确认。核对目标地址，确认愿意提交正文、话术和 API 凭据后，点击「同意并分析」；选择「取消」则不上传。
3. 已同意当前配置后，后续主动点击「AI 分析」或「重新分析」会直接提交内容，不会每次都弹窗。
4. 分析完成后，查看简短结论、信息缺口和回复建议。默认要求模型生成 3 条建议；也可接受符合格式的 2 条建议。
5. 点击某条建议旁的「复制」，确认目标会话后自行粘贴、修改并发送。插件不会替你发送。

通过「本次话术」可切换回复风格；切换后点击「重新分析」才会生成新建议。修改接口设置或保存话术后，当前结果会清空，也需要点击「重新分析」。

请求期间可点击「取消」，关闭分析窗口也会取消等待并清除窗口内容。**取消或关闭窗口不能撤回已经上传的内容。** 当前账号变化或无法确认时，插件会清除正文和结果，需要重新右键选择消息。

### 3. 话术管理

在「AI 设置…」中点击「话术管理…」，可编辑公共提示词、场景话术并设置默认话术。内置 5 种场景：

* **狗头军师｜普通聊天**：自然接话，推进日常聊天。
* **狗头军师·会撩｜暧昧 / 调侃**：适用于已有熟悉度、暧昧或调侃氛围的聊天。
* **狗头军师·抽离｜对方冷淡**：简短、体面地回应，避免追问或施压。
* **夸夸｜照片 / 成果 / 分享**：根据已提供的文字回应分享内容；不会上传或识别照片。
* **高情商话术｜工作 / 正事**：用于安排、协调、请求和工作沟通。

公共提示词应用于全部场景，每次请求只附带公共提示词和本次所选场景话术。每段提示词须为 1～12000 字符，不能全为空白。

切换编辑对象会保留尚未保存的草稿；点击「保存话术」后，下次分析生效。点击「恢复当前默认」只恢复正在编辑的那一段，仍需保存；取消或关闭窗口会放弃未保存修改。自定义话术保存在本地偏好设置中。

话术仅用于调整内容与语气，不能修改固定的 JSON 输出协议、仅使用已提供文本及不自动发送等约束。

### 4. 范围与隐私

* 当前只分析选中的**单条普通文本消息**，不会自动读取前后聊天记录、遍历会话或补充聊天上下文。
* 暂不分析图片、语音、视频、文件或引用消息。消息正文最多 12000 字符，过长时拒绝请求，不会自动截断上传；窗口中的原文只读。
* 提交内容包括选中正文、公共提示词、所选场景话术和固定输出约束；API Key 用于请求鉴权。插件不额外上传会话或账号标识，但**正文或自定义话术本身仍可能包含姓名、账号、工作内容等私人信息**。
* 服务端的数据保留、处理方式和调用费用以目标服务为准。仅向可信地址发送凭据和聊天内容，并确保有权分享相关信息；不要把使用此功能视为本地离线分析。
* AI 可能误解语气、遗漏信息或生成不合适的承诺。发送前请核对事实、对象和表达。复制后的内容进入系统剪贴板，可能被其他应用读取。

### 5. 常见问题

* **找不到「AI 分析」**：检查插件构建是否包含 AI 功能，以及微信是否为 4.1.11.23 / Build 269079、Apple Silicon 版本。宿主校验不匹配时会跳过菜单补丁，不要通过修改版本白名单绕过保护。
* **提示不支持消息或无法安全读取**：重新选择普通文本消息；空消息、过长消息、非文本消息或账号无法确认时不会上传。
* **提示尚未保存 API Key**：为当前接口协议和 Base URL 填写密钥；更换地址后不会自动继承旧地址的密钥。
* **钥匙串访问失败**：检查系统授权；微信更新或重签名后可能需要重新授权。
* **接口请求失败**：核对最终请求地址、协议、模型 ID、密钥、账号额度及网络连接，并参考窗口中的错误提示。
* **提示模型返回不完整、拒绝回答或格式不符**：重试，或更换支持 JSON 输出且兼容所选协议的文本模型。不要仅因服务宣称「OpenAI 兼容」就认定其支持所有请求字段。

---

## Troubleshooting / 常见问题

### 1. 提示 `Operation not permitted`

如果安装时报错：

```text
cp: xxxxx: Operation not permitted
```

请到：

```text
系统设置 → 隐私与安全性
```

给你当前运行脚本的“终端工具”开启以下权限：

| 权限                          | 说明         |
| --------------------------- | ---------- |
| 完整磁盘访问权限 / Full Disk Access | 允许脚本修改应用目录 |
| 文件与文件夹 / Files and Folders  | 允许访问相关文件   |

常见终端工具包括：

* Terminal / 终端
* iTerm2
* VSCode
* Cursor
* Warp

你用哪个工具执行脚本，就给哪个工具开权限。

### 2. 如果反复弹窗提示[”微信“想访问其他App的数据]
```text
在系统设置中打开微信”完全磁盘访问“，如果微信已经在里面，则删除后重新添加。
```

---

### 3. 提示版本不支持

请确认你的微信版本和 Build 号是否在支持表格中。

查看方式：

```bash
defaults read /Applications/WeChat.app/Contents/Info.plist CFBundleShortVersionString
defaults read /Applications/WeChat.app/Contents/Info.plist CFBundleVersion
```

只有表格中明确列出的版本才保证可用。

---

### 4. 安装后微信打不开

可以先执行卸载脚本恢复：

```bash
sh /Users/mustangym/SovietExtension/SovietExtension/Rely/uninstall.sh
```

如果仍然打不开，可以删除微信后重新安装官方版本。

---

## Uninstall / 卸载

进入 `Rely` 文件夹，执行：

```bash
sh uninstall.sh
```

或者直接执行完整路径：

```bash
sh /Users/mustangym/SovietExtension/SovietExtension/Rely/uninstall.sh
```

---

## Notes / 说明

* 本项目仅用于学习、研究与个人折腾。
* 代码完全开源，可自行查看实现。
* 不接受除 Bug 以外的任何 Issue。
* 不接受任何形式的捐赠与收费。
* 其他版本适配随缘，别催，催就是你对。

---

## Thanks / 致谢

感谢湖畔大学全体同学。

**瑞思拜。**

MustangYM.

---

## License / 开源协议

<a href="LICENSE">
  <img src="https://img.shields.io/github/license/fstudio/clangbuilder.svg" />
</a>

<a href="https://996.icu">
  <img src="https://img.shields.io/badge/link-996.icu-red.svg" />
</a>
