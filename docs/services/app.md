# App service (`compose.apps.yml`)

## Vai trò
- Triển khai CollabMD (`https://github.com/andes90/collabmd`) bằng image `ghcr.io/andes90/collabmd`.
- Có 3 hình thức triển khai độc lập, mỗi hình thức là một app/container riêng:
  - `app` với profile `collabmd-local`: dùng thư mục local.
  - `collabmd-rclone` với profile `collabmd-rclone`: dùng thư mục được rclone mount.
  - `collabmd-git` với profile `collabmd-git`: bootstrap vault từ private git repo.
- `collabmd-plantuml` là PlantUML renderer dùng chung cho các app CollabMD đang bật.

## Bật/tắt hình thức triển khai
- Local: `COLLABMD_LOCAL_ENABLED=true|false` (mặc định true).
- Rclone: `COLLABMD_RCLONE_ENABLED=true|false`.
- Git private repo: `COLLABMD_GIT_DEPLOY_ENABLED=true|false`.

`docker-compose/scripts/dc.sh` tự thêm Compose profile tương ứng khi chạy `npm run dockerapp-exec:up`.

## Cấu hình chung
- `COLLABMD_IMAGE`: image CollabMD.
- `COLLABMD_PORT` + `APP_PORT`: port app lắng nghe trong container. `APP_PORT` vẫn là nguồn sự thật cho Compose.
- `COLLABMD_HEALTH_PATH` + `HEALTH_PATH`: health endpoint, mặc định `/health`.
- `COLLABMD_AUTH_*`: cấu hình auth/password/OIDC chung.
- `COLLABMD_PLANTUML_SERVER_URL`: mặc định `http://collabmd-plantuml:8080`.
- `DOCKER_VOLUMES_ROOT`: root mặc định cho dữ liệu persistent.

## Local mode
- Service: `app`.
- Host vault dir: `COLLABMD_LOCAL_HOST_DIR`.
- Container vault dir: `COLLABMD_LOCAL_CONTAINER_DIR` (mặc định `/data`).
- Direct host port: `COLLABMD_LOCAL_HOST_PORT`.
- Public Caddy site: `COLLABMD_LOCAL_CADDY_SITE`.
- Public app origin: `COLLABMD_LOCAL_PUBLIC_BASE_URL`.

## Rclone mode
- Services: `collabmd-rclone` + `collabmd-rclone-mount`.
- rclone remote: `COLLABMD_RCLONE_REMOTE` (ví dụ `gdrive:notes/collabmd`).
- rclone config:
  - đặt `rclone.conf` trong `COLLABMD_RCLONE_CONFIG_DIR`, hoặc
  - đặt toàn bộ file config dạng base64 vào `COLLABMD_RCLONE_CONFIG_B64`.
- Host mount dir: `COLLABMD_RCLONE_HOST_DIR`.
- Cache dir: `COLLABMD_RCLONE_CACHE_DIR`.
- Direct host port: `COLLABMD_RCLONE_HOST_PORT`.
- Public Caddy site: `COLLABMD_RCLONE_CADDY_SITE`.

Rclone mount cần host/container hỗ trợ FUSE (`/dev/fuse`, `SYS_ADMIN`, bind propagation `rshared`).

## Git private repo mode
- Service: `collabmd-git`.
- Host vault dir: `COLLABMD_GIT_HOST_DIR`.
- Repo URL: `COLLABMD_GIT_REPO_URL`.
- SSH key:
  - đơn giản nhất: `COLLABMD_GIT_SSH_PRIVATE_KEY_B64`, hoặc
  - mount file trong `COLLABMD_GIT_SECRETS_DIR` rồi đặt `COLLABMD_GIT_SSH_PRIVATE_KEY_FILE` theo path trong container.
- Optional known hosts: `COLLABMD_GIT_SSH_KNOWN_HOSTS_FILE`.
- Git identity:
  - với OIDC, commit author/email lấy từ user đang đăng nhập.
  - không dùng OIDC thì có thể đặt fallback qua `COLLABMD_GIT_USER_NAME`, `COLLABMD_GIT_USER_EMAIL`.
- Non-interactive Git: `COLLABMD_GIT_TERMINAL_PROMPT=0`.
- Git safe directory: `COLLABMD_GIT_SAFE_DIRECTORY`, mặc định trùng `COLLABMD_GIT_CONTAINER_DIR`.
- Direct host port: `COLLABMD_GIT_HOST_PORT`.
- Public Caddy site: `COLLABMD_GIT_CADDY_SITE`.

Khi `COLLABMD_GIT_REPO_URL` được đặt, CollabMD clone repo vào `COLLABMD_GIT_CONTAINER_DIR` trong lần boot đầu, sau đó reuse checkout ở các lần chạy tiếp theo.

Env-only setup nên để `COLLABMD_GIT_SSH_PRIVATE_KEY_FILE=` và `COLLABMD_GIT_SSH_KNOWN_HOSTS_FILE=` trống, rồi đặt private key đã base64 vào `COLLABMD_GIT_SSH_PRIVATE_KEY_B64`. Khi không set `COLLABMD_GIT_SSH_KNOWN_HOSTS_FILE`, CollabMD dùng SSH `StrictHostKeyChecking=accept-new`.
Nếu API Git báo `detected dubious ownership in repository at '/data'`, giữ `COLLABMD_GIT_SAFE_DIRECTORY=/data`; compose sẽ truyền `safe.directory` cho Git qua env `GIT_CONFIG_*`.

## Routing / Cloudflare Tunnel
Mỗi hostname Cloudflare Tunnel nên trỏ về `http://caddy:80`; Caddy label sẽ route đến app tương ứng:
- `COLLABMD_LOCAL_CADDY_SITE` -> service `app`.
- `COLLABMD_RCLONE_CADDY_SITE` -> service `collabmd-rclone`.
- `COLLABMD_GIT_CADDY_SITE` -> service `collabmd-git`.

Các ví dụ hostname đã có trong `.env.example` và `cloudflared/config.yml.example`.
