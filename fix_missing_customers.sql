-- 为现有企业档案创建对应的客户记录
INSERT INTO customer (id, name, owner, collection_time, in_shared_pool, organization_id, create_time, update_time, create_user, update_user)
SELECT 
    e.customer_id,
    e.company_name,
    'admin',
    UNIX_TIMESTAMP() * 1000,
    0,
    e.organization_id,
    e.create_time,
    e.update_time,
    e.create_user,
    e.update_user
FROM enterprise_profile e
LEFT JOIN customer c ON e.customer_id = c.id
WHERE c.id IS NULL AND e.organization_id = '100001';
