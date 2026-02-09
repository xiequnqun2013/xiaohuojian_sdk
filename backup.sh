#!/bin/bash
# Supabase 数据库备份脚本

SUPABASE_URL="http://8.161.114.102:80"
SERVICE_KEY="eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJvbGUiOiJzZXJ2aWNlX3JvbGUiLCJpYXQiOjE3NzA0NDQ2NDQsImV4cCI6MTMyODEwODQ2NH0.quYlkZGW8wis-Ouc0sdhFiEx9qgD2UJqVVCCLSskFe0"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="./backups"

mkdir -p $BACKUP_DIR

echo "开始备份: $DATE"

# 导出数据（通过 Supabase Management API 或 SQL）
# 注：需要 PostgreSQL 直连密码，从阿里云控制台获取
echo "请从阿里云控制台获取数据库密码，然后执行:"
echo "pg_dump -h 8.161.114.102 -p 5432 -U postgres -d postgres > $BACKUP_DIR/backup_$DATE.sql"

echo "备份完成!"
