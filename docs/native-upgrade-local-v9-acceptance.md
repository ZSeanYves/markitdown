# 本地 mime-cmap-v9 验收记录

记录日期：2026-10-24。本记录绑定一份已冻结源码与两个已冻结Native产物；它是本地
阶段证据，完整P2–P6退出、正式延迟/RSS门槛和发布均未完成。范围仍以
[原升级计划](architecture/native-performance-plan.md)为准，原计划及旧失败证据保留。

|冻结对象|SHA-256与大小|
|---|---|
|源码 `mime-cmap-v9-source.tar`|`b2ad6acb8cd27588b48c52510376d27adfdc502662b2ba44583932e0e36dc21e`|
|源码构建 `mime-cmap-v9-step.exe`|`45fb7433de513e44e896992d0a217d95079a6c63b359355f24eb5017a0612bc3`；8122608B|
|实际安装 `local-install-v10/install/bin/markitdown`|`4617414a436ccdd7e492181b7dd51d497415cc8bcbe0cb5bf04d48145e3551a5`；8122832B|
|partial_v9计量合同|`9784f6fac5bbec71d40375be610b6e81e62bb8591c754b156a543fb26673930f`|

证据均位于本机忽略目录 `.audit/2026-10-23-native-upgrade/`，尚非公开长期证据包。
下列重复执行是同一套合同在不同产物/表面的检查，不累加为独立测试数量。

|门槛|实际结果|原始证据（相对上述目录）|
|---|---|---|
|Native严格检查、接口、格式、release构建|通过；显式+73/deny-warn，FD leak检查开启|`mime-cmap-v9-{check,info,fmt,build}.log`|
|完整Native单测|debug/release各1316/1316|`mime-cmap-v9-{debug-tests,release-tests}.log`|
|标准语料及独立预算侧车|各935/935，manifest errors=0|`mime-cmap-v9-{regression,quality-profile}/summary.tsv`|
|对v8完整输出比较|原始3328equal/1unexpected；唯一W4 provenance只改schema/coverage，全部八counter与其它稳定字段相同；七项负控拒绝、0未解释|`mime-cmap-v9-comparison/`、`mime-cmap-v9-output-review.json`|
|实际本地安装及全新公共/lib consumer|通过；consumer独立check/run，安装全部16阶段exit0|`local-install-v10/{summary.tsv,phases.tsv,commands.json,fingerprints.tsv}`|
|安装后二进制语料/输出比较|935/935；3329equal、0unexpected|`local-install-v10-regression/`、`local-install-v10-comparison/`|
|新预算采样|126accepted×3view=378 benchmark，加935quality，共1313有效、0失败；九项missing仍未验|`mime-cmap-v9-budget-profile/summary.tsv`|
|1313数据独立复核|通过；10504值、2488组最大值及见证全部吻合，1177源码文件与tar及双副本精确绑定|`mime-cmap-v9-review-preparation/actual-review-v1/review-results.json`|
|新候选远程CI与固定Git RC|**待执行**；旧d1平台结论不继承|待新候选推送后分别执行并记录run与安装SHA|

本轮新增MIME raw-byte半开范围与原depth8/parts1024的typed硬错误，以及同document的
Ranged local CMap Result复用。MIME最终owned body、附件/inspect等仍有明确未迁移范围。
真实五PDF的Read/Inflate/Working没有测量收益，部分Cache峰值增加；构造例操作减少不作为
真实延迟或RSS收益。partial_v9只新增CMap postparse的Native64选中字段/容量/String payload
覆盖，其余未测维度仍未测；13字段、8字符串counter、原数值默认值不变。此处采样是
`measurement_not_performance`，不用于冻结新默认限额或宣称正式P5通过。

v10的版本日志于11:01:23记录moon `0.1.20261021` / moonc `v0.10.17+093cb8f9c`，
安装与新consumer均于11:02:56前结束；当前全局SDK文件在11:17:07–08被替换。原记录支持
此次安装先于替换完成，未见中途混用，但没有每阶段compiler SHA。11:19复核器在新版
compiler的新增Warning96处停止；随后改用隔离固定093cb8f9c工具链，Native负控自测与
完整独立复核均通过，checker源未改。旧sandbox锁、误用新compiler和隔离registry未初始化
的三次失败日志保留；不能将新版诊断伪装为旧工具链产品失败。详见
`local-install-v10-toolchain-window-review.md`；外部libtool的无symbols告警继续保留。

独立复核结果JSON的SHA为
`13efb0e8cc1947be7bff14253fcd5a6070d4ae893c73a02bf0f900bdc6d5576d`；
checker源`c3a603f30717fd5b94089d038d3aed5216f1d37c61b016b01cdfc5a48da4af18`，
冻exe`cb135a811bf61c5b1b02d3c576342bb98c0281189229cba2e1056c051d5c7671`，
配置`23b2333d02a4337933ea16f87eadc6adc99f86d3979146eeb45ecca8ad4bb04a`。
实际tar payload为26453001B；只读捕获以已验证的29399040B容器长度为上限，无文件解包。

远程旧基础提交 `d1a7198896417a2ae5f439432d2e805facdef174` 的CI39964545691和固定Git
RC39964818181已在Linux/macOS通过，覆盖旧1138测试和安装935语料。它们不覆盖本v9；
跨平台原始44项差异及精确路径审查也不改称全部字节相同。新remote必须绑定新完整SHA，
安装来源显式选`git`、suite选`all`，同时核对workflow自身checkout与安装目标SHA。

已完成debug/release测试缓存与v10的1388个生成中间文件已清理，三个保留exe路径的SHA
前后相同。旧七轮27769文件已有逐文件SHA验证的无损归档：原19.53GiB，gzip本体约950MiB，
含清单的目录约958MiB，按各`CASES-ARCHIVE.md`恢复。源码、exe、日志、摘要、原失败保留；
本次v9另归档3969文件，fresh解包逐项长度/SHA、打包前后原件及gzip完整性全通过，
原3033596KiB变为147656KiB gzip，archive SHA为
`eaa860a74ea2384ca0d21e51bc8a3e19739258af2a8e6e6beaf7e0a52703aff8`；
原stdout、摘要、profile TSV及独立review保留，按`mime-cmap-v9-budget-profile/CASES-ARCHIVE.md`
还原。这是旧七轮之外的新一次归档。详见`disk-cleanup-20261023.md`和
`local-install-v10-cache-{retained-before,retained-after}.sha256`。

后续须完成远程两平台新CI及固定Git安装，并记录各自产物指纹；不得用旧冻结通过替代新
门槛。没有tag、registry精确版本发布或完整升级完成结论。
