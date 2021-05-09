# Sharding-JDBC使用方式

官网：https://shardingsphere.apache.org/document/legacy/4.x/document/cn/overview/
github：https://github.com/apache/shardingsphere



## 1.分片核心概念

- 逻辑表

  水平拆分的数据库（表）的相同逻辑和数据结构表的总称。例：订单数据根据主键尾数拆分为 10 张表，分别是 `t_order_0` 到 `t_order_9`，他们的逻辑表名为 `t_order`。

  ![image-20210509231139419](https://notebook1.oss-cn-shenzhen.aliyuncs.com/img/sharding_jdbc/20210509231139.png)

- 真实表

  在分片的数据库中真实存在的物理表。即上个示例中的 `t_order_0` 到 `t_order_9`。

- 分片表

- 数据节点

  数据分片的最小单元。由数据源名称和数据表组成，例：`ds_0.t_order_0`。

- 动态表

  ![image-20210509231334046](https://notebook1.oss-cn-shenzhen.aliyuncs.com/img/sharding_jdbc/20210509231334.png)

- 广播表

  指所有的分片数据源中都存在的表，表结构和表中的数据在每个数据库中均完全一致。适用于数据量不大且需要与海量数据的表进行关联查询的场景，例如：字典表。

- 绑定表

  ![image-20210509231742196](https://notebook1.oss-cn-shenzhen.aliyuncs.com/img/sharding_jdbc/20210509231742.png)

  指分片规则一致的主表和子表。例如：`t_order` 表和 `t_order_item` 表，均按照 `order_id` 分片，则此两张表互为绑定表关系。绑定表之间的多表关联查询不会出现笛卡尔积关联，关联查询效率将大大提升。举例说明，如果 SQL 为：

  ```sql
  SELECT i.* FROM t_order o JOIN t_order_item i ON o.order_id=i.order_id WHERE o.order_id in (10, 11);
  ```

  在不配置绑定表关系时，假设分片键 `order_id` 将数值 10 路由至第 0 片，将数值 11 路由至第 1 片，那么路由后的 SQL 应该为 4 条，它们呈现为笛卡尔积：

  ```sql
  SELECT i.* FROM t_order_0 o JOIN t_order_item_0 i ON o.order_id=i.order_id WHERE o.order_id in (10, 11);
  SELECT i.* FROM t_order_0 o JOIN t_order_item_1 i ON o.order_id=i.order_id WHERE o.order_id in (10, 11);
  SELECT i.* FROM t_order_1 o JOIN t_order_item_0 i ON o.order_id=i.order_id WHERE o.order_id in (10, 11);
  SELECT i.* FROM t_order_1 o JOIN t_order_item_1 i ON o.order_id=i.order_id WHERE o.order_id in (10, 11);
  ```

  在配置绑定表关系后，路由的 SQL 应该为 2 条：

  ```sql
  SELECT i.* FROM t_order_0 o JOIN t_order_item_0 i ON o.order_id=i.order_id WHERE o.order_id in (10, 11);
  SELECT i.* FROM t_order_1 o JOIN t_order_item_1 i ON o.order_id=i.order_id WHERE o.order_id in (10, 11);
  ```

  其中 `t_order` 在 FROM 的最左侧，ShardingSphere 将会以它作为整个绑定表的主表。 所有路由计算将会只使用主表的策略，那么 `t_order_item` 表的分片计算将会使用 `t_order` 的条件。故绑定表之间的分区键要完全相同。



## 2.Sharding-JDBC使用

https://shardingsphere.apache.org/document/legacy/4.x/document/cn/quick-start/sharding-jdbc-quick-start/

### 2.1引入依赖

```xml
<dependency>
    <groupId>org.apache.shardingsphere</groupId>
    <artifactId>sharding-jdbc-core</artifactId>
    <version>${sharding-sphere.version}</version>
</dependency>
```



### 2.2API使用

#### 2.2.1数据分片

https://shardingsphere.apache.org/document/legacy/4.x/document/cn/manual/sharding-jdbc/usage/sharding/

**基于Java编码的规则配置**

Sharding-JDBC的分库分表通过规则配置描述，以下例子是根据user_id取模分库, 且根据order_id取模分表的两库两表的配置。

```java
// 配置真实数据源
Map<String, DataSource> dataSourceMap = new HashMap<>();

// 配置第一个数据源
BasicDataSource dataSource1 = new BasicDataSource();
dataSource1.setDriverClassName("com.mysql.jdbc.Driver");
dataSource1.setUrl("jdbc:mysql://localhost:3306/ds0");
dataSource1.setUsername("root");
dataSource1.setPassword("");
dataSourceMap.put("ds0", dataSource1);

// 配置第二个数据源
BasicDataSource dataSource2 = new BasicDataSource();
dataSource2.setDriverClassName("com.mysql.jdbc.Driver");
dataSource2.setUrl("jdbc:mysql://localhost:3306/ds1");
dataSource2.setUsername("root");
dataSource2.setPassword("");
dataSourceMap.put("ds1", dataSource2);

// 配置Order表规则
TableRuleConfiguration orderTableRuleConfig = new TableRuleConfiguration("t_order","ds${0..1}.t_order${0..1}");

// 配置分库 + 分表策略
orderTableRuleConfig.setDatabaseShardingStrategyConfig(new InlineShardingStrategyConfiguration("user_id", "ds${user_id % 2}"));
orderTableRuleConfig.setTableShardingStrategyConfig(new InlineShardingStrategyConfiguration("order_id", "t_order${order_id % 2}"));

// 配置分片规则
ShardingRuleConfiguration shardingRuleConfig = new ShardingRuleConfiguration();
shardingRuleConfig.getTableRuleConfigs().add(orderTableRuleConfig);

// 省略配置order_item表规则...
// ...

// 获取数据源对象
DataSource dataSource = ShardingDataSourceFactory.createDataSource(dataSourceMap, shardingRuleConfig, new Properties());
```

**基于Yaml的规则配置**

或通过Yaml方式配置，与以上配置等价：

```yaml
dataSources:
  ds0: !!org.apache.commons.dbcp.BasicDataSource
    driverClassName: com.mysql.jdbc.Driver
    url: jdbc:mysql://localhost:3306/ds0
    username: root
    password: 
  ds1: !!org.apache.commons.dbcp.BasicDataSource
    driverClassName: com.mysql.jdbc.Driver
    url: jdbc:mysql://localhost:3306/ds1
    username: root
    password: 
    
shardingRule:
  tables:
    t_order: 
      actualDataNodes: ds${0..1}.t_order${0..1}
      databaseStrategy: 
        inline:
          shardingColumn: user_id
          algorithmExpression: ds${user_id % 2}
      tableStrategy: 
        inline:
          shardingColumn: order_id
          algorithmExpression: t_order${order_id % 2}
    t_order_item: 
      actualDataNodes: ds${0..1}.t_order_item${0..1}
      databaseStrategy: 
        inline:
          shardingColumn: user_id
          algorithmExpression: ds${user_id % 2}
      tableStrategy: 
        inline:
          shardingColumn: order_id
          algorithmExpression: t_order_item${order_id % 2}
    DataSource dataSource = YamlShardingDataSourceFactory.createDataSource(yamlFile);
```

**使用原生JDBC**

通过ShardingDataSourceFactory或者YamlShardingDataSourceFactory工厂和规则配置对象获取ShardingDataSource，ShardingDataSource实现自JDBC的标准接口DataSource。然后可通过DataSource选择使用原生JDBC开发，或者使用JPA, MyBatis等ORM工具。 以JDBC原生实现为例：

```java
DataSource dataSource = YamlShardingDataSourceFactory.createDataSource(yamlFile);
String sql = "SELECT i.* FROM t_order o JOIN t_order_item i ON o.order_id=i.order_id WHERE o.user_id=? AND o.order_id=?";
try (
        Connection conn = dataSource.getConnection();
        PreparedStatement preparedStatement = conn.prepareStatement(sql)) {
    preparedStatement.setInt(1, 10);
    preparedStatement.setInt(2, 1001);
    try (ResultSet rs = preparedStatement.executeQuery()) {
        while(rs.next()) {
            System.out.println(rs.getInt(1));
            System.out.println(rs.getInt(2));
        }
    }
}
```

总结： 

ShardingDataSourceFactory 利用 ShardingRuleConfiguration 创建数据源。 

ShardingRuleConfiguration 可以包含多个 TableRuleConfiguration（多张表）， 每张表都可以通过 ShardingStrategyConfiguration 设置自己的分库和分表策略。

#### 2.2.2读写分离

https://shardingsphere.apache.org/document/legacy/4.x/document/cn/manual/sharding-jdbc/usage/read-write-splitting/

**基于Java编码的规则配置**

```java
// 配置真实数据源
Map<String, DataSource> dataSourceMap = new HashMap<>();

// 配置主库
BasicDataSource masterDataSource = new BasicDataSource();
masterDataSource.setDriverClassName("com.mysql.jdbc.Driver");
masterDataSource.setUrl("jdbc:mysql://localhost:3306/ds_master");
masterDataSource.setUsername("root");
masterDataSource.setPassword("");
dataSourceMap.put("ds_master", masterDataSource);

// 配置第一个从库
BasicDataSource slaveDataSource1 = new BasicDataSource();
slaveDataSource1.setDriverClassName("com.mysql.jdbc.Driver");
slaveDataSource1.setUrl("jdbc:mysql://localhost:3306/ds_slave0");
slaveDataSource1.setUsername("root");
slaveDataSource1.setPassword("");
dataSourceMap.put("ds_slave0", slaveDataSource1);

// 配置第二个从库
BasicDataSource slaveDataSource2 = new BasicDataSource();
slaveDataSource2.setDriverClassName("com.mysql.jdbc.Driver");
slaveDataSource2.setUrl("jdbc:mysql://localhost:3306/ds_slave1");
slaveDataSource2.setUsername("root");
slaveDataSource2.setPassword("");
dataSourceMap.put("ds_slave1", slaveDataSource2);

// 配置读写分离规则
MasterSlaveRuleConfiguration masterSlaveRuleConfig = new MasterSlaveRuleConfiguration("ds_master_slave", "ds_master", Arrays.asList("ds_slave0", "ds_slave1"));

// 获取数据源对象
DataSource dataSource = MasterSlaveDataSourceFactory.createDataSource(dataSourceMap, masterSlaveRuleConfig, new Properties());
```

**基于Yaml的规则配置**

或通过Yaml方式配置，与以上配置等价：

```yaml
dataSources:
  ds_master: !!org.apache.commons.dbcp.BasicDataSource
    driverClassName: com.mysql.jdbc.Driver
    url: jdbc:mysql://localhost:3306/ds_master
    username: root
    password: 
  ds_slave0: !!org.apache.commons.dbcp.BasicDataSource
    driverClassName: com.mysql.jdbc.Driver
    url: jdbc:mysql://localhost:3306/ds_slave0
    username: root
    password:
  ds_slave1: !!org.apache.commons.dbcp.BasicDataSource
    driverClassName: com.mysql.jdbc.Driver
    url: jdbc:mysql://localhost:3306/ds_slave1
    username: root
    password: 

masterSlaveRule:
  name: ds_ms
  masterDataSourceName: ds_master
  slaveDataSourceNames: [ds_slave0, ds_slave1]
  
props:
  sql.show: true
    DataSource dataSource = YamlMasterSlaveDataSourceFactory.createDataSource(yamlFile);
```

**使用原生JDBC**

通过YamlMasterSlaveDataSourceFactory工厂和规则配置对象获取MasterSlaveDataSource，MasterSlaveDataSource实现自JDBC的标准接口DataSource。然后可通过DataSource选择使用原生JDBC开发，或者使用JPA, MyBatis等ORM工具。 以JDBC原生实现为例：

```java
DataSource dataSource = YamlMasterSlaveDataSourceFactory.createDataSource(yamlFile);
String sql = "SELECT i.* FROM t_order o JOIN t_order_item i ON o.order_id=i.order_id WHERE o.user_id=? AND o.order_id=?";
try (
        Connection conn = dataSource.getConnection();
        PreparedStatement preparedStatement = conn.prepareStatement(sql)) {
    preparedStatement.setInt(1, 10);
    preparedStatement.setInt(2, 1001);
    try (ResultSet rs = preparedStatement.executeQuery()) {
        while(rs.next()) {
            System.out.println(rs.getInt(1));
            System.out.println(rs.getInt(2));
        }
    }
}
```

![image-20210509232642365](https://notebook1.oss-cn-shenzhen.aliyuncs.com/img/sharding_jdbc/20210509232642.png)

在 JDBC API 中使用，我们可以直接创建数据源。 

如果在 Spring 中使用，我们自定义的数据源怎么定义使用呢？因为数据源是容器管 理的，所以需要通过注解或者 xml 配置文件注入。



### 2.3Spring中使用

先来总结一下，第一个，使用的数据源需要用 Sharding-JDBC 的数据源。而不是容 器或者 ORM 框架定义的。这样才能保证动态选择数据源的实现。 

当然，流程是先由Sharding-JDBC 定义，再交给 Druid 放进池子里，再交给 MyBatis， 最后再注入到 Spring。最外层是 Spring，因为代码是从 Spring 开始调用的。 

第二个，因为 Sharding-JDBC 是工作在客户端的，所以我们要在客户端配置分库分 表的策略。跟 Mycat 不一样的是，Sharding-JDBC 没有内置各种分片策略和算法，需要 我们通过表达式或者自定义的配置文件实现。

总体上，需要配置的就是这两个，数据源和分片策略。 

配置的方式是多种多样的，在官网也有详细的介绍，大家可以根据项目的实际情况进行选择。

https://shardingsphere.apache.org/document/legacy/4.x/document/cn/manual/sharding-jdbc/configuration/

#### 2.3.1Java配置

表结构

```sql
CREATE TABLE `user_info` (
  `user_id` bigint(19) NOT NULL,
  `user_name` varchar(45) DEFAULT NULL,
  `account` varchar(45) NOT NULL,
  `password` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
```

DataSourceConfig.java

```java
import com.alibaba.druid.pool.DruidDataSource;
import org.apache.shardingsphere.api.config.sharding.ShardingRuleConfiguration;
import org.apache.shardingsphere.api.config.sharding.TableRuleConfiguration;
import org.apache.shardingsphere.api.config.sharding.strategy.StandardShardingStrategyConfiguration;
import org.apache.shardingsphere.shardingjdbc.api.ShardingDataSourceFactory;
import org.mybatis.spring.annotation.MapperScan;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Primary;
import org.springframework.jdbc.datasource.DataSourceTransactionManager;
import javax.sql.DataSource;
import java.sql.SQLException;
import java.util.HashMap;
import java.util.Map;
import java.util.Properties;

/**
 * 分片数据源配置，返回 ShardingDataSource
 */
@Configuration
@MapperScan(basePackages = "com.sendbp.mapper", sqlSessionFactoryRef = "sqlSessionFactory")
public class DataSourceConfig {
    @Bean
    @Primary
    public DataSource shardingDataSource() throws SQLException {
        // 配置真实数据源
        Map<String, DataSource> dataSourceMap = new HashMap<>();

        // 配置第一个数据源
        DruidDataSource dataSource1 = new DruidDataSource();
        dataSource1.setDriverClassName("com.mysql.cj.jdbc.Driver");
        dataSource1.setUrl("jdbc:mysql://127.0.0.1:3306/ds0");
        dataSource1.setUsername("root");
        dataSource1.setPassword("123456");
        dataSourceMap.put("ds0", dataSource1);

        // 配置第二个数据源
        DruidDataSource dataSource2 = new DruidDataSource();
        dataSource2.setDriverClassName("com.mysql.cj.jdbc.Driver");
        dataSource2.setUrl("jdbc:mysql://127.0.0.1:3306/ds1");
        dataSource2.setUsername("root");
        dataSource2.setPassword("123456");
        dataSourceMap.put("ds1", dataSource2);

        // 配置Order表规则
        TableRuleConfiguration orderTableRuleConfig = new TableRuleConfiguration("user_info", "ds${0..1}.user_info");

        // 分表策略，使用 Standard 自定义实现，这里没有分表，表名固定为user_info
        StandardShardingStrategyConfiguration tableInlineStrategy =
                new StandardShardingStrategyConfiguration("user_id", new TblPreShardAlgo(), new TblRangeShardAlgo());
        orderTableRuleConfig.setTableShardingStrategyConfig(tableInlineStrategy);

        // 分库策略，使用 Standard 自定义实现
        StandardShardingStrategyConfiguration dataBaseInlineStrategy =new StandardShardingStrategyConfiguration("user_id", new DBShardAlgo());
        orderTableRuleConfig.setDatabaseShardingStrategyConfig(dataBaseInlineStrategy);

        // 添加表配置
        ShardingRuleConfiguration shardingRuleConfig = new ShardingRuleConfiguration();
        shardingRuleConfig.getTableRuleConfigs().add(orderTableRuleConfig);

        // 获取数据源对象
        DataSource dataSource = ShardingDataSourceFactory.createDataSource(dataSourceMap, shardingRuleConfig, new Properties());
        return dataSource;
    }

    // 事务管理器
    @Bean
    public DataSourceTransactionManager transactitonManager(DataSource shardingDataSource) {
        return new DataSourceTransactionManager(shardingDataSource);
    }
}
```

DBShardAlgo.java

```java
import org.apache.shardingsphere.api.sharding.standard.PreciseShardingAlgorithm;
import org.apache.shardingsphere.api.sharding.standard.PreciseShardingValue;

import java.util.Collection;

/**
 * 数据库分库的策略，根据分片键，返回数据库名称
 */
public class DBShardAlgo implements PreciseShardingAlgorithm<Long> {
    @Override
    public String doSharding(Collection<String> collection, PreciseShardingValue<Long> preciseShardingValue) {
        String db_name="ds";
        Long num = preciseShardingValue.getValue()%2;
        db_name = db_name + num;
        for (String each : collection) {
            if (each.equals(db_name)) {
                return each;
            }
        }
        throw new IllegalArgumentException();
    }
}
```

TblPreShardAlgo.java

```java
import org.apache.shardingsphere.api.sharding.standard.PreciseShardingAlgorithm;
import org.apache.shardingsphere.api.sharding.standard.PreciseShardingValue;
import java.util.Collection;

/**
 * 等值查询使用的分片算法，包括in
 */
public class TblPreShardAlgo implements PreciseShardingAlgorithm<Long> {
    @Override
    public String doSharding(Collection<String> availableTargetNames, PreciseShardingValue<Long> shardingColumn) {
        // 不分表
        for (String tbname : availableTargetNames) {
            return tbname ;
        }
        throw new IllegalArgumentException();
    }
}
```

TblRangeShardAlgo.java

```java
import com.google.common.collect.Range;
import org.apache.shardingsphere.api.sharding.standard.RangeShardingAlgorithm;
import org.apache.shardingsphere.api.sharding.standard.RangeShardingValue;
import java.util.Collection;
import java.util.LinkedHashSet;

/**
 * 范围查询所使用的分片算法
 */
public class TblRangeShardAlgo implements RangeShardingAlgorithm<Long> {
    @Override
    public Collection<String> doSharding(Collection<String> availableTargetNames, RangeShardingValue<Long> rangeShardingValue) {
        System.out.println("范围-*-*-*-*-*-*-*-*-*-*-*---------------"+availableTargetNames);
        System.out.println("范围-*-*-*-*-*-*-*-*-*-*-*---------------"+rangeShardingValue);
        Collection<String> collect = new LinkedHashSet<>();
        Range<Long> valueRange = rangeShardingValue.getValueRange();
        for (Long i = valueRange.lowerEndpoint(); i <= valueRange.upperEndpoint(); i++) {
            for (String each : availableTargetNames) {
                if (each.endsWith(i % availableTargetNames.size() + "")) {
                    collect.add(each);
                }
            }
        }
        return collect;
    }
}
```

把数据源和分片策略都写在 Java Config 中，加上注解。它的特点是非常灵 活，我们可以实现各种定义的分片策略。但是缺点是，如果把数据源、策略都配置在 Java Config 中，就出现了硬编码，在修改的时候比较麻烦。

#### 2.3.2SpringBoot配置

表结构

```sql

数据库ds0,ds1

CREATE TABLE `user_info` (
  `user_id` bigint(128) NOT NULL,
  `user_name` varchar(45) DEFAULT NULL,
  `account` varchar(45) NOT NULL,
  `password` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `t_order` (
  `order_id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  PRIMARY KEY (`order_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `t_order_item` (
  `item_id` int(11) NOT NULL,
  `order_id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  PRIMARY KEY (`item_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `t_config` (
  `config_id` int(16) NOT NULL AUTO_INCREMENT,
  `para_name` varchar(255) DEFAULT NULL,
  `para_value` varchar(255) DEFAULT NULL,
  `para_desc` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`config_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

truncate table user_info;
truncate table t_order;
truncate table t_order_item;
truncate table t_config;
```

application.properties

```properties
# MyBatis配置
mybatis.mapper-locations=classpath:mapper/*.xml
mybatis.config-location=classpath:mybatis-config.xml

spring.shardingsphere.props.sql.show=true

# 数据源配置
spring.shardingsphere.datasource.names=ds0,ds1
spring.shardingsphere.datasource.ds0.type=com.alibaba.druid.pool.DruidDataSource
spring.shardingsphere.datasource.ds0.driver-class-name=com.mysql.jdbc.Driver
spring.shardingsphere.datasource.ds0.url=jdbc:mysql://192.168.44.121:3306/ds0
spring.shardingsphere.datasource.ds0.username=root
spring.shardingsphere.datasource.ds0.password=123456

spring.shardingsphere.datasource.ds1.type=com.alibaba.druid.pool.DruidDataSource
spring.shardingsphere.datasource.ds1.driver-class-name=com.mysql.jdbc.Driver
spring.shardingsphere.datasource.ds1.url=jdbc:mysql://192.168.44.121:3306/ds1
spring.shardingsphere.datasource.ds1.username=root
spring.shardingsphere.datasource.ds1.password=123456

# 默认策略
spring.shardingsphere.sharding.default-database-strategy.inline.sharding-column=user_id
spring.shardingsphere.sharding.default-database-strategy.inline.algorithm-expression=ds${user_id % 2}

# 分库算法 user_info，多库分表
# 单库内没有分表
spring.shardingsphere.sharding.tables.user_info.actual-data-nodes=ds$->{0..1}.user_info
spring.shardingsphere.sharding.tables.user_info.databaseStrategy.inline.shardingColumn=user_id
spring.shardingsphere.sharding.tables.user_info.databaseStrategy.inline.algorithm-expression=ds${user_id % 2}
spring.shardingsphere.sharding.tables.user_info.key-generator.column=user_id
spring.shardingsphere.sharding.tables.user_info.key-generator.type=SNOWFLAKE

# 分库算法 t_order 多库分表
spring.shardingsphere.sharding.tables.t_order.databaseStrategy.inline.shardingColumn=order_id
spring.shardingsphere.sharding.tables.t_order.databaseStrategy.inline.algorithm-expression=ds${order_id % 2}
spring.shardingsphere.sharding.tables.t_order.actual-data-nodes=ds$->{0..1}.t_order

# 分库算法 t_order_item 多库分表
spring.shardingsphere.sharding.tables.t_order_item.databaseStrategy.inline.shardingColumn=order_id
spring.shardingsphere.sharding.tables.t_order_item.databaseStrategy.inline.algorithm-expression=ds${order_id % 2}
spring.shardingsphere.sharding.tables.t_order_item.actual-data-nodes=ds$->{0..1}.t_order_item

# 绑定表规则列表，防止关联查询出现笛卡尔积
spring.shardingsphere.sharding.binding-tables[0]=t_order,t_order_item

# 广播表
spring.shardingsphere.sharding.broadcast-tables=t_config
```

DBShardAlgo.java

```java
import org.apache.shardingsphere.api.sharding.standard.PreciseShardingAlgorithm;
import org.apache.shardingsphere.api.sharding.standard.PreciseShardingValue;
import java.util.Collection;

/**
 * 数据库分库的策略，根据分片键，返回数据库名称
 */
public class DBShardAlgo implements PreciseShardingAlgorithm<Long> {
    @Override
    public String doSharding(Collection<String> collection, PreciseShardingValue<Long> preciseShardingValue) {
        String db_name="ds";
        Long num= preciseShardingValue.getValue()%2;
        db_name=db_name + num;
        System.out.println("----------------db_name:" + db_name);

        for (String each : collection) {
            System.out.println("ds:" + each);
            if (each.equals(db_name)) {
                return each;
            }
        }
        throw new IllegalArgumentException();
    }
}
```

TblPreShardAlgo.java

```java
import org.apache.shardingsphere.api.sharding.standard.PreciseShardingAlgorithm;
import org.apache.shardingsphere.api.sharding.standard.PreciseShardingValue;
import java.util.Collection;

/**
 * 等值查询使用的分片算法，包括in
 */
public class TblPreShardAlgo implements PreciseShardingAlgorithm<Long> {
    @Override
    public String doSharding(Collection<String> availableTargetNames, PreciseShardingValue<Long> shardingColumn) {
        // 不分表
        System.out.println("-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-availableTargetNames:" + availableTargetNames);
        for (String tbname : availableTargetNames) {
            return tbname;
        }
        throw new IllegalArgumentException();
    }
}
```

TblRangeShardAlgo.java

```java
import com.google.common.collect.Range;
import org.apache.shardingsphere.api.sharding.standard.RangeShardingAlgorithm;
import org.apache.shardingsphere.api.sharding.standard.RangeShardingValue;
import java.util.Collection;
import java.util.LinkedHashSet;

/**
 * 范围查询所使用的分片算法
 */
public class TblRangeShardAlgo implements RangeShardingAlgorithm<Long> {
    public Collection<String> doSharding(Collection<String> availableTargetNames, RangeShardingValue<Long> rangeShardingValue) {
        Collection<String> collect = new LinkedHashSet<>();
        Range<Long> valueRange = rangeShardingValue.getValueRange();
        for (Long i = valueRange.lowerEndpoint(); i <= valueRange.upperEndpoint(); i++) {
            // 不分表
            for (String each : availableTargetNames) {
                collect.add(each);
/*                if (each.endsWith(i % availableTargetNames.size() + "")) {
                    collect.add(each);
                }*/
            }
        }
        return collect;
    }
}
```

是直接使用 Spring Boot 的 application.properties 来配置，这个要基于 starter 模块。 

把数据源和分库分表策略都配置在 properties 文件中。这种方式配置比较简单，但 是不能实现复杂的分片策略，不够灵活。

#### 2.3.3yml配置

application.yml

```yaml

mybatis:
  mapper-locations: classpath*:mapper/*.xml
  type-aliases-package: com.qingshan.entity

server:
  port: 8080

spring:
  application:
    name: spring-boot-sharding-jdbc
  # 数据源
  shardingsphere:
    datasource:
      names: master0,master1,slave0,slave1
      #数据库db
      master0:
        type: com.alibaba.druid.pool.DruidDataSource
        driver-class-name: com.mysql.jdbc.Driver
        url: jdbc:mysql://192.168.44.121:3306/ds0
        username: root
        password: 123456
      master1:
        type: com.alibaba.druid.pool.DruidDataSource
        driver-class-name: com.mysql.jdbc.Driver
        url: jdbc:mysql://192.168.44.121:3306/ds1
        username: root
        password: 123456
      slave0:
        type: com.alibaba.druid.pool.DruidDataSource
        driver-class-name: com.mysql.jdbc.Driver
        url: jdbc:mysql://192.168.44.128:3306/ds0
        username: root
        password: 123456
      slave1:
        type: com.alibaba.druid.pool.DruidDataSource
        driver-class-name: com.mysql.jdbc.Driver
        url: jdbc:mysql://192.168.44.128:3306/ds1
        username: root
        password: 123456
    sharding:
#      default-database-strategy:
#        inline:
#          sharding-column: user_id
#          algorithm-expression: master$->{user_id % 2}
      tables:
        user_info: #user_info表
          #key-generator-column-name: user_id #主键
          actual-data-nodes: master$->{0..1}.user_info    #数据节点,均匀分布
          database-strategy:   #分库策略
            inline: #行表达式
              sharding-column: user_id        #列名称，多个列以逗号分隔
              algorithm-expression: master$->{user_id % 2}    #按模运算分配
#          table-strategy:  #分表策略
#            inline: #行表达式
#              sharding-column: user_id
#              algorithm-expression: user_info_$->{user_id % 2}
        t_order: # order表
          #key-generator-column-name: order_id #主键
          actual-data-nodes: master$->{0..1}.t_order   #数据节点,均匀分布
          database-strategy:   #分库策略
            inline: #行表达式
              sharding-column: order_id        #列名称，多个列以逗号分隔
              algorithm-expression: master$->{order_id % 2}    #按模运算分配
        t_order_item: # t_order_item 表
          #key-generator-column-name: order_id #主键
          actual-data-nodes: master$->{0..1}.t_order_item   #数据节点,均匀分布
          database-strategy:   #分库策略
            inline: #行表达式
              sharding-column: order_id        #列名称，多个列以逗号分隔
              algorithm-expression: master$->{order_id % 2}    #按模运算分配
#          table-strategy:  #分表策略
#            inline: #行表达式
#              sharding-column: order_id
#              algorithm-expression: t_order_item_$->{order_id % 2}
#      masterslave: #读写分离
#        load-balance-algorithm-type: round_robin
#        name: ms
      master-slave-rules: #这里配置读写分离的时候一定要记得添加主库的数据源名称 这里为master0
        master0: #指定master0为主库，slave0为它的从库
          master-data-source-name: master0
          slave-data-source-names: slave0
        master1: #指定master1为主库，slave1为它的从库
          master-data-source-name: master1
          slave-data-source-names: slave1
      binding-tables: t_order,t_order_item
      broadcast-tables:
    props:
      sql: #打印sql
        show: true
```



使用 Spring Boot 的 yml 配置（shardingjdbc.yml），也要依赖 starter模块。当然我们也可以结合不同的配置方式，比如把分片策略放在 JavaConfig 中，数据 源配置在 yml 中或 properties 中。

这里面配置了读写分离，确认一下查询是否发生在 slave 上。

```sh
stop slave;
SET GLOBAL SQL_SLAVE_SKIP_COUNTER=1;
start slave;
show slave status\G
```



### 2.4Sharding-JDBC分片方案验证

切分到本地的两个库ds0，ds1。

两个库里面都是相同的4张表：user_info、t_order、t_order_item、t_config

当 我 们 使 用 了 Sharding-JDBC 的 数 据 源 以 后 ， 对 于 数 据 的 操 作 会 交 给 Sharding-JDBC 的代码来处理。 

先来给大家普及一下，分片策略从维度上分成两种，一种是分库，一种是分表。 

我们可以定义默认的分库分表策略，例如：用 user_id 作为分片键。 

这里用到了一种分片策略的实现，叫做行内表达式。我们对 user_id 取模，然后选择数据 库。如果模 2 等于 0，在第一个数据库中。模 2 等于 1，在第二个数据库中。 

数据源名称是行内表达式组装出来的。

```properties
spring.shardingsphere.sharding.tables.user_info.actual-data-nodes=ds$->{0..1}.user_info
```



对于不同的表，也可以单独配置分库策略（databaseStrategy）和分表策略 （tableStrategy）。案例中只有分库没有分表，所以没定义 tableStrategy。

#### 2.4.1取模分片



#### 2.4.2绑定表

#### 2.4.3广播表

#### 2.4.4读写分离



## 3.分片策略详解

### 3.1分片策略

#### 3.1.1行表达式分片策略

#### 3.1.2标准分片策略

#### 3.1.3复合分片策略

#### 3.1.4Hint分片策略

#### 3.1.5不分片策略

### 3.2分片算法

#### 3.2.1精确分片算法

#### 3.2.2范围分片算法

#### 3.2.3复合分片算法

#### 3.2.4Hint分片算法

#### 3.2.5自定义算法



## 4.Sharding-JDBC介绍

### 发展历史

### 基本特性

### 架构

### 功能-全局ID





## 5.分布式事务

### 1.事务概述

### 2.两阶段事务-XA

### 3.柔性事务Seata



## 6.Sharding-JDBC工作流程

### 1.SQL解析

### 2.SQL路由

### 3.SQL改写

### 4.SQL执行

### 5.结果归并





## 7.Sharding-JDBC实现原理

### 1.四大核心对象

### 2.MyBatis数据源获取



## 8.Sharding-Proxy介绍



## 9.Mycat对比





















