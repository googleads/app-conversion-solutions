print('customer_id,conversion_action_id,gclid,gbraid,wbraid,conversion_date_time,conversion_value,currency')
for i in range(30):
  print(f'1234567890,123{i},gclid_{i},,,2021-04-26 06:10:00+08:00,0.1,USD')
for i in range(30):
  print(f'1234567890,123{i},,gbraid_{i},,2021-04-26 06:10:00+08:00,0.1,USD')
for i in range(30):
  print(f'1234567890,123{i},,,wbraid_{i},2021-04-26 06:10:00+08:00,0.1,USD')
