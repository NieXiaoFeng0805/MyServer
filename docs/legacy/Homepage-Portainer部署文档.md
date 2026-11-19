# Homepage + Portainer 部署文档

> **部署日期**: 2026-07-12
> **用途**: NXL Server 家庭服务器的服务仪表盘与容器可视化管理
> **本文件是 Claude Code 知识库的一部分**

---

## 一、方案说明

采用了 **Homepage + Portainer 双组件** 方案：

| 组件 | 用途 | 访问地址 | 使用频率 |
|---|---|---|---|
| **Homepage** | 服务导航仪表盘，一眼看所有服务状态 | `http://192.168.1.88:3000` | 日常高频 |
| **Portainer** | Docker 容器全功能管理（日志/启停/配置） | `https://192.168.1.88:9443` | 维护时使用 |

两个工具互补，不冲突：
- Homepage 面向"查看状态 + 快速跳转"
- Portainer 面向"深度管理 Docker 环境"

---

## 二、Homepage 配置

### 2.1 部署信息

| 属性 | 值 |
|---|---|
| **镜像** | `ghcr.io/gethomepage/homepage:latest` |
| **容器名** | `homepage` |
| **访问端口** | `3000` |
| **配置目录** | `/data/docker/homepage/config/` |
| **网络** | `docker_default`（与 Jellyfin/qBittorrent 同一网络） |
| **重启策略** | `unless-stopped` |
| **docker.sock** | 已挂载（只读）— 用于 Docker 集成 |

### 2.2 Compose 配置

```yaml
homepage:
  image: ghcr.io/gethomepage/homepage:latest
  container_name: homepage
  restart: unless-stopped
  environment:
    - PUID=1000
    - PGID=1000
    - TZ=Asia/Shanghai
    - HOMEPAGE_ALLOWED_HOSTS=192.168.1.88:3000,192.168.1.88
  volumes:
    - /data/docker/homepage/config:/app/config
    - /var/run/docker.sock:/var/run/docker.sock:ro
  ports:
    - "3000:3000"
  depends_on:
    - jellyfin
    - qbittorrent
```

### 2.3 配置文件结构

```
/data/docker/homepage/config/
├── settings.yaml      ← 全局设置（主题、标题、布局）
├── services.yaml      ← 服务卡片和 Widget 定义
├── bookmarks.yaml     ← 书签/快速链接
├── docker.yaml        ← Docker 容器自动发现
└── widgets.yaml       ← 自定义 Widget（可选）
```

> **热加载**: Homepage 监控 config 目录，修改 YAML 后无需重启，页面自动刷新。

### 2.4 settings.yaml — 全局设置

```yaml
title: NXL Server
description: 家庭服务器管理仪表盘
theme: dark
color: slate
headerStyle: boxed
statusStyle: "dot"
language: zh-Hans
fiveColumns: true
showStats: true

layout:
  Media:
    style: row
    columns: 2
  Downloads:
    style: row
    columns: 2
  Management:
    style: row
    columns: 2
  Quick Links:
    style: row
    columns: 4
```

### 2.5 services.yaml — 服务卡片配置

**✅ 当前状态 (2026-10-04)**: Jellyfin API Key 和 qBittorrent 凭据已填入，Widget 可正常取数。Portainer Widget 的 API Key 已生成并填入。2026-10-04 起服务卡片链接切到统一入口（NPM 反代）。

```yaml
- Media:
    - Jellyfin:
        icon: jellyfin.png
        href: http://192.168.1.88:8096
        description: 媒体服务器
        widget:
          type: jellyfin
          url: http://jellyfin:8096
          key: <见 APIKey.txt>                      # ✅ 已填入 (2026-10-04)
          enableBlocks: true
          enableNowPlaying: true
          showEpisodeNumber: true

- Downloads:
    - qBittorrent:
        icon: qbittorrent.png
        href: http://192.168.1.88/qbittorrent/
        description: BT 下载管理
        widget:
          type: qbittorrent
          url: http://qbittorrent:8080
          username: admin                              # ✅ 已填入 (2026-10-04)
          password: <见 APIKey.txt>                    # ✅ 已填入 (2026-10-04)
          enableLeechProgress: true

- Management:
    - Portainer:
        icon: portainer.png
        href: http://192.168.1.88/portainer/           # 统一入口，需网关密码
        description: Docker 容器管理 (网关密码)
        widget:
          type: portainer
          url: http://portainer:9000       # ← 用内网 HTTP：9443 自签名证书在容器内 TLS 校验失败
          env: 1
          key: <见 APIKey.txt>              # ✅ 已填入 (2026-10-04)
    - code-server:
        icon: code-server.png
        href: http://192.168.1.88/code/                # 统一入口，需网关密码
        description: VS Code 网页版 (网关密码)
    - Nginx Proxy Manager:
        icon: nginxproxymanager.png
        href: http://192.168.1.88:81
        description: 统一入口管理台
```

> **统一入口 (2026-10-04)**: 所有服务通过 NPM 反代收敛到 `http://192.168.1.88/` 子路径，详见 `服务器配置文档.md` §5.7。

> **注意**: services.yaml 中容器间通信使用的是 Docker 内部服务名（如 `http://jellyfin:8096`）而非外网 IP，因为 Homepage 和它们都在 `docker_default` 网络上，服务名自动 DNS 解析。

### 2.6 如何获取 API Key

#### Jellyfin API Key
1. 登录 Jellyfin WebUI: `http://192.168.1.88:8096`
2. 进入 **管理仪表盘 → 高级 → API 密钥**
3. 点击 **+** 创建新密钥，名称填 `homepage`
4. 复制生成的 API Key
5. 编辑 `/data/docker/homepage/config/services.yaml`，替换 `JELLYFIN_API_KEY_PLACEHOLDER`

#### qBittorrent 用户名和密码
1. 登录 qBittorrent WebUI: `http://192.168.1.88:8080`
   - 默认用户名: `admin`
   - 默认密码: `adminadmin`（可在日志中查到）
2. 编辑 `/data/docker/homepage/config/services.yaml`，替换占位符

> 修改后 Homepage 会自动重载，无需手动重启容器。

### 2.7 bookmarks.yaml — 快速链接

```yaml
- Quick Links:
    - GitHub:
        icon: github.png
        href: https://github.com
    - Claude:
        icon: claude.png
        href: https://claude.ai
    - Docker Hub:
        icon: docker.png
        href: https://hub.docker.com
```

---

## 三、Portainer 配置

### 3.1 部署信息

| 属性 | 值 |
|---|---|
| **镜像** | `portainer/portainer-ce:lts` |
| **容器名** | `portainer` |
| **访问端口** | `9443` (HTTPS) |
| **数据目录** | `/data/docker/portainer/data` |
| **重启策略** | `always` |
| **docker.sock** | 已挂载（读写）— Portainer 需要管理 Docker |

### 3.2 Compose 配置

```yaml
portainer:
  image: portainer/portainer-ce:lts
  container_name: portainer
  restart: always
  volumes:
    - /var/run/docker.sock:/var/run/docker.sock
    - /data/docker/portainer/data:/data
  ports:
    - "9443:9443"
```

> **为什么不用 `8000` 端口**: 8000 用于 Portainer Edge Agent 模式（管理远程 Docker 节点），单机部署不需要。

### 3.3 首次设置

> ✅ (2026-10-04) 初始化完成（此前从未初始化，5 分钟安全窗口超时后由 Claude 重启容器取 setup token 完成）。admin 凭据见 APIKey.txt。以下为首次设置步骤记录。

1. 浏览器打开 `https://192.168.1.88:9443`
2. 浏览器会提示证书不安全（自签名证书），点击 **高级 → 继续访问**
3. 创建管理员账户（用户名 + 密码，要求至少 12 个字符）
4. 选择 "**Get Started**"（本地 Docker 环境会自动检测到）
5. 点击 `local` 环境进入管理面板

> **端口 9443 vs 9000**: 9443 是 HTTPS（推荐），9000 是 HTTP（仅向后兼容）。如果浏览器 9443 有问题，可改用 9000 端口，但需要在 compose 中添加。

> ✅ (2026-10-04) Homepage Widget 通过内网 `http://portainer:9000` 访问 API：9443 自签名证书在 Homepage 容器内 TLS 校验失败（`DEPTH_ZERO_SELF_SIGNED_CERT`）。9000 仅 docker_default 网络内可达（compose 未发布到宿主机），无暴露风险。

### 3.4 主要功能

| 功能 | 路径 | 用途 |
|---|---|---|
| **Dashboard** | Home | 容器/镜像/卷/网络概览 |
| **Containers** | Containers | 查看日志、启停、进入容器终端、查看 stats |
| **Stacks** | Stacks | 管理 Docker Compose 项目（可直接编辑 compose 文件） |
| **Images** | Images | 镜像管理（拉取/删除/查看） |
| **Volumes** | Volumes | 数据卷管理 |

> **注意**: 当前 compose 项目是通过命令行 `docker compose` 管理的，Portainer 的 Stacks 功能可以识别但不能直接管理外部创建的 compose 项目。建议继续用命令行 + compose 文件管理，Portainer 用于**监控和调试**。

---

## 四、当前服务全景

```
┌──────────────────────────────────────────────┐
│                  NXL Server                   │
│                                              │
│  ┌─────────┐  ┌──────────┐  ┌────────────┐  │
│  │ Homepage│  │ Portainer│  │  Jellyfin  │  │
│  │  :3000  │  │  :9443   │  │   :8096    │  │
│  │  ● 在线  │  │  ● 在线   │  │  ● 在线    │  │
│  └─────────┘  └──────────┘  └────────────┘  │
│                                              │
│  ┌──────────┐                               │
│  │qBittorrent│                              │
│  │  :8080   │                               │
│  │  ● 在线   │                               │
│  └──────────┘                               │
│                                              │
│  Docker Compose 项目: docker                  │
│  网络: docker_default (172.18.0.0/16)        │
└──────────────────────────────────────────────┘
```

---

## 五、日常使用速查

### 5.1 Homepage

```bash
# 查看日志
docker compose -f /data/docker/docker-compose.yml logs homepage -f

# 重启
docker compose -f /data/docker/docker-compose.yml restart homepage

# 验证配置文件语法（Homepage 启动时会自动检查）
docker compose -f /data/docker/docker-compose.yml logs homepage
```

### 5.2 Portainer

```bash
# 查看日志
docker compose -f /data/docker/docker-compose.yml logs portainer -f

# 重启
docker compose -f /data/docker/docker-compose.yml restart portainer

# 重置 Portainer（删除所有数据，需重新初始化）
docker compose -f /data/docker/docker-compose.yml down portainer
rm -rf /data/docker/portainer/data/*
docker compose -f /data/docker/docker-compose.yml up -d portainer
```

### 5.3 修改 Homepage 配置

```bash
# 编辑服务卡片
vim /data/docker/homepage/config/services.yaml

# 编辑页面设置
vim /data/docker/homepage/config/settings.yaml

# 无需重启 — Homepage 热加载配置
```

---

## 六、更新后的端口清单

| 端口 | 协议 | 服务 | 用途 |
|---|---|---|---|
| `22` | TCP | SSH | 远程管理 |
| `80` | TCP | NPM | **2026-10-04 新增** — 统一入口反代 |
| `81` | TCP | NPM | **2026-10-04 新增** — NPM 管理台 |
| `3000` | TCP | Homepage | **新增** — 服务仪表盘 |
| `8096` | TCP | Jellyfin | 媒体服务器 WebUI |
| `8080` | TCP | qBittorrent | BT 下载 WebUI |
| `6881` | TCP/UDP | qBittorrent | BT P2P DHT |
| `9443` | TCP | Portainer | **新增** — Docker 管理 (HTTPS) |

---

## 七、待完成事项

- [x] **获取 Jellyfin API Key** — 已填入 `services.yaml` (2026-10-04 核对)
- [x] **获取 qBittorrent 密码** — 已填入 `services.yaml` (2026-10-04 核对)
- [x] **Portainer 初始化** — 2026-10-04 完成（setup token 方式，此前从未初始化）
- [x] **Portainer API Key** — 2026-10-04 已生成并填入 `services.yaml`
- [x] **统一入口 (NPM 反代)** — 2026-10-04 完成：`/`→Homepage、`/jellyfin`、`/qbittorrent`、`/portainer`、`/code`，后两者加网关密码
- [ ] **Homepage 自定义** — 按需修改主题色、背景图、书签等

---

## 八、变更记录

| 日期 | 变更 |
|---|---|
| 2026-07-12 | 部署 Homepage (`ghcr.io/gethomepage/homepage:latest`) 和 Portainer (`portainer/portainer-ce:lts`) |
| 2026-07-12 | 创建 Homepage 配置文件（settings/services/bookmarks/docker.yaml），含占位符 |
| 2026-07-12 | 编写本配置文档 |
| 2026-10-04 | 服务器 IP 固定为 `192.168.1.88`，Homepage `HOMEPAGE_ALLOWED_HOSTS` 与 `services.yaml` 跳转链接同步更新并重建容器 |
| 2026-10-04 | 核对确认 Jellyfin/qBittorrent Widget 凭据已配置；用户确认 Portainer 已完成初始化 |
| 2026-10-04 | Portainer 完成首次初始化（setup token 方式）并生成 Homepage Widget 用 API Key |
| 2026-10-04 | 部署统一入口 NPM 反代：服务卡片链接切到 `:80` 子路径（Portainer/code-server 走网关密码），`HOMEPAGE_ALLOWED_HOSTS` 增加裸 IP |
