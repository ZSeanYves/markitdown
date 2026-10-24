# Native v13 本地候选验收

2026-10-24。本轮组合为 `cache-atomic-epub-v13`，以 v12 候选
`f8b8f9ba9a74649f4a15cb1192ce5763ed3f4d5c` 为基底。本文记录本地冻结；
远程 CI、固定提交安装及合并状态由关联 PR 和工作流记录。
完整升级仍以[原计划](architecture/native-performance-plan.md)为准，P2–P6 尚未全部完成。

## 本轮实现

- PDF Font/CMap 局部结果缓存支持真实 SelectedLoaded 身份，保留当前解码参数、
  文档所有权和首个硬错误检查；确定的局部结果可以复用，父级查询与合并仍执行。
  首次发布时完整计量两个缓存各24B的包装字段，修复每个缓存漏记16B的问题。
- Atomic writer 显式管理文件/临时名字所有权，重复 abort/finalizer 不会删除后来
  创建的同名文件。写入与 JSONL spool 共享原 Temporary 账本，使用单个可增长 lease；
  编码前计量工作区，确认 rename 后退还临时 credit，无法确认的 close 保留 credit。
- File/Atomic 补充末尾 LF 前先扣输出预算，成功写入后只确认一次；正文及正文大小
  的含义不变。stdout 最终 ACK 和资产 URL/path 改写差值仍待补齐。
- JSONL None pull 使用完整行的空白事实，修复长空格前缀后的 scalar/非 BMP 内容
  被静默丢弃。四次原“成功但空输出”对照现在明确 RecordLimit/exit4 且无产物，
  其余十二次 CLI 正控正文逐字节保持。
- EPUB 强制 container.xml 改为共享 XML cursor，正确处理属性引号、实体单次解码、
  命名空间和层级；发布 rootfile 前验证完整 UTF8/EOF/ZIP CRC。普通语法错误只进行
  同一 archive/account 的有界完整性复核，硬错误直接终止。
- `partial_v13` 两分支均导出十项计数：None15字段、有限 Temporary16字段；记录真实
  Temporary peak/current。工具按实际 cap、完整选项、所有权和输出目的地分别分组，
  保留 v1–v12 协议，未知上下文不产可用 maxima。

## 已执行检查

| 检查 | 实际结果 |
| --- | --- |
| 有序恢复 | 52项 before/proposed SHA guard，43个最终路径各写一次 |
| Native | info/fmt/check/release build通过；FD leak、+73/deny-warn，debug1590/1590、release1590/1590 |
| 全量语料 | 标准、预算侧车、安装后二进制各935/935 |
| 实际安装及库消费 | local-install-v14全部16阶段成功；全新公共库 consumer 检查和执行通过 |
| 安装/源码输出 | 3329 equal，0 repair，0 unexpected |
| 对 v12 差分 | 原始3328 equal/1 unexpected保留；W4唯一差异精确复核，523个资产 SHA相同，28项篡改负控全部拒绝 |
| None/有限上限 CLI | 45次调用成功验收，含30成功、9硬拒绝、6独立源修复对照；18项 parity负控拒绝 |
| 验收工具 | 两工具 Wasm/Native共8门通过；18项旧协议字节守恒证明 |
| 新预算数据 | 378 benchmark+935 quality=1313项，零失败/不可用；9个缺失候选继续未验 |
| 独立复核 | 13130个原始值、142上下文组、3100个动态 maxima及见证全核；1246项源码与完整 tar、两个物理副本精确绑定 |

W4 Cache1081192→1133096：Font50888+CMap984+两个实际首次发布包装字段32。
Output admitted/confirmed25347→25348，仅补实际文件末尾 LF；新增 None Temporary0/0。
Read340631、Inflate555703、Working1264907、ParseWork335654和其余稳定字段保持。
该审查没有忽略其它预算叶、数字词法、正文或资产差异。

## 冻结身份

| 产物 | SHA256 |
| --- | --- |
| 源码 tar，1246文件 | `89cceb10f9d59de660732e67ef3ffcd5cebcfcc5dcd40738370a3d8f6243d342` |
| Native exe，8635072B | `fdec6f53737675329b69691403a2b6b7f916491bfbb92366c8d9d6785d63c7dd` |
| v13 budget合同 | `f560f34686bd2f268238658a4582d9c61a086fb5f050bb08c0e678e5774d87e2` |
| 独立预算复核结果 | `86bead13c1a5c348c661ef3a2f208c613ccfd1b776e9b00027210b53d01638eb` |
| 标准输出精确复核 | `f008f9923597c5a66bc94b99de76121a052cf9ae2d37384719a7525805829654` |

证据在本机 `.audit/2026-10-23-native-upgrade/`，包括 `cache-atomic-epub-v13-*`、
`v13-components-restored/`、`v13-frozen-tools/`、`budget-v13-review-preparation/`
及 `local-install-v14*`。发布包只含 shipping source；实验、语料及调试产物不进入交付。
冻结后清理了已完成的主仓构建缓存，源码 tar/exe 前后 SHA 相同；大型 cases 的归档
恢复方式记录在对应 `CASES-ARCHIVE.md`，审查表和原始摘要保留。

## 仍未验收

完整预算/default/缓存淘汰、IR/RAG及其它元数据覆盖、stdout与资产改写输出闭环，
剩余 Office/ODF/EPUB 迁移，PDF逐页生命周期、六元仿射/页面框/advance及阅读顺序
仍需后续实施。文档内缓存和局部计数下降不等于完整 P4 或正式性能收益。

尚未执行两个独立3预热+30交错性能窗口，也未完成两平台各60分钟混合负载及1/2/4进程
持续性验收。PDF延迟降低50%、RSS降低30%目标没有验收结论。未正式发布、打版本标签，
也没有 P6 精确发布版本安装与新消费者验收。本轮按用户指示在候选 CI通过、合并和
关闭分支后收尾；这些未完成项继续保留。
