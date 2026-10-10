#!lua name=ticketlib

-- Atomically reserve `qty` tickets from an inventory counter key.
-- KEYS[1] = inventory key, ARGV[1] = quantity to reserve.
-- Returns the remaining inventory on success, or -1 if not enough tickets remain.
redis.register_function('reserve_ticket', function(keys, args)
  local key = keys[1]
  local qty = tonumber(args[1])
  local current = tonumber(redis.call('GET', key))
  if current == nil then
    return redis.error_reply('no such inventory key: ' .. key)
  end
  if current >= qty then
    redis.call('DECRBY', key, qty)
    return current - qty
  end
  return -1
end)
