#!/bin/bash

set -e


os_name=$(uname)
echo "当前系统: $os_name"
case $os_name in
  Darwin*)
    if [ -z $(which megacmd) ]; then
      if [ -z $(which brew) ]; then
        echo "没有安装Homebrew,无法用脚本上传文件。可以使用网页上传: https://mega.io/storage"
        exit -0
      else
        brew install --cask megacmd-app
        if [ ! -z $(which megacmd) ]; then
          echo "megacmd 安装成功"
        else
          echo "megacmd 安装失败"
          exit -0
        fi
      fi
    else
      echo "megacmd 已安装"
    fi
    ;;
  Linux*)
    if dpkg -l | grep -q "megacmd"; then
        echo "megacmd 已安装"
    else
      version=$(lsb_release -a | grep Release: | awk '{print $2}')
      fileName="megacmd-xUbuntu_${version}_amd64.deb"
      download_url="https://mega.nz/linux/repo/xUbuntu_${version}/amd64/${fileName}"
      if [ -e $fileName ]; then
          echo "文件已存在，不需要下载。"
      else
          if ! wget $download_url; then
            echo "下载失败！megacmd可能不兼容当前版本$version"
            exit -0
        fi
      fi
      sudo apt install "$PWD/$fileName"
      if dpkg -l | grep -q "megacmd"; then
        echo "megacmd 安装成功"
      else
        echo "megacmd 安装失败"
        exit -0
      fi
    fi
    ;;
  *)
    echo "脚本仅支持Ubuntu OS、Mac OS，不支持的操作系统,可以使用网页上传: https://mega.io/storage"
    exit -0
    ;;
esac

if mega-whoami | grep -q "e-mail"; then
  echo "megacmd 已登录可以进行文件上传了，执行'mega-logout'可以退出登录"
else
  echo 'megacmd 未登录，执行登录操作' 
  echo 'mega 是一个免费提供文件云存储的服务商'
  echo '注册地址：https://mega.nz/register'
  echo "执行命令'mega-cmd'可以进入交互式响应操作，执行'mega-xxx'可以直接执行对应的操作，更多命令参考'mega-help'"

  echo '输入账号'
  while true; do
    read mega_account
      if [ -n "$mega_account" ]; then
          break  # 退出循环，因为路径有效
      else
          echo "输入账号"
      fi
  done
  echo '输入密码'
  while true; do
    read mega_pwd
      if [ -n "$mega_pwd" ]; then
          break  # 退出循环，因为路径有效
      else
          echo "输入密码"
      fi
  done
  mega-login $mega_account $mega_pwd
  if mega-whoami | grep -q "e-mail"; then
    echo '登录成功'
  else
    echo '登录失败'
    exit -0
  fi
fi
echo ''
echo '输入需要上传到文件所在路径'
while true; do
  read -e target_path
    if [ -e "$target_path" ] && [ -f "$target_path" ]; then
      break  # 退出循环，因为路径有效
  else
        echo "请输入正确的路径！没找到文件路径: $target_path"
  fi
done
mega-put $target_path
target_name=$(basename $target_path)
echo ''
echo '输出下载地址：'
if ! mega-export -a "$target_name"; then
  mega-export "$target_name" | head -n 1
fi



