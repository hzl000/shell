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

operate_time="$(TZ='GMT-8' date +%Y%m%d%H%M%S)"
echo "当前时间：$operate_time"

bundle_files=()
while IFS= read -r -d $'\0' file; do
    bundle_files+=("$file")
done < <(find /home/ubuntu/work -name "*bundle.sh" -print0 2>/dev/null)

echo "选择项目进行打包操作："
for i in "${!bundle_files[@]}"; do
    filename=$(basename "${bundle_files[i]}")
    project_code="${filename%%-bundle.sh}"
    echo "$i --- $project_code"
done
# 验证输入
while true; do
    read -p "请输入序号选择项目: " index
    
    # 验证输入是否为数字且在有效范围内
    if [[ "$index" =~ ^[0-9]+$ ]] && [ "$index" -lt "${#bundle_files[@]}" ]; then
        break
    else
        echo "非法序号:$index"
    fi
done
bundle_file="${bundle_files[index]}"
filename=$(basename "${bundle_files[index]}")
project_code="${filename%%-bundle.sh}"
project_folder=$(dirname "${bundle_files[index]}")
echo "准备执行 $project_code 打包操作,所在路径$project_folder"
echo ""

# --------git操作
git_folders=()
while IFS= read -r -d $'\0' file; do
    git_folders+=("$file")
done < <(find $project_folder -name ".git" -print0 2>/dev/null)
git_folder=""
for i in "${!git_folders[@]}"; do
    git_folder=$(dirname "${git_folders[i]}")
    if grep -q "$git_folder" "$bundle_file"; then
        break
    fi
done
if [[ -z "$git_folder" ]]; then
    echo "错误：没找到项目代码文件夹，退出脚本。"
    exit 0
fi

while ! git -C "$git_folder" ls-remote origin >/dev/null 2>&1; do
    echo "git认证失败，需要重新配置认证信息"
    git_url=""
    origin_url=""

    origin_url=$(git -C "$git_folder" remote get-url origin 2>/dev/null || true)

    if [ -n "$origin_url" ]; then
        # 还原成不带认证信息的 url
        git_url=$(sed -E 's#(http[s]?://)[^/@]+@#\1#' <<< "$origin_url")
    fi
    echo "当前仓库地址：$git_url"  
    read -p "切换“git仓库地址”吗？yes/no：" change_origin_text
    if [ -z "$git_url" ] || [[ "$change_origin_text" =~ ^[Yy]([Ee][Ss])?$ ]]; then
        while true; do
            read -p "请输入git仓库地址: " git_url
            # 判断非空且以 http:// 或 https:// 开头
            if [[ -n "$git_url" && "$git_url" =~ ^https?:// ]]; then
                break
            else
                echo "输入无效，请输入以 http:// 或 https:// 开头的仓库地址"
            fi
        done
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
    git -C "$git_folder" remote remove origin || true
    git -C "$git_folder" remote add origin "$git_full_remote"
done

echo "git分支列表："
git -C "$git_folder" branch
read -p "切换“git分支”吗？yes/no：" update_config_text
if [[ "$update_config_text" =~ ^[Yy]([Ee][Ss])?$ ]]; then
    git -C "$git_folder" fetch
    branches_array_alt=()
    while IFS= read -r branch; do
        # 去除当前分支的*标记和前后空格
        clean_branch=$(echo "$branch" | sed 's/^\*//' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
        branches_array_alt+=("$clean_branch")
    done < <(git -C "$git_folder" branch -r | grep -v "HEAD" | sed 's/origin\///')
    echo "选择git分支："
    for i in "${!branches_array_alt[@]}"; do
        echo "$i --- ${branches_array_alt[i]}"
    done
    while true; do
        read -p "请输入序号选择git分支：" index
        
        # 验证输入是否为数字且在有效范围内
        if [[ "$index" =~ ^[0-9]+$ ]] && [ "$index" -lt "${#branches_array_alt[@]}" ]; then
            break
        else
            echo "非法序号:$index"
        fi
    done
    branch_name="${branches_array_alt[index]}"
    git -C "$git_folder" checkout $branch_name
    echo ""
fi
# --------git操作

# --------配置文件夹操作
read -p "更新“配置文件夹”吗？yes/no：" update_config_text
if [[ "$update_config_text" =~ ^[Yy]([Ee][Ss])?$ ]]; then
    while true; do
        read -p "输入最新的配置文件夹压缩包路径：:" -e update_zip_path
        if [ -e "$update_zip_path" ] && [ -f "$update_zip_path" ]; then
            break
        else
            echo "配置文件夹压缩包不存在"
        fi
    done
    # 创建配置文件夹备份目录
    if [ ! -e "$project_folder/configBackup" ] || [ ! -d "$project_folder/configBackup" ]; then
        mkdir -p "$project_folder/configBackup"
    fi
    config_folders=()
    while IFS= read -r -d $'\0' file; do
        config_folders+=("$file")
    done < <(find "$project_folder" -name "*.properties" ! -path "$git_folder/*" -print0 2>/dev/null)
    config_folder=""
    for i in "${!config_folders[@]}"; do
        config_folder=$(dirname "${config_folders[i]}")
        if grep -q "$config_folder" "$bundle_file"; then
            break
        fi
    done
    if [[ -z "$config_folder" ]]; then
        echo "没找到项目配置文件夹，跳过备份原配置文件夹"
    else
        backup_name="$(basename "$config_folder")${operate_time}.zip"
        echo "备份现有的配置文件夹，备份路径：$project_folder/configBackup/$backup_name"
        zip -r "$project_folder/configBackup/$backup_name" "$config_folder"
        rm -rf "$config_folder"
    fi

    echo "检查压缩包是否存在Mac OS系统文件"
    # 使用unzip -l命令列出压缩包中的文件，并提取文件名
    file_list=$(unzip -l "$update_zip_path" | awk '{print $NF}' | tail -n +4)
    # 要查找的多个字符串
    search_strings=("DS_Store" "__MACOSX")
    # 遍历文件列表，根据文件名进行删除
    for file in $file_list; do
        # 检查文件名是否包含任何一个要查找的字符串
        for search_string in "${search_strings[@]}"; do
            if [[ "$file" == *"$search_string"* ]]; then
                # 如果包含，执行你要的操作
                zip -d $update_zip_path $file
                break  # 如果找到一个匹配，跳出内部循环
            fi
        done
    done
    echo ""

    echo "解压最新的配置文件夹压缩包"
    unzip "$update_zip_path" -d "$project_folder"
    echo ""
fi
# --------配置文件夹操作

echo "执行打包脚本：$bundle_file"
sh "$bundle_file"


