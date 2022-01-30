# Learning Kubernetes

Notes going together with the YT video [Kubernetes Tutorial for Beginners [FULL COURSE in 4 Hours] - YouTube](https://www.youtube.com/watch?v=X48VuDVv0do) from "Techworld with Nana".

## K8S main components

[Concepts | Kubernetes](https://kubernetes.io/docs/concepts/)

### Node

[Nodes | Kubernetes](https://kubernetes.io/docs/concepts/architecture/nodes/): Worker or node is the basic component of a K8S cluster. It contains 1 or more pods.

### Pod

[Pods | Kubernetes](https://kubernetes.io/docs/concepts/workloads/pods/): A pod is an abstraction layer over the used container technology (docker, containerd, crio, ...). When created, they receive an IP address that allows them to communicate with other pods

Pods are ephemeral in nature and non persistent. When recreated they are resetted and receive an new IP.

```yaml
apiVersion: v1
kind: Pod
metadata:
 name: nginx
spec:
 containers:
 - name: nginx
   image: nginx:1.14.2
   ports:
   - containerPort: 80
```

One (1) pod $\approx$ 1 container $\approx$ 1 application, but a pod can contain several containers. For example, you might have a container that acts as a web server for files in a shared volume, and a separate "sidecar" container that updates those files from a remote source, as in the following diagram:

![](C:\Users\Chris\AppData\Roaming\marktext\images\2022-01-16-10-43-38-image.png)

![Pod creation diagram](https://d33wubrfki0l68.cloudfront.net/aecab1f649bc640ebef1f05581bfcc91a48038c4/728d6/images/docs/pod.svg)![Pod creation diagram](https://d33wubrfki0l68.cloudfront.net/aecab1f649bc640ebef1f05581bfcc91a48038c4/728d6/images/docs/pod.svg)

![Pod creation diagram](https://d33wubrfki0l68.cloudfront.net/aecab1f649bc640ebef1f05581bfcc91a48038c4/728d6/images/docs/pod.svg)![Pod creation diagram](https://d33wubrfki0l68.cloudfront.net/aecab1f649bc640ebef1f05581bfcc91a48038c4/728d6/images/docs/pod.svg)![Pod creation diagram](https://d33wubrfki0l68.cloudfront.net/aecab1f649bc640ebef1f05581bfcc91a48038c4/728d6/images/docs/pod.svg)

### Service

[Service | Kubernetes](https://kubernetes.io/docs/concepts/services-networking/service/): A service is an abstraction layer above (1 or more) pods. Services keep their IP addresses and acts as a load balancer by connecting to an underlying pod(s) to provide the requested service.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-service
spec:
  selector:
    app: MyApp
  ports:
    - protocol: TCP
      port: 80
      targetPort: 9376
```

### Volume

[Volumes | Kubernetes](https://kubernetes.io/docs/concepts/storage/volumes/): By concept, on-disk files in a container are ephemeral. When a pod ceases to exist, Kubernetes destroys ephemeral volumes (data is preserved across container restarts). This causes issues:

- loss of files when a container crashes. The kubelet restarts the container but with a clean state.

- Issues in sharing files between containers running together in a `Pod`.

Creating *persistent* volumes addresses these issues: Kubernetes does not destroy persistent volumes.

Kubernetes supports many types of volumes. A [Pod](https://kubernetes.io/docs/concepts/workloads/pods/) can use any number of volume types simultaneously.

Example of persistent storage on a NFS mount

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv0003
spec:
  capacity:
    storage: 5Gi
  volumeMode: Filesystem
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Recycle
  storageClassName: slow
  mountOptions:
    - hard
    - nfsvers=4.1
  nfs:
    path: /tmp
    server: 172.17.0.2
```

### Ingress

[Ingress | Kubernetes](https://kubernetes.io/docs/concepts/services-networking/ingress/): Allows external incoming traffic to a service. It allows for external publication of a service.

[Ingress](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.23/#ingress-v1-networking-k8s-io) exposes HTTP and HTTPS routes from outside the cluster to [services](https://kubernetes.io/docs/concepts/services-networking/service/) within the cluster. Traffic routing is controlled by rules defined on the Ingress resource.

An [Ingress controller](https://kubernetes.io/docs/concepts/services-networking/ingress-controllers) is responsible for fulfilling the Ingress, usually with a load balancer, though it may also configure your edge router or additional frontends to help handle the traffic.

![](C:\Users\Chris\AppData\Roaming\marktext\images\2022-01-16-10-29-51-image.png)

![](C:\Users\Chris\AppData\Roaming\marktext\images\2021-12-29-22-10-47-image.png)

### Deployments: ReplicaSet (of pods)

[ReplicaSet | Kubernetes](https://kubernetes.io/docs/concepts/workloads/controllers/replicaset/): Replica of pods are connected to the same service. Combined with a service, it acts as a load balancer in the K8S cluster.

`xtophe@rpi4a:~$ kubectl get deployments
NAME               READY   UP-TO-DATE   AVAILABLE   AGE
nginx-deployment   3/3     3            3           17d`

`xtophe@rpi4a:~$ kubectl get replicasets
NAME                          DESIRED   CURRENT   READY   AGE
nginx-deployment-66b6c48dd5   3         3         3       17d`

`xtophe@rpi4a:~$ kubectl get pods
NAME                                READY   STATUS    RESTARTS   AGE
aws-linux-priv                      1/1     Running   2          17d
nginx-deployment-66b6c48dd5-7rlj7   1/1     Running   2          17d
nginx-deployment-66b6c48dd5-r8tpg   1/1     Running   2          17d
nginx-deployment-66b6c48dd5-sbk4s   1/1     Running   2          17d
ubuntu-priv                         1/1     Running   2          18d`

### StatefulSet (of DBs)

[StatefulSets | Kubernetes](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/): DBs (Mongo, Elastic, MySQL, ...) cannot just point to the same (persistent) volume. A specific mechanism is needed to avoid inconsistency = Stateful set. Difficult to setup and hence DB consistency is build outside of the K8S cluster

![](C:\Users\Chris\AppData\Roaming\marktext\images\2021-12-29-22-41-16-image.png)

### Debugging

- `kubectl exec -it <podname> -- bin/bash` ==> Provides (eventual) logs generated by the pod
- `kubectl edit <resourcetype> <resourcename>` ==> Using default editor, it will produce a yaml file of the configuration of the resource
- `kubectl logs <podname>` ==> Provides (eventual) logs generated by the pod
- `kubectl describe <resourcetype> <resourcename>` ==> Gives even more insights to what's happening in the pod

## K8S architecture

### Worker (slave)

*Manages the resources inside the node*

- Container runtime (docker, containerd, crio, ...)

- Kubelet
  
  - Link between "Node" and "pods". Assigns node resources to the different pods
  
  - Communicates using services between kubelets

- Kube proxy

### Master

*Manges the overall cluster*

- API server
  
  - Gateway to "talk" to the cluster
  
  - Gatekeeper of the cluster (checks rights and permissions)

- Scheduler: Decides what worker shold start a specific pod

- Controller manager: Detects state changes and acts upon them

- etcd: Contains current status of any k8s component = cluster brain

## K8S config file YAML structure

:exclamation: Attention points:

- Structure is submitted to strict indentation

- Keys in the key value pairs are camelCase

The YAML-file's structure is as follows:

1. Generic info
   
   - apiVersion:
   
   - kind:

2. Three (3) declarative parts:
   
   1. metadata
      Contains **labels**
   
   2. spec
      Attributes specific to the kind (resourcetype)
      Contains **selector**. The selector links with the label key value pair.
   
   3. status
      Autogenerated by K8S. Controller manager compares **actual** state (in etcd) with **desired** state (in yaml) and acts if needed.

# Demo: deplo mongoDB and mongo-express

## High level

1. Deploy a mongodb pod using a deployment yaml

2. Create a service on top of the pod to allow to connect to

3. Deploy a mongo-express (= admin web interface for mongoDB) pod using a deployment yaml

4. Publish it outside of the cluster (using a service)

## Detailed step-by-step

See Youtube video. Remarks:

1. Use image: mongo:4.2-rc (4.4 requires ARM64v8.2 and rpi4 has ARM64v8 only)

2. You can "concatenate" the differend yaml config kinds, by separating it with <crLf> '---' <crLf>

3. Best to keep the secret configuration outside of the "main" yaml

4. When creating the service for mongo-express (to allow external access), create it with type "LoadBalancer".

5. LoadBalancer type did not get an enxternal IP. `kubectl get service` --> EXTERNAL-IP stays on "<pending>". I had to manually map the local node IP to the service using:
   `kubectl port-forward service/mongo-express-service --address 0.0.0.0 --address :: 8081:8081`

# Namespaces

Namespaces can be used to group the different components in logical entities. By default, when creating a component, it is placed in the **default** namespace.

To define a component in a specific namespace:

- `kubectl apply -f <my_definition.yaml> --namespace= >my-namespace>`

- Add `namespace: `in the metadata section of the yam file

Some components cannot be namespaced and live globally in the cluster: volumes, nodes.

`kubectl api-resources --namespaced=true/false`

You can permanently switch your ns context (no need to add -n <namespace> anymore) with kubens (see [GitHub - ahmetb/kubectx: Faster way to switch between clusters and namespaces in kubectl](https://github.com/ahmetb/kubectx))

## 4 Namespaces out of the box

![](C:\Users\Chris\AppData\Roaming\marktext\images\2022-01-16-09-11-26-image.png)

## Namespace useage

1. Structure your components

2. Avoid conflicts between teams

3. Share services between different environments

4. Access and Resource Limits on Namespace Level

### Structure your components: Group resources

![](C:\Users\Chris\AppData\Roaming\marktext\images\2022-01-16-09-19-36-image.png)

### Avoid conflicts

Many teams, same applications --> teams identification

![](C:\Users\Chris\AppData\Roaming\marktext\images\2022-01-16-09-21-50-image.png)

### Service/ resource sharing

Namespaces can share some of their resources, but not all.

ConfigMap, Secret = per namesapce

Service = Can be accessed by resources from other ns.

#### Staging/ Development

![](C:\Users\Chris\AppData\Roaming\marktext\images\2022-01-16-09-22-17-image.png)

#### Blue, Green deployments

![](C:\Users\Chris\AppData\Roaming\marktext\images\2022-01-16-09-23-28-image.png)

### Access and resource limitation

Isolated environment + Limit CPU, RAM, Storage per NS

![](C:\Users\Chris\AppData\Roaming\marktext\images\2022-01-16-09-24-25-image.png)

![](C:\Users\Chris\AppData\Roaming\marktext\images\2022-01-16-09-25-19-image.png)

# Kubernetes Ingress

Simple, quick and dirty external publishing: use type "LoadBalancer". Point to IP-address + port (30000-30)

![](C:\Users\Chris\AppData\Roaming\marktext\images\2022-01-16-10-20-19-image.png)

Better solution: use ingress. This allows for:

- publishing using a correct url

- load balancing traffic

- terminating SSL/ TLS connection

- name-based virtual hosting



![](C:\Users\Chris\AppData\Roaming\marktext\images\2022-01-16-10-30-06-image.png)



![](C:\Users\Chris\AppData\Roaming\marktext\images\2022-01-16-10-10-52-image.png)

![](C:\Users\Chris\AppData\Roaming\marktext\images\2022-01-16-10-14-12-image.png)
