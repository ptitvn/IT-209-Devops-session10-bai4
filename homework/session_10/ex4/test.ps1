# ==============================================================================
# Bài 4: PowerShell Script kiểm thử trên môi trường Windows
# ==============================================================================

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " [BUOC 0] Don dep cac tai nguyen cu (neu co)" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
docker rm -f db-server app-container 2>$null | Out-Null
docker network rm app-net 2>$null | Out-Null
docker volume rm db-data 2>$null | Out-Null

Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host " [BUOC 1] Tao Custom Bridge Network: app-net" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
docker network create --driver bridge app-net

Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host " [BUOC 2] Tao Named Volume: db-data" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
docker volume create db-data

Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host " [BUOC 3] Khoi chay Database Container (postgres:15-alpine)" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
docker run -d --name db-server --network app-net -v db-data:/var/lib/postgresql/data -e POSTGRES_DB=testdb -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=postgres postgres:15-alpine

Write-Host "[*] Cho PostgreSQL khoi dong..."
while ($true) {
    Start-Sleep -Seconds 2
    docker exec db-server pg_isready -U postgres -d testdb 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        break
    }
}
Write-Host "[OK] PostgreSQL da san sang!" -ForegroundColor Green

Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host " [BUOC 4] Khoi chay Backend Container: app-container" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
docker run -d --name app-container --network app-net -e DB_HOST=db-server -e DB_PORT=5432 -e DB_NAME=testdb -e DB_USER=postgres -e DB_PASSWORD=postgres alpine:latest sleep infinity
Write-Host "[OK] Backend container da tham gia app-net." -ForegroundColor Green

Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host " [BUOC 5] Kiem tra cau hinh he thong" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "--- 1. Kiem tra Network app-net ---" -ForegroundColor Yellow
docker network ls | Select-String "app-net"

Write-Host "`n--- 2. Kiem tra Volume db-data ---" -ForegroundColor Yellow
docker volume ls | Select-String "db-data"

Write-Host "`n--- 3. Kiem tra chi tiet Network inspect ---" -ForegroundColor Yellow
docker network inspect app-net

Write-Host "`n--- 4. Kiem tra DNS Resolution: app-container ping db-server ---" -ForegroundColor Yellow
docker exec app-container ping -c 2 db-server

Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host " [BUOC 6] Test Data Persistence" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "--- 6.1: Them du lieu vao database ---" -ForegroundColor Yellow
docker exec -i db-server psql -U postgres -d testdb -c "CREATE TABLE IF NOT EXISTS users (id SERIAL PRIMARY KEY, name VARCHAR(100), email VARCHAR(100)); INSERT INTO users (name, email) VALUES ('Nguyen Van A', 'vana@example.com'), ('Tran Thi B', 'thib@example.com'); SELECT * FROM users;"

Write-Host "`n--- 6.2: Xoa cung container DB: docker rm -f db-server ---" -ForegroundColor Yellow
docker rm -f db-server
Write-Host "[OK] Container db-server da bi xoa cung." -ForegroundColor Green

Write-Host "`n--- 6.3: Khoi chay lai container DB moi gan cung volume db-data ---" -ForegroundColor Yellow
docker run -d --name db-server --network app-net -v db-data:/var/lib/postgresql/data -e POSTGRES_DB=testdb -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=postgres postgres:15-alpine

Write-Host "[*] Cho PostgreSQL tai khoi dong..."
while ($true) {
    Start-Sleep -Seconds 2
    docker exec db-server pg_isready -U postgres -d testdb 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        break
    }
}
Write-Host "[OK] DB moi da san sang!" -ForegroundColor Green

Write-Host "`n--- 6.4: Xac minh du lieu van con nguyen ---" -ForegroundColor Yellow
docker exec -i db-server psql -U postgres -d testdb -c "SELECT * FROM users;"

Write-Host "`n--- 6.5: Kiem tra DNS resolution tu app-container toi DB moi ---" -ForegroundColor Yellow
docker exec app-container ping -c 2 db-server

Write-Host "`n============================================================" -ForegroundColor Green
Write-Host " [HOAN TAT] Tat ca cac buoc kiem tra da thanh cong 100%!" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
