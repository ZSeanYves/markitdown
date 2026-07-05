# Benchmark 体系架构书

> 路径：`docs/architecture/benchmark-architecture.md`
>
> 本文是
> [`docs/architecture/mb-markitdown-architecture.md`](./mb-markitdown-architecture.md)
> 与
> [`docs/architecture/format-mode-and-execution-profile-architecture.md`](./format-mode-and-execution-profile-architecture.md)
> 在 benchmark、性能回归、对标复现与可信度门禁上的专项补充文档。

建议阅读顺序：

1. 先读主架构书，理解统一产品主链 `detect -> probe -> planner -> parser -> pipeline -> renderer`。
2. 再读 mode / profile 架构书，理解 route、profile、provenance 的稳定语义。
3. 再读本文，理解 benchmark 如何测量真实产品路径，并把结果组织成可长期维护的正式体系。
4. 最后读 [`docs/capabilities-and-limitations.md`](../capabilities-and-limitations.md)，理解正式支持矩阵与对外承诺边界。

---

## 0. 文档定位

本文是规范性架构文档，不是阶段性迁移记录、历史跑分摘要或一次性性能说明。

它回答的是以下问题：

1. 本项目的正式 benchmark 到底在测什么，而不在测什么。
2. benchmark 的事实源应如何分层，哪些文件负责 corpus、policy、execution 与 trust。
3. benchmark 如何证明自己测到的是“真实产品路径”，而不是被 benchmark 特化过的旁路。
4. benchmark 结果中 `trust_status`、`gate_status`、`route_coverage_status` 分别代表什么。
5. 结果协议、报告协议、扩展方式应如何设计，才能支持长期维护与迭代。

因此本文的使用原则是：

1. benchmark 是产品验证系统的一部分，不是独立于产品架构的跑分脚本。
2. benchmark 的第一原则是“诚实测量”，不是“尽量把数字做大”。
3. 若实现与本文冲突，应优先视为待收敛技术债，而不是反向修改本文去迁就阶段性实现。
4. 操作文档负责说明“如何复现”；本文负责规定“什么才算正式 benchmark”。
5. 仓库路径、命令行示例、构建产物位置、运行样例等信息属于实现与操作层，不属于本文的核心论证。

### 0.1 产品定位

本项目的 benchmark 体系服务于以下长期目标：

1. 为正式产品路径提供可复现的性能观测。
2. 为 route selection、parser mode、render path 提供可审计的 provenance 证明。
3. 为内部优化、外部对标、格式专项诊断提供彼此分离但共享底座的运行框架。
4. 为 release 质量判断提供 fail-closed 的 trust gate，而不是只输出一个“看起来很快”的数字。

因此，正式 benchmark 体系既不是：

1. 任意局部热点的 micro benchmark 集合。
2. 只看 wall time、完全不关心输出真相的脚本。
3. 为了追求 benchmark 数字而专门引入的产品旁路。

### 0.2 术语约定

为避免文档与实现长期漂移，本文固定使用以下术语：

1. `bench root`：
   benchmark 语料根目录。
2. `row`：
   corpus manifest 中的一条正式 benchmark 输入声明。
3. `scenario`：
   一组具有共同目标的测量任务定义，例如 `product`、`compare`、`diagnostic`、`doctor`。
4. `preset`：
   对多个 scenario 与默认运行参数的命名组合。
5. `tool`：
   被测对象或对标对象，例如 `moonbit-cli`、`moonbit-engine`、`markitdown`。
6. `sample`：
   单次 warmup 之外的实际测量结果，一般对应一次 `repeat`。
7. `case`：
   对同一 `scenario x tool x row` 的多个 sample 聚合后的结果。
8. `run`：
   一次完整 benchmark 执行，拥有唯一 `run_id` 和固定结果目录。
9. `trust`：
   MoonBit 正式产品路径的可信度判断，关注 provenance completeness、route fidelity 与 fail-closed 约束。
10. `gate`：
   一轮 run 是否形成完整可比集，关注是否所有应比较的 case 都成功完成。

### 0.3 架构与实现的关系

本文定义 benchmark 体系的规范性目标、边界与契约。

因此：

1. 本文是实现收敛的标准，不是对现有实现的复述。
2. runner、policy 实例、manifest 实例、操作文档、测试与脚本都属于从属产物。
3. 当实现与本文冲突时，默认动作应是修实现、修操作文档或显式承认技术债。
4. 只有在产品目标、正式承诺或长期演进方向发生明确变化时，才应修订本文。
5. 禁止因为阶段性实现便利而反向收缩架构抽象。

---

## 1. 设计目标

benchmark 体系必须同时满足以下目标：

1. 测量真实产品路径：
   正式 benchmark 只能测正式产品入口、正式 benchmark orchestrator 与真实产品 route。
2. 保持结果可解释：
   每个正式结果都必须能解释“测了谁、测了什么、为何可信、为何不可信”。
3. 保持外部语料独立：
   benchmark 输入应独立于主仓源码，避免把正式语料退化为一组随手生成的仓内样例。
4. 分离不同视图：
   内部性能口径、外部对标口径、专项诊断口径、契约检查口径必须共享底座但保持语义分离。
5. 允许按 policy 演进：
   扩展格式、场景、对标工具时，应优先修改 manifest、policy、tool registry，而不是复制一条新的 benchmark 主链。
6. 保持 fail-closed：
   对 provenance 缺失、route 不匹配、语义密度异常等情况必须直接降为不可信，而不是弱化成 warning。

### 1.1 最先应该记住的五条规则

如果只记住本文五件事，应当是：

1. 正式 benchmark 对外只能有一个主入口。
2. 正式 benchmark 对外必须只有一个主入口，并且只认 release binary，不认构建工具转调。
3. benchmark 测的是产品路径及其 provenance，不只是 wall time。
4. `trust_status` 与 `gate_status` 是两回事：前者判断 MoonBit 路径是否可信，后者判断这一轮比较是否完整。
5. benchmark 的扩展应进入统一 manifest / policy / orchestrator / result protocol，而不是再长出新的专项脚本主路径。

---

## 2. 不变约束

本文与主架构书共同满足以下不变约束：

1. 正式 benchmark 不得依赖通用构建工具提供的 benchmark surface。
2. 正式 benchmark 不得依赖通用构建工具提供的 run delegation surface。
3. 正式 benchmark orchestrator 必须以 release binary 形态存在。
4. 正式产品 CLI 被测对象必须以 release binary 形态存在。
5. 若 benchmark 调度链经过构建工具转调，则该 run 直接视为 binary contract failure。
6. 正式对外或对内口径场景只能测量真实产品默认路径，不能引入 benchmark-only parser、benchmark-only renderer 或隐藏 fast path。
7. MoonBit 正式 case 若缺少完整 provenance，不是 warning，而是 trust failure。
8. 若 `route_fidelity_status != matched`，不是 warning，而是 trust failure。
9. 若存在显式 `expected_route` 且 `expected_route != actual_route`，不是 warning，而是 trust failure。
10. 对结构化大样本的低密度输出保护必须 fail closed，不能因为“命令成功退出”就视为可信。
11. 契约检查视图不是正式性能结论视图。

同时，以下路径不再属于正式 benchmark 主路径：

1. micro 路径
2. pipeline 专项路径
3. product 专项脚本路径

它们即使保留为局部实验，也不得再代表正式 benchmark 口径。

---

## 3. 顶层架构

### 3.1 分层模型

benchmark 体系由四层稳定边界组成：

```text
external corpus
  -> manifest selection
  -> policy expansion
  -> runner orchestration
  -> product execution + provenance
  -> sample / case / summary / report
```

更具体地说：

1. corpus 层：
   负责 benchmark 输入身份，不负责调度和结果解释。
2. policy 层：
   负责 scenario、preset、tool matrix、默认参数、row route expectation。
3. runner 层：
   负责命令解析、契约检查、调度、测量、聚合与报告。
4. product contract 层：
   负责把真实产品 route 决策以稳定 provenance 形式暴露给 benchmark。

### 3.2 Benchmark 侧三类事实源

benchmark 侧只有三类正式事实源：

1. corpus manifest
   只负责 corpus identity。
2. benchmark policy
   负责 scenario policy、preset policy、tool matrix、row-level route expectation。
3. benchmark orchestrator
   负责 execution orchestration、measurement protocol、result protocol、trust aggregation。

这三者的职责不能互相越权：

1. manifest 不定义 benchmark 逻辑。
2. policy 不直接执行命令。
3. runner 不私自发明新的 corpus 身份或绕过产品 provenance。

### 3.3 产品侧契约

benchmark 不是单独推断 route 的系统。

它依赖产品侧提供稳定契约，至少包括：

1. `plan_input(source, options) -> RoutePlan`
2. `convert_input_with_provenance(source, options) -> ConvertExecution`
3. CLI 的 `--provenance-out` 输出能力

也就是说，benchmark 只能消费产品给出的 route 真相，不能自己维护第二套 route 判定器。

---

## 4. 稳定数据模型

### 4.1 Bench Root 与 Corpus Identity

正式 benchmark 必须拥有一个稳定的 `bench root` 概念。

它应满足以下要求：

1. 默认位置稳定且可文档化。
2. override 机制必须显式，而不是隐式搜索多个不透明来源。
3. benchmark 结果中应能解释本次 run 实际使用了哪个 corpus root。

这种设计的目的有三点：

1. 让正式语料独立于主仓实现代码。
2. 让 benchmark 结果与语料版本、payload 身份可分离管理。
3. 避免仓内样例与正式 benchmark 语料混用。

### 4.2 Row

正式 benchmark 必须拥有一个 corpus manifest 作为 row catalog。

一条正式 row 至少应包含以下字段：

1. `bench_id`
2. `format`
3. `size_class`
4. `rel_path`
5. `source_kind`
6. `source_ref`
7. `bytes`
8. `sha256`
9. `enabled_tier`
10. `bench_layers`
11. `tags`
12. `review_status`
13. `notes`

其中：

1. `bench_id` 定义 row 的稳定身份。
2. `format` 与 `size_class` 支撑场景选择和统计聚合。
3. `rel_path`、`bytes`、`sha256` 支撑 payload 定位与完整性判断。
4. `enabled_tier` 控制 `smoke / regular / release / stress` 可见性。
5. `bench_layers`、`tags`、`review_status`、`notes` 提供治理信息，而不直接改变执行主链。

manifest selection 必须 fail closed 过滤以下情况：

1. payload 缺失
2. `enabled_tier=disabled`
3. `source_kind` 或 `review_status` 标记为缺失候选
4. 非法 tier
5. 零字节输入
6. 空 `rel_path`

### 4.3 Scenario 与 Preset

benchmark 用 `scenario` 表达测量意图，用 `preset` 表达常用组合。

正式 benchmark 至少应区分以下 scenario kind：

1. `product`
2. `compare`
3. `diagnostic`
4. `doctor`

正式 benchmark 至少应允许以 preset 组织常用视图，例如：

1. `official-internal`
2. `official-compare`
3. `doctor`

它们的职责边界应保持稳定：

1. `product`：
   面向 MoonBit 产品路径自身的正式性能与可信度观察。
2. `compare`：
   面向与外部工具的正式对标。
3. `diagnostic`：
   面向重点格式或重点路线的专项诊断。
4. `doctor`：
   面向 release binary contract 检查。

`preset` 的职责是：

1. 展开多个 `scenario_id`
2. 提供 tier / repeat / warmup / timeout 默认值
3. 固定一个常用正式视图

它不负责：

1. 直接定义 corpus
2. 直接决定 route 真相
3. 绕过 runner 去执行命令

### 4.4 Tool

正式 benchmark 至少应支持三类 tool role：

1. 产品 CLI 入口
2. in-process engine 参考视图
3. 外部 baseline adapter

它们共享统一 registry，但不共享完全相同的 measurement mode：

1. 产品 CLI：
   正式产品二进制入口，按 `process-cli` 测量。
2. in-process engine：
   正式 orchestrator 内的 in-process 引擎视图，按 `inprocess-engine` 测量。
3. 外部 baseline：
   外部对标对象，按 `process-cli` 测量。

benchmark 必须显式记录 tool availability，不允许隐式跳过正式 compare 依赖。
例如：正式 compare 视图下若外部 baseline adapter 不可用，应直接 fail closed。

### 4.5 Sample、Case、Run

稳定抽象如下：

1. `sample`：
   一次实际测量记录，包含 status、wall time、output bytes、route provenance 等字段。
2. `case`：
   对同一 `scenario x tool x bench_id` 的 sample 聚合结果，包含 median、coverage、trust、reason。
3. `run`：
   一次完整 benchmark 执行，至少产出 sample log、case log、summary record 与 report projection。

这种三层协议的意义是：

1. `sample` 保留原始测量痕迹。
2. `case` 提供稳定聚合语义。
3. `run summary` 提供对外阅读与自动化消费入口。

---

## 5. 执行主链

### 5.1 正式执行流程

正式 run 的主链固定为：

```text
args
  -> load policy
  -> verify binary contract
  -> apply preset defaults
  -> resolve scenarios
  -> select rows from manifest
  -> expand row x tool
  -> warmup + repeat measurement
  -> collect provenance and artifacts
  -> aggregate cases
  -> write summary and report
```

各步骤的职责边界如下：

1. 参数解析：
   只负责把 CLI 输入整理成 `RunOptions`，不负责测量逻辑。
2. policy 解析：
   只负责默认值与 scenario 展开，不负责执行。
3. binary contract：
   只负责验证 release runner / release CLI / no moon delegation。
4. row selection：
   只负责从 manifest 中筛选正式输入。
5. execution：
   只负责运行工具、收集原始测量和 side artifacts。
6. aggregation：
   只负责把 sample 折叠成 case，再折叠成 run summary。
7. report generation：
   只负责把 summary 投影成 Markdown，不重新解释 route 真相。

### 5.2 Measurement Policy

measurement policy 至少应包含以下维度：

1. `warmup_count`
2. `repeat_count`
3. `execution_order`

其中：

1. warmup 用于降低首次启动噪声。
2. repeat 用于形成中位数聚合。
3. interleaved execution order 用于减少长批次场景下单一 tool 或单一格式连续运行带来的系统性偏置。

这些参数的具体默认值属于 policy 层，而不是本文的核心约束。

契约检查视图可以采用与正式性能视图不同的 warmup / repeat 策略，但其解释仍然是 contract verification，而不是 performance benchmarking。

### 5.3 Process CLI 与 In-Process Engine

`process-cli` 路径的职责是测量真实用户入口：

1. runner 为 tool 生成命令。
2. native measure 层执行命令并记录 wall time、exit code、timeout、peak RSS。
3. 若 tool 是 `moonbit-cli`，runner 还会注入 `--provenance-out`，把 route provenance 作为正式 sidecar 产物落盘。

`inprocess-engine` 路径的职责是提供内部参考视图：

1. runner 直接调用 `convert_input_with_provenance`。
2. 测量 wall time。
3. 记录同样的 route provenance。
4. 不承诺与 `process-cli` 完全相同的资源统计维度，例如峰值 RSS。

因此：

1. `moonbit-cli` 是正式外部入口视图。
2. `moonbit-engine` 是正式内部引擎视图。
3. 两者都属于正式 benchmark，但解释口径不能混淆。

---

## 6. Truth Model 与 Trust Gate

### 6.1 Benchmark 测量的不是“命令是否成功”，而是“产品路径是否被证明”

正式 benchmark 至少同时关心四类事实：

1. 命令是否成功完成。
2. 是否走了期望的产品路径。
3. provenance 是否足够完整，可以解释该路径。
4. 输出是否触发了已知的 fail-closed 保护，例如结构化大样本低密度退化。

因此一个 case 即使：

1. 退出码为 `0`
2. 有 wall time
3. 生成了输出文件

也仍然可能因为 trust gate 失败而不被视为可信。

### 6.2 Provenance Completeness Contract

MoonBit 正式 benchmark 至少要求以下字段存在：

1. `route_plan.selected_route`
2. `route_plan.route_reason`
3. `route_plan.route_probe_summary`
4. `effective_parser_mode`
5. `parse_result_kind`
6. `pipeline_output_kind`
7. `render_input_kind`
8. `route_fidelity_status`

这些字段缺一不可。

原因是：

1. `selected_route` 说明最终走了哪条主路径。
2. `route_reason` 与 `route_probe_summary` 说明为什么选这条路。
3. `effective_parser_mode`、`parse_result_kind`、`pipeline_output_kind`、`render_input_kind` 说明路径中间形态是否与架构预期一致。
4. `route_fidelity_status` 说明执行结果是否真正符合 route plan。

### 6.3 Route Expectation 与 Coverage

benchmark 不强制每个正式 row 都有固定 route expectation。

正式 route expectation 至少应支持以下三类语义：

1. `product_default`：
   表示该场景只要求“忠实于当前产品默认选路”，不强绑某个固定 route 名称。
2. `not_applicable`：
   表示该场景不参与 route coverage 判断。
3. 显式 route expectation：
   通过 scenario 或 row override 为某些样本绑定稳定期望路线。

对应地：

1. `route_coverage_status=covered`
   表示已满足当前 expectation。
2. `route_coverage_status=mismatch`
   表示 expectation 与实际 route 不一致。
3. `route_coverage_status=not_applicable`
   表示该 case 不参加此项判断。

### 6.4 Route Fidelity

对 MoonBit 正式 case，`route_fidelity_status` 必须为 `matched`。

这条规则的意义在于：

1. benchmark 不只看 planner 说自己想走哪条路。
2. benchmark 还要验证实际 parse / pipeline / render 结果是否与该计划匹配。

也就是说：

```text
planned route
!=
executed route shape
```

时，benchmark 必须判为不可信。

### 6.5 Semantic Density Guard

benchmark 还需要对“命令成功但产出明显异常稀薄”的情况做 fail-closed 保护。

正式 density guard 必须首先覆盖那些容易出现“命令成功但语义塌缩”的结构化文本族。

它至少应关注：

1. `large` / `huge` 样本
2. 极低 `output_bytes`
3. 极低 `output_density`

其目标不是精细评价质量，而是避免如下情况被误记为正式成功：

1. 复杂结构样本只吐出极少文本
2. 命令 technically 成功，但语义上已经接近空结果

### 6.6 Trust 与 Gate 的区别

`trust_status` 与 `gate_status` 必须明确区分：

1. `trust_status`：
   关注 MoonBit case 是否可信，主要由 provenance completeness、route fidelity、route coverage、density guard 决定。
2. `gate_status`：
   关注这一轮 run 是否形成完整可比集，主要由 selected rows 与 comparable rows 的关系决定。

这意味着：

1. `trust_status=trusted`
   并不自动等于 compare 完整。
2. `gate_status=partial`
   也不必然说明 MoonBit 自己不可信。
3. `markitdown` 不参与 MoonBit provenance trust 判定，但会影响 compare gate 是否完整。

---

## 7. 结果协议

### 7.1 固定结果目录

每次 run 必须拥有一个隔离的 run root。

该 run root 在逻辑上至少应分为以下命名空间：

1. `results`
2. `reports`
3. `outputs`

其中：

1. `results/`
   存放机器可读的正式结果。
2. `reports/`
   存放面向人阅读的报告。
3. `outputs/`
   存放每个 tool 的原始输出、provenance sidecar、stdout、stderr 等执行产物。

### 7.2 三层正式结果

正式结果协议固定为三层逻辑产物：

1. sample log
2. case log
3. summary record

同时提供一个人读 report projection。

这四类文件的职责分别是：

1. sample log：
   原始 sample 级测量记录。
2. case log：
   聚合后的 case 级真相记录。
3. summary record：
   机器可读的 run 级正式结论。
4. report projection：
   对 summary 的稳定 Markdown 投影。

### 7.3 Summary Contract

summary record 至少应显式记录：

1. `schema_version`
2. `run_id`
3. `preset`
4. `scenario_ids`
5. `binary_only_contract`
6. `trust_status`
7. `gate_summary`
8. `route_coverage_summary`
9. `truth_summary`
10. `diff_summary`
11. `scenarios`
12. `tools`
13. `by_format`

其中：

1. `binary_only_contract` 回答“这轮 run 是否满足正式二进制约束”。
2. `gate_summary` 回答“这轮 run 形成了多完整的可比集”。
3. `route_coverage_summary` 回答“有多少 case 覆盖到了期望路线”。
4. `truth_summary` 回答“失败主要因为什么失败”。
5. `by_format` 回答“按格式看，可比覆盖与 speedup 情况如何”。

### 7.4 Report Regeneration

正式 benchmark 必须支持从历史 sample 结果重生成 case 与 report。

这意味着：

1. sample log 不是临时缓存，而是正式原始记录。
2. `report` 不应依赖一次性终端输出。
3. 若 schema 发生 breaking change，应显式 bump `schema_version`，而不是悄悄改变旧结果解释方式。

---

## 8. 官方视图分工

### 8.1 内部正式视图

内部正式视图只服务于 MoonBit 内部正式判断，重点包括：

1. `moonbit-cli` 与 `moonbit-engine` 的正式性能观察
2. route coverage 与 fidelity 是否成立
3. 各格式是否保持稳定完成
4. 内部回归是否破坏了正式产品路径

它不负责：

1. 对外公开对标结论
2. 代替诊断视图解释所有异常细节

### 8.2 外部对标视图

外部对标视图只服务于外部对标复现。

它的核心约束是：

1. 使用正式语料
2. 使用统一 scenario / row 选择
3. 使用正式 compare tool set
4. 使用与正式 MoonBit case 同样的 trust gate

其 speedup 语义应保持稳定：

1. `cli_geomean_speedup = markitdown 时间 / moonbit-cli 时间`
2. `engine_geomean_speedup = markitdown 时间 / moonbit-engine 时间`

数值越大表示 MoonBit 越快。

### 8.3 专项诊断视图

专项诊断视图用于格式专项诊断。

它的作用是：

1. 放大重点格式观测面
2. 更快定位特定 route、format、payload family 的问题
3. 在不污染官方 KPI 的前提下提供深入诊断入口

它不应被滥用为：

1. 替代正式 compare 的跑分视图
2. 用小范围样本代表全局性能结论

### 8.4 契约体检视图

契约体检视图只回答一个问题：

- 当前环境是否满足正式 benchmark 的 release binary contract

因此它是正式 benchmark 的前置体检，而不是正式 benchmark 结果本身。

---

## 9. 演进与扩展规则

### 9.1 新格式接入

当新格式进入正式 benchmark 体系时，应优先沿以下路径扩展：

1. 先让产品主链具备稳定 route 与 provenance 契约。
2. 再把正式输入加入外部 corpus 与 corpus manifest。
3. 再通过 policy layer 决定是否进入内部正式视图、外部对标视图或新增专项诊断视图。
4. 只有在 route expectation 具有稳定意义时，才增加 row override。
5. 最后补充一致性测试、操作文档与相关架构文档。

不允许的做法是：

1. 先写一个新 benchmark 脚本路径
2. 再让文档去解释为什么它“暂时不走产品主链”

### 9.2 新工具接入

新增 tool 必须经过统一 tool registry，而不是在 runner 内写死特殊分支。

它至少应明确：

1. tool name
2. availability rule
3. command builder
4. measurement mode
5. 该 tool 是否参与正式对标还是只参与诊断

### 9.3 结果协议演进

结果协议应优先 additive evolution：

1. 尽量新增字段，而不是修改旧字段语义。
2. 需要 breaking change 时，显式 bump `schema_version`。
3. 任何新的 trust gate，都应能在 summary record 中被解释，而不是只体现在终端文案里。

### 9.4 文档与实现同步要求

下列变化发生时，应同步更新本文或其相邻文档：

1. 正式 preset 语义变化
2. trust gate 规则变化
3. provenance completeness contract 变化
4. result protocol 变化
5. 外部 corpus 发现规则变化

---

## 10. 明确的非目标

以下内容不属于正式 benchmark 体系目标：

1. 把 benchmark 退化为纯 micro hotspot 排行榜。
2. 用 synthetic case 单独代表正式产品性能结论。
3. 为 benchmark 数字引入产品外不可见的专用 fast path。
4. 混淆“路径证明成立”和“对标可比集完整”。
5. 依赖历史 run id、截图或手工整理数字作为正式事实源。

换句话说，本项目的 benchmark 体系不追求“最快得到一个好看的数字”，而追求：

1. 对产品路径诚实
2. 对结果解释诚实
3. 对失败暴露诚实

---

## 11. 收敛原则

benchmark 架构的收敛原则必须写明如下：

1. 架构先于实现：
   正式 benchmark 的唯一判断标准是本文定义的边界与契约。
2. 实现服从架构：
   runner、policy、manifest、报告模板、操作命令与测试都必须向本文收敛。
3. 偏移优先修实现：
   当发现实现、脚本或操作文档与本文冲突时，优先修它们，而不是削弱本文。
4. 文档修订必须有理由：
   只有在产品目标、正式承诺或长期演进方向改变时，才应修本文。
5. 禁止阶段性反向绑架：
   任何“当前实现还没有”“当前脚本更方便”“当前对标工具不好接”之类的理由，都不能单独构成修改架构边界的依据。
