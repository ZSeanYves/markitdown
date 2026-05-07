# Technical Whitepaper

## Executive Summary

This whitepaper consolidates architecture, validation, release workflow, and risk evidence for a MoonBit-native document conversion pipeline. It is intentionally structured as a long-form delivery artifact rather than a feature-isolated sample.

## 1. 研究内容

### 1.1 技术路线

本项目旨在通过模块化设计实现文档格式转换的核心功能，优先完成基础架构搭建与关键模块开发。首先定义统一的中间表示（IR）结构，作为不同文档格式转换的桥梁，确保数据解析与生成的一致性。

## Architecture Overview

![image](assets/image01.png)

Figure 1. Conversion pipeline overview and native validation entrypoint.

在IR模块稳定后，分阶段开展docx和pdf格式的解析工作，docx模块重点处理document.xml中的文本与格式信息，pdf模块则计划采用OCR技术结合布局分析实现内容提取。

### Core Module Status

| 模块 | 状态 | 说明 |
| --- | --- | --- |
| core/ir | 完成 | 定义文档中间表示（IR）的数据结构与转换规则，支持文本、图片、表格等元素的标准化存储 |
| docx | 进行中 | 解析docx文件的document.xml，提取段落、标题、列表等结构化内容，已完成文本提取，正在开发格式映射功能 |
| pdf | TODO | 下一阶段重点任务，计划集成OCR引擎与PDF布局分析算法，实现扫描版与文本版PDF的内容识别与结构化转换 |
| markdown | 规划中 | 基于IR生成符合CommonMark标准的Markdown文本，支持代码块、表格、图片引用等格式转换 |

## Delivery Plan

- bullet A
  1. ordered A.1
  1. ordered A.2
- bullet B

The staged delivery plan emphasizes incremental hardening, checked-in evidence, and explicit policy boundaries for unsupported or intentionally degraded cases.

## Risk Register

| Action | Notes |
| --- | --- |
| [OpenAI Docs](https://openai.com/docs) | Line one |
| Checklist | bullet one<br>bullet two |

## Operator Notes

External references remain embedded in tables or adjacent narrative so that downstream Markdown keeps link targets readable without reconstructing Word layout.

### Pseudo-code

```
let x = 1
println(x)
```

## Visual Appendix

![image](assets/image02.png)

Figure 2. Escalation and validation flow for release candidates.

Body paragraph.

| Cell before |
| --- |
|  |

## Conclusion

通过上述技术路线，将逐步构建从源文档解析到目标格式生成的完整转换链路，最终实现docx/pdf到Markdown的自动化转换，满足申报书快速整理的实际需求。

## Text Boxes

### Text Box 1

Body text box.

### Text Box 2

Table text box.
