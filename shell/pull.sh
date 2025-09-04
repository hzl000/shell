#!/usr/bin/env bash
set -e

urlencode() {
  local string="${1}"
  local length=${#string}
  local encoded=""
  local pos char

  for (( pos = 0 ; pos < length ; pos++ )); do
     char=${string:$pos:1}
     case "$char" in
        [a-zA-Z0-9.~_-]) encoded+="$char" ;;
        *) encoded+=$(printf '%%%02X' "'$char") ;;
     esac
  done
  echo "$encoded"
}

workFolder="/home/ubuntu/work/"

read -p "请输入项目代号: " projectCode
projectFolder="$workFolder$projectCode"
if [ ! -e "$projectFolder" ] || [ ! -d "$projectFolder" ]; then
    mkdir -p "$projectFolder"
# else
    # echo "$projectCode 项目已存在，不适用此脚本"
    # exit 0
fi
echo "--------------"
echo "项目相关的所有文件都存放在此文件夹：$projectFolder"
echo "--------------"

read -p "创建新的签名文件？yes/no:" generaSign
if [ "$generaSign" = "yes" ]; then
    while true; do
        read -p "请输入alias:" alias
        if [ -n "$alias" ]; then
            break
        fi
    done
    while true; do
        read -p "请输入storePassword:" store_password
        if [ -n "$store_password" ]; then
            break
        fi
    done
    while true; do
        read -p "请输入KeyPassword，不输默认和Password相同:" key_password
        if [ -n "$key_password" ]; then
            break
        else
            key_password="$store_password"
            break
        fi
    done
    while true; do
        read -p "请输入文件名，可以指定路径:" -e sign_path
        if [ -e "$sign_path" ] && [ -f "$sign_path" ]; then
            echo "请输入文件名，可以指定路径，文件已存在$sign_path"
        elif [ -n "$sign_path" ]; then
            break
        fi
    done
    echo "keytool -genkeypair -v -alias $alias -keyalg RSA -keysize 2048 -validity 36500 -keypass $key_password -keystore $sign_path -storepass $store_password"
    keytool -genkeypair -v -alias "$alias" -keyalg RSA -keysize 2048 -validity 36500 -keypass "$key_password" -keystore "$sign_path" -storepass "$store_password"
    generaSignPath=$(realpath "$sign_path")
    echo "新创建的签名文件路径:$generaSignPath"
fi

while true; do
    read -p "请输入配置文件夹压缩包路径:" -e zip_path
    if [ -e "$zip_path" ] && [ -f "$zip_path" ]; then
        break
    else
        echo "配置文件夹压缩包不存在"
    fi
done
configFolderName=$(zipinfo -1 "$zip_path" | head -n 1 | sed 's:/$::')
unzip "$zip_path" -d "$projectFolder"
if [ -n "$generaSignPath" ]; then
    cp -rf "$generaSignPath" "$projectFolder/$configFolderName"
fi
flavorName=$(grep "flavor=" "$projectFolder/$configFolderName/$configFolderName.properties" | cut -d'=' -f2)
if [ -z "$flavorName" ]; then
    echo "$projectFolder/$configFolderName/$configFolderName.properties找不到flavor属性"
    exit 0
fi

while true; do
    read -p "请输入git仓库地址:" git_url
    if [ -n "$git_url" ]; then
        break  # 退出循环，因为路径有效
    fi
done
read -p "输入分支名称，不输默认拉取主分支:" git_brunch
if [ -z "$git_brunch" ]; then
    codeFolderName="$(basename -s .git $git_url)"
else
    codeFolderName="$(basename -s .git $git_url)_$git_brunch"
fi

echo "设置git免登录操作"
echo "0:不设置"
echo "1:设置token免登录"
echo "2:设置账号密码免登录"
while true; do
    read -p "请输入选项(0,1,2):" git_option
    if [[ "$git_option" =~ ^[0-2]$ ]]; then
        break
    fi
done
if [ "$git_option" -eq 1 ]; then
    while true; do
        read -p "请输入git token:" git_token
        if [ -n "$git_token" ]; then
            break  # 退出循环，因为路径有效
        fi
    done
    git_full_remote=$(sed -E "s#(http[s]?://)#\1${git_token}@#" <<< "$git_url")
elif [ "$git_option" -eq 2 ]; then
    while true; do
        read -p "请输入git 用户名:" git_username
        if [ -n "$git_username" ]; then
            break  # 退出循环，因为路径有效
        fi
    done
    while true; do
        read -p "请输入git 密码:" git_pwd
        if [ -n "$git_pwd" ]; then
            break  # 退出循环，因为路径有效
        fi
    done
    encoded_username=$(urlencode "$git_username")
    encoded_pwd=$(urlencode "$git_pwd")
    git_full_remote=$(sed -E "s#(http[s]?://)#\1${encoded_username}:${encoded_pwd}@#" <<< "$git_url")
else
    git_full_remote="$git_url"
fi
if [ -z "$git_brunch" ]; then
    echo "git clone $git_full_remote $projectFolder/$codeFolderName"
    git clone $git_full_remote "$projectFolder/$codeFolderName"
else
    echo "git clone -b $git_brunch $git_full_remote $projectFolder/$codeFolderName"
    git clone -b $git_brunch $git_full_remote "$projectFolder/$codeFolderName"
fi

while true; do
    read -p "请输入打包文件aab的压缩密码:" aabZipPwd
    if [ -n "$aabZipPwd" ]; then
        break  # 退出循环，因为路径有效
    fi
done
encodedProjectCode=$(urlencode "$projectCode")
encodedProjectPath=$(urlencode "$projectFolder/$codeFolderName")
encodedConfigPath=$(urlencode "$projectFolder/$configFolderName")
encodedFlavorName=$(urlencode "$flavorName")
encodedAabZipPwd=$(urlencode "$aabZipPwd")
encodedSavePath=$(urlencode "$projectFolder/bundleZip")
bundleUrl="https://bundle-worker.a807217059.workers.dev/?projectCode=$encodedProjectCode&projectPath=$encodedProjectPath&configPath=$encodedConfigPath&flavorName=$encodedFlavorName&zipPwd=$encodedAabZipPwd&savePath=$encodedSavePath"
# echo "$bundleUrl"
wget -P "$projectFolder" --content-disposition "$bundleUrl"
downloadPath=$(ls -t "$projectFolder" | head -n1)

echo "运行打包脚本，开始打包吧！sh $projectFolder/$downloadPath"