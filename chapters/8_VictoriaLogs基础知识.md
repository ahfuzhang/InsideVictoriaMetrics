# 8.VictoriaLogs 基础知识

2023 年 6 月，VM 团队开了一个新的产品线： VictoriaLogs.
两年过去了，VictoriaLogs 已经非常成熟，并且还推出了群集版本。
这个产品一如既往了延续了高性能低成本的风格，深入研究源码后，也看到了很多精彩的设计。

## 日志的结构
目前的日志都是半结构化的，通常如下:

```text
timestamp: 2025-05-30 14:23:49.123
tag_name_1: tag_value_1
tag_name_2: tag_value_2
tag_name_3: tag_value_3
message: very long text
```

日志由三部分构成：
- 时间戳
- 标签
- 消息

显而易见，在标签部分，tag name + tag value 的格式， 与 metrics 数据的格式是一致的。
因此，如果用存储 metrics 数据的方式来存储标签部分，那么就可以利用 tsdb 的存储引擎来高效过滤日志。

对一些基本概念总结如下：
![](../assets/img/8/VictoriaLogs.png)

* tag value 为空时，相当于不存在这个 tag，不会写入对应的数据。
* tag name 最多 128 字节，超过这个长度会被截断
* message 字段的 tag name 是 _msg
  - 写入索引时，message 对应的 tag name 是空字符串
* tenantID 概念：用户可以使用两个 uint32 来表示一个 tenantID
  - 区分 tenantID 后，每次查询比如提供正确的 tenantID


## 数据的目录结构
VictoriaLogs 存储数据的目录结构如下：

- partitions
  - 20060102 (日志数据的切换周期为天)
    - indexdb (索引文件夹)
        - parts.json
        - part 文件夹(uuid 命名的 part 文件夹)
            - metaindex.bin
            - index.bin
            - items.bin
            - lens.bin
    - datadb  (数据文件夹)
        - parts.json
        - part 目录  (运行的时候会区分是大part还是小part,  smallPart / bigPart )
            - column_names.bin
            - metaindex.bin
            - index.bin
            - columns_header_index.bin
            - columns_header.bin
            - timestamps.bin
            - message_bloom.bin  (part 下面又有 block 的概念，一个 block 只存储同一个 streamID 的日志数据)
            - message_values.bin

有这样一些特性：
* VictoriaLogs 启动时，超过保存天数的文件夹会被删除
* 每天会建立一个新的文件夹，文件夹中包含索引和数据
* 进程启动时还会创建锁文件：flock.lock

## streamID 的概念
变化不频繁的 tag 可以作为 stream 的区分字段。
例如：idc + 机器ip + 容器 构成一个 stream
从而，同一个容器的日志会被放在内部的一个 stream 中。

注意：频繁变化的字段，一定不要放在 stream 中。例如 client ip, user id 等。

所有的 stream tag 放在一个 buffer 中，然后使用 xxhash 库计算 128 bit 的 hash 值。此 hash 值就是 streamID

## 索引的格式
日志中的所有 tag 都会建立索引

```go
// lib/logstorage/indexdb.go:20
const (
	// (tenantID:streamID) entries have this prefix
	//
	// These entries are used for detecting whether the given stream is already registered
	nsPrefixStreamID = 0

	// (tenantID:streamID -> streamTagsCanonical) entries have this prefix
	nsPrefixStreamIDToStreamTags = 1

	// (tenantID:name:value => streamIDs) entries have this prefix
	nsPrefixTagToStreamIDs = 2
)
```

根据源码可知：
* 0 是 streamID 的索引
* 1 是 streamID 到 stream tag 的索引
* 2 是 tag name + tag value -> streamID 的索引

日志中所有的 tag 都会建立索引，最多允许 1000 个 tag.

```go
	// Register tenantID:name:value -> streamIDs entries.
	tags := st.tags
	for i := range tags {
		bufLen = len(buf)
		buf = marshalCommonPrefix(buf, nsPrefixTagToStreamIDs, tenantID)
		buf = tags[i].indexdbMarshal(buf)
		buf = streamID.id.marshal(buf)
		items = append(items, buf[bufLen:])
	}
```

## cache 结构

### streamID cache

* key: 分区名 + streamID
* value: bool 值，表示存在此 streamID

### filterStreamCache

## 数据 block 的细节

### block header
一个 column 序列化时，会判断列属于什么数据类型。
列的数据类型如下：

```go
// lib/logstorage/values_encoder.go
// valueType is the type of values stored in every column block.
type valueType byte

const (
	// valueTypeUnknown is used for determining whether the value type is unknown.
	valueTypeUnknown = valueType(0)

	// default encoding for column blocks. Strings are stored as is.
	valueTypeString = valueType(1)

	// column blocks with small number of unique values are encoded as dict.
	valueTypeDict = valueType(2)

	// uint values up to 2^8-1 are encoded into valueTypeUint8.
	// Every value occupies a single byte.
	valueTypeUint8 = valueType(3)

	// uint values up to 2^16-1 are encoded into valueTypeUint16.
	// Every value occupies 2 bytes.
	valueTypeUint16 = valueType(4)

	// uint values up to 2^31-1 are encoded into valueTypeUint32.
	// Every value occupies 4 bytes.
	valueTypeUint32 = valueType(5)

	// uint values up to 2^64-1 are encoded into valueTypeUint64.
	// Every value occupies 8 bytes.
	valueTypeUint64 = valueType(6)

	// int values in the range [-(2^63) ... 2^63-1] are encoded into valueTypeInt64.
	valueTypeInt64 = valueType(10)

	// floating-point values are encoded into valueTypeFloat64.
	valueTypeFloat64 = valueType(7)

	// column blocks with ipv4 addresses are encoded as 4-byte strings.
	valueTypeIPv4 = valueType(8)

	// column blocks with ISO8601 timestamps are encoded into valueTypeTimestampISO8601.
	// These timestamps are commonly used by Logstash.
	valueTypeTimestampISO8601 = valueType(9)
)
```

** 从这里可以看出：VictoriaLogs 花费大量的算力在对数据进行编码，从而节省存储空间。**

为了达到高压缩率，对数据的探测其实是比较耗资源的：

```go
// lib/logstorage/values_encoder.go
func (ve *valuesEncoder) encode(values []string, dict *valuesDict) (valueType, uint64, uint64) {
	ve.reset()

	if len(values) == 0 {
		return valueTypeString, 0, 0
	}

	var vt valueType
	var minValue, maxValue uint64

	// Try dict encoding at first, since it gives the highest speedup during querying.
	// It also usually gives the best compression, since every value is encoded as a single byte.
	ve.buf, ve.values, vt = tryDictEncoding(ve.buf[:0], ve.values[:0], values, dict)
	if vt != valueTypeUnknown {
		return vt, 0, 0
	}
	// todo: 值得使用 simd 来优化整数转换
	ve.buf, ve.values, vt, minValue, maxValue = tryUintEncoding(ve.buf[:0], ve.values[:0], values)
	if vt != valueTypeUnknown {
		return vt, minValue, maxValue
	}

	ve.buf, ve.values, vt, minValue, maxValue = tryIntEncoding(ve.buf[:0], ve.values[:0], values)
	if vt != valueTypeUnknown {
		return vt, minValue, maxValue
	}

	ve.buf, ve.values, vt, minValue, maxValue = tryFloat64Encoding(ve.buf[:0], ve.values[:0], values)
	if vt != valueTypeUnknown {
		return vt, minValue, maxValue
	}

	ve.buf, ve.values, vt, minValue, maxValue = tryIPv4Encoding(ve.buf[:0], ve.values[:0], values)
	if vt != valueTypeUnknown {
		return vt, minValue, maxValue
	}

	ve.buf, ve.values, vt, minValue, maxValue = tryTimestampISO8601Encoding(ve.buf[:0], ve.values[:0], values)
	if vt != valueTypeUnknown {
		return vt, minValue, maxValue
	}

	// Fall back to default encoding, e.g. leave values as is.
	ve.values = append(ve.values[:0], values...)
	return valueTypeString, 0, 0
}
```

## 相关文章

* [VictoriaLogs Source Reading](https://medium.com/@waynest/victorialogs-source-reading-833db3e8511b)
