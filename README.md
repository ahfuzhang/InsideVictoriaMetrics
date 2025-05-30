# Inside VictoriaMetrics

[VictoriaMetrics](https://github.com/VictoriaMetrics/VictoriaMetrics) is an open source component in the monitoring field that I like very much, and my technical ability has also been improved in the process of in-depth study of its original. Thank you very much to Vayala and his team, they deserve more attention.
I may be the engineer who publishes the most articles about VictoriaMetrics in China, and the materials accumulated in the past few years are enough to write a "book".
Due to limited English skills, I can only publish the Chinese version of the content first.
It costs a lot of money to compile a paper book, so I will first publish the content in the form of free open source. I hope that one day it will be discovered by a technical editor and these contents can be turned into a real book.

> VictoriaMetrics 是我非常喜欢的监控领域的开源组件，并且我在深入学习其原来的过程中，技术能力也得到了提升。非常感谢 vayala 大神及其团队，他们值得被更多人关注。
> 我可能是中国发布最多关于 VictoriaMetrics 的文章的工程师，这几年积累的材料足够写成一本“书”了。
> 英语能力有限，我只能先发布中文版的内容。
> 编撰一本纸质书需要花很多钱，所以我先以免费开源的形式发布内容。希望某天能被某位技术编辑发现，从而可以把这些内容变成一本真正的书。

## Plan 写作计划
1. 把以前写的很多材料，按照书的章节来重新整理；
  - [VictoriaMetrics存储引擎分析.pdf](https://github.com/ahfuzhang/victoria-metrics-1.72.0/blob/master/VictoriaMetrics%E5%AD%98%E5%82%A8%E5%BC%95%E6%93%8E%E5%88%86%E6%9E%90.pdf)
  - 相关的源码阅读笔记：https://github.com/ahfuzhang/victoria-metrics-1.72.0
2. 阅读 VictoriaLogs 部分的源码，增加对 VictoriaLogs 的内容。

## Summary

- [前言](chapters/0_前言.md)
- [1.名词和概念](chapters/1_名词和概念.md)
- [2.监控领域的相关存储引擎介绍](chapters/2._监控领域的相关存储引擎介绍.md)
- [3.VictoriaMetrics的背景知识](chapters/3_VictoriaMetrics的背景知识.md)
- [4.VictoriaMetrics存储引擎的设计](chapters/4_VictoriaMetrics存储引擎的设计.md)
- [5.vm-storage基础结构](chapters/5_vm-storage基础结构.md)
- [6.vm-storage的数据处理流程](chapters/6_vm-storage的数据处理流程.md)
- [7.VictoriaMetrics的其他相关知识](chapters/7_VictoriaMetrics的其他相关知识.md)


## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
