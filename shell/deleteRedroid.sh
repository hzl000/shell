#!/bin/bash
set -e

# 获取所有使用redroid/redroid镜像的容器
containers=$(docker ps -a --format "{{.ID}} {{.Image}} {{.Names}}" | awk '$2 ~ /^redroid\/redroid/')

# 获取所有使用redroid/redroid镜像的容器
containers=$(docker ps -a --format "{{.ID}} {{.Image}} {{.Names}}" | awk '$2 ~ /^redroid\/redroid/')

# 检查是否找到容器
if [ -z "$containers" ]; then
    echo "未找到使用redroid/redroid镜像的容器"
    exit 1
fi

# 显示容器列表
echo "找到以下使用redroid/redroid镜像的容器："
echo "-------------------------------------"
printf "%-3s %-12s %-30s %s\n" "ID" "容器ID" "镜像版本" "容器名称"
echo "-------------------------------------"
counter=1
echo "$containers" | while read -r line; do
    container_id=$(echo "$line" | awk '{print $1}')
    image=$(echo "$line" | awk '{print $2}')
    name=$(echo "$line" | awk '{print $3}')
    short_id=$(echo "$container_id" | cut -c1-12)
    printf "%-3d %-12s %-30s %s\n" "$counter" "$short_id" "$image" "$name"
    counter=$((counter+1))
done
echo "-------------------------------------"

# 让用户选择容器
read -p "请输入要选择的容器编号: " choice

# 验证用户输入
if ! echo "$choice" | grep -qE '^[0-9]+$' || [ "$choice" -lt 1 ] || [ "$choice" -gt $(echo "$containers" | wc -l) ]; then
    echo "无效的选择"
    exit 1
fi

# 获取选择的容器名称
selected_container=$(echo "$containers" | sed -n "${choice}p" | awk '{print $3}')

# 存储到变量
echo "已选择容器: $selected_container"

# 获取容器所有映射的宿主机目录
host_volumes=$(docker inspect --format='{{range .Mounts}}{{if .Source}}{{.Source}} {{end}}{{end}}' "$selected_container" | xargs)

# echo "容器 $selected_container 映射的宿主机目录:"


# 后续可通过 $host_volumes 进行循环处理
echo "-----------------------"
echo "即将删除docker容器$selected_container"
for volume in $host_volumes; do
    echo "即将删除宿主机目录$volume"
done
echo "-----------------------"
read -p "确认执行输入yes: " confirm
if [ "$confirm" = "yes" ]; then
    echo "开始执行命令"    
else
    echo "停止执行命令"
    exit 1
fi

docker stop $selected_container
docker rm $selected_container
for volume in $host_volumes; do
    rm -rf $volume
done

echo "已删除docker容器$selected_container"
