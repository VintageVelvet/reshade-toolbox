# 使用说明

下载、安装和基本操作见 [README.md](README.md)。

## 配置文件与路径

`OptiScaler.ini` 是 OptiScaler 的配置文件，FF14 和 DR 不会自带它。先按 [OptiScaler 安装说明](https://github.com/optiscaler/OptiScaler/wiki/Manual-Installation)安装，游戏要求见 [FF14 专页](https://github.com/optiscaler/OptiScaler/wiki/Final-Fantasy-XIV-Dawntrail)。已有配置继续使用；缺失时，从 [对应版本安装包](https://github.com/optiscaler/OptiScaler/releases)取得 INI。本模块读取、备份和修改已有文件，不自动安装、下载或生成 INI。

正常安装布局中，配置文件在正在运行的 `ffxiv_dx11.exe` 旁，通常是游戏安装目录下的 `game`。可在任务管理器“详细信息”中右键该进程，选择“打开文件所在的位置”。

```text
<游戏安装目录>\game\OptiScaler.ini
```

“自动定位”根据当前游戏进程的可执行文件目录填写预期路径，保存后立即读取；不会扫描磁盘。首次启用时，已保存路径为空会自动填写，已有路径会保留。

使用自定义配置位置时，在“配置文件”输入框中填写 OptiScaler 实际读取的 INI 完整路径，结束编辑后保存并读取。“重新读取”重读当前路径；每秒更新也只读取指定文件，不会重新定位。出现“读取失败”时检查文件是否存在及路径是否正确，文件缺失也会导致写入失败。

## 判断读取与应用结果

模块每秒读取磁盘配置，外部修改会更新“配置目标”，不会覆盖下拉框中尚未写入的选择。下拉选择需点击操作按钮后应用。

“配置目标”中的配置模型和有效倍率来自最近一次 INI 读取，例如 PRESET K（11）和 2×。倍率缺失或无效会显示“未设置或无效”；读取失败显示原因；尚未取得结果时显示“正在读取……”。需要立即确认当前文件时点击“重新读取”。

“配置已保存”表示上一次写入完成。输出分辨率与 DLSS 文件版本有各自的数据来源，单独显示这两项不能证明 INI 已读取成功；配置读取或保存成功也不能证明游戏已经应用。

“配置渲染分辨率”按输出尺寸除以配置倍率计算，是目标尺寸。实际输入尺寸需在角色加载后按 Insert 打开 OptiScaler 查看底部，例如：

- DLAA：`2560×1440 → 2560×1440`。
- Performance：`1280×720 → 2560×1440`。

“DLSS”显示配置目录中 `nvngx_dlss.dll` 的文件版本，不证明驱动覆盖后的实际模型。

## 模型选择

游戏默认关闭 OptiScaler 模型覆盖，将模型选择交还 FF14；它不替换 DLSS DLL，缩放挡位仍单独保存，当前需要重启游戏应用。

K 可作为 DLAA / Quality / Balanced 的常用起点，RTX 20/30 系列可优先考虑。M 面向 Performance，L 面向 4K Ultra Performance，L/M 的计算开销较高。K 要求文件版本至少 310.2.0，L/M 至少 310.5.0；版本未知时只提供游戏默认。

已有配置中的模型和比例会如实显示。如果模型不在可选范围内，写入前需重新选择可用模型。

## 快捷命令

| 命令 | 操作 |
|---|---|
| `/pdr dlss` | 打开界面 |
| `/pdr dlss quality` 或 `/pdr dlss set quality` | 选择挡位、写入并刷新 |
| `/pdr dlss select quality` | 只选择挡位 |
| `/pdr dlss preset default` 或 `preset 0` | 保存游戏默认模型选择，需重启应用 |
| `/pdr dlss preset K` | 选择模型、写入并刷新；也接受 L/M 或 11/12/13 |
| `/pdr dlss apply` | 写入配置 |
| `/pdr dlss refresh` | 对已保存配置请求桥接更新并刷新窗口 |
| `/pdr optidlss` | 命令别名 |

挡位命令名：`dlaa`、`uq`、`quality`、`balanced`、`performance`、`up`。

## 常见问题与回退

成功结果为 `OptiScaler：ok applied；窗口刷新已完成`。若显示“结果未确认”，不能据此认定热切换成功；已写入的配置仍保留，可重启游戏应用。游戏默认也需要重启，K/L/M 热切换需要支持桥接的 OptiScaler。

窗口最小化时先还原再刷新。高级刷新设置通常保持默认参数即可。

切换时的长时间停顿可能与 ReShade 重载效果有关。“Load only enabled effects”（只加载已启用效果）可减少未启用效果的加载，但在 ReShade 6.6.1 中空预设仍可能加载全部效果，不能保证消除停顿。机制与条件见 [技术说明](TECHNICAL.md#reshade-与尺寸重建)。

INI 原文件备份放在配置旁，名称为 `OptiScaler.ini.drbackup-*`；回退配置时，关闭游戏后恢复对应备份。回退模块版本时，先在 DR 中停用当前版本，再添加对应版本 DLL。

自行构建时，`out/` 是模块源码目录中的默认产出目录，包含 DLL 和 `build-info.json`，可通过 `-OutputDirectory` 改变。下载发布 DLL 时无需创建该目录，INI 路径也不指向这里。
