#!/bin/bash

## 全局变量

# API Token
api_token="token"
# 区域 ID (Zone ID)
zone_id="zone_id"
# 目标记录 ID
record_id="record_id"
## IPv4
# 目标记录
record_name="test.test.test"
record_type="A"

echo $(date +"%Y-%m-%d %H:%M:%S")  > /tmp/DDNS.log
## 循环部分
# 最大尝试次数
max_retries=5

retry_count=0

while [ $retry_count -lt $max_retries ]; do
echo "获取本地公网IP......" >> /tmp/DDNS.log
# 利用 CloudFlare 服务检测外网 IP
record_ip=$(curl -s ip.ddnspod.com)
echo "本地公网IP:$record_ip" >> /tmp/DDNS.log
echo "获取DDNS解析IP......" >> /tmp/DDNS.log
# 主动向 CloudFlare 请求目标域名的解析结果并记录
record_ip_check_response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records?type=$record_type&name=$record_name" \
                                   -H "Authorization: Bearer $api_token" \
                                   -H "Content-Type: application/json")
record_ip_check=$(echo "$record_ip_check_response" | jq -r '.result[0].content')
echo "DDNS解析IP:$record_ip_check" >> /tmp/DDNS.log

  if [ "$record_ip" = "$record_ip_check" ]
  then   echo DDNS解析IP与本地公网IP相同，不需要更新  >> /tmp/DDNS.log
         break
  else
         echo DDNS解析IP与本机IP不同，更新DDNS解析IP为本地公网IP...... >> /tmp/DDNS.log
        # 向 CloudFlare 更新目标域名的解析结果
         update_record_response=$(curl -s --request PUT \
                                 -L https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records/$record_id \
                                 -H 'Content-Type: application/json' \
                                 -H "Authorization: Bearer $api_token" \
                                 --data "{\"content\": \"$record_ip\", \"name\": \"$record_name\", \"type\": \"$record_type\"}")

        # 利用返回值判断是否更新成功
         update_record=$(echo "$update_record_response" | jq '.success')
         if [ "$update_record" = "true" ]
         then
              echo 修改成功！>> /tmp/DDNS.log
              break
         else
              retry_count=$((retry_count + 1))
             # 记录错误时间和对应次数
              echo "$(date +"%Y-%m-%d %H:%M:%S") 错误第 $retry_count 次" >> /tmp/DDNS.log
              echo "$update_record_response"  >> /tmp/DDNS.log
              echo "$record_ip_check_response"  >> /tmp/DDNS.log
              exec "$0" "$@"
         fi
   fi
done

