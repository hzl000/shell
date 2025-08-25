#!/bin/bash
set -e

# 定义脚本信息数组
scripts=(
    "部署Java,Android环境:linux_env.sh"
    "拉取项目代码，配置打包脚本:pull.sh"
    "部署模拟器:deployRedroid.sh"
    "模拟器配置Google套件:gms.sh"
    "生成签名文件keystore:generateKeystore.sh"
    "查看签名的哈希散列base64编码:querySigntureHashBase64.sh"
    "生成play store上架output.zip:generatePlayStoreOutputZip.sh"
    "上传文件:megacmd.sh"
    "认证Google套件的Android ID:authGms.sh"
    "删除模拟器:deleteRedroid.sh"
)

if [ -z "$1" ]; then
    echo "请输入序号执行脚本"
    for i in "${!scripts[@]}"; do
        echo "$i--- ${scripts[$i]%%:*}"
    done
    read index
else
    index="$1"
fi

prefix_url="https://github.com/hzl000/shell/releases/download/v1.0.0/"

if [ "$index" -ge 0 ] && [ "$index" -lt "${#scripts[@]}" ]; then
    # 获取脚本信息
    script_info="${scripts[$index]}"
    
    # 提取脚本名称和文件名
    script_name="${script_info%%:*}"
    script_file="${script_info#*:}"

    echo "执行脚本: $script_name"
    sudo /bin/bash -c "$(curl -fsSL "${prefix_url}${script_file}")"
else 
    echo "没找到'$index'对应的操作"
fi
