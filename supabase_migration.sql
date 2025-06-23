-- 宠物管理系统 - 数据库迁移脚本
-- 将现有表结构迁移到新的字段名
-- 请在 Supabase Dashboard > SQL Editor 中运行此脚本

-- 1. 首先检查并备份现有数据
-- 如果 expense_categories 表存在且使用 category_id 字段
DO $$
BEGIN
    -- 检查 expense_categories 表是否存在 category_id 列
    IF EXISTS (SELECT 1 FROM information_schema.columns 
               WHERE table_name = 'expense_categories' AND column_name = 'category_id') THEN
        
        -- 如果存在 category_id 列，则进行迁移
        RAISE NOTICE '开始迁移 expense_categories 表字段名...';
        
        -- 1. 添加新的 cat_id 列
        ALTER TABLE expense_categories ADD COLUMN IF NOT EXISTS cat_id TEXT;
        
        -- 2. 复制数据从 category_id 到 cat_id
        UPDATE expense_categories SET cat_id = category_id WHERE cat_id IS NULL;
        
        -- 3. 删除旧的外键约束（如果存在）
        ALTER TABLE expenses DROP CONSTRAINT IF EXISTS expenses_category_id_fkey;
        
        -- 4. 添加新的外键字段到 expenses 表
        ALTER TABLE expenses ADD COLUMN IF NOT EXISTS cat_id TEXT;
        
        -- 5. 复制外键数据
        UPDATE expenses SET cat_id = category_id WHERE cat_id IS NULL;
        
        -- 6. 创建新的外键约束
        ALTER TABLE expenses ADD CONSTRAINT expenses_cat_id_fkey 
            FOREIGN KEY (cat_id) REFERENCES expense_categories(cat_id);
        
        -- 7. 更新 expense_dog_link 表字段名
        IF EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'expense_dog_link' AND column_name = 'expense_id') THEN
            
            ALTER TABLE expense_dog_link ADD COLUMN IF NOT EXISTS exp_id TEXT;
            UPDATE expense_dog_link SET exp_id = expense_id WHERE exp_id IS NULL;
            
            -- 删除旧的外键约束
            ALTER TABLE expense_dog_link DROP CONSTRAINT IF EXISTS expense_dog_link_expense_id_fkey;
            
            -- 创建新的外键约束
            ALTER TABLE expense_dog_link ADD CONSTRAINT expense_dog_link_exp_id_fkey 
                FOREIGN KEY (exp_id) REFERENCES expenses(exp_id);
        END IF;
        
        -- 8. 设置新列为 NOT NULL（在数据迁移完成后）
        ALTER TABLE expense_categories ALTER COLUMN cat_id SET NOT NULL;
        ALTER TABLE expenses ALTER COLUMN cat_id SET NOT NULL;
        
        -- 9. 添加新的主键约束（如果需要）
        -- 先删除旧的主键约束，再添加新的
        BEGIN
            ALTER TABLE expense_categories DROP CONSTRAINT IF EXISTS expense_categories_pkey;
            ALTER TABLE expense_categories ADD PRIMARY KEY (cat_id);
        EXCEPTION
            WHEN others THEN
                RAISE NOTICE '主键约束更新跳过: %', SQLERRM;
        END;
        
        -- 10. 清理：删除旧字段（谨慎操作，先备份数据）
        -- 注释掉，需要手动确认后再执行
        -- ALTER TABLE expense_categories DROP COLUMN IF EXISTS category_id;
        -- ALTER TABLE expenses DROP COLUMN IF EXISTS category_id;
        -- ALTER TABLE expense_dog_link DROP COLUMN IF EXISTS expense_id;
        
        RAISE NOTICE '迁移完成！请手动验证数据正确性后，再删除旧字段。';
        
    ELSE
        RAISE NOTICE 'expense_categories 表已使用新字段名，无需迁移。';
    END IF;
    
END $$;

-- 2. 确保默认费用类别存在
INSERT INTO expense_categories (cat_id, name, description, is_shared, created_by) 
VALUES 
    ('default-cat-001', '食物费用', '狗粮、零食等食物相关费用', true, '00000000-0000-0000-0000-000000000000'),
    ('default-cat-002', '医疗费用', '疫苗、看病、体检等医疗费用', true, '00000000-0000-0000-0000-000000000000'),
    ('default-cat-003', '美容费用', '洗澡、美容、修毛等费用', true, '00000000-0000-0000-0000-000000000000'),
    ('default-cat-004', '用品费用', '玩具、用具、服装等用品费用', true, '00000000-0000-0000-0000-000000000000'),
    ('default-cat-005', '训练费用', '训练课程、行为矫正等费用', true, '00000000-0000-0000-0000-000000000000'),
    ('default-cat-006', '其他费用', '其他未分类的费用', true, '00000000-0000-0000-0000-000000000000')
ON CONFLICT (cat_id) DO NOTHING;

-- 3. 更新视图以使用新字段名
DROP VIEW IF EXISTS v_dog_profit;
CREATE OR REPLACE VIEW v_dog_profit AS
SELECT 
    d.dog_id,
    d.name,
    d.status,
    d.purchase_price,
    d.sale_price,
    COALESCE(SUM(e.amount * edl.share_ratio), 0) as total_expenses,
    CASE 
        WHEN d.status = 'sold' AND d.sale_price IS NOT NULL THEN 
            d.sale_price - COALESCE(d.purchase_price, 0) - COALESCE(SUM(e.amount * edl.share_ratio), 0)
        ELSE 
            -COALESCE(d.purchase_price, 0) - COALESCE(SUM(e.amount * edl.share_ratio), 0)
    END as current_profit
FROM dogs d
LEFT JOIN expense_dog_link edl ON d.dog_id = edl.dog_id
LEFT JOIN expenses e ON edl.exp_id = e.exp_id
GROUP BY d.dog_id, d.name, d.status, d.purchase_price, d.sale_price;

DROP VIEW IF EXISTS v_monthly_summary;
CREATE OR REPLACE VIEW v_monthly_summary AS
SELECT 
    DATE_TRUNC('month', e.date) as month,
    COUNT(DISTINCT d.dog_id) as total_dogs,
    SUM(e.amount) as total_expenses,
    COUNT(e.exp_id) as expense_count
FROM expenses e
LEFT JOIN expense_dog_link edl ON e.exp_id = edl.exp_id
LEFT JOIN dogs d ON edl.dog_id = d.dog_id
GROUP BY DATE_TRUNC('month', e.date)
ORDER BY month DESC;

-- 完成
SELECT '数据库迁移脚本执行完成！' as message; 