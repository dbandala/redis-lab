port 26379
sentinel resolve-hostnames yes
sentinel monitor pulse-primary redis-sentinel-primary 6379 2
sentinel down-after-milliseconds pulse-primary 5000
sentinel failover-timeout pulse-primary 10000
sentinel parallel-syncs pulse-primary 1
