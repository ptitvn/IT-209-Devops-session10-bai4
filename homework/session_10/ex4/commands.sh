#!/bin/bash
# ==============================================================================
# Bài 4: Thiết lập Custom Network & Named Volume bằng Docker CLI
# Script thực thi toàn bộ quy trình: Tạo Network, Volume, Khởi chạy Container,
# Kiểm tra DNS resolution và Kiểm thử Data Persistence
# ==============================================================================

set -e

echo "============================================================"
echo " [BƯỚC 0] Dọn dẹp các tài nguyên cũ (nếu có)"
echo "============================================================"
docker rm -f db-server app-container 2>/dev/null || true
docker network rm app-net 2>/dev/null || true
docker volume rm db-data 2>/dev/null || true

echo ""
echo "============================================================"
echo " [BƯỚC 1] Tạo Custom Bridge Network: app-net"
echo "============================================================"
docker network create --driver bridge app-net
echo "[✓] Đã tạo Custom Network: app-net"

echo ""
echo "============================================================"
echo " [BƯỚC 2] Tạo Named Volume: db-data"
echo "============================================================"
docker volume create db-data
echo "[✓] Đã tạo Named Volume: db-data"

echo ""
echo "============================================================"
echo " [BƯỚC 3] Khởi chạy Database Container (postgres:15-alpine)"
echo " - Tên: db-server"
echo " - Network: app-net"
echo " - Mount volume: db-data -> /var/lib/postgresql/data"
echo "============================================================"
docker run -d \
  --name db-server \
  --network app-net \
  -v db-data:/var/lib/postgresql/data \
  -e POSTGRES_DB=testdb \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  postgres:15-alpine

echo "[✓] Database container đã khởi chạy. Đang chờ PostgreSQL sẵn sàng..."
until docker exec db-server pg_isready -U postgres -d testdb >/dev/null 2>&1; do
  echo "    Đang chờ PostgreSQL khởi động..."
  sleep 2
done
echo "[✓] PostgreSQL đã sẵn sàng nhận kết nối!"

echo ""
echo "============================================================"
echo " [BƯỚC 4] Khởi chạy Backend Container (app-container)"
echo " - Network: app-net"
echo " - Biến môi trường kết nối DB: hostname db-server"
echo "============================================================"
docker run -d \
  --name app-container \
  --network app-net \
  -e DB_HOST=db-server \
  -e DB_PORT=5432 \
  -e DB_NAME=testdb \
  -e DB_USER=postgres \
  -e DB_PASSWORD=postgres \
  alpine:latest sleep infinity

echo "[✓] Backend container app-container đã khởi chạy và tham gia app-net."

echo ""
echo "============================================================"
echo " [BƯỚC 5] Kiểm tra cấu hình hệ thống"
echo "============================================================"

echo "--- 1. Kiểm tra Network app-net ---"
docker network ls | grep app-net || true

echo ""
echo "--- 2. Kiểm tra Volume db-data ---"
docker volume ls | grep db-data || true

echo ""
echo "--- 3. Kiểm tra chi tiết Network inspect (Container tham gia) ---"
docker network inspect app-net

echo ""
echo "--- 4. Kiểm tra DNS Resolution: app-container ping db-server ---"
docker exec app-container ping -c 2 db-server

echo ""
echo "============================================================"
echo " [BƯỚC 6] Test Data Persistence (Tính bền vững dữ liệu)"
echo "============================================================"

echo "--- 6.1: Thêm dữ liệu ban đầu vào database testdb ---"
docker exec -i db-server psql -U postgres -d testdb << 'EOF'
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO users (name, email) VALUES 
('Nguyen Van A', 'vana@example.com'),
('Tran Thi B', 'thib@example.com'),
('Le Van C', 'vanc@example.com');

SELECT * FROM users;
EOF

echo ""
echo "--- 6.2: Xóa cứng Container DB (docker rm -f db-server) ---"
docker rm -f db-server
echo "[✓] Container db-server đã bị xóa hoàn toàn khỏi Docker engine."

echo ""
echo "--- 6.3: Khởi chạy Container DB mới gắn cùng Named Volume db-data ---"
docker run -d \
  --name db-server \
  --network app-net \
  -v db-data:/var/lib/postgresql/data \
  -e POSTGRES_DB=testdb \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  postgres:15-alpine

echo "[✓] Container db-server mới đã chạy. Đang chờ kết nối..."
until docker exec db-server pg_isready -U postgres -d testdb >/dev/null 2>&1; do
  echo "    Đang chờ PostgreSQL tái khởi động..."
  sleep 2
done

echo ""
echo "--- 6.4: Xác minh dữ liệu không bị mất sau khi tái tạo Container ---"
docker exec -i db-server psql -U postgres -d testdb -c "SELECT * FROM users;"

echo ""
echo "--- 6.5: Kiểm tra lại kết nối mạng từ Backend Container tới DB mới ---"
docker exec app-container ping -c 2 db-server

echo ""
echo "============================================================"
echo " [HOÀN TẤT] TẤT CẢ CÁC BƯỚC ĐÃ THỰC THI THÀNH CÔNG RỰC RỠ!"
echo " - DNS resolution nội bộ trong custom network: THÀNH CÔNG"
echo " - Dữ liệu bền vững qua Named Volume: THÀNH CÔNG"
echo "============================================================"
