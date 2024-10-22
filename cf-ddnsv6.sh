
#!/bin/bash

## 全局变量

# API Token
api_token=token
# 区域 ID (Zone ID)
zone_id=Zone ID
# 目标记录 ID
record_id_v6=record_id



## IPv6

# 目标记录
record_name_v6=test.test.test
record_type_v6=AAAA
echo $(date +"%Y-%m-%d %H:%M:%S")  > /tmp/DDNS.log
## 循环部分
# 最大尝试次数
max_retries=5

retry_count=0

while [ $retry_count -lt $max_retries ]; do
echo "获取本地公网IP......" >> /tmp/DDNS.log
# 利用 CloudFlare 服务检测外网 IPv6
record_ip_v6=$(curl -s ip.ddnspod.com)
echo "本地公网IP:$record_ip_v6" >> /tmp/DDNS.log
echo "获取DDNS解析IP......" >> /tmp/DDNS.log
# 主动向 CloudFlare 请求目标域名的解析结果并记录
record_ip_check_response_v6=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records?type=$record_type_v6&name=$record_name_v6" \
                                   -H "Authorization: Bearer $api_token" \
                                   -H "Content-Type: application/json")
record_ip_check_v6=$(echo "$record_ip_check_response_v6" | jq -r '.result[0].content')
echo "DDNS解析IP:$record_ip_check_v6" >> /tmp/DDNS.log

  if [ "$record_ip_v6" = "$record_ip_check_v6" ]
  then   echo DDNS解析IP与本地公网IP相同，不需要更新  >> /tmp/DDNS.log
         break
  else
         echo DDNS解析IP与本机IP不同，更新DDNS解析IP为本地公网IP...... >> /tmp/DDNS.log
        # 向 CloudFlare 更新目标域名的解析结果
         update_record_response_v6=$(curl -s --request PUT \
                                 -L https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records/$record_id_v6 \
                                 -H 'Content-Type: application/json' \
                                 -H "Authorization: Bearer $api_token" \
                                 --data "{\"content\": \"$record_ip_v6\", \"name\": \"$record_name_v6\", \"type\": \"$record_type_v6\"}")

        # 利用返回值判断是否更新成功
         update_record_v6=$(echo "$update_record_response_v6" | jq '.success')
         if [ "$update_record_v6" = "true" ]
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



