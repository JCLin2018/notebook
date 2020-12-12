# [SpringCloud微服务如何优雅停机及源码分析](https://www.cnblogs.com/trust-freedom/p/10744683.html)

转载：https://www.cnblogs.com/trust-freedom/p/10744683.html

**版本：**

SpringBoot 1.5.4.RELEASE

SpringCloud Dalston.RELEASE

本文主要讨论的是微服务注册到Eureka注册中心，并使用Zuul网关负载访问的情况，如何停机可以使用户无感知。

## 方式一：kill -9 java进程id【不建议】

`kill -9` 属于强杀进程，首先微服务正在执行的任务被强制中断了；其次，没有通过Eureka注册中心服务下线，Zuul网关作为Eureka Client仍保存这个服务的路由信息，会继续调用服务，Http请求返回500，后台异常是Connection refuse连接拒绝

这种情况默认最长需要等待：

> 90s（微服务在Eureka Server上租约到期）
>
> +
>
> 30s（Eureka Server服务列表刷新到只读缓存ReadOnlyMap的时间，Eureka Client默认读此缓存）
>
> +
>
> 30s（Zuul作为Eureka Client默认每30秒拉取一次服务列表）
>
> +
>
> 30s（Ribbon默认动态刷新其ServerList的时间间隔）
>
> = 180s，即 3分钟

**总结：**

此种方式既会导致正在执行中的任务无法执行完，又会导致服务没有从Eureka Server摘除，并给Eureka Client时间刷新到服务列表，导致了通过Zuul仍然调用已停掉服务报500错误的情况，不推荐。

## 方式二：kill -15 java进程id 或 直接使用/shutdown 端点【不建议】

### kill 与/shutdown 的含义[#](https://www.cnblogs.com/trust-freedom/p/10744683.html#1996028103)

首先，`kill`等于`kill -15`，根据`man kill`的描述信息

>  The command kill sends the specified signal to the specified process or process group. If no signal is specified, the TERM signal is sent.
>
> 即kill没有执行信号等同于TERM（终止，termination）

而`kill -l`查看信号编号与信号之间的关系，`kill -15`就是 **SIGTERM**，TERM信号

![](https://notebook1.oss-cn-shenzhen.aliyuncs.com/img/Java/1598883555.jpg)

给JVM进程发送TERM终止信号时，会调用其注册的 Shutdown Hook，当SpringBoot微服务启动时也注册了 Shutdown Hook

而直接调用`/shutdown`端点本质和使用 Shutdown Hook是一样的，**所以无论是使用`kill` 或 `kill -15`，还是直接使用`/shutdown`端点，都会调用到JVM注册的Shutdown Hook**

> **注意：**
>
> 启用 /shutdown端点，需要如下配置
>
> endpoints.shutdown.enabled = true
> endpoints.shutdown.sensitive = false

**所有问题都导向了 Shutdown Hook会执行什么？？**

### Spring注册的Shutdown Hook[#](https://www.cnblogs.com/trust-freedom/p/10744683.html#53872309)

通过查询项目组使用`Runtime.getRuntime().addShutdownHook(Thread shutdownHook)`的地方，发现ribbon注册了一些Shutdown Hook，但这不是我们这次关注的，我们关注的是Spring的应用上下文抽象类`AbstractApplicationContext`注册了针对整个Spring容器的Shutdown Hook，在执行Shutdown Hook时的逻辑在 **`AbstractApplicationContext#doClose()`**

```java
//## org.springframework.context.support.AbstractApplicationContext#registerShutdownHook 
/**
 * Register a shutdown hook with the JVM runtime, closing this context
 * on JVM shutdown unless it has already been closed at that time.
 * <p>Delegates to {@code doClose()} for the actual closing procedure.
 * @see Runtime#addShutdownHook
 * @see #close()
 * @see #doClose()
 */
@Override
public void registerShutdownHook() {
	if (this.shutdownHook == null) {
		// No shutdown hook registered yet.
        // 注册shutdownHook，线程真正调用的是 doClose()
		this.shutdownHook = new Thread() {
			@Override
			public void run() {
				synchronized (startupShutdownMonitor) {
					doClose();
				}
			}
		};
		Runtime.getRuntime().addShutdownHook(this.shutdownHook);
	}
}


//## org.springframework.context.support.AbstractApplicationContext#doClose 
/**
 * Actually performs context closing: publishes a ContextClosedEvent and
 * destroys the singletons in the bean factory of this application context.
 * <p>Called by both {@code close()} and a JVM shutdown hook, if any.
 * @see org.springframework.context.event.ContextClosedEvent
 * @see #destroyBeans()
 * @see #close()
 * @see #registerShutdownHook()
 */
protected void doClose() {
	if (this.active.get() && this.closed.compareAndSet(false, true)) {
		if (logger.isInfoEnabled()) {
			logger.info("Closing " + this);
		}

        // 注销注册的MBean
		LiveBeansView.unregisterApplicationContext(this);

		try {
			// Publish shutdown event.
            // 发送ContextClosedEvent事件，会有对应此事件的Listener处理相应的逻辑
			publishEvent(new ContextClosedEvent(this));
		}
		catch (Throwable ex) {
			logger.warn("Exception thrown from ApplicationListener handling ContextClosedEvent", ex);
		}

		// Stop all Lifecycle beans, to avoid delays during individual destruction.
        // 调用所有 Lifecycle bean 的 stop() 方法
		try {
			getLifecycleProcessor().onClose();
		}
		catch (Throwable ex) {
			logger.warn("Exception thrown from LifecycleProcessor on context close", ex);
		}

		// Destroy all cached singletons in the context's BeanFactory.
        // 销毁所有单实例bean
		destroyBeans();

		// Close the state of this context itself.
		closeBeanFactory();

		// Let subclasses do some final clean-up if they wish...
        // 调用子类的 onClose() 方法，比如 EmbeddedWebApplicationContext#onClose()
		onClose();

		this.active.set(false);
	}
}
```

**`AbstractApplicationContext#doClose()`** 的关键点在于

- publishEvent(new ContextClosedEvent(this))： 发送ContextClosedEvent事件，会有对应此事件的Listener处理相应的逻辑
- getLifecycleProcessor().onClose()： 调用所有 Lifecycle bean 的 stop() 方法

而ContextClosedEvent事件的Listener有很多，实现了Lifecycle生命周期接口的bean也很多，但其中我们只关心一个，即 **`EurekaAutoServiceRegistration`** ，它即监听了ContextClosedEvent事件，也实现了Lifecycle接口

### EurekaAutoServiceRegistration的stop()事件[#](https://www.cnblogs.com/trust-freedom/p/10744683.html#324707157)

```java
//## org.springframework.cloud.netflix.eureka.serviceregistry.EurekaAutoServiceRegistration
public class EurekaAutoServiceRegistration implements AutoServiceRegistration, SmartLifecycle, Ordered {

    // lifecycle接口的 stop()
    @Override
	public void stop() {
		this.serviceRegistry.deregister(this.registration);
		this.running.set(false);  // 设置liffecycle的running标示为false
	}
    
    // ContextClosedEvent事件监听器
    @EventListener(ContextClosedEvent.class)
	public void onApplicationEvent(ContextClosedEvent event) {
		// register in case meta data changed
		stop();
	}
    
}
```

如上可以看到，`EurekaAutoServiceRegistration`中对 ContextClosedEvent事件 和 Lifecycle接口 的实现都调用了`stop()`方法，虽然都调用了`stop()`方法，但由于各种对于状态的判断导致不会重复执行，如

- Lifecycle的running标示置为false，就不会调用到此Lifecycle#stop()
- `EurekaServiceRegistry#deregister()`方法包含将实例状态置为DOWN 和 EurekaClient#shutdown() 两个操作，其中状态置为DOWN一次后，下一次只要状态不变就不会触发状态复制请求；EurekaClient#shutdown() 之前也会判断`AtomicBoolean isShutdown`标志位

下面具体看看**`EurekaServiceRegistry#deregister()`**方法

### EurekaServiceRegistry#deregister() 注销[#](https://www.cnblogs.com/trust-freedom/p/10744683.html#1573468350)

```java
//## org.springframework.cloud.netflix.eureka.serviceregistry.EurekaServiceRegistry#deregister
@Override
public void deregister(EurekaRegistration reg) {
	if (reg.getApplicationInfoManager().getInfo() != null) {

		if (log.isInfoEnabled()) {
			log.info("Unregistering application " + reg.getInstanceConfig().getAppname()
					+ " with eureka with status DOWN");
		}

        // 更改实例状态，会立即触发状态复制请求
		reg.getApplicationInfoManager().setInstanceStatus(InstanceInfo.InstanceStatus.DOWN);

		//TODO: on deregister or on context shutdown
        // 关闭EurekaClient
		reg.getEurekaClient().shutdown();
	}
}
```

主要涉及两步：

- **更新Instance状态为 DOWN**： 更新状态会触发`StatusChangeListener`监听器，状态复制器`InstanceInfoReplicator`会向Eureka Server发送状态更新请求。实际上状态更新和Eureka Client第一次注册时都是调用的`DiscoveryClient.register()`，都是发送`POST /eureka/apps/appID`请求到Eureka Server，只不过请求Body中的Instance实例状态不同。执行完此步骤后，Eureka Server页面上变成

![](https://notebook1.oss-cn-shenzhen.aliyuncs.com/img/Java/677054-20190421122316241-1860898753.jpg)

- **EurekaClient.shutdown()**： 整个Eureka Client的关闭操作包含以下几步

  - ```java
    @PreDestroy
    @Override
    public synchronized void shutdown() {
        if (isShutdown.compareAndSet(false, true)) {
            logger.info("Shutting down DiscoveryClient ...");
    
            // 1、注销所有 StatusChangeListener
            if ( statusChangeListener != null && applicationInfoManager != null) {
                applicationInfoManager.unregisterStatusChangeListener(statusChangeListener.getId());
            }
    
            // 2、停掉所有定时线程（实例状态复制、心跳、client缓存刷新、监督线程）
            cancelScheduledTasks();
    
            // If APPINFO was registered
            // 3、向Eureka Server注销实例
            if (applicationInfoManager != null && clientConfig.shouldRegisterWithEureka()) {
                applicationInfoManager.setInstanceStatus(InstanceStatus.DOWN);
                unregister();
            }
    
            // 4、各种shutdown关闭
            if (eurekaTransport != null) {
                eurekaTransport.shutdown();
            }
    
            heartbeatStalenessMonitor.shutdown();
            registryStalenessMonitor.shutdown();
    
            logger.info("Completed shut down of DiscoveryClient");
        }
    }
    ```

  - 其中应关注`unregister()`注销，其调用`AbstractJerseyEurekaHttpClient#cancel()`方法，向Eureka Server发送`DELETE /eureka/v2/apps/appID/instanceID`请求，DELETE请求成功后，Eureka Server页面上服务列表就没有当前实例信息了。注意： 由于在注销上一步已经停掉了定时心跳线程，否则注销后的下次心跳又会导致服务上线

### 总结[#](https://www.cnblogs.com/trust-freedom/p/10744683.html#1270664850)

使用`kill`、`kill -15` 或 `/shutdown`端点都会调用Shutdown Hook，触发Eureka Instance实例的注销操作，这一步是没有问题的，优雅下线的第一步就是从Eureka注册中心注销实例，但关键问题是shutdown操作除了注销Eureka实例，还会马上停止服务，而此时无论Eureka Server端，Zuul作为Eureka Client端都存在陈旧的缓存还未刷新，服务列表中仍然有注销下线的服务，通过zuul再次调用报500错误，后台是connection refuse连接拒绝异常，故不建议使用

另外，由于`unregister`注销操作涉及状态更新DOWN 和 注销下线 两步操作，且是分两个线程执行的，实际注销时，根据两个线程执行完成的先后顺序，最终在Eureka Server上体现的结果不同，但最终效果是相同的，经过一段时间的缓存刷新后，此服务实例不会再被调用

- 状态更新DOWN先结束，注销实例后结束： Eureka Server页面清除此服务实例信息
- 注销实例先结束，状态更新DOWN后结束： Eureka Server页面显示此服务实例状态为DOWN

## 方式三：/pause 端点【可用，但有缺陷】

### /pause 端点[#](https://www.cnblogs.com/trust-freedom/p/10744683.html#244896777)

首先，启用`/pause`端点需要如下配置

```properties
Copyendpoints.pause.enabled = true
endpoints.pause.sensitive = false
```

`PauseEndpoint`是`RestartEndPoint`的内部类

```java
//## Restart端点
@ConfigurationProperties("endpoints.restart")
@ManagedResource
public class RestartEndpoint extends AbstractEndpoint<Boolean>
		implements ApplicationListener<ApplicationPreparedEvent> {
		
	// Pause端点
	@ConfigurationProperties("endpoints")
	public class PauseEndpoint extends AbstractEndpoint<Boolean> {

		public PauseEndpoint() {
			super("pause", true, true);
		}

		@Override
		public Boolean invoke() {
			if (isRunning()) {
				pause();
				return true;
			}
			return false;
		}
	}
	
    // 暂停操作
    @ManagedOperation
	public synchronized void pause() {
		if (this.context != null) {
			this.context.stop();
		}
	}
}
```

如上可见，`/pause`端点最终会调用Spring应用上下文的`stop()`方法

### AbstractApplicationContext#stop()[#](https://www.cnblogs.com/trust-freedom/p/10744683.html#330397663)

```java
Copy//## org.springframework.context.support.AbstractApplicationContext#stop
@Override
public void stop() {
    // 1、所有实现Lifecycle生命周期接口 stop()
	getLifecycleProcessor().stop();
    
    // 2、触发ContextStoppedEvent事件
	publishEvent(new ContextStoppedEvent(this));
}
```

查看源码，并没有发现有用的ContextStoppedEvent事件监听器，故stop的逻辑都在**Lifecycle生命周期接口实现类**的stop()

而`getLifecycleProcessor().stop()` 与 方式二中shutdown调用的 `getLifecycleProcessor().doClose()` 内部逻辑都是一样的，都是调用了`DefaultLifecycleProcessor#stopBeans()`，进而调用Lifecycle接口实现类的stop()，如下

```java
Copy//## DefaultLifecycleProcessor
@Override
public void stop() {
	stopBeans();
	this.running = false;
}

@Override
public void onClose() {
	stopBeans();
	this.running = false;
}
```

所以，执行`/pause`端点 和 shutdown时的其中一部分逻辑是一样的，依赖于`EurekaServiceRegistry#deregister() 注销`，会依次执行：

- 触发状态复制为DOWN，和Eureka Client注册上线register调用方法一样`DiscoveryClient#register()`，发送`POST /eureka/apps/appID`请求到Eureka Server，只不过请求Body中的Instance实例状态不同。执行完此步骤后，Eureka Server页面上实例状态变成DOWN

- 触发

   

  ```
  EurekaClient.shutdown
  ```

  - 1、注销所有 StatusChangeListener
  - 2、停掉所有定时线程（实例状态复制、心跳、client缓存刷新、监督线程）
  - 3、向Eureka Server注销实例
    - 调用`AbstractJerseyEurekaHttpClient#cancel()`方法，向Eureka Server发送`DELETE /eureka/v2/apps/appID/instanceID`请求，DELETE请求成功后，Eureka Server页面上服务列表就没有当前实例信息了。注意： 由于在注销上一步已经停掉了定时心跳线程，否则注销后的下次心跳又会导致服务上线
  - 4、各种shutdown关闭

- stop()执行完毕后，Eureka Server端当前实例状态是DOWN，还是下线，取决于 状态DOWN的复制线程 和 注销请求 哪个执行快

### 总结[#](https://www.cnblogs.com/trust-freedom/p/10744683.html#353088383)

`/pause`端点可以用于让服务从Eureka Server下线，且与shutdown不一样的是，其不会停止整个服务，导致整个服务不可用，只会做从Eureka Server注销的操作，最终在Eureka Server上体现的是 **服务下线** 或 **服务状态为DOWN**，且eureka client相关的定时线程也都停止了，不会再被定时线程注册上线，所以可以在sleep一段时间，待服务实例下线被像Zuul这种Eureka Client刷新到，再停止微服务，就可以做到优雅下线（停止微服务的时候可以使用`/shutdown端点` 或 直接暴利`kill -9`）

**注意：**

我实验的当前版本下，使用`/pause`端点下线服务后，无法使用`/resume`端点再次上线，即如果发版过程中想重新注册服务，只有重启微服务。且为了从Eureka Server下线服务，将整个Spring容器stop()，也有点“兴师动众”

`/resume`端点无法让服务再次上线的原因是，虽然此端点会调用`AbstractApplicationContext#start()` --> `EurekaAutoServiceRegistration#start()` --> `EurekaServiceRegistry#register()`，但由于之前已经停止了Eureka Client的所有定时任务线程，比如状态复制 和 心跳线程，重新注册时虽然有`maybeInitializeClient(eurekaRegistration)`尝试重新启动EurekaClient，但并没有成功（估计是此版本的Bug），导致UP状态并没有发送给Eureka Server

**可下线，无法重新上线**

## 方式四：/service-registry 端点【可用，但有坑】

### /service-registry 端点[#](https://www.cnblogs.com/trust-freedom/p/10744683.html#2723642636)

首先，在我使用的版本 `/service-registry` 端点默认是启用的，但是是`sensitive` 的，也就是需要认证才能访问

我试图找一个可以单独将`/service-registry`的`sensitive`置为false的方式，但在当前我用的版本没有找到，`/service-registry`端点是通过 `ServiceRegistryAutoConfiguration`自动配置的 `ServiceRegistryEndpoint`，而 `ServiceRegistryEndpoint`这个MvcEndpoint的`isSensitive()`方法写死了返回true，并没有给可配置的地方或者自定义什么实现，然后在`ManagementWebSecurityAutoConfiguration`这个安全管理自动配置类中，将所有这些`sensitive==true`的通过Spring Security的 `httpSecurity.authorizeRequests().xxx.authenticated()`设置为必须认证后才能访问，目前我找到只能通过 `management.security.enabled=false` 这种将所有端点都关闭认证的方式才可以无认证访问

```properties
Copy# 无认证访问 /service-registry 端点
management.security.enabled=false
```

### 更新远端实例状态[#](https://www.cnblogs.com/trust-freedom/p/10744683.html#2641429175)

/service-registry端点的实现类是`ServiceRegistryEndpoint`，其暴露了两个RequestMapping，分别是GET 和 POST请求的/service-registry，GET请求的用于获取实例本地的status、overriddenStatus，POST请求的用于调用Eureka Server修改当前实例状态

```java
Copy//## org.springframework.cloud.client.serviceregistry.endpoint.ServiceRegistryEndpoint
@ManagedResource(description = "Can be used to display and set the service instance status using the service registry")
@SuppressWarnings("unchecked")
public class ServiceRegistryEndpoint implements MvcEndpoint {
    private final ServiceRegistry serviceRegistry;

	private Registration registration;

	public ServiceRegistryEndpoint(ServiceRegistry<?> serviceRegistry) {
		this.serviceRegistry = serviceRegistry;
	}

	public void setRegistration(Registration registration) {
		this.registration = registration;
	}

	@RequestMapping(path = "instance-status", method = RequestMethod.POST)
	@ResponseBody
	@ManagedOperation
	public ResponseEntity<?> setStatus(@RequestBody String status) {
		Assert.notNull(status, "status may not by null");

		if (this.registration == null) {
			return ResponseEntity.status(HttpStatus.NOT_FOUND).body("no registration found");
		}

		this.serviceRegistry.setStatus(this.registration, status);
		return ResponseEntity.ok().build();
	}

	@RequestMapping(path = "instance-status", method = RequestMethod.GET)
	@ResponseBody
	@ManagedAttribute
	public ResponseEntity getStatus() {
		if (this.registration == null) {
			return ResponseEntity.status(HttpStatus.NOT_FOUND).body("no registration found");
		}

		return ResponseEntity.ok().body(this.serviceRegistry.getStatus(this.registration));
	}

	@Override
	public String getPath() {
		return "/service-registry";
	}

	@Override
	public boolean isSensitive() {
		return true;
	}

	@Override
	public Class<? extends Endpoint<?>> getEndpointType() {
		return null;
	}
}
```

我们关注的肯定是POST请求的/service-registry，如上可以看到，其调用了 `EurekaServiceRegistry.setStatus()` 方法更新实例状态

```java
Copy//## org.springframework.cloud.netflix.eureka.serviceregistry.EurekaServiceRegistry
public class EurekaServiceRegistry implements ServiceRegistry<EurekaRegistration> {
    
    // 更新状态
    @Override
	public void setStatus(EurekaRegistration registration, String status) {
		InstanceInfo info = registration.getApplicationInfoManager().getInfo();

        // 如果更新的status状态为CANCEL_OVERRIDE，调用EurekaClient.cancelOverrideStatus()
		//TODO: howto deal with delete properly?
		if ("CANCEL_OVERRIDE".equalsIgnoreCase(status)) {
			registration.getEurekaClient().cancelOverrideStatus(info);
			return;
		}

        // 调用EurekaClient.setStatus()
		//TODO: howto deal with status types across discovery systems?
		InstanceInfo.InstanceStatus newStatus = InstanceInfo.InstanceStatus.toEnum(status);
		registration.getEurekaClient().setStatus(newStatus, info);
	}
    
}
```

`EurekaServiceRegistry.setStatus()` 方法支持像Eureka Server发送两种请求，分别是通过 `EurekaClient.setStatus()` 和 `EurekaClient.cancelOverrideStatus()` 来支持的，下面分别分析：

- **`EurekaClient.setStatus()`**：

- 实际是发送 `PUT /eureka/apps/appID/instanceID/status?value=xxx` 到Eureka Server，这是注册中心对于 `Take instance out of service 实例下线` 而开放的Rest API，可以做到更新Eureka Server端的实例状态（status 和 overriddenstatus），一般会在发版部署时使用，让服务下线，更新为 **OUT_OF_SERVICE**

- 由于overriddenstatus更新为了OUT_OF_SERVICE，故即使有 **心跳** 或 **UP状态复制**，也不会改变其OUT_OF_SERVICE的状态，overriddenstatus覆盖状态就是为了避免服务下线后又被定时线程上线或更新状态而设计的，有很多所谓的 “覆盖策略”

- 也正是由于overriddenstatus覆盖状态无法被 心跳 和 UP状态复制（其实就是EurekaClient.register()）而影响，故在发版部署完新版本后，最好先调用Rest API清除overriddenstatus，再启动服务，如果直接启动服务，可能导致Server端仍是OUT_OF_SERVICE状态的问题

- **实验：** 更新状态为OUT_OF_SERVICE后，直接停服务，只有等到Server端服务租约到期下线后，再启动客户端上线才能成功注册并状态为UP；如果没等Server端下线服务不存在后就启动服务，注册上线后无法改变overriddenstatus==OUT_OF_SERVICE

- `EurekaClient.cancelOverrideStatus()`

   

  ：

  - 实际是发送 `DELETE /eureka/v2/apps/appID/instanceID/status` 到Eureka Server，用于清除覆盖状态，其实官方给出的是 `DELETE /eureka/v2/apps/appID/instanceID/status?value=UP`，其中 `value=UP`可选，是删除overriddenstatus为UNKNOWN之后，建议status回滚为什么状态，但我当前使用版本里没有这个 `value=UP`可选参数，就导致发送后，Eureka Server端 status=UNKNOWN 且 overriddenstatus=UNKNOWN，但UNKNOWN覆盖状态不同的事，虽然心跳线程仍对其无作用，但注册（等同于UP状态更新）是可以让服务上线的

### 总结[#](https://www.cnblogs.com/trust-freedom/p/10744683.html#3762702381)

- `/service-registry`端点可以更新服务实例状态为 OUT_OF_SERVICE，再经过一段Server端、Client端缓存的刷新，使得服务不会再被调用，此时再通过`/shutdown`端点 或 暴利的`kill -9` 停止服务进程，可以达到优雅下线的效果

- 如希望回滚，可以通过几种方式

  - 还是`/service-registry`端点，只不过状态为 CANCEL_OVERRIDE，具体逻辑在 `EurekaServiceRegistry.setStatus()` 中，其等同于直接调用Eureka Server API ： `DELETE /eureka/v2/apps/appID/instanceID/status`，可以让Server端 status=UNKNOWN 且 overriddenstatus=UNKNOWN
  - 也可以用 `/service-registry`端点，状态为UP，可使得Server端 status=UP且 overriddenstatus=UP，虽然可以临时起到上线目的，但 overriddenstatus=UP 仍需要上一步的DELETE请求才能清楚，很麻烦，不建议使用
  - 不通过Eureka Client的端点，直接调用Eureka Server端点： `DELETE /eureka/apps/appID/instanceID/status?value=UP`

- 实际使用过程中建议如下顺序

  - 1、调用`/service-registry`端点将状态置为 OUT_OF_SERVICE

  - 2、sleep 缓存刷新时间 + 单个请求处理时间

    - **缓存刷新时间** 指的是Eureka Server刷新只读缓存、Eureka Client刷新本地服务列表、Ribbon刷新ServerList的时间，默认都是30s，可以适当缩短缓存刷新时间

      ```properties
      Copy# Eureka Server端配置
      eureka.server.responseCacheUpdateIntervalMs=5000
      eureka.server.eviction-interval-timer-in-ms=5000
      
      # Eureka Client端配置
      eureka.client.registryFetchIntervalSeconds=5
      ribbon.ServerListRefreshInterval=5000
      ```

    - **单个请求处理时间** 是为了怕服务还有请求没处理完

  - 3、调用 `/service-registry`端点将状态置为 CANCEL_OVERRIDE，其实就是向Server端发送DELETE overriddenstatus的请求，这会让Server端 status=UNKNOWN 且 overriddenstatus=UNKNOWN

  - 4、使用 `/shutdown`端点 或 暴利`kill -9`终止服务

  - 5、发版部署后，启动服务注册到Eureka Server，服务状态变为UP

## 方式五： 直接调用Eureka Server Rest API【可用，但URL比较复杂】

上面说了这么多，其实这些都是针对Eureka Server Rest API在Eureka客户端上的封装，即通过Eureka Client服务由于引入了actuator，增加了一系列端点，其实一些端点通过调用Eureka Server暴露的Rest API的方式实现Eureka实例服务下线功能

**Eureka Rest API包括：**

| **Operation**                                                | **HTTP action**                                              | **Description**                                              |
| ------------------------------------------------------------ | ------------------------------------------------------------ | ------------------------------------------------------------ |
| Register new application instance                            | POST /eureka/apps/**appID**                                  | Input: JSON/XMLpayload HTTPCode: 204 on success              |
| De-register application instance                             | DELETE /eureka/apps/**appID**/**instanceID**                 | HTTP Code: 200 on success                                    |
| Send application instance heartbeat                          | PUT /eureka/apps/**appID**/**instanceID**                    | HTTP Code: * 200 on success * 404 if **instanceID** doesn’t exist |
| Query for all instances                                      | GET /eureka/apps                                             | HTTP Code: 200 on success Output: JSON/XML                   |
| Query for all **appID** instances                            | GET /eureka/apps/**appID**                                   | HTTP Code: 200 on success Output: JSON/XML                   |
| Query for a specific **appID**/**instanceID**                | GET /eureka/apps/**appID**/**instanceID**                    | HTTP Code: 200 on success Output: JSON/XML                   |
| Query for a specific **instanceID**                          | GET /eureka/instances/**instanceID**                         | HTTP Code: 200 on success Output: JSON/XML                   |
| Take instance out of service                                 | PUT /eureka/apps/**appID**/**instanceID**/status?value=OUT_OF_SERVICE | HTTP Code: * 200 on success * 500 on failure                 |
| Move instance back into service (remove override)            | DELETE /eureka/apps/**appID**/**instanceID**/status?value=UP (The value=UP is optional, it is used as a suggestion for the fallback status due to removal of the override) | HTTP Code: * 200 on success * 500 on failure                 |
| Update metadata                                              | PUT /eureka/apps/**appID**/**instanceID**/metadata?key=value | HTTP Code: * 200 on success * 500 on failure                 |
| Query for all instances under a particular **vip address**   | GET /eureka/vips/**vipAddress**                              | * HTTP Code: 200 on success Output: JSON/XML * 404 if the **vipAddress**does not exist. |
| Query for all instances under a particular **secure vip address** | GET /eureka/svips/**svipAddress**                            | * HTTP Code: 200 on success Output: JSON/XML * 404 if the **svipAddress**does not exist. |

其中大多数非查询类的操作在之前分析Eureka Client的端点时都分析过了，其实调用Eureka Server的Rest API是最直接的，但由于目前多采用一些类似Jenkins的发版部署工具，其中操作均在脚本中执行，Eureka Server API虽好，但URL中都涉及**appID** 、**instanceID**，对于制作通用的脚本来说拼接出调用端点的URL有一定难度，且不像调用本地服务端点IP使用localhost 或 127.0.0.1即可，需要指定Eureka Server地址，所以整理略显复杂。不过在比较规范化的公司中，也是不错的选择

