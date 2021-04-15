# Eureka原理分析

**分布式系统的CAP理论**

理论首先把分布式系统中的三个特性进行了如下归纳：
- 一致性（C）：在分布式系统中的所有数据备份，在同一时刻是否同样的值。（等同于所有节点访问同一份最新的数据副本）
- 可用性（A）：在集群中一部分节点故障后，集群整体是否还能响应客户端的读写请求。（对数据更新具备高可用性）
- 分区容错性（P）：以实际效果而言，分区相当于对通信的时限要求。系统如果不能在时限内达成数据一致性，就意味着发生了分区的情况，必须就当前操作在C和A之间做出选择。

Eureka是AP模型，索引导致他的实时性不强，最迟知道服务状态时间为90s。

## Eureka如何注入到SpringIOC容器

### Eureka利用了Spring容器级生命周期LifeCycle
`
**Lifecycle接口**

任何Spring管理的对象都可以实现此接口。当ApplicationContext接口启动和关闭时，它会调用本容器内所有的Lifecycle实现。

```java
public interface Lifecycle {
    void start();
    void stop();
    boolean isRunning();
}
```

**LifecycleProcessor接口**

它继承Lifcycle接口。同时，增加了2个方法，用于处理容器的refreshed和closed事件。

```java
public interface LifecycleProcessor extends Lifecycle {
    void onRefresh();
    void onClose();
}
```

**SmartLifecycle接口**

若两个对象有依赖关系（这种依赖不一定是一个bean引用另一个bean）,希望某些bean先初始化，完成一些工作后，再初始化另一些bean。在此场景中，可以使用SmartLifecycle接口,该接口有个方法getPhase(),实现了父接口Phased，它返回一个int型数字，表明执行顺序:

> 启动时，最小的phase最先启动，停止时相反。因此，若对象实现了SmartLifecycle接口，它的getPhase()方法返回Integer.MIN_VALUE，那么该对象最先启动，最后停止。若是getPhase()方法返回Integer.MAX_VALUE，那么该方法最后启动最先停止。关于phase的值，常规的并未实现SmartLifecycle接口的Lifecycle对象，其值默认为0。因此，负phase值表示要在常规Lifecycle对象之前启动（在常规Lifecycyle对象之后停止），使用正值则恰恰相反。

**Lifecycle触发流程**

```java
@SpringBootApplicationpublic class ServerEurekaApplication {    
    public static void main(String[] args) {        
        SpringApplication.run(ServerEurekaApplication.class, args);    
    }
}
```

```java
public ConfigurableApplicationContext run(String... args) {
    StopWatch stopWatch = new StopWatch();
    stopWatch.start();
    ConfigurableApplicationContext context = null;
    Collection<SpringBootExceptionReporter> exceptionReporters = new ArrayList<>();
    configureHeadlessProperty();
    SpringApplicationRunListeners listeners = getRunListeners(args);
    listeners.starting();
    try {
        ApplicationArguments applicationArguments = new DefaultApplicationArguments(args);
        ConfigurableEnvironment environment = prepareEnvironment(listeners, applicationArguments);
        configureIgnoreBeanInfo(environment);
        Banner printedBanner = printBanner(environment);
        context = createApplicationContext();
        exceptionReporters = getSpringFactoriesInstances(SpringBootExceptionReporter.class,
                new Class[] { ConfigurableApplicationContext.class }, context);
        prepareContext(context, environment, listeners, applicationArguments, printedBanner);
        refreshContext(context); // 在这里
        afterRefresh(context, applicationArguments);
        stopWatch.stop();
        if (this.logStartupInfo) {
            new StartupInfoLogger(this.mainApplicationClass).logStarted(getApplicationLog(), stopWatch);
        }
        listeners.started(context);
        callRunners(context, applicationArguments);
    }
    catch (Throwable ex) {
        handleRunFailure(context, ex, exceptionReporters, listeners);
        throw new IllegalStateException(ex);
    }
    // 代码省略...
```

最后到达org.springframework.context.support.AbstractApplicationContext#refresh

```java
@Override
public void refresh() throws BeansException, IllegalStateException {
    synchronized (this.startupShutdownMonitor) {
        // Prepare this context for refreshing.
        prepareRefresh();

        // Tell the subclass to refresh the internal bean factory.
        ConfigurableListableBeanFactory beanFactory = obtainFreshBeanFactory();

        // Prepare the bean factory for use in this context.
        prepareBeanFactory(beanFactory);

        try {
            // 代码省略 ....
            // Last step: publish corresponding event.
            finishRefresh(); // 在这里
        }

        catch (BeansException ex) {
        // 代码省略 ....
        
    }
}
```

```java
protected void finishRefresh() {
    // Clear context-level resource caches (such as ASM metadata from scanning).
    clearResourceCaches();

    // Initialize lifecycle processor for this context.
    initLifecycleProcessor(); // 初始化 Lifecycle, 应该有排序操作

    // Propagate refresh to lifecycle processor first.
    getLifecycleProcessor().onRefresh(); // Lifecycle#start方法

    // Publish the final event.
    publishEvent(new ContextRefreshedEvent(this));

    // Participate in LiveBeansView MBean, if active.
    LiveBeansView.registerApplicationContext(this);
}
```

### Eureka初始化配置

![](https://notebook1.oss-cn-shenzhen.aliyuncs.com/img/SpringCloud/eureka/Snipaste_2020-10-26_16-23-42.jpg)

org.springframework.cloud.netflix.eureka.server.EurekaServerInitializerConfiguration实现SmartLifecycle

```java
@Override
public void start() {
    new Thread(() -> {
        try {
            // TODO: is this class even needed now?
            eurekaServerBootstrap.contextInitialized(EurekaServerInitializerConfiguration.this.servletContext);
            log.info("Started Eureka Server");

            publish(new EurekaRegistryAvailableEvent(getEurekaServerConfig())); // 发布eureka注册可用事件
            EurekaServerInitializerConfiguration.this.running = true;
            publish(new EurekaServerStartedEvent(getEurekaServerConfig()));  // 发布eureka服务启动成功事件
        }
        catch (Exception ex) {
            // Help!
            log.error("Could not initialize Eureka servlet context", ex);
        }
    }).start();
}

@Override
public void stop() {      
    this.running = false;      
    eurekaServerBootstrap.contextDestroyed(this.servletContext);
}

private void publish(ApplicationEvent event) {      
    this.applicationContext.publishEvent(event);
}
```

org.springframework.cloud.netflix.eureka.serviceregistry.EurekaAutoServiceRegistration实现SmartLifecycle

```java
@Override
public void start() {
    // only set the port if the nonSecurePort or securePort is 0 and this.port != 0
    if (this.port.get() != 0) {
        if (this.registration.getNonSecurePort() == 0) {
            this.registration.setNonSecurePort(this.port.get());
        }
        if (this.registration.getSecurePort() == 0 && this.registration.isSecure()) {
            this.registration.setSecurePort(this.port.get());
        }
    }

    // only initialize if nonSecurePort is greater than 0 and it isn't already running
    // because of containerPortInitializer below
    if (!this.running.get() && this.registration.getNonSecurePort() > 0) {
        this.serviceRegistry.register(this.registration);
        this.context.publishEvent(new InstanceRegisteredEvent<>(this, this.registration.getInstanceConfig())); // 发布实例注册事件
        this.running.set(true);
    }
}

@Override
public void stop() {      
    this.serviceRegistry.deregister(this.registration);      
    this.running.set(false);
}
```

## Eureka的自我保护机制的原理


Eureka Server在运行期间会去统计心跳失败的比例在15分钟之内是否低于85% , 如果低于85%， Eureka Server会认为当前实例的客户端与自己的心跳连接出现了网络故障，那么Eureka Server会把这 些实例保护起来，让这些实例不会过期导致实例剔除。 

这样做的目的是为了减少网络不稳定或者网络分区的情况下，Eureka Server将健康服务剔除下线的问 题。 使用自我保护机制可以使得Eureka 集群更加健壮和稳定的运行。


进入自我保护状态后，会出现以下几种情况 
- Eureka Server不再从注册列表中移除因为长时间没有收到心跳而应该剔除的过期服务 
- Eureka Server仍然能够接受新服务的注册和查询请求，但是不会被同步到其他节点上，保证当前 节点依然可用。

在Eureka的自我保护机制中，有两个很重要的变量，Eureka的自我保护机制，都是围绕这两个变量来 实现的，在AbstractInstanceRegistry这个类中定义的

```java
protected volatile int numberOfRenewsPerMinThreshold;           // 每分钟最小续约数量（Eureka Server期望每分钟收到客户端实例续约的总数的阈值。如果小于这个阈值，就会触发自我保护机制）
protected volatile int expectedNumberOfClientsSendingRenews; // 预期每分钟收到续约的 客户端数量，取决于注册到eureka server上的服务数量
```

```java
protected void updateRenewsPerMinThreshold() {
    this.numberOfRenewsPerMinThreshold = (int) (this.expectedNumberOfClientsSendingRenews
            * (60.0 / serverConfig.getExpectedClientRenewalIntervalSeconds()) // 客户端的续约间隔，默认为30s
            * serverConfig.getRenewalPercentThreshold());  // 自我保护续约百分比阈值因子，默认0.85。 也就是说每分钟的续 约数量要大于85%
}
// 自我保护阀值 = 服务总数 * 每分钟续约数(60S / 客户端续约间隔) * 自我保护续约百分比阀值因子
// 例如：自我保护阀值 = 2 * (60s / 30s) * 0.85 = 2 * 2 * 0.85 = 3
```

**这两个变量是动态更新的，有四个地方来更新这两个值**

1. Eureka-Server的初始化 
在EurekaBootstrap这个类中，有一个 initEurekaServerContext 方法
```java
protected void initEurekaServerContext() throws Exception {
    EurekaServerConfig eurekaServerConfig = new DefaultEurekaServerConfig();
    //...
    registry.openForTraffic(applicationInfoManager, registryCount);
}
```
com.netflix.eureka.registry.PeerAwareInstanceRegistryImpl#openForTraffic
```java
@Override
public void openForTraffic(ApplicationInfoManager applicationInfoManager, int count) {
    // Renewals happen every 30 seconds and for a minute it should be a factor of 2.
    this.expectedNumberOfClientsSendingRenews = count;
    updateRenewsPerMinThreshold();  // 这里
    logger.info("Got {} instances from neighboring DS node", count);
    logger.info("Renew threshold is: {}", numberOfRenewsPerMinThreshold);
    this.startupTime = System.currentTimeMillis();
    if (count > 0) {
        this.peerInstancesTransferEmptyOnStartup = false;
    }
    DataCenterInfo.Name selfName = applicationInfoManager.getInfo().getDataCenterInfo().getName();
    boolean isAws = Name.Amazon == selfName;
    if (isAws && serverConfig.shouldPrimeAwsReplicaConnections()) {
        logger.info("Priming AWS connections for all replicas..");
        primeAwsReplicas(applicationInfoManager);
    }
    logger.info("Changing status to UP");
    applicationInfoManager.setInstanceStatus(InstanceStatus.UP);
    super.postInit();
}
```

2. PeerAwareInstanceRegistryImpl.cancel    服务主动下线

当服务提供者主动下线时，表示这个时候Eureka-Server要剔除这个服务提供者的地址，同时也代表这个心跳续约的阈值要发生变化。所以在 PeerAwareInstanceRegistryImpl.cancel 中可以看到数据的更新

调用路径 PeerAwareInstanceRegistryImpl.cancel -> AbstractInstanceRegistry.cancel- >internalCancel

服务下线之后，意味着需要发送续约的客户端数量递减了，所以在这里进行修改

```java
protected boolean internalCancel(String appName, String id, boolean isReplication) {
    // ...
    synchronized (lock) {
        if (this.expectedNumberOfClientsSendingRenews > 0) {
            // Since the client wants to cancel it, reduce the number of clients to send renews.
            this.expectedNumberOfClientsSendingRenews = this.expectedNumberOfClientsSendingRenews - 1;
            updateRenewsPerMinThreshold();  // 这里
        }
    }
    return true;
}
```

3. PeerAwareInstanceRegistryImpl.register  新服务注册上来

当有新的服务提供者注册到eureka-server上时，需要增加续约的客户端数量，所以在register方法中会 进行处理

register ->super.register(AbstractInstanceRegistry

```java
public void register(InstanceInfo registrant, int leaseDuration, boolean isReplication) {
    try {
        read.lock();
        // ...
        Lease<InstanceInfo> existingLease = gMap.get(registrant.getId());
        // Retain the last dirty timestamp without overwriting it, if there is already a lease
        if (existingLease != null && (existingLease.getHolder() != null)) {
            // ...
        } else {
            // The lease does not exist and hence it is a new registration
            synchronized (lock) {
                if (this.expectedNumberOfClientsSendingRenews > 0) {
                    // Since the client wants to register it, increase the number of clients sending renews
                    this.expectedNumberOfClientsSendingRenews = this.expectedNumberOfClientsSendingRenews + 1;
                    updateRenewsPerMinThreshold();  // 这里
                }
            }
        }
        // ...
    } finally {
        read.unlock();
    }
}
```

4. PeerAwareInstanceRegistryImpl.scheduleRenewalThreshold UpdateTask

15分钟运行一次，判断在15分钟之内心跳失败比例是否低于85%。在

DefaultEurekaServerContext -> @PostConstruct修饰的initialize()方法 -> init()

```java
private void scheduleRenewalThresholdUpdateTask() {
    timer.schedule(new TimerTask() {
                @Override
                public void run() {
                    updateRenewalThreshold();
                }
            }, serverConfig.getRenewalThresholdUpdateIntervalMs(),
    serverConfig.getRenewalThresholdUpdateIntervalMs());
}
private void updateRenewalThreshold() {
    try {
        Applications apps = eurekaClient.getApplications();
        int count = 0;
        for (Application app : apps.getRegisteredApplications()) {
            for (InstanceInfo instance : app.getInstances()) {
                if (this.isRegisterable(instance)) {
                    ++count;
                }
            }
        }
        synchronized (lock) {
            // Update threshold only if the threshold is greater than the
            // current expected threshold or if self preservation is disabled.
            if ((count) > (serverConfig.getRenewalPercentThreshold() * expectedNumberOfClientsSendingRenews)
                    || (!this.isSelfPreservationModeEnabled())) {
              	// 发送更新的客户端预期数量
                this.expectedNumberOfClientsSendingRenews = count;
                updateRenewsPerMinThreshold();  // 这里
            }
        }
        logger.info("Current renewal threshold is : {}", numberOfRenewsPerMinThreshold);
    } catch (Throwable e) {
        logger.error("Cannot update renewal threshold", e);
    }
}
```

### 自我保护机制触发任务

在AbstractInstanceRegistry的postInit方法中，会开启一个EvictionTask的任务，这个任务用来检测是否需要开启自我保护机制。






## Eureka执行流程

![](https://notebook1.oss-cn-shenzhen.aliyuncs.com/img/SpringCloud/eureka/Spring%20Cloud%20Eureka.jpg)

## EurekaServer如何接受请求

### Eureka Rest API

| 名称                       | 接口地址                                                  | 请求method | 源码地址                                                     |
| -------------------------- | --------------------------------------------------------- | ---------- | ------------------------------------------------------------ |
| 服务注册                   | /eureka/v2/apps/appID                                     | POST       | com.netflix.eureka.resources.ApplicationResource.addInstance() |
| 服务下线                   | /eureka/apps/appID/instanceID                             | DELETE     | com.netflix.eureka.resources.InstanceResource.cancelLease()  |
| 心跳续约                   | /eureka/apps/appID/instanceID                             | PUT        | com.netflix.eureka.resources.InstanceResource.renewLease()   |
| 获取所有注册信息           | /eureka/apps                                              | GET        | com.netflix.eureka.resources.ApplicationsResource.getContainers() |
| 获取某个应用下所有实例信息 | /eureka/apps/appID                                        | GET        | com.netflix.eureka.resources.ApplicationsResource.getApplicationResource() |
| 获取某个应用下指定的实例   | /eureka/apps/appID/instanceID                             | GET        | com.netflix.eureka.resources.ApplicationsResource.getApplicationResource() |
| 设置覆盖状态               | /eureka/apps/appID/instanceID/status?value=OUT_OF_SERVICE | PUT        | com.netflix.eureka.resources.InstanceResource.statusUpdate() |
| 更新实例的metadata信息     | /eureka/apps/appID/instanceID/metadata?key=value          | PUTE       | com.netflix.eureka.resources.InstanceResource.updateMetadata() |

ApplicationsResource.java
ApplicationResource.java
InstancesResource.java
InstanceResource.java

## EurekaClient如何注册

说spring cloud是一个生态，它提供了一套标准，这套标准可以通过不同的组件来实现，其中就包 含服务注册/发现、熔断、负载均衡等，在spring-cloud-common这个包中，`org.springframework.cloud.client.serviceregistry`路径下，可以看到一个服务注册的接口定义 `ServiceRegistry` 。它就是定义了spring cloud中服务注册的一个接口。

这个接口有一个唯一的实现 `EurekaServiceRegistry`。表示采用的是EurekaServer作为服务注册中心。

![](https://notebook1.oss-cn-shenzhen.aliyuncs.com/img/SpringCloud/eureka/Snipaste_2020-10-27_21-35-28.jpg)

### 服务注册的触发路径

服务的 注册取决于服务是否已经启动好了。而在spring boot中，会等到spring 容器启动并且所有的配置都完 成之后来进行注册。而这个动作在spring boot的启动方法中的refreshContext中完成。

```java
SpringApplication.run() -> this.refreshContext(context); ->this.refresh(context); -> ServletWebServerApplicationContext.refresh(); -> this.finishRefresh(); -> AbstractApplicationContext.finishRefresh(); -> getLifecycleProcessor().onRefresh(); -> this.startBeans(true); -> this.start(); -> this.doStart()
```

观察一下finishRefresh这个方法，从名字上可以看到它是用来体现完成刷新的操作，也就是刷新完 成之后要做的后置的操作。它主要做几个事情

- 清空缓存 
- 初始化一个LifecycleProcessor，在Spring启动的时候启动bean，在spring结束的时候销毁bean 
- 调用LifecycleProcessor的onRefresh方法，启动实现了Lifecycle接口的bean 
- 发布ContextRefreshedEvent 
- 注册MBean，通过JMX进行监控和管理

```java
protected void finishRefresh() {
    // Clear context-level resource caches (such as ASM metadata from scanning).
    clearResourceCaches();

    // Initialize lifecycle processor for this context.
    initLifecycleProcessor();

    // Propagate refresh to lifecycle processor first.
    getLifecycleProcessor().onRefresh();

    // Publish the final event.
    publishEvent(new ContextRefreshedEvent(this));

    // Participate in LiveBeansView MBean, if active.
    LiveBeansView.registerApplicationContext(this);
}
```

在这个方法中，我们重点关注 `getLifecycleProcessor().onRefresh()` ，它是调用生命周期处理器 的onrefresh方法，找到SmartLifecycle接口的所有实现类并调用start方法。


调用的可能是EurekaAutoServiceRegistration中的start方法，因为很显然，它实 现了SmartLifeCycle接口。

```java
public class EurekaAutoServiceRegistration implements AutoServiceRegistration, SmartLifecycle, Ordered, SmartApplicationListener {

    @Override
    public void start() {
        // only set the port if the nonSecurePort or securePort is 0 and this.port != 0
        if (this.port.get() != 0) {
            if (this.registration.getNonSecurePort() == 0) {
                this.registration.setNonSecurePort(this.port.get());
            }
            if (this.registration.getSecurePort() == 0 && this.registration.isSecure()) {
                this.registration.setSecurePort(this.port.get());
            }
        }

        // only initialize if nonSecurePort is greater than 0 and it isn't already running
        // because of containerPortInitializer below
        if (!this.running.get() && this.registration.getNonSecurePort() > 0) {
            this.serviceRegistry.register(this.registration);
            // 发布实例注册事件
            this.context.publishEvent(new InstanceRegisteredEvent<>(this, this.registration.getInstanceConfig())); 
            this.running.set(true);
        }
    }

    @Override
    public void stop() {      
        this.serviceRegistry.deregister(this.registration);      
        this.running.set(false);
    }
    
}
```

在start方法中，我们可以看到`this.serviceRegistry.register`这个方法，它实际上就是发起服务注册的机制。

此时this.serviceRegistry的实例，应该是 EurekaServiceRegistry ， 原因是 EurekaAutoServiceRegistration的构造方法中，会有一个赋值操作，而这个构造方法是在 EurekaClientAutoConfiguration 这个自动装配类中被装配和初始化的，代码如下

```java
@Bean
@ConditionalOnBean(AutoServiceRegistrationProperties.class)
@ConditionalOnProperty(value = "spring.cloud.service-registry.auto-registration.enabled", matchIfMissing = true)
public EurekaAutoServiceRegistration eurekaAutoServiceRegistration(ApplicationContext context, EurekaServiceRegistry registry, EurekaRegistration registration) {
    return new EurekaAutoServiceRegistration(context, registry, registration);
}
```

`this.serviceRegistry.register(this.registration);` 方法最终会调用 EurekaServiceRegistry 类中的 register 方法来实现服务注册。

**EurekaServiceRegistry.register**

```java
@Override
public void register(EurekaRegistration reg) {
    maybeInitializeClient(reg);

    if (log.isInfoEnabled()) {
        log.info("Registering application "
                + reg.getApplicationInfoManager().getInfo().getAppName()
                + " with eureka with status "
                + reg.getInstanceConfig().getInitialStatus());
    }
    // 设置当前实例的状态，一旦这个实例的状态发生变化，只要状态不是DOWN，那么就会被监听器监听并且执行服务注册。
    reg.getApplicationInfoManager().setInstanceStatus(reg.getInstanceConfig().getInitialStatus());
    // 设置健康检查的处理
    reg.getHealthCheckHandler().ifAvailable(healthCheckHandler -> reg.getEurekaClient().registerHealthCheck(healthCheckHandler));
}
```

从上述代码来看，注册方法中并没有真正调用Eureka的方法去执行注册，而是仅仅设置了一个状态以及设置健康检查处理器。我们继续看一下reg.getApplicationInfoManager().setInstanceStatus方法。

```java
public synchronized void setInstanceStatus(InstanceStatus status) {
    InstanceStatus next = instanceStatusMapper.map(status);
    if (next == null) {
        return;
    }

    InstanceStatus prev = instanceInfo.setStatus(next);
    if (prev != null) {
        for (StatusChangeListener listener : listeners.values()) {
            try {
                listener.notify(new StatusChangeEvent(prev, next));
            } catch (Exception e) {
                logger.warn("failed to notify listener: {}", listener.getId(), e);
            }
        }
    }
}
```

在这个方法中，它会通过监听器来发布一个状态变更事件。ok，此时listener的实例是 `StatusChangeListener` ，也就是调用 `StatusChangeListener` 的notify方法。这个事件是触发一个服 务状态变更，应该是有地方会监听这个事件，然后基于这个事件。

这个时候我们以为找到了方向，然后点击进去一看，卞击，发现它是一个接口。而且我们发现它是静态的内部接口，还无法直接看到它的实现类。

一定是在某个地方做了初始化的工作， 于是，找到EurekaServiceRegistry.register方法中的 reg.getApplicationInfoManager 这个实例 是什么，而且我们发现ApplicationInfoManager是来自于EurekaRegistration这个类中的属性。而 EurekaRegistration又是在EurekaAutoServiceRegistration这个类中实例化的。那我在想，是不是在自动装配中做了什么东西。于是找到EurekaClientAutoConfiguration这个类，果然看到了Bean的一些自动装配，其中包含 EurekaClient 、 ApplicationInfoMangager 、 EurekaRegistration 等。

`org.springframework.cloud.netflix.eureka.EurekaClientAutoConfiguration.EurekaClientConfiguration`
```java
@Configuration(proxyBeanMethods = false)
@ConditionalOnMissingRefreshScope
protected static class EurekaClientConfiguration {

    @Autowired
    private ApplicationContext context;

    @Autowired
    private AbstractDiscoveryClientOptionalArgs<?> optionalArgs;

    @Bean(destroyMethod = "shutdown")
    @ConditionalOnMissingBean(value = EurekaClient.class,
            search = SearchStrategy.CURRENT)
    public EurekaClient eurekaClient(ApplicationInfoManager manager,
            EurekaClientConfig config) {
        return new CloudEurekaClient(manager, config, this.optionalArgs,
                this.context);
    }

    @Bean
    @ConditionalOnMissingBean(value = ApplicationInfoManager.class,
            search = SearchStrategy.CURRENT)
    public ApplicationInfoManager eurekaApplicationInfoManager(
            EurekaInstanceConfig config) {
        InstanceInfo instanceInfo = new InstanceInfoFactory().create(config);
        return new ApplicationInfoManager(config, instanceInfo);
    }

    @Bean
    @ConditionalOnBean(AutoServiceRegistrationProperties.class)
    @ConditionalOnProperty(
            value = "spring.cloud.service-registry.auto-registration.enabled",
            matchIfMissing = true)
    public EurekaRegistration eurekaRegistration(EurekaClient eurekaClient,
            CloudEurekaInstanceConfig instanceConfig,
            ApplicationInfoManager applicationInfoManager, @Autowired(
                    required = false) ObjectProvider<HealthCheckHandler> healthCheckHandler) {
        return EurekaRegistration.builder(instanceConfig).with(applicationInfoManager)
                .with(eurekaClient).with(healthCheckHandler).build();
    }

}
```

不难发现，我们似乎看到了一个很重要的Bean在启动的时候做了自动装配，也就是 CloudEurekaClient 。从名字上来看，我可以很容易的识别并猜测出它是Eureka客户端的一个工具 类，用来实现和服务端的通信以及处理。这个很多源码一贯的套路，要么在构造方法里面去做很多的初 始化和一些后台执行的程序操作，要么就是通过异步事件的方式来处理。

接着，我们看一下CloudEurekaClient的初始化过程，它的构造方法中会通过 super 调用父类的构造方 法。也就是DiscoveryClient的构造

**CloudEurekaClient**

super(applicationInfoManager, config, args);调用父类的构造方法，而CloudEurekaClient的父类是 DiscoveryClient.

```java
public CloudEurekaClient(ApplicationInfoManager applicationInfoManager, EurekaClientConfig config, AbstractDiscoveryClientOptionalArgs<?> args, ApplicationEventPublisher publisher) {
    super(applicationInfoManager, config, args);
    this.applicationInfoManager = applicationInfoManager;
    this.publisher = publisher;
    this.eurekaTransportField = ReflectionUtils.findField(DiscoveryClient.class, "eurekaTransport");
    ReflectionUtils.makeAccessible(this.eurekaTransportField);
}
```
**DiscoveryClient**

我们可以看到在最终的DiscoveryClient改造方法中，有非常长的代码。其实很多代码可以不需要关心， 大部分都是一些初始化工作，比如初始化了几个定时任务

- scheduler 
- heartbeatExecutor 心跳定时任务 
- cacheRefreshExecutor 定时去同步服务端的实例列表

```java
@Inject
DiscoveryClient(ApplicationInfoManager applicationInfoManager, EurekaClientConfig config, AbstractDiscoveryClientOptionalArgs args,
                Provider<BackupRegistry> backupRegistryProvider, EndpointRandomizer endpointRandomizer) {
    // 省略部分代码...
    // 是否要从eureka server上获取服务地址信息
    if (config.shouldFetchRegistry()) {
        this.registryStalenessMonitor = new ThresholdLevelsMetric(this, METRIC_REGISTRY_PREFIX + "lastUpdateSec_", new long[]{15L, 30L, 60L, 120L, 240L, 480L});
    } else {
        this.registryStalenessMonitor = ThresholdLevelsMetric.NO_OP_METRIC;
    }
    // 是否要注册到eureka server上
    if (config.shouldRegisterWithEureka()) {
        this.heartbeatStalenessMonitor = new ThresholdLevelsMetric(this, METRIC_REGISTRATION_PREFIX + "lastHeartbeatSec_", new long[]{15L, 30L, 60L, 120L, 240L, 480L});
    } else {
        this.heartbeatStalenessMonitor = ThresholdLevelsMetric.NO_OP_METRIC;
    }

    logger.info("Initializing Eureka in region {}", clientConfig.getRegion());
    // 如果不需要注册并且不需要更新服务地址
    if (!config.shouldRegisterWithEureka() && !config.shouldFetchRegistry()) {
        logger.info("Client configured to neither register nor query for data.");
        scheduler = null;
        heartbeatExecutor = null;
        cacheRefreshExecutor = null;
        eurekaTransport = null;
        instanceRegionChecker = new InstanceRegionChecker(new PropertyBasedAzToRegionMapper(config), clientConfig.getRegion());

        // This is a bit of hack to allow for existing code using DiscoveryManager.getInstance()
        // to work with DI'd DiscoveryClient
        DiscoveryManager.getInstance().setDiscoveryClient(this);
        DiscoveryManager.getInstance().setEurekaClientConfig(config);

        initTimestampMs = System.currentTimeMillis();
        initRegistrySize = this.getApplications().size();
        registrySize = initRegistrySize;
        logger.info("Discovery Client initialized at timestamp {} with initial instances count: {}",
                initTimestampMs, initRegistrySize);

        return;  // no need to setup up an network tasks and we are done
    }

    try {
        // default size of 2 - 1 each for heartbeat and cacheRefresh
        scheduler = Executors.newScheduledThreadPool(2,
                new ThreadFactoryBuilder()
                        .setNameFormat("DiscoveryClient-%d")
                        .setDaemon(true)
                        .build());
        // 心跳定时任务 
        heartbeatExecutor = new ThreadPoolExecutor(
                1, clientConfig.getHeartbeatExecutorThreadPoolSize(), 0, TimeUnit.SECONDS,
                new SynchronousQueue<Runnable>(),
                new ThreadFactoryBuilder()
                        .setNameFormat("DiscoveryClient-HeartbeatExecutor-%d")
                        .setDaemon(true)
                        .build()
        );  // use direct handoff
        // 定时去同步服务端的实例列表
        cacheRefreshExecutor = new ThreadPoolExecutor(
                1, clientConfig.getCacheRefreshExecutorThreadPoolSize(), 0, TimeUnit.SECONDS,
                new SynchronousQueue<Runnable>(),
                new ThreadFactoryBuilder()
                        .setNameFormat("DiscoveryClient-CacheRefreshExecutor-%d")
                        .setDaemon(true)
                        .build()
        );  // use direct handoff

        eurekaTransport = new EurekaTransport();
        scheduleServerEndpointTask(eurekaTransport, args);

        AzToRegionMapper azToRegionMapper;
        if (clientConfig.shouldUseDnsForFetchingServiceUrls()) {
            azToRegionMapper = new DNSBasedAzToRegionMapper(clientConfig);
        } else {
            azToRegionMapper = new PropertyBasedAzToRegionMapper(clientConfig);
        }
        if (null != remoteRegionsToFetch.get()) {
            azToRegionMapper.setRegionsToFetch(remoteRegionsToFetch.get().split(","));
        }
        instanceRegionChecker = new InstanceRegionChecker(azToRegionMapper, clientConfig.getRegion());
    } catch (Throwable e) {
        throw new RuntimeException("Failed to initialize DiscoveryClient!", e);
    }

    if (clientConfig.shouldFetchRegistry()) {
        try {
            boolean primaryFetchRegistryResult = fetchRegistry(false);
            if (!primaryFetchRegistryResult) {
                logger.info("Initial registry fetch from primary servers failed");
            }
            boolean backupFetchRegistryResult = true;
            if (!primaryFetchRegistryResult && !fetchRegistryFromBackup()) {
                backupFetchRegistryResult = false;
                logger.info("Initial registry fetch from backup servers failed");
            }
            if (!primaryFetchRegistryResult && !backupFetchRegistryResult && clientConfig.shouldEnforceFetchRegistryAtInit()) {
                throw new IllegalStateException("Fetch registry error at startup. Initial fetch failed.");
            }
        } catch (Throwable th) {
            logger.error("Fetch registry error at startup: {}", th.getMessage());
            throw new IllegalStateException(th);
        }
    }

    // call and execute the pre registration handler before all background tasks (inc registration) is started
    if (this.preRegistrationHandler != null) {
        this.preRegistrationHandler.beforeRegistration();
    }
    // 如果需要注册到Eureka server并且是开启了初始化的时候强制注册，则调用register()发起服
务注册

    if (clientConfig.shouldRegisterWithEureka() && clientConfig.shouldEnforceRegistrationAtInit()) {
        try {
            if (!register() ) {
                throw new IllegalStateException("Registration error at startup. Invalid server response.");
            }
        } catch (Throwable th) {
            logger.error("Registration error at startup: {}", th.getMessage());
            throw new IllegalStateException(th);
        }
    }

    // finally, init the schedule tasks (e.g. cluster resolvers, heartbeat, instanceInfo replicator, fetch
    // 最后，init调度任务(例如集群解析器、心跳、instanceInfo复制器、fetch)
    initScheduledTasks(); 

    try {
        Monitors.registerObject(this);
    } catch (Throwable e) {
        logger.warn("Cannot register timers", e);
    }

    // This is a bit of hack to allow for existing code using DiscoveryManager.getInstance()
    // to work with DI'd DiscoveryClient
    DiscoveryManager.getInstance().setDiscoveryClient(this);
    DiscoveryManager.getInstance().setEurekaClientConfig(config);

    initTimestampMs = System.currentTimeMillis();
    initRegistrySize = this.getApplications().size();
    registrySize = initRegistrySize;
}
```

initScheduledTasks 去启动一个定时任务
- 如果配置了开启从注册中心刷新服务列表，则会开启cacheRefreshExecutor这个定时任务
- 如果开启了服务注册到Eureka，则通过需要做几个事情.
    - 建立心跳检测机制
    - 通过内部类来实例化StatusChangeListener 实例状态监控接口，这个就是前面我们在分析启 动过程中所看到的，调用notify的方法，实际上会在这里体现。

```java
private void initScheduledTasks() {
    // 如果配置了开启从注册中心刷新服务列表，则会开启cacheRefreshExecutor这个定时任务
    if (clientConfig.shouldFetchRegistry()) {
        // registry cache refresh timer
        int registryFetchIntervalSeconds = clientConfig.getRegistryFetchIntervalSeconds();
        int expBackOffBound = clientConfig.getCacheRefreshExecutorExponentialBackOffBound();
        cacheRefreshTask = new TimedSupervisorTask(
                "cacheRefresh",
                scheduler,
                cacheRefreshExecutor,
                registryFetchIntervalSeconds,
                TimeUnit.SECONDS,
                expBackOffBound,
                new CacheRefreshThread()
        );
        scheduler.schedule(
                cacheRefreshTask,
                registryFetchIntervalSeconds, TimeUnit.SECONDS);
    }
    // 如果开启了服务注册到Eureka，则通过需要做几个事情
    if (clientConfig.shouldRegisterWithEureka()) {
        int renewalIntervalInSecs = instanceInfo.getLeaseInfo().getRenewalIntervalInSecs();
        int expBackOffBound = clientConfig.getHeartbeatExecutorExponentialBackOffBound();
        logger.info("Starting heartbeat executor: " + "renew interval is: {}", renewalIntervalInSecs);
        // Heartbeat timer 心跳检测机制
        heartbeatTask = new TimedSupervisorTask(
                "heartbeat",
                scheduler,
                heartbeatExecutor,
                renewalIntervalInSecs,
                TimeUnit.SECONDS,
                expBackOffBound,
                new HeartbeatThread()
        );
        scheduler.schedule(
                heartbeatTask,
                renewalIntervalInSecs, TimeUnit.SECONDS);
        // InstanceInfo replicator  初始化一个:instanceInfoReplicator
        instanceInfoReplicator = new InstanceInfoReplicator(
                this,
                instanceInfo,
                clientConfig.getInstanceInfoReplicationIntervalSeconds(),
                2); // burstSize
        // 内部类来实例化StatusChangeListener 实例状态监控接口
        statusChangeListener = new ApplicationInfoManager.StatusChangeListener() {
            @Override
            public String getId() {
                return "statusChangeListener";
            }
            @Override
            public void notify(StatusChangeEvent statusChangeEvent) {
                if (InstanceStatus.DOWN == statusChangeEvent.getStatus() ||
                        InstanceStatus.DOWN == statusChangeEvent.getPreviousStatus()) {
                    // log at warn level if DOWN was involved
                    logger.warn("Saw local status change event {}", statusChangeEvent);
                } else {
                    logger.info("Saw local status change event {}", statusChangeEvent);
                }
                instanceInfoReplicator.onDemandUpdate();
            }
        };
        // 注册实例状态变化的监听
        if (clientConfig.shouldOnDemandUpdateStatusChange()) {
            applicationInfoManager.registerStatusChangeListener(statusChangeListener);
        }
        //启动一个实例信息复制器，主要就是为了开启一个定时线程，每40秒判断实例信息是否变更，如果变更了则重新注册
        instanceInfoReplicator.start(clientConfig.getInitialInstanceInfoReplicationIntervalSeconds());
    } else {
        logger.info("Not registering with Eureka server per configuration");
    }
}
```

**instanceInfoReplicator.onDemandUpdate()**

这个方法的主要作用是根据实例数据是否发生变化，来触发服务注册中心的数据。

```java
public boolean onDemandUpdate() {
    //限流判断
    if (rateLimiter.acquire(burstSize, allowedRatePerMinute)) {
        if (!scheduler.isShutdown()) {
            scheduler.submit(new Runnable() {
                @Override
                public void run() {
                    logger.debug("Executing on-demand update of local InstanceInfo");
                    //取出之前已经提交的任务，也就是在start方法中提交的更新任务，如果任务还没有执行完成，则取消之前的任务。
                    Future latestPeriodic = scheduledPeriodicRef.get();
                    if (latestPeriodic != null && !latestPeriodic.isDone()) {
                        logger.debug("Canceling the latest scheduled update, it will be rescheduled at the end of on demand update");
                        latestPeriodic.cancel(false);//如果此任务未完成，就立即取消
                    }
                    //通过调用run方法，令任务在延时后执行，相当于周期性任务中的一次
                    InstanceInfoReplicator.this.run();
                }
            });
            return true;
        } else {
            logger.warn("Ignoring onDemand update due to stopped scheduler");
            return false;
        }
    } else {
        logger.warn("Ignoring onDemand update due to rate limiter");
        return false;
    }
}
```

**InstanceInfoReplicator.this.run();**

run方法实际上和前面自动装配所执行的服务注册方法是一样的，也就是调用 register 方法进行服务注册，并且在finally中，每30s会定时执行一下当前的run 方法进行检查。

```java
public void run() {
    try {
        discoveryClient.refreshInstanceInfo();
        Long dirtyTimestamp = instanceInfo.isDirtyWithTime();
        if (dirtyTimestamp != null) {
            discoveryClient.register();
            instanceInfo.unsetIsDirty(dirtyTimestamp);
        }
    } catch (Throwable t) {
        logger.warn("There was a problem with the instance info replicator", t);
    } finally {
        Future next = scheduler.schedule(this, replicationIntervalSeconds, TimeUnit.SECONDS);
        scheduledPeriodicRef.set(next);
    }
}
```
**DiscoveryClient.register**

最终，我们终于找到服务注册的入口了， `eurekaTransport.registrationClient.register` 最终调用的是 `AbstractJerseyEurekaHttpClient#register(...)`， 当然大家如果自己去看代码，就会发现去调用之前有很多绕来绕去的代码，比如工厂模式、装饰器模式等。

```java
boolean register() throws Throwable {
    logger.info(PREFIX + "{}: registering service...", appPathIdentifier);
    EurekaHttpResponse<Void> httpResponse;
    try {
        httpResponse = eurekaTransport.registrationClient.register(instanceInfo);
    } catch (Exception e) {
        logger.warn(PREFIX + "{} - registration failed {}", appPathIdentifier, e.getMessage(), e);
        throw e;
    }
    if (logger.isInfoEnabled()) {
        logger.info(PREFIX + "{} - registration status: {}", appPathIdentifier, httpResponse.getStatusCode());
    }
    return httpResponse.getStatusCode() == Status.NO_CONTENT.getStatusCode();
}
```

**AbstractJerseyEurekaHttpClient#register**

很显然，这里是发起了一次http请求，访问Eureka-Server的apps/${APP_NAME}接口，将当前服务实例的信息发送到Eureka Server进行保存。 

至此，我们基本上已经知道Spring Cloud Eureka 是如何在启动的时候把服务信息注册到Eureka Server上的了

```java
@Override
public EurekaHttpResponse<Void> register(InstanceInfo info) {
    String urlPath = "apps/" + info.getAppName();
    ClientResponse response = null;
    try {
        Builder resourceBuilder = jerseyClient.resource(serviceUrl).path(urlPath).getRequestBuilder();
        addExtraHeaders(resourceBuilder);
        response = resourceBuilder
                .header("Accept-Encoding", "gzip")
                .type(MediaType.APPLICATION_JSON_TYPE)
                .accept(MediaType.APPLICATION_JSON)
                .post(ClientResponse.class, info);
        return anEurekaHttpResponse(response.getStatus()).headers(headersOf(response)).build();
    } finally {
        if (logger.isDebugEnabled()) {
            logger.debug("Jersey HTTP POST {}/{} with instance {}; statusCode={}", serviceUrl, urlPath, info.getId(),
                    response == null ? "N/A" : response.getStatus());
        }
        if (response != null) {
            response.close();
        }
    }
}
```

但是，似乎最开始的问题还没有解决，也就是Spring Boot应用在启动时，会调用start方法，最终调用 StatusChangeListener.notify 去更新服务的一个状态，并没有直接调用register方法注册。所以我 们继续去看一下 statusChangeListener.notify 方法。

**总结**

至此，我们知道Eureka Client发起服务注册时，有两个地方会执行服务注册的任务

1. 在Spring Boot启动时，由于自动装配机制将CloudEurekaClient注入到了容器，并且执行了构造方法，而在构造方法中有一个定时任务每40s会执行一次判断，判断实例信息是否发生了变化，如果是则会发起服务注册的流程 
2. 在Spring Boot启动时，通过refresh方法，最终调用StatusChangeListener.notify进行服务状态变 更的监听，而这个监听的方法受到事件之后会去执行服务注册。


## EurekaServer如何存储服务地址

### Eureka Server收到请求之后的处理

在没分析源码实现之前，我们一定知道它肯定对请求过来的服务实例数据进行了存储。那么我们去 Eureka Server端看一下处理流程。

请求入口在： `com.netflix.eureka.resources.ApplicationResource.addInstance()`

大家可以发现，这里所提供的REST服务，采用的是jersey来实现的。Jersey是基于JAX-RS标准，提供 REST的实现的支持，这里就不展开分析了。

**ApplicationResource.addInstance()**

当EurekaClient调用register方法发起注册时，会调用ApplicationResource.addInstance方法。

服务注册就是发送一个 POST 请求带上当前实例信息到类 ApplicationResource 的 addInstance 方法进行服务注册

```java
@POST
@Consumes({"application/json", "application/xml"})
public Response addInstance(InstanceInfo info,
                            @HeaderParam(PeerEurekaNode.HEADER_REPLICATION) String isReplication) {
    logger.debug("Registering instance {} (replication={})", info.getId(), isReplication);
    // validate that the instanceinfo contains all the necessary required fields
    if (isBlank(info.getId())) {
        return Response.status(400).entity("Missing instanceId").build();
    } else if (isBlank(info.getHostName())) {
        return Response.status(400).entity("Missing hostname").build();
    } else if (isBlank(info.getIPAddr())) {
        return Response.status(400).entity("Missing ip address").build();
    } else if (isBlank(info.getAppName())) {
        return Response.status(400).entity("Missing appName").build();
    } else if (!appName.equals(info.getAppName())) {
        return Response.status(400).entity("Mismatched appName, expecting " + appName + " but was " + info.getAppName()).build();
    } else if (info.getDataCenterInfo() == null) {
        return Response.status(400).entity("Missing dataCenterInfo").build();
    } else if (info.getDataCenterInfo().getName() == null) {
        return Response.status(400).entity("Missing dataCenterInfo Name").build();
    }
    // handle cases where clients may be registering with bad DataCenterInfo with missing data
    DataCenterInfo dataCenterInfo = info.getDataCenterInfo();
    if (dataCenterInfo instanceof UniqueIdentifier) {
        String dataCenterInfoId = ((UniqueIdentifier) dataCenterInfo).getId();
        if (isBlank(dataCenterInfoId)) {
            boolean experimental = "true".equalsIgnoreCase(serverConfig.getExperimental("registration.validation.dataCenterInfoId"));
            if (experimental) {
                String entity = "DataCenterInfo of type " + dataCenterInfo.getClass() + " must contain a valid id";
                return Response.status(400).entity(entity).build();
            } else if (dataCenterInfo instanceof AmazonInfo) {
                AmazonInfo amazonInfo = (AmazonInfo) dataCenterInfo;
                String effectiveId = amazonInfo.get(AmazonInfo.MetaDataKey.instanceId);
                if (effectiveId == null) {
                    amazonInfo.getMetadata().put(AmazonInfo.MetaDataKey.instanceId.getName(), info.getId());
                }
            } else {
                logger.warn("Registering DataCenterInfo of type {} without an appropriate id", dataCenterInfo.getClass());
            }
        }
    }
    registry.register(info, "true".equals(isReplication)); // 执行注册流程
    return Response.status(204).build();  // 204 to be backwards compatible
}
```
**PeerAwareInstanceRegistryImpl.register**




















PeerAwareInstanceRegistryImpl#register 处理客户端上报的实例信息

InstanceInfo -> ConcurrentHashMap


### EurekaServer三级缓存

原因：读写分离

ResponseCache管理三级缓存




## EurekaClient如何查询地址

DiscoveryClient构造方法触发查询

DiscoveryClient#fetchRegistry 查询服务列表

TimedSupervisorTask 超时后做衰减任务 10s,20,30s






## eureka监听各服务状态，下线、重连等，并做相应的处理

https://github.com/spring-cloud/spring-cloud-netflix/issues/1726

Eureka的server端会发出5个事件通知，分别是：

| 类名                          | 事件名称               |
| ----------------------------- | ---------------------- |
| EurekaRegistryAvailableEvent  | Eureka注册中心启动事件 |
| EurekaServerStartedEvent      | Eureka Server启动事件  |
| EurekaInstanceRegisteredEvent | 服务注册事件           |
| EurekaInstanceCanceledEvent   | 服务下线事件           |
| EurekaInstanceRenewedEvent    | 服务续约事件           |

### EurekaRegistryAvailableEvent与EurekaServerStartedEvent

```java
@Configuration
public class EurekaServerInitializerConfiguration implements ServletContextAware, SmartLifecycle, Ordered {

	private static final Log log = LogFactory.getLog(EurekaServerInitializerConfiguration.class);

	@Autowired
	private EurekaServerConfig eurekaServerConfig;

	private ServletContext servletContext;

	@Autowired
	private ApplicationContext applicationContext;

	@Autowired
	private EurekaServerBootstrap eurekaServerBootstrap;

	private boolean running;

	private int order = 1;

	@Override
	public void setServletContext(ServletContext servletContext) {
		this.servletContext = servletContext;
	}

	@Override
	public void start() {
		new Thread(new Runnable() {
			@Override
			public void run() {
				try {
					//TODO: is this class even needed now?
					eurekaServerBootstrap.contextInitialized(EurekaServerInitializerConfiguration.this.servletContext);
					log.info("Started Eureka Server");

					publish(new EurekaRegistryAvailableEvent(getEurekaServerConfig())); // Eureka注册中心启动事件
					EurekaServerInitializerConfiguration.this.running = true;
					publish(new EurekaServerStartedEvent(getEurekaServerConfig()));  // Eureka Server启动事件
				}
				catch (Exception ex) {
					// Help!
					log.error("Could not initialize Eureka servlet context", ex);
				}
			}
		}).start();
	}

	private EurekaServerConfig getEurekaServerConfig() {
		return this.eurekaServerConfig;
	}

	private void publish(ApplicationEvent event) {
		this.applicationContext.publishEvent(event);
	}

	@Override
	public void stop() {
		this.running = false;
		eurekaServerBootstrap.contextDestroyed(this.servletContext);
	}

	@Override
	public boolean isRunning() {
		return this.running;
	}

	@Override
	public int getPhase() {
		return 0;
	}

	@Override
	public boolean isAutoStartup() {
		return true;
	}

	@Override
	public void stop(Runnable callback) {
		callback.run();
	}

	@Override
	public int getOrder() {
		return this.order;
	}

}
```




### EurekaInstanceRegisteredEvent EurekaInstanceCanceledEvent EurekaInstanceRenewedEvent

```java
public class InstanceRegistry extends PeerAwareInstanceRegistryImpl implements ApplicationContextAware {

	private static final Log log = LogFactory.getLog(InstanceRegistry.class);

	private ApplicationContext ctxt;
	private int defaultOpenForTrafficCount;

	public InstanceRegistry(EurekaServerConfig serverConfig, EurekaClientConfig clientConfig, ServerCodecs serverCodecs, EurekaClient eurekaClient, int expectedNumberOfClientsSendingRenews, int defaultOpenForTrafficCount) {
		super(serverConfig, clientConfig, serverCodecs, eurekaClient);

		this.expectedNumberOfClientsSendingRenews = expectedNumberOfClientsSendingRenews;
		this.defaultOpenForTrafficCount = defaultOpenForTrafficCount;
	}

	@Override
	public void setApplicationContext(ApplicationContext context) throws BeansException {
		this.ctxt = context;
	}

	@Override
	public void openForTraffic(ApplicationInfoManager applicationInfoManager, int count) {
		super.openForTraffic(applicationInfoManager, count == 0 ? this.defaultOpenForTrafficCount : count);
	}

	@Override
	public void register(InstanceInfo info, int leaseDuration, boolean isReplication) {
		handleRegistration(info, leaseDuration, isReplication);
		super.register(info, leaseDuration, isReplication);
	}

	@Override
	public void register(final InstanceInfo info, final boolean isReplication) {
		handleRegistration(info, resolveInstanceLeaseDuration(info), isReplication);
		super.register(info, isReplication);
	}

	@Override
	public boolean cancel(String appName, String serverId, boolean isReplication) {
		handleCancelation(appName, serverId, isReplication);
		return super.cancel(appName, serverId, isReplication);
	}
    
    /**
     * 服务续约事件
     */
	@Override
	public boolean renew(final String appName, final String serverId, boolean isReplication) {
		log("renew " + appName + " serverId " + serverId + ", isReplication {}" + isReplication);
		List<Application> applications = getSortedApplications();
		for (Application input : applications) {
			if (input.getName().equals(appName)) {
				InstanceInfo instance = null;
				for (InstanceInfo info : input.getInstances()) {
					if (info.getId().equals(serverId)) {
						instance = info;
						break;
					}
				}
				publishEvent(new EurekaInstanceRenewedEvent(this, appName, serverId, instance, isReplication));
				break;
			}
		}
		return super.renew(appName, serverId, isReplication);
	}

	@Override
	protected boolean internalCancel(String appName, String id, boolean isReplication) {
		handleCancelation(appName, id, isReplication);
		return super.internalCancel(appName, id, isReplication);
	}

    /**
     * 服务下线事件
     */
	private void handleCancelation(String appName, String id, boolean isReplication) {
		log("cancel " + appName + ", serverId " + id + ", isReplication " + isReplication);
		publishEvent(new EurekaInstanceCanceledEvent(this, appName, id, isReplication));
	}
    
    /**
     * 服务注册事件
     */
	private void handleRegistration(InstanceInfo info, int leaseDuration, boolean isReplication) {
		log("register " + info.getAppName() + ", vip " + info.getVIPAddress() + ", leaseDuration " + leaseDuration + ", isReplication " + isReplication);
		publishEvent(new EurekaInstanceRegisteredEvent(this, info, leaseDuration, isReplication));
	}
		
	private void log(String message) {
		if (log.isDebugEnabled()) {
			log.debug(message);
		}
	}

	private void publishEvent(ApplicationEvent applicationEvent) {
		this.ctxt.publishEvent(applicationEvent);
	}

	private int resolveInstanceLeaseDuration(final InstanceInfo info) {
		int leaseDuration = Lease.DEFAULT_DURATION_IN_SECS;
		if (info.getLeaseInfo() != null && info.getLeaseInfo().getDurationInSecs() > 0) {
			leaseDuration = info.getLeaseInfo().getDurationInSecs();
		}
		return leaseDuration;
	}
}
```