项目申报书

1. 研究内容

1.1 技术路线

本项目旨在通过模块化设计实现文档格式转换的核心功能，优先完成基础架构搭建与关键模块开发。首先定义统一的中间表示（IR）结构，作为不同文档格式转换的桥梁，确保数据解析与生成的一致性。

![image](assets/image1.png)

在IR模块稳定后，分阶段开展docx和pdf格式的解析工作，docx模块重点处理document.xml中的文本与格式信息，pdf模块则计划采用OCR技术结合布局分析实现内容提取。

| <w:tcW w:w="0" w:type="auto"/><w:tcMar><w:left w:w="108" w:type="dxa"/><w:right w:w="108" w:type="dxa"/></w:tcMar><w:vAlign w:val="center"/></w:tcPr><w:p w14:paraId="42A869A5"><w:pPr><w:jc w:val="center"/><w:rPr><w:b/></w:rPr></w:pPr><w:r><w:rPr><w:b/></w:rPr><w:t>模块 | <w:tcW w:w="0" w:type="auto"/><w:tcMar><w:left w:w="108" w:type="dxa"/><w:right w:w="108" w:type="dxa"/></w:tcMar><w:vAlign w:val="center"/></w:tcPr><w:p w14:paraId="258B6252"><w:pPr><w:jc w:val="center"/><w:rPr><w:b/></w:rPr></w:pPr><w:r><w:rPr><w:b/></w:rPr><w:t>状态 | <w:tcW w:w="0" w:type="auto"/><w:tcMar><w:left w:w="108" w:type="dxa"/><w:right w:w="108" w:type="dxa"/></w:tcMar><w:vAlign w:val="center"/></w:tcPr><w:p w14:paraId="778B2F12"><w:pPr><w:jc w:val="center"/><w:rPr><w:b/></w:rPr></w:pPr><w:r><w:rPr><w:b/></w:rPr><w:t>说明 |
| --- | --- | --- |
| <w:tcW w:w="0" w:type="auto"/><w:tcMar><w:left w:w="108" w:type="dxa"/><w:right w:w="108" w:type="dxa"/></w:tcMar><w:vAlign w:val="center"/></w:tcPr><w:p w14:paraId="144D6C51"><w:r><w:t>core/ir | <w:tcW w:w="0" w:type="auto"/><w:tcMar><w:left w:w="108" w:type="dxa"/><w:right w:w="108" w:type="dxa"/></w:tcMar><w:vAlign w:val="center"/></w:tcPr><w:p w14:paraId="27092F90"><w:r><w:t>完成 | <w:tcW w:w="0" w:type="auto"/><w:tcMar><w:left w:w="108" w:type="dxa"/><w:right w:w="108" w:type="dxa"/></w:tcMar><w:vAlign w:val="center"/></w:tcPr><w:p w14:paraId="66A3F916"><w:r><w:t>定义文档中间表示（IR）的数据结构与转换规则，支持文本、图片、表格等元素的标准化存储 |
| <w:tcW w:w="0" w:type="auto"/><w:tcMar><w:left w:w="108" w:type="dxa"/><w:right w:w="108" w:type="dxa"/></w:tcMar><w:vAlign w:val="center"/></w:tcPr><w:p w14:paraId="4EBBBF49"><w:r><w:t>docx | <w:tcW w:w="0" w:type="auto"/><w:tcMar><w:left w:w="108" w:type="dxa"/><w:right w:w="108" w:type="dxa"/></w:tcMar><w:vAlign w:val="center"/></w:tcPr><w:p w14:paraId="0DD80997"><w:r><w:t>进行中 | <w:tcW w:w="0" w:type="auto"/><w:tcMar><w:left w:w="108" w:type="dxa"/><w:right w:w="108" w:type="dxa"/></w:tcMar><w:vAlign w:val="center"/></w:tcPr><w:p w14:paraId="0893A091"><w:r><w:t>解析docx文件的document.xml，提取段落、标题、列表等结构化内容，已完成文本提取，正在开发格式映射功能 |
| <w:tcW w:w="0" w:type="auto"/><w:tcMar><w:left w:w="108" w:type="dxa"/><w:right w:w="108" w:type="dxa"/></w:tcMar><w:vAlign w:val="center"/></w:tcPr><w:p w14:paraId="1BE7A3F1"><w:r><w:t>pdf | <w:tcW w:w="0" w:type="auto"/><w:tcMar><w:left w:w="108" w:type="dxa"/><w:right w:w="108" w:type="dxa"/></w:tcMar><w:vAlign w:val="center"/></w:tcPr><w:p w14:paraId="4010DE0E"><w:r><w:t>TODO | <w:tcW w:w="0" w:type="auto"/><w:tcMar><w:left w:w="108" w:type="dxa"/><w:right w:w="108" w:type="dxa"/></w:tcMar><w:vAlign w:val="center"/></w:tcPr><w:p w14:paraId="4EFE70DD"><w:r><w:t>下一阶段重点任务，计划集成OCR引擎与PDF布局分析算法，实现扫描版与文本版PDF的内容识别与结构化转换 |
| <w:tcW w:w="0" w:type="auto"/><w:tcMar><w:left w:w="108" w:type="dxa"/><w:right w:w="108" w:type="dxa"/></w:tcMar><w:vAlign w:val="center"/></w:tcPr><w:p w14:paraId="73967B01"><w:r><w:t>markdown | <w:tcW w:w="0" w:type="auto"/><w:tcMar><w:left w:w="108" w:type="dxa"/><w:right w:w="108" w:type="dxa"/></w:tcMar><w:vAlign w:val="center"/></w:tcPr><w:p w14:paraId="2B837238"><w:r><w:t>规划中 | <w:tcW w:w="0" w:type="auto"/><w:tcMar><w:left w:w="108" w:type="dxa"/><w:right w:w="108" w:type="dxa"/></w:tcMar><w:vAlign w:val="center"/></w:tcPr><w:p w14:paraId="6D5A09AE"><w:r><w:t>基于IR生成符合CommonMark标准的Markdown文本，支持代码块、表格、图片引用等格式转换 |

通过上述技术路线，将逐步构建从源文档解析到目标格式生成的完整转换链路，最终实现docx/pdf到Markdown的自动化转换，满足申报书快速整理的实际需求。

