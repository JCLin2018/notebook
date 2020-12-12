# docker的/var/run/docker.sock参数

[转载-程序员欣宸](https://blog.csdn.net/boling_cavalry/article/details/92846483)

## 关于/var/run/docker.sock参数

在创建docker容器时，有时会用到/var/run/docker.sock这样的数据卷参数，例如以下docker-compose.yml，可以看到kafka容器的数据卷参数带有/var/run/docker.sock：

```yaml
version: '2'
services:
  zookeeper:
    container_name: zookeeper
    image: wurstmeister/zookeeper
    ports:
      - "2181:2181"
  kafka:
    container_name: kafka
    image: wurstmeister/kafka:2.11-0.11.0.3
    ports:
      - "9092"
    environment:
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://:9092
      KAFKA_LISTENERS: PLAINTEXT://:9092
      KAFKA_ZOOKEEPER_CONNECT: zookeeper:2181
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock

```

本文要聊的就是这个/var/run/docker.sock参数。

注：关于上述docker-compose.yml的作用和相关实战，请参考[《kafka的Docker镜像使用说明(wurstmeister/kafka)》](https://blog.csdn.net/boling_cavalry/article/details/85395080)；

## 预备知识

搞清楚/var/run/docker.sock参数的前提是了解docker的client+server架构，如下是执行docker version命令的结果：

```shell
[root@minikube ~]# docker version
Client:
 Version:         1.13.1
 API version:     1.26
 Package version: docker-1.13.1-96.gitb2f74b2.el7.centos.x86_64
 Go version:      go1.10.3
 Git commit:      b2f74b2/1.13.1
 Built:           Wed May  1 14:55:20 2019
 OS/Arch:         linux/amd64

Server:
 Version:         1.13.1
 API version:     1.26 (minimum version 1.12)
 Package version: docker-1.13.1-96.gitb2f74b2.el7.centos.x86_64
 Go version:      go1.10.3
 Git commit:      b2f74b2/1.13.1
 Built:           Wed May  1 14:55:20 2019
 OS/Arch:         linux/amd64
 Experimental:    false
12345678910111213141516171819
```

可见在电脑上运行的docker由client和server组成，我们输入docker version命令实际上是通过客户端将请求发送到同一台电脑上的Doceker Daemon服务，由Docker Daemon返回信息，客户端收到信息后展示在控制台上，来自stack overflow的架构图如下：

![](https://notebook1.oss-cn-shenzhen.aliyuncs.com/img/docker/Snipaste_2020-09-02_22-10-17.jpg)

做好了准备工作就可以进入正题了。

## 官方解释

从下面这个官方文档看起，地址是：https://docs.docker.com/v17.09/engine/reference/commandline/dockerd/#description

![](https://notebook1.oss-cn-shenzhen.aliyuncs.com/img/docker/20190620215237191.jpg)

上图是Docker Daemon的配置参数，红框处可见daemon默认监听的是/var/run/docker.sock这个文件，所以docker客户端只要把请求发往这里，daemon就能收到并且做出响应。

按照上面的解释来推理：我们也可以向/var/run/docker.sock发送请求，也能达到docker ps、docker images这样的效果；

好吧，来试试！

## 向Docker Daemon发送请求

为了验证Docker Daemon可以通过/var/run/docker.sock接收请求，我们用curl命令来验证，测试环境如下：

1. 操作系统：CentOS Linux release 7.6.1810
2. Docker： 1.13.1

接下来开始动手验证：

1. 执行docker image命令看本地有哪些镜像：

```shell
[root@centos7 ~]# docker images
REPOSITORY          TAG                        IMAGE ID            CREATED             SIZE
docker.io/tomcat    8.5.42-jdk8-openjdk-slim   d9f443abac03        7 days ago          286 MB
docker.io/nginx     1.16.0-alpine              ef04b00b089d        6 weeks ago         20.4 MB
1234
```

可见有tomcat和nginx两个镜像；
\2. 执行docker ps命令看本地有哪些正在运行的容器：

```shell
[root@centos7 ~]# docker ps
CONTAINER ID        IMAGE                                       COMMAND             CREATED             STATUS              PORTS               NAMES
37df022f2429        docker.io/tomcat:8.5.42-jdk8-openjdk-slim   "catalina.sh run"   7 minutes ago       Up 7 minutes        8080/tcp            tomcat
123
```

可见只运行了一个tomcat容器；
\3. 执行以下命令，可以直接发http请求到Docker Daemon，获取本地镜像列表，等同于docker image：

```shell
curl -s --unix-socket /var/run/docker.sock http:/images/json
1
```

收到的响应是JSON，格式化后如下所示，可见通过/var/run/docker.sock向Docker Daemon发送请求是没有问题的：

```shell
[
    {
        "Containers": -1,
        "Created": 1560552952,
        "Id": "sha256:d9f443abac03d29c12d600d5e65dbb831fb75d681ade76a541daa5ecfeaf54df",
        "Labels": null,
        "ParentId": "",
        "RepoDigests": [
            "docker.io/tomcat@sha256:aa736d24929d391d98ece184b810cca869a31312942f2b45309b9acd063d36ae"
        ],
        "RepoTags": [
            "docker.io/tomcat:8.5.42-jdk8-openjdk-slim"
        ],
        "SharedSize": -1,
        "Size": 286484547,
        "VirtualSize": 286484547
    },
    {
        "Containers": -1,
        "Created": 1557535081,
        "Id": "sha256:ef04b00b089d1dc0f8afe7d9baea21609ff3edf91893687aed0eec1351429ff6",
        "Labels": {
            "maintainer": "NGINX Docker Maintainers <docker-maint@nginx.com>"
        },
        "ParentId": "",
        "RepoDigests": [
            "docker.io/nginx@sha256:270bea203d2fc3743fb9ce0193325e188b7e6233043487e3d3cf117ea4d3f337"
        ],
        "RepoTags": [
            "docker.io/nginx:1.16.0-alpine"
        ],
        "SharedSize": -1,
        "Size": 20421143,
        "VirtualSize": 20421143
    }
]
123456789101112131415161718192021222324252627282930313233343536
```

1. 执行以下命令，可以直接发http请求到Docker Daemon，获取运行中的容器列表，等同于docker ps：

```shell
curl -s --unix-socket /var/run/docker.sock http:/containers/json
1
```

收到的响应是JSON，格式化后如下所示：

```shell
[
    {
        "Id": "37df022f242924526750cda7580edb487085f9acde0ae65e2cebc7529fb02d5d",
        "Names": [
            "/tomcat"
        ],
        "Image": "docker.io/tomcat:8.5.42-jdk8-openjdk-slim",
        "ImageID": "sha256:d9f443abac03d29c12d600d5e65dbb831fb75d681ade76a541daa5ecfeaf54df",
        "Command": "catalina.sh run",
        "Created": 1561172541,
        "Ports": [
            {
                "PrivatePort": 8080,
                "Type": "tcp"
            }
        ],
        "Labels": {},
        "State": "running",
        "Status": "Up 18 minutes",
        "HostConfig": {
            "NetworkMode": "default"
        },
        "NetworkSettings": {
            "Networks": {
                "bridge": {
                    "IPAMConfig": null,
                    "Links": null,
                    "Aliases": null,
                    "NetworkID": "4509fb8eabe34dc61145284a637f138c2b734683749e590be878afb1763f07a9",
                    "EndpointID": "ebb5de894f92c36a88aa01f785be4b4782723c565e1628ea77bccf7a9c32017a",
                    "Gateway": "172.17.0.1",
                    "IPAddress": "172.17.0.2",
                    "IPPrefixLen": 16,
                    "IPv6Gateway": "",
                    "GlobalIPv6Address": "",
                    "GlobalIPv6PrefixLen": 0,
                    "MacAddress": "02:42:ac:11:00:02"
                }
            }
        },
        "Mounts": []
    }
]
12345678910111213141516171819202122232425262728293031323334353637383940414243
```

1. 更多与Docker Daemon交互的请求信息请参考官方文档：https://docs.docker.com/engine/api/v1.39 ，信息很全面，如下图：

![](https://notebook1.oss-cn-shenzhen.aliyuncs.com/img/docker/20190622113632602.jpg)

1. 至此，我们对docker的client、server架构有了清楚的认识：Docker Daemon相当于一个server，监听来自/var/run/docker.sock的请求，然后做出各种响应，例如返回镜像列表，创建容器。

## 顺便搞清楚一个常见问题

1. 有个常见的问题相信大家都遇见过，执行docker命令时控制台报错如下：

```shell
[root@centos7 ~]# docker ps
Cannot connect to the Docker daemon at unix:///var/run/docker.sock. Is the docker daemon running?
12
```

此时的您一定很清楚问题原因了：Docker Daemon服务不正常，所以客户端发送请求得不到响应
\2. 用systemctl status docker命令看看Docker Daemon状态，应该是停止或报错：

```shell
[root@centos7 ~]# systemctl status docker
● docker.service - Docker Application Container Engine
   Loaded: loaded (/usr/lib/systemd/system/docker.service; enabled; vendor preset: disabled)
   Active: inactive (dead) since 六 2019-06-22 11:45:14 CST; 3min 58s ago
     Docs: http://docs.docker.com
  Process: 9134 ExecStart=/usr/bin/dockerd-current --add-runtime docker-runc=/usr/libexec/docker/docker-runc-current --default-runtime=docker-runc --exec-opt native.cgroupdriver=systemd --userland-proxy-path=/usr/libexec/docker/docker-proxy-current --init-path=/usr/libexec/docker/docker-init-current --seccomp-profile=/etc/docker/seccomp.json $OPTIONS $DOCKER_STORAGE_OPTIONS $DOCKER_NETWORK_OPTIONS $ADD_REGISTRY $BLOCK_REGISTRY $INSECURE_REGISTRY $REGISTRIES (code=exited, status=0/SUCCESS)
 Main PID: 9134 (code=exited, status=0/SUCCESS)
1234567
```

1. 如果是停止状态，执行systemctl start docker启动服务即可，如果是错误就要case by case去分析了。

## 开篇问题

再回到文章开篇处的问题，启动容器时的数据卷参数"/var/run/docker.sock:/var/run/docker.sock"有什么用？相信您已经猜到了：

宿主机的/var/run/docker.sock被映射到了容器内，有以下两个作用：

1. 在容器内只要向/var/run/docker.sock发送http请求就能和Docker Daemon通信了，可以做的事情前面已经试过了，官方提供的API文档中有详细说明，镜像列表、容器列表这些统统不在话下；
2. 如果容器内有docker文件，那么在容器内执行docker ps、docker port这些命令，和在宿主机上执行的效果是一样的，因为容器内和宿主机上的docker文件虽然不同，但是他们的请求发往的是同一个Docker Daemon；

基于以上结论，开篇问题中的镜像wurstmeister/kafka:2.11-0.11.0.3既然用到了/var/run/docker.sock参数，那么该容器应该会向Docker Daemon发送请求，接下来我们尝试着分析一下，看看能否证实这个推测；

## 证实推测

1. 去镜像的官网找到容器启动时自动执行的脚本 [start-kafka.sh](http://start-kafka.sh/)，地址是：https://github.com/wurstmeister/kafka-docker/blob/0.10.0/start-kafka.sh ，如下图红框所示，果然有用到docker客户端，执行的是docker port命令：

![](https://notebook1.oss-cn-shenzhen.aliyuncs.com/img/docker/20190622151843216.jpg)

1. 上图红框中的功能：通过docker port命令得到该容器的端口映射信息，再通过sed命令从该信息中取得端口号，然后再用export命令暴露出去。
2. 还剩最后一个问题：上图红框中的docker命令在容器中可以执行么？会不会提示"找不到docker命令"？
   对于这个问题，我的猜测是该镜像已经包含了可执行文件"docker"，所以去看看该镜像的Dockerfile文件吧，地址是：https://github.com/wurstmeister/kafka-docker/blob/0.10.0/Dockerfile 如下图红框，果然在构建镜像的时候就安装了docker应用，因此在容器中执行docker xxx命令是没问题的：
3. ![](https://notebook1.oss-cn-shenzhen.aliyuncs.com/img/docker/20190622155159311.jpg)

1. 至此，所有理论上的推测都找到了直接证据，可以动手验证：进kafka容器内试试docker命令。

## 验证上述分析

1. 首先确保您的电脑上docker、docker-compose都已经装好可以正常使用；
2. 创建名为docker-compose.yml的文件，内容如下（其实就是开篇贴出的那个）：

```yml
version: '2'
services:
  zookeeper:
    container_name: zookeeper
    image: wurstmeister/zookeeper
    ports:
      - "2181:2181"
  kafka:
    container_name: kafka
    image: wurstmeister/kafka:2.11-0.11.0.3
    ports:
      - "9092"
    environment:
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://:9092
      KAFKA_LISTENERS: PLAINTEXT://:9092
      KAFKA_ZOOKEEPER_CONNECT: zookeeper:2181
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
123456789101112131415161718
```

1. 在docker-compose.yml所在目录执行命令docker-compose up -d创建容器：

```shell
[root@centos7 22]# docker-compose up -d
Creating network "22_default" with the default driver
Creating zookeeper ... done
Creating kafka ...
1234
```

1. 执行以下命令进入kafka容器：

```shell
docker exec -it kafka /bin/bash
1
```

1. 在容器内执行命令docker ps，看到的内容和在宿主机上执行docker ps命令是一样的：

```shell
bash-4.4# docker ps
CONTAINER ID        IMAGE                              COMMAND                  CREATED             STATUS              PORTS                                                NAMES
d612301ea365        wurstmeister/zookeeper             "/bin/sh -c '/usr/sb…"   3 hours ago         Up 2 hours          22/tcp, 2888/tcp, 3888/tcp, 0.0.0.0:2181->2181/tcp   zookeeper
9310ab2d82f4        wurstmeister/kafka:2.11-0.11.0.3   "start-kafka.sh"         3 hours ago         Up 2 hours          0.0.0.0:32769->9092/tcp                              kafka
1234
```

可见容器内的docker客户端发出的请求的确是到达了宿主机的Docker Daemon，并且收到了响应。
\6. 在容器内执行命令ps -ef|grep docker，没有结果，证明容器内没有Docker Daemon服务在运行，在宿主机执行此命令可以看到如下内容，证明宿主机上的Docker Daemon服务是正常的：

```shell
[root@centos7 22]# ps -ef|grep docker
root      14604      1  0 12:00 ?        00:00:46 /usr/bin/dockerd-current --add-runtime docker-runc=/usr/libexec/docker/docker-runc-current --default-runtime=docker-runc --exec-opt native.cgroupdriver=systemd --userland-proxy-path=/usr/libexec/docker/docker-proxy-current --init-path=/usr/libexec/docker/docker-init-current --seccomp-profile=/etc/docker/seccomp.json --selinux-enabled --log-driver=journald --signature-verification=false --storage-driver overlay2
root      14610  14604  0 12:00 ?        00:00:11 /usr/bin/docker-containerd-current -l unix:///var/run/docker/libcontainerd/docker-containerd.sock --metrics-interval=0 --start-timeout 2m --state-dir /var/run/docker/libcontainerd/containerd --shim docker-containerd-shim --runtime docker-runc --runtime-args --systemd-cgroup=true
root      27981  14604  0 16:03 ?        00:00:00 /usr/libexec/docker/docker-proxy-current -proto tcp -host-ip 0.0.0.0 -host-port 32769 -container-ip 172.18.0.2 -container-port 9092
root      27999  14610  0 16:03 ?        00:00:00 /usr/bin/docker-containerd-shim-current 9310ab2d82f41629f734a9dcf54d0002945eaccb7cfcc2352d5a76141a709a14 /var/run/docker/libcontainerd/9310ab2d82f41629f734a9dcf54d0002945eaccb7cfcc2352d5a76141a709a14 /usr/libexec/docker/docker-runc-current
root      28022  14604  0 16:03 ?        00:00:00 /usr/libexec/docker/docker-proxy-current -proto tcp -host-ip 0.0.0.0 -host-port 2181 -container-ip 172.18.0.3 -container-port 2181
root      28029  14610  0 16:03 ?        00:00:00 /usr/bin/docker-containerd-shim-current d612301ea365ac6c6e2b8987e28beb2c2c3eccca720e7d5d7214bf9945c15034 /var/run/docker/libcontainerd/d612301ea365ac6c6e2b8987e28beb2c2c3eccca720e7d5d7214bf9945c15034 /usr/libexec/docker/docker-runc-current
root      38299  10540  0 19:23 pts/0    00:00:00 grep --color=auto docker
12345678
```

## 优化建议

目前我们docker的client、server架构已经比较清楚了，对开篇的问题也找到了答案，不过细心的您是否注意到一个问题，如下图，这是kafka镜像的Dockerfile文件：

![](https://notebook1.oss-cn-shenzhen.aliyuncs.com/img/docker/20190622192840989.jpg)

上图显示kafka镜像中安装了docker应用，这里面包含了client和daemon，但实际上只用到了client，这样是否有些浪费呢？如果以后我们制作镜像的时候要用到docker客户端，难道我们的镜像也要这样把整个docker应用装好么？

一篇来自官方的文档给我们了启发，地址是：https://docs.docker.com/docker-for-azure/upgrade/ ，如下图红框所示，将宿主机的可执行文件docker映射到容器的/usr/bin目录下，这样容器启动后就可以直接执行docker命令了：

![](https://notebook1.oss-cn-shenzhen.aliyuncs.com/img/docker/2019062219521030.jpg)

至此，对docker的/var/run/docker.sock参数的学习和实战就全部完成了，希望本文能帮助您加深对docker的理解，灵活的使用该参数可以助您设计出更强大的docker镜像。