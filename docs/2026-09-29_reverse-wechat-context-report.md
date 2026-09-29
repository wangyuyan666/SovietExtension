# 微信所选消息上下文：原生查询链路调查记录

> 2026-09-29 · 静态分析阶段。**已定位原生查询及结果包装链路，尚未证明插件能够安全调用并取得所选消息前后文。本文不是可直接调用的 ABI 定义。**
>
> 后续需求可直接从第 5 节继续调查，无需重新搜索接口。不得将候选参数含义、函数名或地址直接作为生产适配依据。

## 1. 范围与样本

用户要求确认能否取得所选消息的上下文，并将已有成果保存以便复用。本次仅只读检查仓库和本机应用二进制：未启动、注入或终止微信，未执行安装、签名、宿主函数调用，未读取真实聊天记录或上传消息。未建立独立 case/scope 文件，本节记录调查边界。

| 项目 | 实际检查值 |
| --- | --- |
| 样本 | `/Applications/WeChat.app/Contents/Resources/wechat.dylib` |
| 完整版本 / Build | `4.1.11.23 / 269079`（Info.plist 的 WeChatBundleVersion / CFBundleVersion） |
| 分析架构 | arm64，64 位 Mach-O，符号已剥离 |
| arm64 LC_UUID | `580294A4-5AF5-310D-9A9A-C3639BEE0A28` |
| 整个通用二进制 SHA-256 | `05c1a88ba5c02ccf370bc01c0cc0ebc9ce4a727f09e29407c73e704f8f8b2df4` |
| arm64 slice 文件起点 / 长度 | `0x9df8000 / 0x93cccd0` |
| 仓库基准提交 | `93306661e3d136bbd5610a657b9fc35b87505177` |
| 使用工具 | radare2 6.1.8、rabin2、otool、Python 3、CodeGraph、文本检索 |

IDA MCP 工具未暴露，探测本地 13337 端口未连接成功；后续使用本机 radare2 只读分析。没有为分析安装工具或修改工具配置。

**地址规则：**下文代码地址为 arm64 slice 的静态虚拟地址，不是整个 fat 文件偏移，也不是 ASLR 后地址。rabin2 报告该 slice 基址为 0；已检查的代码及常量位置中 slice 文件偏移与虚拟地址一致。其他段不能无条件套用这一对应关系。运行时必须重新校验版本、架构、UUID、指令指纹及 slide，不得跨 Build 复用。

## 2. 现有插件入口与限制

下列路径均相对仓库根目录；行号为上述基准提交中的调查定位。

| 来源 | 已确认内容 |
| --- | --- |
| [MessageMenuPatch.mm](../SovietExtension/SovietExtension/MessageMenuPatch.mm):110–128 | 菜单消息对象为 `model + 0x120`；读取消息 `+0x90` 标识及 `+0x58` 会话；菜单条目不是聊天记录列表 |
| [MessageMenuPatch.h](../SovietExtension/SovietExtension/MessageMenuPatch.h) | `YMMessageSnapshot` 大小 `0x340`，使用原生复制和析构，不能普通 memcpy 复制宿主对象 |
| [RevokePatch.mm](../SovietExtension/SovietExtension/RevokePatch.mm):4217–4228 | `YMIsRetainedSelfMessage` 将 `+0x90` 读取为 uint64 serverID、`+0x74` 为 uint32 localID，读取 `+0x10` sender、`+0x58` session |
| [YMAIMessageAction.mm](../SovietExtension/SovietExtension/YMAIMessageAction.mm):15–37 | 从已持有的单条消息取正文、发送者；执行当前账号检查；向分析窗口传入单条正文 |
| [YMAIService.m](../SovietExtension/SovietExtension/YMAIService.m):80–89 | 固定指令限制为单条消息；请求只有 `selected_message` 和 `user_requirements`，没有历史消息字段 |
| [YMAIWindowController.m](../SovietExtension/SovietExtension/YMAIWindowController.m) | `presentText:session:sender:account:` 最后调用 `generate:`，打开分析窗口会进入提交流程，并非先编辑上下文再提交 |

选中消息定位信息已存在，不代表已经确定如何映射到原生附近查询参数。仓库未发现已完成适配的上下文读取封装；这不能推导为微信没有上下文接口。

## 3. Evidence：静态证据索引

函数名称来自程序内部日志常量，不是导出符号。以下每项均可用第 6 节命令复核。

| ID | 位置 | 观察事实 |
| --- | --- | --- |
| E-01 | 样本 Info.plist / LC_UUID / SHA-256 | 样本身份见第 1 节；arm64 UUID 与当前菜单适配代码目标一致 |
| E-02 | 第 2 节源码 | 选中消息入口提供会话和单条消息快照；当前 AI 请求没有上下文 |
| E-03 | `0x2868084` | 函数内构造日志名称 `GetNearbyMessages`；`0x28680e0` 取 `[x0 + 0xb78]`；`0x28680e8` 调用 `0x299ccb4` |
| E-04 | `0x286a0d8` | 函数内构造 `GetPagedMessages`；`0x286a210` 取 `[x24 + 0xb78]`，随后转交 x1–x4，`0x286a228` 调用 `0x2999cc4` |
| E-05 | `0x2999cc4` | 日志名称还原为 `CoGetPagedMessageListWithSortInterval`；x1 按 libc++ string 布局检查长度；检查 w3 非零；从 x2 指向对象读取 `+0` 的 32 位、`+8` 的 64 位及 `+0x10` 的 32 位字段 |
| E-06 | `0x299ccb4` | x1 按 string 布局检查长度；`0x299cd1c–0x299cd20` 检查 w5、w6 是否同时为零；后续分别处理这两个参数 |
| E-07 | `0x3671f4c` / `0x3671fb4` | 原生调用者取得管理对象，组装 x1–x7 参数，通过 x8 传递结果存储地址，然后调用 `0x2868084` |
| E-08 | `0x3672054–0x3672060` / `0x28a0b68` | 调用者将上述结果地址作为 x1、其自身 `+8` 地址作为 x0，调用日志名为 `BuildCompleteMessageWrapper` 的函数；这说明查询后仍有包装处理步骤 |
| E-09 | 导入 / 导出表 | 导入包含 `connect`、`fopen`、`fread`、`dlopen`、C++ string 操作和 shared_ptr 引用计数相关函数；导出检查显示 `_WeChatMain`、`_SetWeixinCallbackFunc`，未提供这些查询函数的公开签名 |

### 3.1 附近查询调用点的参数来源

在 `0x3671f4c` 函数中，x19 保存调用对象，`0x3671f98–0x3671fb4` 可直接观察到：

| 查询寄存器 | 调用点来源 | 业务含义的确认状态 |
| --- | --- | --- |
| x0 | 获取管理对象的链路结果 | 管理对象；内部所有权、账号作用域尚未完整确认 |
| x1 | `x19 + 8` | 下游按 string 读取；疑似会话，尚未追到构造来源 |
| w2 | `[x19 + 0x20]` | 32 位字段，不能直接认定为 localID |
| x3 | `[x19 + 0x28]` | 64 位字段，不能直接认定为 serverID 或时间 |
| w4 | `[x19 + 0x30]` | 32 位字段，含义未定 |
| w5 | `[x19 + 0x34]` | 数量相关候选，方向未定 |
| w6 | `[x19 + 0x38]` | 数量相关候选，方向未定 |
| x7 | `x19 + 0x40` | 配置对象候选；下游读取其 `+0x48` 的 32 位字段，不能传空指针代替 |
| x8 | `x29 - 0x38` | 间接返回存储地址，不是普通 x0 返回的消息指针 |

调用者此前依次调用 `0x428e5d4 → 0x13aae84 → 0x2151aec` 获取对象，并在查询后执行 shared_ptr 相关释放操作。**仅确认调用顺序及引用计数操作，不将其臆断为线程安全或账号隔离保证。**

存储层另有以下证据支持“两组数量使用相同定位参数”的推断：

- `0x299d7d0–0x299d7e8`：使用保存的 w5 减去已累计数量，填入一个请求对象；同时填入保存的 x3、w4。
- `0x299ec40–0x299ec58`：使用保存的 w6 减去另一累计数量，填入另一个请求对象；同样填入保存的 x3、w4。
- 这**尚不能确定**哪组是向前、哪组是向后，也不能确定边界是否包含锚点、是否跨相同时间戳消息或如何排序去重。

### 3.2 可复用地址表

| 静态地址 | 用途 |
| --- | --- |
| `0x2868084` | 带 `GetNearbyMessages` 日志名的管理层函数 |
| `0x299ccb4` | 附近查询存储层，参数及线程要求仍待还原 |
| `0x286a0d8` | 带 `GetPagedMessages` 日志名的管理层函数 |
| `0x2999cc4` | `CoGetPagedMessageListWithSortInterval` |
| `0x3671f4c` | 附近查询原生调用者，可继续追其对象构造和执行环境 |
| `0x3671fb4` | 调用附近查询的 BL 指令 |
| `0x3672060` | 将查询结果传给完整消息包装构建函数的 BL 指令 |
| `0x28a0b68` | `BuildCompleteMessageWrapper` |
| `0x366fc2c`、`0x367f728`、`0x2d20e5c` | 扫描到的分页查询直接 BL 调用点 |
| `0x29a319c` | 除管理层外，另一个调用 `0x299ccb4` 的直接 BL 点 |
| `0x78d2f30`、`0x78d2f40` | 附近 / 分页日志名所用常量；前者完整名字还需代码追加尾部 |

直接 BL 扫描不覆盖间接调用、虚表分发和尾调用，不能作为完整调用图。

## 4. Finding 与 Path

### F-01：存在原生查询路径，但安全接入仍属候选

- 类型：逆向可行性，非漏洞评级。
- 状态：candidate；静态链路存在的证据较强，运行时可用性未验证。
- 证据：E-03、E-04、E-05、E-06、E-07、E-08。
- 结论：不应因仓库没有封装就放弃自动上下文；优先复用原生查询与包装链路，而不是重新解析聊天数据库。
- 限制：还不能给出可直接编译调用的函数 typedef，也不能声称已获取上下文。

### P-01：后续接入的调用路径

1. 现有菜单取得选中消息和会话（E-02）。**从这里到查询锚点的映射尚未建立。**
2. 参考原生调用者 `0x3671f4c` 构造查询参数（E-07，F-01）。
3. `0x2868084 → 0x299ccb4` 执行附近查询（E-03、E-06，F-01）。
4. 结果经 `0x28a0b68` 进行完整消息包装处理（E-08，F-01）。
5. 提取拥有独立生命周期的上下文、供用户预览后提交 AI：**尚未实现，不能视为已观察到的宿主行为。**

## 5. 下次直接从这里继续

按以下顺序推进，不重复做全局字符串搜索：

1. **追 `0x3671f4c` 所接收对象的构造与调度。**确认 `+8/+0x20/+0x28/+0x30/+0x34/+0x38/+0x40` 的来源；可以从附近复制辅助函数 `0x3672380` 入手，但复制布局本身不等于字段语义。
2. **建立所选消息到查询锚点的映射。**区分消息 ID、排序值、时间戳及其他标志，不能把 x3 的 64 位宽度当作 serverID 的证明。
3. **核实查询结果与包装对象。**继续分析 `0x28a0b68` 的遍历、构造、复制、析构及错误路径；不要把查询集合元素强转为 `YMMessageSnapshot`，也不要省略包装步骤。
4. **核实线程和账号。**检查管理器获取链、原生任务调度线程、注销和切换账号的失效路径；不要因为 AI 菜单在主线程就直接同步调用存储层。
5. **准备有界运行验证方案，再取得明确授权。**使用许可的测试账号和会话，仅记录条数、顺序、匿名身份和定位匹配情况；不在日志打印真实消息正文。验证旧消息锚点、双向边界、群聊多发言人、空结果及切换账号。

可安全接入的最低标准：完整参数语义和 ABI、正确生命周期、明确线程契约、同账号同会话校验、版本及指令指纹门控、边界测试与有界读取全部成立。任何一项不成立应拒绝读取，而非猜测回退。

产品接入还需单独实施并批准：上下文预览删减、条数/总长度限制、移除窗口打开即提交、更新上传说明，以及将 AI 单条消息固定协议改为结合明确提供的上下文。此报告没有实施这些修改。

## 6. 只读复核命令与还原代码

从仓库根目录执行。RTK 是当前操作环境包装器，不是仓库依赖；其他环境可去掉 `rtk` 前缀。命令只读取应用文件，不连接微信进程，不读取用户消息数据库。

### 6.1 样本和关键指令

```bash
rtk plutil -p /Applications/WeChat.app/Contents/Info.plist
rtk shasum -a 256 /Applications/WeChat.app/Contents/Resources/wechat.dylib
rtk otool -l /Applications/WeChat.app/Contents/Resources/wechat.dylib
rtk rabin2 -I /Applications/WeChat.app/Contents/Resources/wechat.dylib
rtk rabin2 -i /Applications/WeChat.app/Contents/Resources/wechat.dylib
rtk rabin2 -E /Applications/WeChat.app/Contents/Resources/wechat.dylib
rtk r2 -q -e scr.color=0 -c 'pd 100 @ 0x2868084; pd 100 @ 0x286a0d8; pd 150 @ 0x299ccb4; pd 100 @ 0x2999cc4; q' /Applications/WeChat.app/Contents/Resources/wechat.dylib
rtk r2 -q -e scr.color=0 -c 'pd 100 @ 0x3671f4c; pd 65 @ 0x28a0b68; pd 40 @ 0x299d7c8; pd 40 @ 0x299ec40; q' /Applications/WeChat.app/Contents/Resources/wechat.dylib
```

r2 调查时提示未应用 relocations。这里检查的是静态指令和直接 BL，不据此推断已解析全部动态指针。执行前必须确认选中了 arm64 slice；不要在工具默认选择其他架构时使用这些地址。

### 6.2 还原日志名并定位直接调用

下列脚本是本次只读还原方法的归档版，先校验整个样本 SHA-256，再解析 fat 表选择 arm64。不依赖运行时解密或真实聊天数据；只输出内部函数名和代码位置。

```bash
rtk python3 - <<'PY'
import hashlib
import struct
from pathlib import Path

raw = Path('/Applications/WeChat.app/Contents/Resources/wechat.dylib').read_bytes()
expected = '05c1a88ba5c02ccf370bc01c0cc0ebc9ce4a727f09e29407c73e704f8f8b2df4'
assert hashlib.sha256(raw).hexdigest() == expected, '样本变化，停止复用偏移'
assert raw[:4] == bytes.fromhex('cafebabe'), '预期为已调查的 fat32 容器'
count = struct.unpack_from('>I', raw, 4)[0]
slices = [struct.unpack_from('>IIIII', raw, 8 + 20 * i) for i in range(count)]
arm = [entry for entry in slices if entry[0] == 0x100000c]
assert len(arm) == 1
_, _, offset, size, _ = arm[0]
b = raw[offset:offset + size]
print('arm64 slice:', hex(offset), hex(size))

def decode(base, key, data, length, adjustment):
    return bytes(((b[base + data + i] + adjustment) & 255)
                 ^ b[base + key + i % 16] for i in range(length))

print(decode(0x78e6a00, 0x29a9, 0x29b9, 0x26, 0))
print(decode(0x78d4690, 0x64e4, 0x64f4, 0x1c, -0x76))

# 本样本代码扫描范围；只识别直接 BL，输出需再用反汇编核对。
targets = {0x2868084, 0x286a0d8, 0x299ccb4}
for (pc, (insn,)) in enumerate(struct.iter_unpack('<I', b[:0x63f0000])):
    if insn & 0xfc000000 != 0x94000000:
        continue
    imm = insn & 0x3ffffff
    if imm & (1 << 25):
        imm -= 1 << 26
    target = pc * 4 + imm * 4
    if target in targets:
        print(hex(pc * 4), '->', hex(target))
PY
```

预期还原名称为 `CoGetPagedMessageListWithSortInterval` 和 `BuildCompleteMessageWrapper`（输出含结尾 `\x00`）。调用点应包括第 3 节列出的地址。

### 6.3 已排除的低效定位方式

- `rabin2 -z` 的普通字符串扫描未直接找到上述关键名称；部分名称位于 `__TEXT.__const`，由 SIMD 常量加载、拼接或逐字节变换构造，不能据此判断接口不存在。
- 扫描 ADRP + ADD 未命中附近/分页名称；实际引用使用 ADRP + `ldr q0`：`0x286822c/0x2868230` 对应 `0x78d2f30`，`0x286a12c/0x286a130` 对应 `0x78d2f40`。
- `GetNearbyMessages` 在 `0x2868230` 加载前 16 字节，随后追加字符 `s` 和终止符；不能只把常量片段当完整函数名。
- 宽范围 `/r` 搜索曾给出 `(nofunc) 0x78c10cc [DATA] ldr s25, 0x78d2f30`。它位于数据区，**未作为有效代码调用或引用证据**。

## 7. 验证与调查时间线

- 2026-09-29：检查现有 AI 单条消息入口和请求；确认缺少上下文字段。
- 同日：核对本机版本与 arm64 UUID，定位附近和分页查询的日志名称及实际代码引用。
- 同日：追到存储层、参数读取、原生调用者和完整消息包装步骤；还原两个内部函数名。
- 同日：将成果归档为本文件，并记录样本 SHA-256，供后续匹配样本后复用。

已经执行的验证是源码检查、只读样本解析和反汇编，不是宿主功能回归。未验证实际上下文条数、消息顺序、参数方向、线程安全及账号切换行为。文档工作不需要构建、安装或启动微信。
