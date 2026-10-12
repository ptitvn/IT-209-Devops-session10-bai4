# Bài 4: Thiết Lập Custom Network & Named Volume Bằng Docker CLI

> **Môn học:** IT-209 - DevOps  
> **Session:** 10 - Container Networking & Storage  
> **Thực hiện:** Thiết lập Custom Bridge Network và Named Volume, kiểm tra DNS resolution nội bộ và tính bền vững của dữ liệu (Data Persistence).

---

## 📂 Cấu Trúc Nộp Bài
```text
bai4/
├── README.md
└── homework/
    └── session_10/
        └── ex4/
            ├── commands.sh   # File script chính thực thi các yêu cầu
            ├── test.ps1      # Script hỗ trợ chạy trên PowerShell (Windows)
            └── README.md     # Báo cáo chi tiết, phân tích kỹ thuật và kết quả test
```

---

## 🚀 Hướng Dẫn Chạy Thử Nhanh

### Lựa chọn 1: Chạy bằng Git Bash hoặc Linux Terminal
```bash
cd homework/session_10/ex4
bash commands.sh
```

### Lựa chọn 2: Chạy trên Windows PowerShell
```powershell
cd homework\session_10\ex4
.\test.ps1
```

---

## 📋 Tóm Tắt Các Lệnh Kiểm Tra Cốt Lõi

1. **Kiểm tra Custom Bridge Network:**
   ```bash
   docker network ls | grep app-net
   ```

2. **Kiểm tra Named Volume:**
   ```bash
   docker volume ls | grep db-data
   ```

3. **Kiểm tra chi tiết Network Inspect:**
   ```bash
   docker network inspect app-net
   ```

4. **Kiểm tra DNS Resolution giữa Backend và DB:**
   ```bash
   docker exec -it app-container ping -c 2 db-server
   ```

5. **Xác minh Data Persistence:**
   - Xóa cứng DB: `docker rm -f db-server`
   - Khởi động lại DB gắn volume `db-data`:
     ```bash
     docker run -d --name db-server --network app-net -v db-data:/var/lib/postgresql/data -e POSTGRES_DB=testdb -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=postgres postgres:15-alpine
     ```
   - Truy vấn kiểm tra:
     ```bash
     docker exec -it db-server psql -U postgres -d testdb -c "SELECT * FROM users;"
     ```

Chi tiết lý thuyết và hình ảnh kiến trúc được mô tả đầy đủ tại [homework/session_10/ex4/README.md](homework/session_10/ex4/README.md).
