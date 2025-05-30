
# 7.VictoriaMetrics的其他相关知识


## 并发管理

See: [VictoriaMetrics中协程优先级的处理方式](https://www.cnblogs.com/ahfuzhang/p/15847860.html)

## VM中的golang代码优化技巧

See: [VictoriaMetrics中的golang代码优化方法](https://www.cnblogs.com/ahfuzhang/p/15918127.html)

用 golang 开发系统级的软件，还有一篇总结：《[用golang开发系统软件的总结](https://www.cnblogs.com/ahfuzhang/p/16745742.html)》




## vm不使用WAL的理由
see: https://valyala.medium.com/wal-usage-looks-broken-in-modern-time-series-databases-b62a627ab704

> 在现代时间序列数据库中，WAL 的使用看起来很糟糕。它不能保证最近插入的断电数据的数据安全。WAL 还有两个额外的缺点：
预写日志往往会消耗很大一部分磁盘 IO 带宽。由于这个缺点，建议将 WAL 放入单独的物理磁盘中。“直接写入 SSTable”的方式需要更少的磁盘 IO 带宽，因此在没有 WAL 的情况下，数据库可能会消耗更多的数据。
WAL 可能会由于缓慢的恢复步骤而减慢数据库启动时间，甚至可能导致OOM 和崩溃循环。




## VM代码不够好的地方

1.用上了goto

2.成员变量应该根据分类再封装成具体的类

3.游标类的操作，封装得很丑陋

4.命名太短了

5.a.b.c.d这样的操作太魔性了，应该封装起来

6.对象的封装不够好，大量的直接引用对象的成员

7.层次性不好

8.文件太长

9.函数太长

10.任何一个错误都不会影响整体流程

   很可能某些情况下数据莫名其妙的丢失了



# 引用文章
本文大量引用了其他作者的文章，对前人的专业和分享精神表示感谢！

## valyala
[valyala](https://github.com/valyala)是fasthttp, fastcache等知名组件的作者，同时也是VM团队的CTO。很多VM的设计细节可以从他的博客了解到。

* valyala的博客：https://valyala.medium.com/
* [WAL usage looks broken in modern Time Series Databases?](https://valyala.medium.com/wal-usage-looks-broken-in-modern-time-series-databases-b62a627ab704)
* [VictoriaMetrics开发历史: VictoriaMetrics — creating the best remote storage for Prometheus](https://faun.pub/victoriametrics-creating-the-best-remote-storage-for-prometheus-5d92d66787ac)
* [VictoriaMetrics 中的 Go 优化](https://habr.com/ru/post/500844/)
  - [valyala:Go optimizations in VictoriaMetrics](https://docs.google.com/presentation/d/1k7OjHvxTHA7669MFwsNTCx8hII-a8lNvpmQetLxmrEU/edit#slide=id.g623cf286f0_0_571)
* [VictoriaMetrics: achieving better compression than Gorilla for time series data](https://faun.pub/victoriametrics-achieving-better-compression-for-time-series-data-than-gorilla-317bc1f95932)
* [valyala: How VictoriaMetrics makes instant snapshots for multi-terabyte time series data](https://valyala.medium.com/how-victoriametrics-makes-instant-snapshots-for-multi-terabyte-time-series-data-e1f3fb0e0282)
  - 翻译: [VictoriaMetrics如何快照数TB的时序数据](https://zhuanlan.zhihu.com/p/315583711)
* [How ClickHouse Inspired Us to Build a High Performance Time Series Database](https://altinity.com/wp-content/uploads/2021/11/How-ClickHouse-Inspired-Us-to-Build-a-High-Performance-Time-Series-Database.pdf)



## 其他作者
* jiangmo： 《[时间序列数据库 (TSDB)](https://www.jianshu.com/p/31afb8492eff)》
* 刘家财: 《[Prometheus 存储引擎分析](https://liujiacai.net/blog/2021/04/11/prometheus-storage-engine/)》
* [无毁的湖光](https://my.oschina.net/alchemystar): 《[[Prometheus时序数据库-磁盘中的存储结构](https://my.oschina.net/alchemystar/blog/4965684)]》
* [时序数据库tsdb世界排名](https://db-engines.com/en/ranking/time+series+dbms)
* [wikipedia: Log-structured merge-tree](https://en.wikipedia.org/wiki/Log-structured_merge-tree)
* [维基百科: 时间序列](https://zh.wikipedia.org/wiki/%E6%99%82%E9%96%93%E5%BA%8F%E5%88%97)
* [详解SSTable结构和LSMTree索引](https://www.cnblogs.com/fxjwind/archive/2012/08/14/2638371.html)
* [各年份各种设备的访问延迟表](https://colin-scott.github.io/personal_website/research/interactive_latency.html)
* [Time-series compression algorithms, explained](https://www.timescale.com/blog/time-series-compression-algorithms-explained/)
* [介绍一个golang库：fastcache](https://mp.weixin.qq.com/s?__biz=MzI0NzM3NDAyNQ==&mid=2247483766&idx=1&sn=5b941a3c2211eff104064d595c04e7df&chksm=e9b048d0dec7c1c687e639928c8ff3e299194e8ff1ed8ad5d0eb2258468eb48ead77e273e0d6&token=1570151211&lang=zh_CN#rd)
* [介绍一个golang库：zstd](https://www.cnblogs.com/ahfuzhang/p/15842350.html)
* [golang源码阅读：VictoriaMetrics中协程优先级的处理方式](https://www.cnblogs.com/ahfuzhang/p/15847860.html)
* [ahfuzhang随笔分类 - VictoriaMetrics](https://www.cnblogs.com/ahfuzhang/category/2076800.html)
* [大铁憨(胡建洪)的知乎专栏](https://www.zhihu.com/people/datiehan/posts)
  - [大铁憨(胡建洪):浅析下开源时序数据库VictoriaMetrics的存储机制](https://zhuanlan.zhihu.com/p/368912946)
* [blackbox:VictoriaMetrics阅读笔记](https://zhuanlan.zhihu.com/p/394961301)
* [单机 20 亿指标，知乎 Graphite 极致优化！](https://github.com/zhihu/promate/wiki/%E5%8D%95%E6%9C%BA-20-%E4%BA%BF%E6%8C%87%E6%A0%87%EF%BC%8C%E7%9F%A5%E4%B9%8E-Graphite-%E6%9E%81%E8%87%B4%E4%BC%98%E5%8C%96%EF%BC%81)
* [ClickHouse for Time-Series](https://www.percona.com/sites/default/files/ple19-slides/day1-pm/clickhouse-for-timeseries.pdf)
* [Victoria Metrics 索引写入流程](https://juejin.cn/post/6854573222373900301)
* [victoria-metrics-1.72.0源码中文注释](https://github.com/ahfuzhang/victoria-metrics-1.72.0)
* [布谷鸟索引：轻量级的二级索引结构](https://www.toutiao.com/i6937334005767356940)
