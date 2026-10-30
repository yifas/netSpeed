# NetSpeed — macOS 菜单栏实时下行速率显示

本机自用的 macOS 菜单栏小工具：实时显示当前**下行速率**（以及可选的上行速率），点击菜单可查看各接口明细、切换统计范围与刷新间隔。

- 无 Dock 图标（`LSUIElement=1`），只驻留在菜单栏
- 数据来源：内核 `getifaddrs` / `if_data` 的每接口累计收发字节计数（不需要 root、不装任何驱动）
- 纯 Swift + AppKit（`NSStatusItem`），零第三方依赖

## 效果图

![NetSpeed 菜单栏效果](docs/screenshot.png)

菜单栏标签定宽显示：`↓` 为下行速率、`↑` 为上行速率，单位自动在 `K` / `M` / `G` 之间切换。

---

## 一、GitHub 既有项目检索结论

> 说明：本机网络无法直连 GitHub（`api.github.com` / `github.com` 被阻断，DNS 解析到污染 IP `198.20.0.26`）。
> 因此检索是通过 **Bing 索引（cn.bing.com RSS）** 定位仓库、再用 **gitclone.com 代理** 克隆验证的方式完成的；
> 下列带 ✅ 的仓库已通过 `git ls-remote` 实测存在。

| 项目 | 说明 | 结论 |
|---|---|---|
| [yujitach/MenuMeters](https://github.com/yujitach/MenuMeters) ✅(搜索验证) | 经典 macOS 菜单栏系统监控（含网速插件），Objective-C，年代久远 | 功能重合，但非“纯下行速率”工具，界面陈旧 |
| [exelban/stats](https://github.com/exelban/stats) ✅(搜索验证) | 开源菜单栏系统监视器（CPU/GPU/内存/网络），SwiftUI | 功能重合度最高，界面现代，但体量大、不是专门做网速 |
| [matryer/bitbar](https://github.com/matryer/bitbar) ✅ | 菜单栏插件平台，可用脚本输出任意指标 | 需要额外写插件脚本，非开箱即用 |
| [swiftbar/SwiftBar](https://github.com/swiftbar/SwiftBar) ✅ | BitBar 的活跃分支，菜单栏插件平台 | 同上 |
| [vergoh/vnstat](https://github.com/vergoh/vnstat) ✅(搜索验证) | 命令行流量统计（按接口/时段） | 无 GUI，需终端查看 |
| [zhongyang219/TrafficMonitor](https://github.com/zhongyang219/TrafficMonitor) ✅(搜索验证) | Windows 版网速/任务栏流量监控 | 平台不符（Windows） |
| [apple/sample-food-truck](https://github.com/apple/sample-food-truck) | Apple 官方 `MenuBarExtra` 示例 | 仅代码示例 |
| iStat Menus / CleanMyMac 等商业软件 | 闭源、功能大而全 | 商业授权 |

**结论**：生态里有“通用监控器”和“插件平台”，但**没有一款轻量、专注、只做菜单栏实时下行速率**的开源小工具。
考虑到本机自用、无需 GUI 界面和一堆统计图表的诉求，本项目按“最小可用 + 干净”的方向自行实现，代码量约 300 行。

## 二、方案设计

### 1. 采集原理

macOS 内核在每个网络接口的 `if_data` 结构中维护累计计数：

- `ifi_ibytes`：累计接收字节
- `ifi_obytes`：累计发送字节

通过 `getifaddrs()` 遍历接口，取 `ifa_data` 中 `if_data` 的两个字段，相邻两次采样做差：

```
速率(字节/秒) = (本次累计接收 - 上次累计接收) / 采样间隔
```

优点：无轮询开销（不产生额外网络流量）、无需管理员权限、不依赖任何驱动。

### 2. 接口选择（避免重复计数）

本机若同时存在 Wi-Fi(`en0`)、VPN 隧道(`utun*`)、回环(`lo0`)、桥接(`bridge*`)，同一份流量会被**重复统计**。
菜单里提供三种统计范围：

- **自动**（默认）：排除 `lo/awdl/llw/utun/ppp/ipsec/bridge/vlan/gif/stf`，只统计物理接口
- **全部接口**：除 `lo0` 外所有 UP 接口（会重复计数，便于对照排查）
- **主接口**：固定 `en0/en1/...` 中第一个存在的

### 3. 界面

菜单栏标签（**定宽**，等宽字体，速率位数变化时菜单栏宽度不跳动）：

```
↓ 36.2M ↑  1.4M
```

> 实际效果见上方 [效果图](#效果图)。

实现要点（这是“不跳动”的关键）：

- 标签用 **AppKit `NSStatusItem`**，并显式设置 `statusItem.length = 116`（固定宽度）
- 标签内容用**固定尺寸的 NSImage**（116×18 pt）承载，图片宽度与文字内容完全无关
- 图片内用等宽字体 `NSFont.monospacedSystemFont` 绘制，字符位置恒定
- 数值用 `%5.1f` + 单位填充到 6 字符（`  3.0K` / ` 36.2M` / `999.9M`），单位字母始终在同一列

> 为什么不用 SwiftUI 的 `MenuBarExtra`：实测 `MenuBarExtra` 会忽略 label 上的 `.font(design: .monospaced)`
> 与 `.frame(width:)`，按**比例字体**测量文字宽度，数字位数一变整个文字块宽度就变，
> 把左边的图标推着来回跳（实测标签左边界漂移 17px）。改用 `NSStatusItem` + 固定长度 + 固定尺寸图片后彻底消除。

点击展开菜单（NSMenu）：

- 下载 / 上传当前速率（`1.2 MB/s`）
- **接口明细**子菜单：逐接口的上下行速率
- 统计范围、刷新间隔（1/2/5 秒）、是否显示上行
- 登录时启动（`SMAppService`）
- 退出

设置通过 `UserDefaults` 持久化。

### 4. 目录结构

```
Sources/NetSpeed/
├── main.swift              # 入口（AppKit，--report 命令行自检）
├── AppDelegate.swift       # NSStatusItem + NSMenu 界面与菜单
├── StatusLabelRenderer.swift# 固定尺寸标签图片渲染（等宽字体）
├── SpeedMonitor.swift      # 定时采样、差分计算、接口筛选
├── NetworkReader.swift     # getifaddrs 读取内核计数
├── ByteFormatter.swift     # 字节数格式化（定宽/普通两种）
├── HeadlessReport.swift    # 命令行自检模式 --report
└── LoginItem.swift         # 登录自启
Scripts/build-app.sh        # 打包成 NetSpeed.app（ad-hoc 签名）
```

## 三、构建与使用

```bash
# 构建并生成 dist/NetSpeed.app
./Scripts/build-app.sh

# 运行
open dist/NetSpeed.app

# 安装到「应用程序」
cp -R dist/NetSpeed.app /Applications/
```

命令行自检（验证采集是否正常）：

```bash
.build/release/NetSpeed --report 5
```

实测校准：从 USTC 镜像下载时 `curl` 平均 39 MB/s，NetSpeed 逐秒采样为 24.8 / 50.8 / 45.5 / 40.6 MB/s（1 秒窗口内的瞬时值），与真实链路一致。

## 四、已知限制与修复记录

- 速率是**当前采样窗口的瞬时值**，不是滑动平均；如需平滑可把间隔调大或自行加指数平滑
- macOS 13+（本机为 macOS 15.8.2）

### 已修复

1. **菜单栏宽度抖动（图标左右跳）**：
   - 第一版用 SwiftUI `MenuBarExtra`，实测它忽略 label 上的等宽字体与固定宽度，按比例字体测量 →
     数字位数一变（`3.0K` → `36.2M`）文字块宽度就变，把旁边的图标推着移动（实测漂移 17px）
   - 修复：改用 AppKit `NSStatusItem` + **固定 `length`** + **固定尺寸 NSImage** 承载标签，
     标签宽度与内容彻底解耦；图片内用等宽字体绘制，单位字母固定在某一列
   - 验证：连续 12 次采样（速率在 `3.0K` 与 `17.0K`/`320.4K` 之间跳变），
     标签左边界恒定在 px 1602-1616，右邻图标恒定在 px 1870-1905，**零漂移**
2. **偶发崩溃**（`EXC_BREAKPOINT`）：接口计数器回绕/重置时 `UInt64` 减法回绕成巨大值，
   `Int64(bytesPerSecond)` 触发 Swift 运行时 trap → 改为饱和减法（回绕按 0 处理）+
   速率上限钳制（1 TB/s）+ 格式化函数内部再做一次防御

