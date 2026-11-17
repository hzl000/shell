#!/bin/sh
set -e

# 重启redroid
restartRedroid() {
  apt install linux-modules-extra-$(uname -r) || {
    code=$?
    echo "警告：linux-modules-extra 安装失败，错误码：$code，继续执行脚本"
  }
  modprobe binder_linux devices="binder,hwbinder,vndbinder"
  # modprobe ashmem_linux

  if ! docker ps -a --format '{{.Names}}' | grep -q "redroid11"; then
    docker run -itd --privileged \
      -v ~/data11:/data \
      -p 5555:5555 \
      --name redroid11 \
      redroid/redroid:11.0.0-latest 
  else
    docker restart redroid11
  fi
}

# 定义连接方法
connectToDevice() {
  local deviceIpPort="$1"
  local counter=1
  local connected=false

  while [ $counter -le 20 ]; do
    deviceIp=$(docker exec redroid11 ifconfig eth0 | grep "inet " | awk -F '[: ]+' '{print $4}')
    result=$(docker exec ws-scrcpy adb connect "$deviceIpPort")

    if ! [ -z "$(echo "$result" | grep "connected")" ]; then
      echo "成功连接！"
      connected=true
      break
    else
      echo "连接失败：$result"
    fi

    counter=$((counter + 1))
    sleep 1
  done

  if [ "$connected" = true ]; then
    return 0
  else
    echo "设备连接失败。退出脚本"
    return 1
  fi
}

if [ -e gapp.zip ]; then
  echo "gapp.zip 文件已存在，不需要下载。"
else
  curl -L -O https://github.com/hzl000/shell/releases/download/v1.0.0/gapp.zip
  echo "gapp.zip 下载完成。"
fi

deviceIp=$(docker exec redroid11 ifconfig eth0 | grep "inet " | awk -F '[: ]+' '{print $4}')
deviceIpPort="$deviceIp:5555"
echo "$deviceIpPort"
connectToDevice "$deviceIpPort"
echo "$(docker exec ws-scrcpy adb -s "$deviceIpPort" root)"
connectToDevice "$deviceIpPort"
docker exec ws-scrcpy adb -s "$deviceIpPort" shell "rm -rf system/priv-app/PackageInstaller"
cp -r gapp.zip /home/ubuntu/apk
docker exec ws-scrcpy adb -s "$deviceIpPort" push /apk/gapp.zip /
docker exec ws-scrcpy adb -s "$deviceIpPort" shell "unzip -o /gapp.zip"
docker exec ws-scrcpy adb -s "$deviceIpPort" shell "pm grant com.google.android.gms android.permission.ACCESS_COARSE_LOCATION"
docker exec ws-scrcpy adb -s "$deviceIpPort" shell "pm grant com.google.android.gms android.permission.ACCESS_FINE_LOCATION"
docker exec ws-scrcpy adb -s "$deviceIpPort" shell "pm grant com.google.android.setupwizard android.permission.READ_PHONE_STATE"
docker exec ws-scrcpy adb -s "$deviceIpPort" shell "pm grant com.google.android.setupwizard android.permission.READ_CONTACTS"
docker exec ws-scrcpy adb -s "$deviceIpPort" reboot
sleep 3
restartRedroid
connectToDevice "$deviceIpPort"
echo "$(docker exec ws-scrcpy adb -s "$deviceIpPort" root)"
connectToDevice "$deviceIpPort"

echo "谷歌环境配置完毕"
echo "前往Google网站进行设备认证,网址https://www.google.com/android/uncertified"
echo "认证完毕后等待几分钟重启模拟器,就能使用Play Store"


echo "运行命令获取设备的android_id"
echo "docker exec ws-scrcpy adb -s $deviceIpPort shell 'sqlite3 /data/data/com.google.android.gsf/databases/gservices.db \
          \"select * from main where name = \\\"android_id\\\";\"'"

