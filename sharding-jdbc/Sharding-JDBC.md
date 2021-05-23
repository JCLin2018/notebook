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

首先我们来验证一下user_info表的取模分片(modulo['mod jul eu] ) 。

我们根据userid， 把用户数据划分到两个数据节点上。

在本地创建两个数据库ds 0和ds 1， 都userinfo创建表：

```sql
CREATE TABLE `user_info` (
`user_id` bigint(19) NOT NULL,
`user_name` varchar(45) DEFAULT NULL,
`account` varchar(45) NOT NULL,
`password` varchar(45) DEFAULT NULL,
PRIMARYKEY(`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
```

这里只定义了分库策略，没有定义单库内的分表策略，两个库都是相同的表名。

路由的结果：dsO.user_info，ds1.user_info。

如果定义了分库策略，两个库里面都有两张表，那么路由的结果可能是4种：

ds0.user_info0, ds0.user_info1
ds1.user_info0, ds1.user_info1 

```properties 
spring.shardingsphere.sharding.tables.user_info.actual-data-nodes=dsS->{0..1}.user_info
spring.shardingsphere.sharding.tables.user_info.databaseStrategy.inline.shardingColumn=user_id
spring.shardingsphere.sharding.tables.user_info.databaseStrategy.inline.algorithm-expression=ds${user_id%2}
```

首先两个数据库的user_info表里面没有任何数据。

在单元测量测试类UserSharding Test里面， 执行insert()， 调用Mapper接口循环插入100条数据。

我们看一下插入的结果。user_id为偶数的数据， 都落到了第一个库。user_id为奇数的数据，都落到了第二个库。

执行select() 测一下查询， 看看数据分布在两个节点的时候， 我们用程序查询， 能不能取回正确的数据。

#### 2.4.2绑定表

第二种是绑定表，也就是父表和子表有关联关系。主表和子表使用相同的分片策略。

```sql
CREATE TABLE `t_order`(
`order_id`int(11) NOT NULL，
`user_id`int(11) NOT NULL，
PRIMARYKEY(`order_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;


CREATE TABLE `t_order_item` (
`item_id`int(11) NOT NULL，
`order_id`int(11) NOT NULL，
`user_id`int(11) NOT NULL，
PRIMARYKEY(`item_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
```

绑定表将使用主表的分片策略。

```properties
# 分库算法t order多库分表
spring.shardingsphere.sharding.tables.t_order.database Strategy.inline.shardingColumn=order_id
spring.shardingsphere.sharding.tables.t_order.database Strategy.inline.algorithm-expression=dsS{order_id%2}
spring.shardingsphere.sharding.tables.t_order.actual-data-nodes=ds$->{0..1}.t_order

# 分库算法t_order_item多库分表
spring.shardingsphere.sharding.tables.t_order_item.database Strategy.inline.shardingColumn=order_id
spring.shardingsphere.sharding.tables.t_order_item.database Strategy.inline.algorithm-expression=dsS{order_id%2}
spring.shardingsphere.sharding.tables.t_order_item.actual-data-nodes=ds$->{0..1}.t_order_item

# 绑定表规则列表，防止关联查询出现笛卡尔积
spring.shardingsphere.sharding.binding-tables[0]=t_order,t_order_item
```

除了定义分库和分表算法之外， 我们还需要多定义一个binding-tables。

绑定表不使用分片键查询时，会出现笛卡尔积。

什么叫笛卡尔积?假如有2个数据库，两张表要相互关联，两张表又各有分表，那么SQL的执行路径就是2*2*2=8种。

不适用分片键：

![image-20210523105718702](https://notebook1.oss-cn-shenzhen.aliyuncs.com/img/sharding_jdbc/20210523105718.png)



使用分片键：

![image-20210523105747771](https://notebook1.oss-cn-shenzhen.aliyuncs.com/img/sharding_jdbc/20210523105747.png)

(mycat不支持这种二维的路由， 要么是分库， 要么是分表)

我们去看一下测试的代码OrderS hardingTest和OrderltemShardingTest。

先插入主表的数据，再插入子表的数据。

先看插入。再看查询。

#### 2.4.3广播表

最后一种是广播表，也就是需要在所有节点上同步操作的数据表。

```properties
spring.shardingsphere.sharding.broadcast-tables=t_config
```

我们用broadcast-tables来定义。

ConfigS harding Test java

插入和更新都会在所有节点上执行，查询呢?随机负载。



#### 2.4.4读写分离

参考spring-boot-s harding-jdbc

在com.qing shan.jdbc.Master Slave Test里面已经验证过了。

```yaml
master-slave-rules:
  master0:
    master-data-source-name: master0
    slave-data-source-names: slave0
  master1:
    master-data-source-name: master1
    slave-data-source-names: slave1
```

OK， 这个就是S harding-JDBC里面几种主要的表类型的分片验证。

如果我们需要更加复杂的分片策略， properties文件中行内表达式的这种方式肯定满足不了。实际上properties里面的分片策略可以指定， 比如user_info表的分库和分表策略。

```properties
spring.shardingsphere.sharding.tables.user_info.tableStrategy.standard.shardingColumn=
spring.shardingsphere.sharding.tables.user_info.tableStrategy.standard.preciseAlgorithmClassName=
spring.shardingsphere.sharding.tables.user_info.tableStrategy.standard.rangeAlgorithmClassName=
```


这个时候我们需要了解S harding-JDBC中几种不同的分片策略。

## 3.分片策略详解

https://shardingsphere.apache.org/document/current/cn/features/sharding/concept/sharding/

工程：gu pao-shard-java config

Sharding-JDBC中的分片策略有两个维度：分库(数据源分片) 策略和分表策略。

分库策略表示数据路由到的物理目标数据源，分表分片策略表示数据被路由到的目标表。分表策略是依赖于分库策略的，也就是说要先分库再分表，当然也可以不分库只分表。

跟My cat不一样， S harding-JDBC没有提供内置的分片算法， 而是通过抽象成接口，让开发者自行实现，这样可以根据业务实际情况灵活地实现分片。



### 3.1分片策略

包含分片键和分片算法，分片算法是需要自定义的。可以用于分库，也可以用于分表。

Sharding-JDBC提供了5种分片策略(接口) ， 策略全部继承自ShardingStrategy，可以根据情况选择实现相应的接口。

![image-20210523110744571](https://notebook1.oss-cn-shenzhen.aliyuncs.com/img/sharding_jdbc/20210523110744.png)

#### 3.1.1行表达式分片策略

https://shardingsphere.apache.org/document/current/cn/features/sharding/concept/inline-expression/

对应InlineShardingStrategy类。只支持单分片键， 提供对=和in操作的支持。行内表达式的配置比较简单。

例如：

- ${begin..end} 表示范围区间
- ${[unit1, unit2, unit_x]}表示枚举值
- t_user_$->{u_id%8}表示t_user表根据u_id模8, 而分成8张表, 表名称为t_user_0到t_user_7。

行表达式中如果出现连续多个${expression} 或$->{expression} 表达式， 整个表达式最终的结果将会根据每个子表达式的结果进行笛卡尔组合。

例如，以下行表达式：

- ${['db1', 'db2']} _table${1..3}
- 最终会解析为：
  db1_table1, db_1_table2, db_1_table3,
  db2_table1, db_2_table2, db_2_table3 



#### 3.1.2标准分片策略

对应StandardS harding Strategy类。

标准分片策略只支持单分片键， 提供了提供PreciseShardingAlgorithm和RangeShardingAlgorithm两个分片算法， 分别对应于SQL语句中的=，IN和BETWEEN AND。

如果要使用标准分片策略， 必须要实现PreciseShardingAlgorithm， 用来处理=和in的分片。RangeShardingAlgorithm是可选的。如果没有实现， SQL语句会发到所有的数据节点上执行。

#### 3.1.3复合分片策略

比如：根据日期和ID两个字段分片，每个月3张表，先根据日期，再根据ID取模。

对应ComplexShardingStrategy类。可以支持等值查询和范围查询。

复合分片策略支持多分片键，提供了ComplexKeysShardingAlgorithm， 分片算法需要自己实现。

#### 3.1.4Hint分片策略

https://shardingsphere.apache.org/document/current/cn/user-manual/shardingsphere-idbc/usage/sharding/hint/

对应HintShardingStrategy。通过Hint而非SQL解析的方式分片的策略。有点类似于My cat的指定分片注解。

#### 3.1.5不分片策略

对应NoneShardingStrategy。不分片的策略(只在一个节点存储) 。

### 3.2分片算法

创建了分片策略之后，需要进一步实现分片算法，作为参数传递给分片策略。

Sharding-JDBC目前提供4种分片算法。

#### 3.2.1精确分片算法

对应PreciseShardingAlgorithm， 用于处理使用单一键作为分片键的=与IN进行分片的场景。需要配合StandardShardingStrategy使用。

#### 3.2.2范围分片算法

对应RangeShardingAlgorithm， 用于处理使用单一键作为分片键的BETWEEN AND进行分片的场景。需要配合StandardShardingStrategy使用。

如果不配置范围分片算法，范围查询默认会路由到所有节点。

#### 3.2.3复合分片算法

对应ComplexKeysShardingAlgorithm， 用于处理使用多键作为分片键进行分片的场景，包含多个分片键的逻辑较复杂，需要应用开发者自行处理其中的复杂度。需要配合ComplexShardingStrategy使用。

#### 3.2.4Hint分片算法

对应HintShardingAlgorithm， 用于处理使用Hint行分片的场景。需要配合HintShardingStrategy使用。

#### 3.2.5自定义算法

所有的算法都需要实现对应的接口， 实现doSharding()方法：

例如：PreciseShardingAlgorithm

传入分片键，返回一个精确的分片(数据源名称)

```java
String doSharding(Collection<String> availableTargetNames, PreciseShardingValue<T> shardingValue);
```

RangeShardingAlgorithm

传入分片键，返回多个数据源名称

```java
Collection<String> doSharding(Collection<String> availableTargetNames, RangeShardingValue<T> shardingValue);
```

ComplexKeysShardingAlgorithm

传入多个分片键，返回多个数据源名称

```java
Collection<String> doSharding(Collection<String> availableTargetNames, Collection<ShardingValue> shardingValues);
```



## 4.Sharding-JDBC介绍

https://github.com/apache/shardingsphere
https://shardingsphere.apache.org/document/legacy/4.x/document/cn/overview/



### 发展历史

它是从当当网的内部架构ddframe里面的一个分库分表的模块脱胎出来的， 用来解决当当的分库分表的问题， 把跟业务相关的敏感的代码剥离后， 就得到了Sharding-JDBC。它是一个工作在客户端的分库分表的解决方案。

DubboX, Elastic-job也是当当开源出来的产品。

2018年5月， 因为增加了Proxy的版本和S harding-Sidecar(尚未发布)，Sharding-JDBC更名为ShardingSphere， 从一个客户端的组件变成了一个套件。

2018年11月， Sharding-Sphere正式进入Apache基金会孵化器， 这也是对Sharding-Sphere的质量和影响力的认可

2020年4月从Apache孵化器毕业， 成为Apache顶级项目。



### 基本特性

定位为轻量级Java框架， 在Java的JDBC层提供的额外服务。它使用客户端直连数据库， 以jar包形式提供服务， 无需额外部署和依赖， 可理解为增强版的JDBC驱动，完全兼容JDBC和各种ORM框架。

也就是说， 在maven的工程里面， 我们使用它的方式是引入依赖， 然后进行配置就可以了， 不用像My cat一样独立运行一个服务， 客户端不需要修改任何一行代码， 原来是SSM连接数据库， 还是SSM， 因为它是支持MyBatis的。

跟mycat一样， 因为数据源有多个， 所以要配置数据源， 而且分片规则是定义在客户端的。

第二个， 我们来看一下Sharding-JDBC的架构。

### 架构

我们在项目内引入Sharding-JDBC的依赖， 我们的业务代码在操作数据库的时候，就会通过S harding-JDBC的代码连接到数据库。

也就是分库分表的一些核心动作， 比如SQL解析， 路由， 执行， 结果处理， 都是由它来完成的。它工作在客户端。

![image-20210523112745557](https://notebook1.oss-cn-shenzhen.aliyuncs.com/img/sharding_jdbc/20210523112745.png)

当然， 在Sharding-Sphere里面同样提供了代理Proxy的版本， 跟Mycat的作用是一样的。S harding-Sidecar是一个Kubernetes的云原生数据库代理， 正在开发中。

|            | Sharding-JDBC | Sharding-Proxy | Sharding-Sidecar |
| ---------- | ------------- | -------------- | ---------------- |
| 数据库     | 任意          | Mysql          | Mysql            |
| 连接消耗数 | 高            | 低             | 高               |
| 异构语言   | 仅java        | 任意           | 任意             |
| 性能       | 损耗低        | 损耗高         | 损耗低           |
| 无中心化   | 是            | 否             | 是               |
| 静态入口   | 无            | 有             | 无               |



### 功能-全局ID

https://shardingsphere.apache.org/document/current/cn/features/sharding/concept/key-generator/

无中心化分布式主键 (包括UUID雪花SNOWFLAKE)

使用key-generator-column-name配置， 生成了一个18位的ID。

Properties配置：

```properties
spring.shardingsphere.sharding.tables.user_info.key-generator.column=user_id
spring.shardingsphere.sharding.tables.user_info.key-generator.type=SNOWFLAKE
```


keyGeneratorColumnName：指定需要生成ID的列

Key GenerotorClass：指定生成器类， 默认是DefaultKeyGenerator.java， 里面使用了雪花算法。

注意：ID要用BIGINT。Mapper.xml insert语句里面不能出现主键。否则会报错：

Sharding value must implements Comparable



## 5.分布式事务

我们用到分布式事务的场景有两种，一种是跨应用(比如微服务场景)，一种是单应用多个数据库(分库分表的场景)，对于代码层的使用来说的一样的。

### 1.事务概述

https://shardingsphere.apache.org/document/current/cn/features/transaction/

XA模型的不足：需要锁定资源
SEATA：支持AT、XA、TCC、SAGA
SEATA是一种全局事务的框架。

### 2.两阶段事务-XA

XA的依赖：

```xml
<dependency>
  <groupId>org.apache.sharding sphere</groupId>
  <artifactId>sharding-transaction-xa-core</artifactId>
  <version>4.1.1</version>
</dependency>
```

在Service类上加上注解

```java
@ShardingTransactionType(TransactionType.XA)
@Transactional(rollbackFor=Exception.class)
```

默认是用atomikos实现的。

其他事务类型：Local、BASE

模拟在两个节点上操作，id=2673、id=2674路由到两个节点，第二个节点插入两个相同对象，发生主键冲突异常，会发生回滚。

XA实现类：
XAShardingTransactionManager —— XATransactionManager —— AtomikosTransactionManager

### 3.柔性事务Seata

https://shardingsphere.apache.org/document/legacy/4.x/document/cn/manual/sharding-idbc/usage/transaction/
https://seata.io/zh-cn/docs/overview/what-is-seata.html
https://github.com/seata/seata
https://github.com/seata/seata-workshop



1. 需要额外部署Seat a-server服务进行分支事务的协调。

2. 使用@GlobalTransaction注解。引入依赖：

   ```xml
   <dependency>
     <groupId>org.apache.shardingsphere</groupId>
     <artifactId>sharding-transaction-base-seata-at</artifactId>
     <version>4.1.1</version>
   </dependency>
   ```

3. seata官方也提供了样例代码
   https://github.com/seata/seata-samples

## 6.Sharding-JDBC工作流程

https://shardingsphere.apache.org/document/current/cn/features/sharding/principle/

Sharding-JDBC的原理总结起来很简单：

SQL解析=>执行器优化=>SQL路由=>SQL改写=>SQL执行=>结果归并。

![image-20210523114131932](https://notebook1.oss-cn-shenzhen.aliyuncs.com/img/sharding_jdbc/20210523114132.png)



### 1.SQL解析

SQL解析主要是词法和语法的解析。目前常见的SQL解析器主要有fdb， jsqlparser和Druid.Sharding-JDBC 1.4.x之前的版本使用Druid作为SQL解析器。从1.5.x版本开始， Sharding-JDBC采用完全自研的SQL解析引擎。


### 2.SQL路由

![image-20210523114236211](https://notebook1.oss-cn-shenzhen.aliyuncs.com/img/sharding_jdbc/20210523114236.png)

SQL路由是根据分片规则配置以及解析上下文中的分片条件， 将SQL定位至真正的数据源。它又分为直接路由、简单路由和笛卡尔积路由。

直接路由， 使用Hint方式。

Binding表是指使用同样的分片键和分片规则的一组表， 也就是说任何情况下，Binding表的分片结果应与主表一致。例如：order表和order item表， 都根据order_id分片， 结果应是order_1与order_item_1成对出现。这样的关联查询和单表查询复杂度和性能相当。如果分片条件不是等于， 而是BETWEEN或IN， 则路由结果不一定落入单库(表) ， 因此一条逻辑SQL最终可能拆分为多条SQL语句。

笛卡尔积查询最为复杂， 因为无法根据Binding关系定位分片规则的一致性， 所以非Binding表的关联查询需要拆解为笛卡尔积组合执行。查询性能较低， 而且数据库连接数较高，需谨慎使用。

### 3.SQL改写

例如：将逻辑表名称改成真实表名称，优化分页查询等。

### 4.SQL执行

因为可能链接到多个真实数据源，Sharding-JDBC将采用多线程并发执行SQL。

### 5.结果归并

例如数据的组装、分页、排序等等。



## 7.Sharding-JDBC实现原理

ShardingJDBC在执行过程中， 主要是三个环节， 一个是解析配置文件。第二个是对SQL进行解析、路由和改写。第三个把结果集汇总到一起返回给客户端。

在这个里面我们最主关心的是第二部， 路由。也就是说， 怎么根据一个SQL语句，和配置好的分片规则，找到对应的数据库节点呢?

### 1.四大核心对象

我们说S harding-JDBC是一个增强版的JDBC驱动。那么， JDBC的四大核心对象，或者说最重要的4个接口是什么?

DataSource、Connection、Statement(PS) 、ResulstSet。

Sharding-JDBC实现了这四个核心接口， 在类名前面加上了Sharding。

Sharding DataSource、Sharding Connection、S harding Statement(PS)、ShardingResulstSet。

如果要在Java代码操作数据库的过程里面， 实现各种各样的逻辑， 肯定是要从数据源就开始替换成自己的实现。当然，因为在配置文件里面配置了数据源，启动的时候就创建好了。

问题就在于， 我们是什么时候用ShardingDataSource获取一个ShardingConnection的?

### 2.MyBatis数据源获取

Java API(com.qing shan.jdbc.Shard JDBC Test) 我们就不说了。

我们以整合了MyBatis的项目为例。MyBatis封装了JDBC的核心对象， 那么在MyBatis操作JDBC四大对象的时候， 就要替换成S harding-JDBC的四大对象。

我们的查询方法最终会走到SimpleExecutor的doQuery) 方法， 这个是我们的前提知识。
spring-boot-sharding-jdbc：com.qingshan.ShardTableTest

doQuery(方法里面调用了prepareStatement() 创建连接，通过ShardingDataSource返回了一个连接(衔接上了) 。

我们直接在prepareStatement() 打断点。

```java
private Statement prepare Statement(Statement Handler handler， Log statement Log) throws SQLException{
  Statement stmt；
  Connection connection=getConnection(statement Log) ；
  stmt=handler.prepare(connection， transaction.get Timeout() ) ；
  handler.parameterize(stmt) ；
  return stmt；
}
```

它经过以下两个方法， 返回了一个S harding Connection。

```java
DataSourceUtil.fetchConnection();
Connection con = dataSource.getConnection();
```

基于这个ShardingConnection， 最终得到一个ShardingPreparedStatement

```java
stmt = handler.prepare(connection, transaction.getTimeout());
```

接下来就是执行

```java
return handler.query(stmt, resultHandler);
```

再调用了的ShardingPreparedStatement的execute()

```java
public<E>List<E>query(Statement statement, ResultHandler resultHandler) throws SQLException{
  PreparedStatement ps = (PreparedStatement) statement;
  ps.execute();
  return resultSetHandler.handleResultSets(ps);
}
```

最终调用的是ShardingPreparedStatement的execute方法。

```java
public boolean execute() throws SQLException{
  try{
    clear Previous(O);
    prepare();
    initPreparedStatementExecutor();
    return preparedStatementExecutor.execute();
  } finally{
    refreshTableMetaData(connection.getShardingContext(), routeResult.getSqlStatement());
    clearBatch();
  }
}
```

prepare方法中， prepareEngine.prepare

```java
RouteContext routeContext = this.executeRoute(sql, clonedParameters);
```

执行路由

```
private Route Context execute Route(String sql, List<Object> clonedParameters) {
  this.registerRouteDecorator();
  return this.route(this.router, sql, clonedParameters);
}
```

最后到相应的路由执行引擎， 比如：ShardingStandardRoutingEngine。

SQL的解析路由就是在这一步完成的。







## 8.Sharding-Proxy介绍



下载地址：
https://shardingsphere.apache.org/document/current/cn/overview/#shardingsphere-proxy

bin目录就是存放启停脚本的， Linux运行start.sh启动(windows用start.bat) ，默认端口3307；

conf目录就是存放所有配置文件， 包括s harding-proxy服务的配置文件、数据源以及s harding规则配置文件和项目日志配置文件；

lib目录就是s harding-proxy核心代码， 以及依赖的JAR包。

需要的自定义分表算法， 只需要将它编译成class文件， 然后放到conf目录下， 也可以打成jar包放在lib目录下。

还有一个管理界面：
https://github.com/apache/shardingsphere/releases



## 9.Mycat对比

|            | Sharding-JDBC            | Mycat                               |
| ---------- | ------------------------ | ----------------------------------- |
| 工作层面   | JDBC协议                 | Mysql协议/JDBC协议                  |
| 运行方式   | Jar包，客户端            | 独立服务，服务端                    |
| 开发方式   | 代码/配置改动            | 连接地址                            |
| 运维方式   | 无                       | 管理独立服务，运维成本高            |
| 性能       | 多线程并发按操作，性能高 | 独立服务+网络开销，存在性能损失风险 |
| 功能范畴   | 协议层面                 | 包括分布式事务、数据迁移等          |
| 适用操作   | OLTP                     | OLTP+OLAP                           |
| 支持数据库 | 基于JDBC协议的数据库     | Mysql和其他JDBC协议的数据库         |
| 支持语言   | Java项目中使用           | 支持JDBC协议语言                    |

从易用性和功能完善的角度来说， Mycat似乎比Sharding-JDBC要好， 因为有现成的分片规则，也提供了4种ID生成方式，通过注解可以支持高级功能，比如跨库关联查询。

建议：小型项目可以用Sharding-JDBC。大型项目， 可以用Mycat。

















