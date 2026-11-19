# compose/

这里是 `/data/docker/docker-compose.yml` 的**镜像副本**，用于版本记录与审查。

- 真相源仍是服务器上的 `/data/docker/docker-compose.yml`
- 本文件不含密钥（原文件也没有）
- 端口、内存上限、卷挂载是"目标状态"；运行态可能还没 apply，用
  `docker compose ps` + `docker inspect` 核对

同步：

```bash
cp /data/docker/docker-compose.yml compose/docker-compose.yml
```
