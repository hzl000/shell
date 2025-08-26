#!/bin/bash
set -e




if ! docker inspect --format='{{.State.Status}}' ws-scrcpy 2>/dev/null | grep -q "running"; then
    echo "ws-scrcpy"
    exit 1
fi

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
echo ""
echo ""


if ! docker inspect --format='{{.State.Status}}' "$selected_container" 2>/dev/null | grep -q "running"; then
    echo "容器未启动"
    exit 1
fi

deviceIp=$(docker exec $selected_container ifconfig eth0 | grep "inet " | awk -F '[: ]+' '{print $4}')
deviceIpPort="$deviceIp:5555"

query=$(docker exec ws-scrcpy adb -s $deviceIpPort shell 'sqlite3 /data/data/com.google.android.gsf/databases/gservices.db \
          "select * from main where name = \"android_id\";"')
androidId=${query#*|}

echo "前往Google网站进行设备认证,网址https://www.google.com/android/uncertified"
echo "模拟器的Android ID=$androidId"
echo "认证完毕后等待几分钟重启模拟器,就能使用Play Store"


