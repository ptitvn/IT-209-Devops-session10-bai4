# Báo Cáo Thực Hành: Bài 4 - Thiết Lập Custom Network & Named Volume Bằng Docker CLI

## 1. Giới Thiệu & Mục Tiêu

### 1.1 Mục Tiêu
- **Custom Bridge Network:** Tạo mạng cầu nối tùy chỉnh (`app-net`) để kích hoạt cơ chế Docker Embedded DNS, cho phép các container phân giải địa chỉ và giao tiếp với nhau bằng service name/container name thay vì IP tĩnh (tránh lỗi khi IP container bị thay đổi lúc khởi động lại).
- **Named Volume:** Tạo volume có định danh (`db-data`) do Docker quản lý nhằm tách biệt dữ liệu khỏi vòng đời của container (Container Lifecycle), đảm bảo **Data Persistence** (tính bền vững của dữ liệu).
- **Kiểm thử Data Persistence:** Thêm dữ liệu vào Database, xóa cứng container (`docker rm -f`), tái tạo container mới gắn vào cùng Volume và chứng minh dữ liệu vẫn toàn vẹn.

### 1.2 Kiến Trúc Hệ Thống

```
+-----------------------------------------------------------------------------------+
| Host Machine                                                                      |
|                                                                                   |
|                           [Custom Network: app-net]                              |
|                    +------------------------------------+                         |
|                    |                                    |                         |
|  +-----------------+--------------+     +---------------+-----------------+       |
|  | Container: app-container       |     | Container: db-server            |       |
|  | Image: alpine:latest           |     | Image: postgres:15-alpine       |       |
|  | - DB_HOST=db-server            |     | - POSTGRES_DB=testdb            |       |
|  | - DB_PORT=5432                 |     | - Port: 5432                    |       |
|  +--------------------------------+     +----------------+----------------+       |
|                 | (DNS Ping / Query)                     |                        |
|                 +----------------------------------------+                        |
|                                                          | Mount                  |
|                                                          v                        |
|                                       +------------------------------------+      |
|                                       | Docker Named Volume: db-data       |      |
|                                       | Path: /var/lib/postgresql/data     |      |
|                                       +------------------------------------+      |
+-----------------------------------------------------------------------------------+
```

---

## 2. Phân Tích Kỹ Thuật (Lý Thuyết Đi Kèm)

### 2.1 Default Bridge vs. Custom Bridge Network
| Đặc điểm | Default Bridge (`bridge`) | Custom Bridge (`app-net`) |
| :--- | :--- | :--- |
| **Phân giải DNS tự động** |  Không hỗ trợ (phải dùng `--link` đã deprecated hoặc IP tĩnh) |  Tự động phân giải DNS qua container name / service name |
| **Tính cô lập mạng** |  Tất cả container không khai báo network đều vào đây chung |  Chỉ các container được chỉ định mới có thể kết nối với nhau |
| **Khả năng kết nối động** |  Container phải cấu hình network lúc tạo |  Có thể `docker network connect/disconnect` khi container đang chạy |
| **Cấu hình bảo mật** | Thấp hơn | Cao hơn (Micro-segmentation) |

### 2.2 Named Volume vs. Container Storage Layer
- Mặc định khi ghi dữ liệu vào container, dữ liệu nằm ở **Writable Container Layer (OverlayFS)**. Khi container bị xóa (`docker rm`), layer này bị hủy hoàn toàn, dẫn đến mất dữ liệu.
- **Named Volume (`db-data`):** Được lưu trữ tại `/var/lib/docker/volumes/db-data/_data` trên host machine. Volume không gắn liền với vòng đời của bất kỳ container nào, cho phép nhiều container lần lượt hoặc cùng lúc sử dụng mà không lo mất dữ liệu.

---

## 3. Các Bước Thực Hiện Chi Tiết

### Bước 1: Tạo Custom Bridge Network
```bash
docker network create --driver bridge app-net
```
*Mục đích:* Tạo mạng riêng biệt với driver `bridge`, hỗ trợ DNS nội bộ.

### Bước 2: Tạo Named Volume
```bash
docker volume create db-data
```
*Mục đích:* Khởi tạo vùng lưu trữ bền vững cho PostgreSQL.

### Bước 3: Khởi Chạy Database Container
```bash
docker run -d \
  --name db-server \
  --network app-net \
  -v db-data:/var/lib/postgresql/data \
  -e POSTGRES_DB=testdb \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  postgres:15-alpine
```
*Giải thích cờ lệnh:*
- `-d`: Chạy ngầm (detached mode).
- `--name db-server`: Đặt tên định danh container (đồng thời là hostname trong DNS nội bộ).
- `--network app-net`: Gia nhập mạng `app-net`.
- `-v db-data:/var/lib/postgresql/data`: Mount volume `db-data` vào thư mục dữ liệu chuẩn của PostgreSQL.
- `-e ...`: Cấu hình thông số khởi tạo Database.

### Bước 4: Khởi Chạy Backend Container
```bash
docker run -d \
  --name app-container \
  --network app-net \
  -e DB_HOST=db-server \
  -e DB_PORT=5432 \
  -e DB_NAME=testdb \
  -e DB_USER=postgres \
  -e DB_PASSWORD=postgres \
  alpine:latest sleep infinity
```
*Giải thích:* Container backend tham gia cùng mạng `app-net` và trỏ cấu hình DB về `db-server`.

---

## 4. Kiểm Tra & Kết Quả Thực Nghiệm

### 4.1 Kiểm tra Network & Volume
```bash
# Kiểm tra network
docker network ls | grep app-net
# Output:
# 7e86a631bc2a   app-net   bridge    local

# Kiểm tra volume
docker volume ls | grep db-data
# Output:
# local     db-data
```

### 4.2 Kiểm tra chi tiết Network
```bash
docker network inspect app-net
```
*Kết quả:* Cả hai container `db-server` (IP `172.19.0.2`) và `app-container` (IP `172.19.0.3`) đều nằm trong cùng subnet và được cấp phát IP nội bộ.

### 4.3 Kiểm tra DNS Resolution từ Backend đến Database
```bash
docker exec -it app-container ping -c 2 db-server
```
**Output thực tế:**
```text
PING db-server (172.19.0.2): 56 data bytes
64 bytes from 172.19.0.2: seq=0 ttl=64 time=0.128 ms
64 bytes from 172.19.0.2: seq=1 ttl=64 time=0.074 ms

--- db-server ping statistics ---
2 packets transmitted, 2 packets received, 0% packet loss
round-trip min/avg/max = 0.074/0.101/0.128 ms
```
> **Đánh giá:** Container `app-container` đã phân giải thành công hostname `db-server` thành IP nội bộ `172.19.0.2` mà không cần biết trước IP.

---

## 5. Kiểm Thử Tính Bền Vững Của Dữ Liệu (Data Persistence Test)

### 5.1 Thêm dữ liệu ban đầu
```bash
docker exec -i db-server psql -U postgres -d testdb << 'EOF'
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL
);
INSERT INTO users (name, email) VALUES 
('Nguyen Van A', 'vana@example.com'), 
('Tran Thi B', 'thib@example.com');
SELECT * FROM users;
EOF
```
**Kết quả hiển thị:**
```text
CREATE TABLE
INSERT 0 2
 id |     name     |      email       
----+--------------+------------------
  1 | Nguyen Van A | vana@example.com
  2 | Tran Thi B   | thib@example.com
(2 rows)
```

### 5.2 Xóa cứng Database Container
```bash
docker rm -f db-server
```
Container `db-server` đã bị hủy hoàn toàn khỏi bộ nhớ và tiến trình Docker.

### 5.3 Khởi tạo Database Container MỚI gắn cùng Named Volume
```bash
docker run -d \
  --name db-server \
  --network app-net \
  -v db-data:/var/lib/postgresql/data \
  -e POSTGRES_DB=testdb \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  postgres:15-alpine
```

### 5.4 Xác minh dữ liệu không bị mất
```bash
docker exec -i db-server psql -U postgres -d testdb -c "SELECT * FROM users;"
```
**Output thực tế:**
```text
 id |     name     |      email       
----+--------------+------------------
  1 | Nguyen Van A | vana@example.com
  2 | Tran Thi B   | thib@example.com
(2 rows)
```

> **Kết luận:** Dữ liệu hoàn toàn nguyên vẹn sau khi xóa cứng container. Volume `db-data` đã bảo toàn toàn bộ database clusters và schema của PostgreSQL.

---

## 6. Hướng Dẫn Chạy & Kiểm Thử

### Thực thi script commands.sh
```bash
cd homework/session_10/ex4
chmod +x commands.sh
./commands.sh
```

---

