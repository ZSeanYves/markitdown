# .snapshot/ignored.txt

hidden checkpoint

# README.md

# Project Export

Synthetic-realistic project export bundle for complex ZIP validation.

# bin/blob.bin

> Skipped: unsupported file type: bin

# data/config.json

| Key | Value |
| --- | --- |
| env | prod |
| replicas | 3 |
| feature_flags | {"real_world":true,"benchmarks":false} |

# data/export.csv

| Region | Quarter | Revenue |
| --- | --- | --- |
| East | Q1 | 120 |
| West | Q1 | 98 |
| North | Q2 | 131 |

# data/settings.yaml

| Key | Value |
| --- | --- |
| env | prod |
| replicas | 3 |
| real_world | true |
| windows_shell | wsl |

# docs/whitepaper.docx

# Technical Whitepaper

## Executive Summary

This whitepaper consolidates architecture, validation, release workflow, and risk evidence for a MoonBit-native document conversion pipeline. It is intentionally structured as a long-form delivery artifact rather than a feature-isolated sample.

## 1. 研究内容

### 1.1 技术路线

本项目旨在通过模块化设计实现文档格式转换的核心功能，优先完成基础架构搭建与关键模块开发。首先定义统一的中间表示（IR）结构，作为不同文档格式转换的桥梁，确保数据解析与生成的一致性。

## Architecture Overview

![image](assets/archive/docs_whitepaper.docx/image01.png)

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

![image](assets/archive/docs_whitepaper.docx/image02.png)

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

# nested/structured_bundle.zip

> Skipped: nested archive is not supported: zip

# notes/plain.txt

Operators retain plain-text notes for environments where richer tooling is unavailable.

# sheets/finance_workbook.xlsx

## Overview

| Key | Value |
| --- | --- |
| k1 | 1 |
| k2 | 2 |
| k3 | 3 |
| k4 | 4 |
| k5 | 5 |
| k6 | 6 |
| k7 | 7 |
| k8 | 8 |
| k9 | 9 |
| k10 | 10 |
| k11 | 11 |
| k12 | 12 |
| k13 | 13 |
| k14 | 14 |
| k15 | 15 |
| k16 | 16 |
| k17 | 17 |
| k18 | 18 |
| k19 | 19 |
| k20 | 20 |
| k21 | 21 |
| k22 | 22 |
| k23 | 23 |
| k24 | 24 |
| k25 | 25 |
| k26 | 26 |
| k27 | 27 |
| k28 | 28 |
| k29 | 29 |
| k30 | 30 |
| k31 | 31 |
| k32 | 32 |
| k33 | 33 |
| k34 | 34 |
| k35 | 35 |
| k36 | 36 |
| k37 | 37 |
| k38 | 38 |
| k39 | 39 |
| k40 | 40 |
| k41 | 41 |
| k42 | 42 |
| k43 | 43 |
| k44 | 44 |
| k45 | 45 |
| k46 | 46 |
| k47 | 47 |
| k48 | 48 |
| k49 | 49 |
| k50 | 50 |


## DataA

| ID | Name | Amt |
| --- | --- | --- |
| 1 | DataA-1 | 7 |
| 2 | DataA-2 | 14 |
| 3 | DataA-3 | 21 |
| 4 | DataA-4 | 28 |
| 5 | DataA-5 | 35 |
| 6 | DataA-6 | 42 |
| 7 | DataA-7 | 49 |
| 8 | DataA-8 | 56 |
| 9 | DataA-9 | 63 |
| 10 | DataA-10 | 70 |
| 11 | DataA-11 | 77 |
| 12 | DataA-12 | 84 |
| 13 | DataA-13 | 91 |
| 14 | DataA-14 | 98 |
| 15 | DataA-15 | 105 |
| 16 | DataA-16 | 112 |
| 17 | DataA-17 | 119 |
| 18 | DataA-18 | 126 |
| 19 | DataA-19 | 133 |
| 20 | DataA-20 | 140 |
| 21 | DataA-21 | 147 |
| 22 | DataA-22 | 154 |
| 23 | DataA-23 | 161 |
| 24 | DataA-24 | 168 |
| 25 | DataA-25 | 175 |
| 26 | DataA-26 | 182 |
| 27 | DataA-27 | 189 |
| 28 | DataA-28 | 196 |
| 29 | DataA-29 | 203 |
| 30 | DataA-30 | 210 |
| 31 | DataA-31 | 217 |
| 32 | DataA-32 | 224 |
| 33 | DataA-33 | 231 |
| 34 | DataA-34 | 238 |
| 35 | DataA-35 | 245 |
| 36 | DataA-36 | 252 |
| 37 | DataA-37 | 259 |
| 38 | DataA-38 | 266 |
| 39 | DataA-39 | 273 |
| 40 | DataA-40 | 280 |
| 41 | DataA-41 | 287 |
| 42 | DataA-42 | 294 |
| 43 | DataA-43 | 301 |
| 44 | DataA-44 | 308 |
| 45 | DataA-45 | 315 |
| 46 | DataA-46 | 322 |
| 47 | DataA-47 | 329 |
| 48 | DataA-48 | 336 |
| 49 | DataA-49 | 343 |
| 50 | DataA-50 | 350 |
| 51 | DataA-51 | 357 |
| 52 | DataA-52 | 364 |
| 53 | DataA-53 | 371 |
| 54 | DataA-54 | 378 |
| 55 | DataA-55 | 385 |
| 56 | DataA-56 | 392 |
| 57 | DataA-57 | 399 |
| 58 | DataA-58 | 406 |
| 59 | DataA-59 | 413 |
| 60 | DataA-60 | 420 |
| 61 | DataA-61 | 427 |
| 62 | DataA-62 | 434 |
| 63 | DataA-63 | 441 |
| 64 | DataA-64 | 448 |
| 65 | DataA-65 | 455 |
| 66 | DataA-66 | 462 |
| 67 | DataA-67 | 469 |
| 68 | DataA-68 | 476 |
| 69 | DataA-69 | 483 |
| 70 | DataA-70 | 490 |
| 71 | DataA-71 | 497 |
| 72 | DataA-72 | 504 |
| 73 | DataA-73 | 511 |
| 74 | DataA-74 | 518 |
| 75 | DataA-75 | 525 |
| 76 | DataA-76 | 532 |
| 77 | DataA-77 | 539 |
| 78 | DataA-78 | 546 |
| 79 | DataA-79 | 553 |
| 80 | DataA-80 | 560 |
| 81 | DataA-81 | 567 |
| 82 | DataA-82 | 574 |
| 83 | DataA-83 | 581 |
| 84 | DataA-84 | 588 |
| 85 | DataA-85 | 595 |
| 86 | DataA-86 | 602 |
| 87 | DataA-87 | 609 |
| 88 | DataA-88 | 616 |
| 89 | DataA-89 | 623 |
| 90 | DataA-90 | 630 |
| 91 | DataA-91 | 637 |
| 92 | DataA-92 | 644 |
| 93 | DataA-93 | 651 |
| 94 | DataA-94 | 658 |
| 95 | DataA-95 | 665 |
| 96 | DataA-96 | 672 |
| 97 | DataA-97 | 679 |
| 98 | DataA-98 | 686 |
| 99 | DataA-99 | 693 |
| 100 | DataA-100 | 700 |
| 101 | DataA-101 | 707 |
| 102 | DataA-102 | 714 |
| 103 | DataA-103 | 721 |
| 104 | DataA-104 | 728 |
| 105 | DataA-105 | 735 |
| 106 | DataA-106 | 742 |
| 107 | DataA-107 | 749 |
| 108 | DataA-108 | 756 |
| 109 | DataA-109 | 763 |
| 110 | DataA-110 | 770 |
| 111 | DataA-111 | 777 |
| 112 | DataA-112 | 784 |
| 113 | DataA-113 | 791 |
| 114 | DataA-114 | 798 |
| 115 | DataA-115 | 805 |
| 116 | DataA-116 | 812 |
| 117 | DataA-117 | 819 |
| 118 | DataA-118 | 826 |
| 119 | DataA-119 | 833 |
| 120 | DataA-120 | 840 |


## DataB

| ID | Name | Amt |
| --- | --- | --- |
| 1 | DataB-1 | 7 |
| 2 | DataB-2 | 14 |
| 3 | DataB-3 | 21 |
| 4 | DataB-4 | 28 |
| 5 | DataB-5 | 35 |
| 6 | DataB-6 | 42 |
| 7 | DataB-7 | 49 |
| 8 | DataB-8 | 56 |
| 9 | DataB-9 | 63 |
| 10 | DataB-10 | 70 |
| 11 | DataB-11 | 77 |
| 12 | DataB-12 | 84 |
| 13 | DataB-13 | 91 |
| 14 | DataB-14 | 98 |
| 15 | DataB-15 | 105 |
| 16 | DataB-16 | 112 |
| 17 | DataB-17 | 119 |
| 18 | DataB-18 | 126 |
| 19 | DataB-19 | 133 |
| 20 | DataB-20 | 140 |
| 21 | DataB-21 | 147 |
| 22 | DataB-22 | 154 |
| 23 | DataB-23 | 161 |
| 24 | DataB-24 | 168 |
| 25 | DataB-25 | 175 |
| 26 | DataB-26 | 182 |
| 27 | DataB-27 | 189 |
| 28 | DataB-28 | 196 |
| 29 | DataB-29 | 203 |
| 30 | DataB-30 | 210 |
| 31 | DataB-31 | 217 |
| 32 | DataB-32 | 224 |
| 33 | DataB-33 | 231 |
| 34 | DataB-34 | 238 |
| 35 | DataB-35 | 245 |
| 36 | DataB-36 | 252 |
| 37 | DataB-37 | 259 |
| 38 | DataB-38 | 266 |
| 39 | DataB-39 | 273 |
| 40 | DataB-40 | 280 |
| 41 | DataB-41 | 287 |
| 42 | DataB-42 | 294 |
| 43 | DataB-43 | 301 |
| 44 | DataB-44 | 308 |
| 45 | DataB-45 | 315 |
| 46 | DataB-46 | 322 |
| 47 | DataB-47 | 329 |
| 48 | DataB-48 | 336 |
| 49 | DataB-49 | 343 |
| 50 | DataB-50 | 350 |
| 51 | DataB-51 | 357 |
| 52 | DataB-52 | 364 |
| 53 | DataB-53 | 371 |
| 54 | DataB-54 | 378 |
| 55 | DataB-55 | 385 |
| 56 | DataB-56 | 392 |
| 57 | DataB-57 | 399 |
| 58 | DataB-58 | 406 |
| 59 | DataB-59 | 413 |
| 60 | DataB-60 | 420 |
| 61 | DataB-61 | 427 |
| 62 | DataB-62 | 434 |
| 63 | DataB-63 | 441 |
| 64 | DataB-64 | 448 |
| 65 | DataB-65 | 455 |
| 66 | DataB-66 | 462 |
| 67 | DataB-67 | 469 |
| 68 | DataB-68 | 476 |
| 69 | DataB-69 | 483 |
| 70 | DataB-70 | 490 |
| 71 | DataB-71 | 497 |
| 72 | DataB-72 | 504 |
| 73 | DataB-73 | 511 |
| 74 | DataB-74 | 518 |
| 75 | DataB-75 | 525 |
| 76 | DataB-76 | 532 |
| 77 | DataB-77 | 539 |
| 78 | DataB-78 | 546 |
| 79 | DataB-79 | 553 |
| 80 | DataB-80 | 560 |
| 81 | DataB-81 | 567 |
| 82 | DataB-82 | 574 |
| 83 | DataB-83 | 581 |
| 84 | DataB-84 | 588 |
| 85 | DataB-85 | 595 |
| 86 | DataB-86 | 602 |
| 87 | DataB-87 | 609 |
| 88 | DataB-88 | 616 |
| 89 | DataB-89 | 623 |
| 90 | DataB-90 | 630 |
| 91 | DataB-91 | 637 |
| 92 | DataB-92 | 644 |
| 93 | DataB-93 | 651 |
| 94 | DataB-94 | 658 |
| 95 | DataB-95 | 665 |
| 96 | DataB-96 | 672 |
| 97 | DataB-97 | 679 |
| 98 | DataB-98 | 686 |
| 99 | DataB-99 | 693 |
| 100 | DataB-100 | 700 |
| 101 | DataB-101 | 707 |
| 102 | DataB-102 | 714 |
| 103 | DataB-103 | 721 |
| 104 | DataB-104 | 728 |
| 105 | DataB-105 | 735 |
| 106 | DataB-106 | 742 |
| 107 | DataB-107 | 749 |
| 108 | DataB-108 | 756 |
| 109 | DataB-109 | 763 |
| 110 | DataB-110 | 770 |
| 111 | DataB-111 | 777 |
| 112 | DataB-112 | 784 |
| 113 | DataB-113 | 791 |
| 114 | DataB-114 | 798 |
| 115 | DataB-115 | 805 |
| 116 | DataB-116 | 812 |
| 117 | DataB-117 | 819 |
| 118 | DataB-118 | 826 |
| 119 | DataB-119 | 833 |
| 120 | DataB-120 | 840 |


## DataC

| ID | Name | Amt |
| --- | --- | --- |
| 1 | DataC-1 | 7 |
| 2 | DataC-2 | 14 |
| 3 | DataC-3 | 21 |
| 4 | DataC-4 | 28 |
| 5 | DataC-5 | 35 |
| 6 | DataC-6 | 42 |
| 7 | DataC-7 | 49 |
| 8 | DataC-8 | 56 |
| 9 | DataC-9 | 63 |
| 10 | DataC-10 | 70 |
| 11 | DataC-11 | 77 |
| 12 | DataC-12 | 84 |
| 13 | DataC-13 | 91 |
| 14 | DataC-14 | 98 |
| 15 | DataC-15 | 105 |
| 16 | DataC-16 | 112 |
| 17 | DataC-17 | 119 |
| 18 | DataC-18 | 126 |
| 19 | DataC-19 | 133 |
| 20 | DataC-20 | 140 |
| 21 | DataC-21 | 147 |
| 22 | DataC-22 | 154 |
| 23 | DataC-23 | 161 |
| 24 | DataC-24 | 168 |
| 25 | DataC-25 | 175 |
| 26 | DataC-26 | 182 |
| 27 | DataC-27 | 189 |
| 28 | DataC-28 | 196 |
| 29 | DataC-29 | 203 |
| 30 | DataC-30 | 210 |
| 31 | DataC-31 | 217 |
| 32 | DataC-32 | 224 |
| 33 | DataC-33 | 231 |
| 34 | DataC-34 | 238 |
| 35 | DataC-35 | 245 |
| 36 | DataC-36 | 252 |
| 37 | DataC-37 | 259 |
| 38 | DataC-38 | 266 |
| 39 | DataC-39 | 273 |
| 40 | DataC-40 | 280 |
| 41 | DataC-41 | 287 |
| 42 | DataC-42 | 294 |
| 43 | DataC-43 | 301 |
| 44 | DataC-44 | 308 |
| 45 | DataC-45 | 315 |
| 46 | DataC-46 | 322 |
| 47 | DataC-47 | 329 |
| 48 | DataC-48 | 336 |
| 49 | DataC-49 | 343 |
| 50 | DataC-50 | 350 |
| 51 | DataC-51 | 357 |
| 52 | DataC-52 | 364 |
| 53 | DataC-53 | 371 |
| 54 | DataC-54 | 378 |
| 55 | DataC-55 | 385 |
| 56 | DataC-56 | 392 |
| 57 | DataC-57 | 399 |
| 58 | DataC-58 | 406 |
| 59 | DataC-59 | 413 |
| 60 | DataC-60 | 420 |
| 61 | DataC-61 | 427 |
| 62 | DataC-62 | 434 |
| 63 | DataC-63 | 441 |
| 64 | DataC-64 | 448 |
| 65 | DataC-65 | 455 |
| 66 | DataC-66 | 462 |
| 67 | DataC-67 | 469 |
| 68 | DataC-68 | 476 |
| 69 | DataC-69 | 483 |
| 70 | DataC-70 | 490 |
| 71 | DataC-71 | 497 |
| 72 | DataC-72 | 504 |
| 73 | DataC-73 | 511 |
| 74 | DataC-74 | 518 |
| 75 | DataC-75 | 525 |
| 76 | DataC-76 | 532 |
| 77 | DataC-77 | 539 |
| 78 | DataC-78 | 546 |
| 79 | DataC-79 | 553 |
| 80 | DataC-80 | 560 |
| 81 | DataC-81 | 567 |
| 82 | DataC-82 | 574 |
| 83 | DataC-83 | 581 |
| 84 | DataC-84 | 588 |
| 85 | DataC-85 | 595 |
| 86 | DataC-86 | 602 |
| 87 | DataC-87 | 609 |
| 88 | DataC-88 | 616 |
| 89 | DataC-89 | 623 |
| 90 | DataC-90 | 630 |
| 91 | DataC-91 | 637 |
| 92 | DataC-92 | 644 |
| 93 | DataC-93 | 651 |
| 94 | DataC-94 | 658 |
| 95 | DataC-95 | 665 |
| 96 | DataC-96 | 672 |
| 97 | DataC-97 | 679 |
| 98 | DataC-98 | 686 |
| 99 | DataC-99 | 693 |
| 100 | DataC-100 | 700 |
| 101 | DataC-101 | 707 |
| 102 | DataC-102 | 714 |
| 103 | DataC-103 | 721 |
| 104 | DataC-104 | 728 |
| 105 | DataC-105 | 735 |
| 106 | DataC-106 | 742 |
| 107 | DataC-107 | 749 |
| 108 | DataC-108 | 756 |
| 109 | DataC-109 | 763 |
| 110 | DataC-110 | 770 |
| 111 | DataC-111 | 777 |
| 112 | DataC-112 | 784 |
| 113 | DataC-113 | 791 |
| 114 | DataC-114 | 798 |
| 115 | DataC-115 | 805 |
| 116 | DataC-116 | 812 |
| 117 | DataC-117 | 819 |
| 118 | DataC-118 | 826 |
| 119 | DataC-119 | 833 |
| 120 | DataC-120 | 840 |

# slides/investor_deck.pptx

## Slide 1

### Project Overview

- Goal 1
- Goal 2

Key message for this slide.


## Slide 2

### Project Overview

Background

Goals

Risks

Timelines


## Slide 3

### PPTX MVP 测试

第一段：Hello, 世界 ✅

第二段：包含 emoji 🙂 与符号 & < >

- 项目符号 1
- 项目符号 2

### Speaker Notes

本页核心信息


## Slide 4

### 第二页标题：Data Overview

段落 A：这是一段普通文本。

段落 B：支持中文、English、123。

### Speaker Notes

第二页备注


## Slide 5

### 第三页：仅标题

### Speaker Notes

最后页备注


## Slide 6

### Feature Cards

Search

Fast retrieval

Vision

Image parsing

Speech

Audio input

Agents

Task execution

Memory

Session state

Planning

Multi-step reasoning


## Slide 7

### Experiment Summary

The following table summarizes the main results.

Model

Score

A

91

B

88

Model A performs best overall.


## Slide 8

### Quarter Overview

| Quarter | Revenue | Profit |
| --- | --- | --- |
| Q1 | 120 | 40 |
| Q2 | 140 | 55 |


## Slide 9

### 第二页标题：Data Overview

段落 A：这是一段普通文本。

段落 B：支持中文、English、123。


## Slide 10

### 第三页：仅标题


## Slide 11

![Figure alt text](assets/archive/slides_investor_deck.pptx/image01.png)
*Figure title text*

### PPTX Links And Images

See [reference](https://example.com/reference) before review.


## Slide 12

### PPTX Link Heavy

Resources: [Alpha](https://example.com/alpha), [Beta](https://example.com/beta), [Gamma](https://example.com/gamma)

Docs: [API](https://example.com/api), [Guide](https://example.com/guide), [FAQ](https://example.com/faq)


## Slide 13

### Model Topics

Search

Ranking

Safety

Vision

Speech

Agents

Memory

Planning

Tooling


## Slide 14

### Third

Alpha


## Slide 15 (hidden)

### First

Beta


## Slide 16

### Second

Gamma

# web/article.html

# Platform Operations Handbook

Edition 2026.2 & validated on checked-in synthetic-realistic fixtures.

- [Overview](#overview)
- [Deployment](#deployment)
- [Observability](#observability)
- [Appendix](#appendix)

Search

Pricing

Careers

## Overview

This handbook describes the operational baseline for a multi-format
            document conversion platform. It focuses on repeatable execution,
            readable output, bounded fallbacks, and evidence-driven change
            control rather than pixel-perfect visual reproduction.

Readers who only need the release checklist can jump to the
            [appendix](#appendix), while implementers should also
            review the [external runbook](https://example.com/runbooks)
            and the [deployment contract](guide.html#deployment-contract).

> Stable structure beats optimistic heuristics when the source format
            mixes headings, links, images, and noisy side material.

Info. The platform ships a native-first validation path and a
            documented fallback path for developer environments.

## Documentation Shape

The typical conversion package contains at least five interacting structures:

- top-level headings and local anchor links
- nested procedures
  1. prepare sample assets
  1. run native validation
  1. review output and metadata
- inline code such as moon build --target native
- tables with external references and operator notes
- local figures and caption-like explanations

Warning. Ignore javascript links
            and data links during conversion.

Failure-mode checklist

Check malformed links, repeated navigation, entity decoding, and preformatted text boundaries.

## Deployment

Production deployment uses a staged rollout. Teams publish a frozen
            build, update the registry cache, run a validation suite, and only
            then fan out to scheduled batch jobs.

```
moon build --target native
moon check
moon test
./samples/check.sh
./samples/check.sh --real-world --tags complex
```

On Windows hosts, the core native target is supported, but shell
            validation remains easier under WSL or another POSIX-like runtime.

| Stage | Owner | Reference | Notes |
| --- | --- | --- | --- |
| Build | Release engineering | [build policy](https://example.com/build-policy) | Prefer native CLI over wrapper timing. |
| Validate | Format owners | [observability section](#observability) | Capture metadata sidecars and asset refs. |
| Promote | Operations | [promotion guide](guide.html#promotion) | Document deviations and explicit non-goals. |

## Observability

A good conversion trace keeps structure readable even when the input
            mixes dense lists, escaped entities like <sample>, and repeated
            section wrappers.

![System overview diagram](assets/archive/web_article.html/image01.jpg)
*Overview diagram*
Figure 1. Release-path overview with assets, metadata, and contracts.

The support bundle also includes a second visual artifact for chart
            references and a compact reminder that real-world samples do not
            imply broader performance claims.

![Metrics trend chart](assets/archive/web_article.html/image02.jpg)
*Trend chart*
Figure 2. Trend chart for smoke validation and contract stability.

## Appendix

### Deployment Contract

Every release record should answer these questions:

1. Which checked-in corpora passed?
1. Which assets were emitted and where are they referenced?
1. Which format-specific boundaries remain explicit non-goals?

See also [the overview](#overview),
            [quality records](https://example.com/quality-records),
            and [ops@example.com](mailto:ops@example.com).

## Sidebar

Navigation and repeated site chrome should not dominate the extracted article body.

Last reviewed 2026-05-08. Synthetic-realistic complex HTML sample for markitdown-mb.

# web/img/img_blue.jpg

> Skipped: unsupported file type: jpg

# web/img/img_green.jpg

> Skipped: unsupported file type: jpg

# xml/feed.xml

```xml
<?xml version="1.0" encoding="UTF-8"?><feed><title>Export Feed</title><entry><id>alpha</id><status>open</status></entry></feed>
```
