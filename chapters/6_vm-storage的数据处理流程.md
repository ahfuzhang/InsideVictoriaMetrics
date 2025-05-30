
# 6. vm-storage的数据处理流程

## 6.1 索引部分

### 6.1.1 mem table切换流程

* 以下情况下，mem table会转换为inmemoryPart:

  * 有N个核就会分为N个桶，当单个桶的inmemoryBlock数量超过512个的时候
    * 也就是mem table的容量超过32MB

  * table对象上的rawItemsFlusher协程，一秒flush一次

* 切换流程：
  * 每15个inmemoryBlock为一组，开启一个独立协程来转换为inmemoryPart
  * block之间两两合并，采用归并排序算法。反复如此，直到所有block都合并
    * 一个block可以看做一个sstable，对公共前缀进行压缩存储
  * 每个block使用ZSTD压缩
  * 产生items.bin, lens.bin对应的格式，只不过存储位置是内存buffer
  * 产生对应的indexBlock和metadataRow信息



### 6.1.2 插入索引过程

* 根据metric数据搜索对应的tsid
  * 搜索到了说明是旧的TSID,进入数据插入流程
* 通过原子加产生唯一metricID
* 构造多条metric对应的索引
* 把多条索引写入mem table
  * Mem table有空间，追加进去，直接返回
  * Mem table写满，申请新的一块inmemoryBlock，继续追加
    * inmemoryBlock超过512个，进入merge流程
  * Mem table中的shard积累数据达到2秒，把mem table转换成immutable table

代码调用流程请看：[victoria-metrics-1.72.0/源码追踪/插入索引过程.md](https://github.com/ahfuzhang/victoria-metrics-1.72.0/blob/master/%E6%BA%90%E7%A0%81%E8%BF%BD%E8%B8%AA/%E6%8F%92%E5%85%A5%E7%B4%A2%E5%BC%95%E8%BF%87%E7%A8%8B.md)



#### 6.1.2.1 索引的类型

一个metric数据插入indexDB中会产生多条索引。(metric是一个序列化后的metric的[]byte类型数据)

VM中存在以下类型的索引：
See: [VictoriaMetrics-1.72.0-cluster/lib/storage/index_db.go:30](https://github.com/ahfuzhang/victoria-metrics-1.72.0/blob/master/VictoriaMetrics-1.72.0-cluster/lib/storage/index_db.go#L30)

```go
const (
   // Prefix for MetricName->TSID entries.
   nsPrefixMetricNameToTSID = 0  //创建索引的时候触发

   // Prefix for Tag->MetricID entries.
   nsPrefixTagToMetricIDs = 1  //创建索引的时候触发

   // Prefix for MetricID->TSID entries.
   nsPrefixMetricIDToTSID = 2  //创建索引的时候触发

   // Prefix for MetricID->MetricName entries.
   nsPrefixMetricIDToMetricName = 3  //创建索引的时候触发

   // Prefix for deleted MetricID entries.
   nsPrefixDeletedMetricID = 4  //删除接口触发

   // Prefix for Date->MetricID entries.
   nsPrefixDateToMetricID = 5  //插入完数据部分后再创建

   // Prefix for (Date,Tag)->MetricID entries.
   nsPrefixDateTagToMetricIDs = 6  //插入完数据部分后再创建
)
```

插入metric过程中创建的索引有：

* Metric -> TSID
* MetricID -> Metric
* MetricID -> TSID
* AccountID + ProjectID + `__name__`  -> MetricID
* AccountID + ProjectID + 每个tag -> MetricID
* AccountID + ProjectID + 每个tag -> MetricID
* AccountID + ProjectID + `__name__` + 每个tag -> MetricID
* 如果`__name__`中含有.  则增加反向索引：  reverse(`__name__`) -> MetricID

数据写入后，还会增加的索引：

* Date->MetricID
* (Date,Tag)->MetricID



#### 6.1.2.2 更新索引cache

在 storage 全局 cache 的 tsidCache 中写入索引：

* Key: TSID
* Value: metric
* 最多允许总可用内存的35%

### 6.1.3 索引merge流程

* 以下情况下会触发索引的merge:
  * part的个数超过512
  * table对象中的partMerger协程每秒执行merge操作

* merge的核心流程大致如下：
  * 在临时目录创建目标的filePart对象
  * 对所有要合并的part，按照firstItem排序
  * part之间两两归并排序，把排序后的索引拷贝到临时的inmemoryBlock对象
  * 每个block最大64KB，达到这个尺寸后，写入目标的文件part中
  * 持续这个过程，直至所有part都合并完成
  * 把新的filePart move到part目录
  * 把合并前的filePart的路径信息写入txn目录下的文件中
    * 这是为了避免突然断电而产生错乱
  * 删除合并前的filePart
  * 打开新的合并后的filePart
  * 从table对象去掉合并前的part
  * 在table对象中加入新的合并后的filePart

See: [victoria-metrics-1.72.0/源码追踪/索引merge流程.md](https://github.com/ahfuzhang/victoria-metrics-1.72.0/blob/master/%E6%BA%90%E7%A0%81%E8%BF%BD%E8%B8%AA/%E7%B4%A2%E5%BC%95merge%E6%B5%81%E7%A8%8B.md)


## 6.2 数据部分


### 6.2.1 插入数据过程

* 在索引插入流程中，先得到metric所对应的tsid
* tsid+timestamp+value构成rawRow结构
* 把多条数据写入mem table
  * Mem table有空间，追加进去，直接返回
  * mem table写满，进入merge流程，清空对应的mem table
  * Mem table中的shard积累数据达到2秒，把mem table转换成immutable table




### 6.2.2 数据merge流程

* merge的触发条件：
  * 超过256个small part的时候，触发merge流程
  * partition对象上的协程，每5秒执行一次merge
* merge数据的核心流程描述如下：
  * 先筛选出需要merge的small part
  * 在临时目录创建目标的filePart对象
  * part之间两两进行归并排序
    * 每个block是一个独立的TSID，因此合并主要是针对同一个tsid
  * 把新的filePart move到part目录
  * 把合并前的filePart的路径信息写入txn目录下的文件中
    * 这是为了避免突然断电而产生错乱
  * 删除合并前的filePart
  * 打开新的合并后的filePart
  * 从table对象去掉合并前的part
    * 注意：这里需要区分是big part还是small part
  * 在table对象中加入新的合并后的filePart

## 6.3 查询流程

重点分析最常见的query_range 查询。

细节请见：[victoria-metrics-1.72.0/源码追踪/查询流程.md](https://github.com/ahfuzhang/victoria-metrics-1.72.0/blob/master/%E6%BA%90%E7%A0%81%E8%BF%BD%E8%B8%AA/%E6%9F%A5%E8%AF%A2%E6%B5%81%E7%A8%8B.md)

> 在现代数据仓库中，数据跳过对于提高查询性能至关重要。虽然索引结构（例如Btrees或哈希表）可以进行精确的修剪，但是它们庞大的存储要求使它们对于索引辅助列不切实际。因此，许多系统依靠近似索引（例如最小/最大草图（ZoneMaps）或布隆过滤器）来进行具有成本效益的数据修剪。例如，使用此类索引，Google PowerDrill平均跳过90％以上的数据。
>
> ——《[布谷鸟索引：轻量级的二级索引结构](https://www.toutiao.com/i6937334005767356940)》

### 6.3.1 主要流程

主要流程可以描述为：

1. 搜索用户提交的查询表达式对应的TSID的集合
   * 根据查询表达式决定采用那种索引
   * 构造索引的前缀，进行前缀匹配
   * part之间是顺序搜索的
     * 可以通过partHeader的firstItem和lastItem可以快速确定当前part内有没有要查询的数据
     * indexBlock之间根据firstItem字段来做二分查找
     * block内做二分查找
2. 根据TSID集合和时间范围，拉取数据部分的timestamp和value
   * 数据部分只有一种KEY：tsid
   * 根据tsid的集合，还有查询的时间范围进行搜索
   * 每个block只有一个tsid的数据

#### 6.3.1.1 大致流程

* 解析请求
  * 客户端传来的超时时间
  * 时间范围
  * 查询表达式
    * 由一组metric表达式构成
      * eg: metricName{tag1="value1",tag2!="value2",tag3=~"regexp"}
      * 然后解析每个标签
        * 标签主要是四个字段：key, value, isNegative, isRegexp
* 查询并发限制
  * See: 《[VictoriaMetrics中协程优先级的处理方式](https://www.cnblogs.com/ahfuzhang/p/15847860.html)》
  * 查询协程数是cpu核的两倍
  * 查询协程优先级低于写入协程，当写入协程无法调度的时候，查询协程要主动退让
* 在indexdb中搜索
  * 先检查上次的同样的查询表达式，是否有缓存的TSID结果
  * 先搜索出key可能存在的所有part，放入优先队列
  * 按照part -> indexBlock -> block的顺序，进行前缀匹配搜索
* 在数据部分搜索
  * 先搜索出所有满足条件的partition
    * 每个partition下再搜索出满足条件的part

  * 以游标的方式读取每条数据
    * 以storage.MetricBlock格式，向vm-select返回数据
    * 每找到一条数据就会发送一次（因此搜索过程不会占用大量vm-storage的内存，流式处理的）
* 最后，根据tsid在cache中查询出完整的metric信息
  * tsid是vm-storage内部的信息，不会返回给查询端
  * 把metric, timestamp, value序列化后，返回给vm-select端


#### 6.3.1.2 对象结构

对象结构：

* vmselectRequestCtx中包含Search对象
* 顶层搜索对象：[Search](https://github.com/ahfuzhang/victoria-metrics-1.72.0/blob/master/VictoriaMetrics-1.72.0-cluster/lib/storage/search.go#L125)
* 成员：
  * 索引：[storage.searchTSIDs()](https://github.com/ahfuzhang/victoria-metrics-1.72.0/blob/master/VictoriaMetrics-1.72.0-cluster/lib/storage/storage.go#L1125) -> [indexdb.searchTSIDs()](https://github.com/ahfuzhang/victoria-metrics-1.72.0/blob/master/VictoriaMetrics-1.72.0-cluster/lib/storage/index_db.go#L1656)
    * 包含 indexSearch对象
      * 包含mergeset.TableSearch对象
        * 包含[]partSearch对象数组
  * 数据：[tableSearch](https://github.com/ahfuzhang/victoria-metrics-1.72.0/blob/master/VictoriaMetrics-1.72.0-cluster/lib/storage/table_search.go#L13)
    * 包含[]partitionSearch对象数组
      * 包含[]partSearch对象数组

所有搜索的代码，都可以描述为这个模式：

```go
func foo(key []byte){
  search.Seek(key)  //打开游标，把主要的数据块放入优先队列
  for search.NextItem() {  //以游标的方式获取所有符合条件的数据
    data := search.Item   //通过游标的成员获取当前数据
    value := data[len(key):]  //所有的搜索都是前缀匹配，去掉前缀就是value的内容
  }
}
```

### 6.3.2 索引上的搜索

* 需要同时搜索curr
* part内的索引，一定是唯一的，有序的
* part之间的索引，可能存在交叉的情况
* 因此：
  * 需要筛选出所有匹配到前缀的part
  * 每个part内再确定偏移量

#### 6.3.2.1 在索引table上搜索

主要使用tableSearch对象

1. 先调用tableSearch.Seek(key)进行前缀查找
   * 这个操作会触发partSearch.Seek(key)
   * 调用完成后，所有符合条件的part都被放到了一个优先队列
2. 在循环内调用tableSearch.NextItem()，可以像游标一样获取每条匹配到的数据
   * 先从优先队列的第一个符合条件的part开始，使用partSearch.NextItem()来获取数据
   * 如果当前的part搜索完毕，从优先队列出队，继续下一个part的搜索。




#### 6.3.2.2 索引part上的搜索

* Init()方法：引用part对象的成员
* Seek()方法：查询某个key
  * 超过partHeader的lastItem，说明key不在这个part上

* nextBHS(): 遍历所有的indexBlock
  * nextBlock()遍历所有的block



#### 6.3.2.3 触发cache更新

1. part上的cache

   * partSearch上调用nextBlock()会把每个block转换成inmemoryBlock，然后缓存起来。

   * 128GB内存下，每个part最多允许32768个block，每个block 64KB，总共允许2GB内存的block缓存。

   * 缓存太多block影响不大，超过120秒未访问的块会被清理掉

2. indexDB上的cache

   * tagFiltersCache记录`查询表达式 -> tsid集合`这样的搜索结果
   * 每10秒为一个generation进行存储
   * 在prev indexdb上的cache，不存储generation，因为不会有新的metric出现了

3. storage上的metricNameCache

​      搜索到tsid后，返回数据时还需要返回tsid对应的完整metric信息。因此会触发这个`MetricID -> MetricName`的cache更新，便于后续快速获取metric信息。

### 6.3.3 数据上的搜索

搜索可以描述为：partition筛选 -> part筛选 -> blockIndex筛选 -> block筛选(tsid筛选)

 搜索过程中会触发part对象上的indexBlockCache更新，这个cache缓存了indexBlock的头信息。

注意：没有block层面的cache。



## 6.4 备份流程
1. 先在snapshot目录创建对应文件夹，生成一个以当前时间为名字的snapshot名称；
2. 把mem table的数据转到inmemory part
3. 把所有的inmemory part变成 file part
4. 对所有磁盘上的文件建立hard link
4. 然后等待vm-backup从磁盘的snapshot目录去读取文件
4. vm-backup完成备份后，调用 `/snapshot/delete`删除快照。
