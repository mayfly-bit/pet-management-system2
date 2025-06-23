-- 宠物管理系统 - Supabase 数据库初始化脚本
-- 请在 Supabase Dashboard > SQL Editor 中运行此脚本

-- 1. 创建用户扩展表
CREATE TABLE IF NOT EXISTS users (
    id UUID REFERENCES auth.users(id) PRIMARY KEY,
    email TEXT UNIQUE NOT NULL,
    display_name TEXT,
    avatar_url TEXT,
    role TEXT DEFAULT 'viewer' CHECK (role IN ('owner', 'viewer')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. 创建狗狗表
CREATE TABLE IF NOT EXISTS dogs (
    dog_id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    name TEXT NOT NULL,
    breed TEXT,
    date_of_birth DATE,
    sex TEXT CHECK (sex IN ('male', 'female')),
    weight DECIMAL(5,2),
    description TEXT,
    purchase_price DECIMAL(10,2),
    sale_price DECIMAL(10,2),
    status TEXT DEFAULT 'available' CHECK (status IN ('available', 'sold')),
    created_by UUID REFERENCES users(id) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. 创建费用类别表 (修改主键字段名为cat_id)
CREATE TABLE IF NOT EXISTS expense_categories (
    cat_id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    name TEXT NOT NULL,
    description TEXT,
    is_shared BOOLEAN DEFAULT true,
    created_by UUID REFERENCES users(id) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. 创建费用表 (修改外键字段名为cat_id)
CREATE TABLE IF NOT EXISTS expenses (
    exp_id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    cat_id TEXT REFERENCES expense_categories(cat_id) NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    date DATE NOT NULL,
    note TEXT,
    created_by UUID REFERENCES users(id) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 5. 创建费用-狗狗关联表 (修改字段名为exp_id)
CREATE TABLE IF NOT EXISTS expense_dog_link (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    exp_id TEXT REFERENCES expenses(exp_id) ON DELETE CASCADE,
    dog_id TEXT REFERENCES dogs(dog_id) ON DELETE CASCADE,
    share_ratio DECIMAL(5,4) NOT NULL DEFAULT 1.0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(exp_id, dog_id)
);

-- 6. 创建狗狗图片表
CREATE TABLE IF NOT EXISTS dog_images (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    dog_id TEXT REFERENCES dogs(dog_id) ON DELETE CASCADE,
    image_url TEXT NOT NULL,
    is_primary BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 7. 创建更新时间触发器函数
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- 8. 创建更新时间触发器
DROP TRIGGER IF EXISTS update_users_updated_at ON users;
CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_dogs_updated_at ON dogs;
CREATE TRIGGER update_dogs_updated_at
    BEFORE UPDATE ON dogs
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_expenses_updated_at ON expenses;
CREATE TRIGGER update_expenses_updated_at
    BEFORE UPDATE ON expenses
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- 9. 创建视图：狗狗利润视图 (更新字段名引用)
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

-- 10. 创建视图：月度汇总视图 (更新字段名引用)
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

-- 11. 启用行级安全性 (RLS)
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE dogs ENABLE ROW LEVEL SECURITY;
ALTER TABLE expense_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE expense_dog_link ENABLE ROW LEVEL SECURITY;
ALTER TABLE dog_images ENABLE ROW LEVEL SECURITY;

-- 12. 创建RLS策略

-- 用户表策略
DROP POLICY IF EXISTS "Users can view their own profile" ON users;
CREATE POLICY "Users can view their own profile" ON users
    FOR SELECT USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can update their own profile" ON users;
CREATE POLICY "Users can update their own profile" ON users
    FOR UPDATE USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can insert their own profile" ON users;
CREATE POLICY "Users can insert their own profile" ON users
    FOR INSERT WITH CHECK (auth.uid() = id);

-- 狗狗表策略
DROP POLICY IF EXISTS "Users can view all dogs" ON dogs;
CREATE POLICY "Users can view all dogs" ON dogs
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can insert dogs" ON dogs;
CREATE POLICY "Users can insert dogs" ON dogs
    FOR INSERT WITH CHECK (auth.uid() = created_by);

DROP POLICY IF EXISTS "Users can update their own dogs" ON dogs;
CREATE POLICY "Users can update their own dogs" ON dogs
    FOR UPDATE USING (auth.uid() = created_by);

DROP POLICY IF EXISTS "Users can delete their own dogs" ON dogs;
CREATE POLICY "Users can delete their own dogs" ON dogs
    FOR DELETE USING (auth.uid() = created_by);

-- 费用类别表策略
DROP POLICY IF EXISTS "Users can view all categories" ON expense_categories;
CREATE POLICY "Users can view all categories" ON expense_categories
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can insert categories" ON expense_categories;
CREATE POLICY "Users can insert categories" ON expense_categories
    FOR INSERT WITH CHECK (auth.uid() = created_by);

DROP POLICY IF EXISTS "Users can update their own categories" ON expense_categories;
CREATE POLICY "Users can update their own categories" ON expense_categories
    FOR UPDATE USING (auth.uid() = created_by);

-- 费用表策略
DROP POLICY IF EXISTS "Users can view all expenses" ON expenses;
CREATE POLICY "Users can view all expenses" ON expenses
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can insert expenses" ON expenses;
CREATE POLICY "Users can insert expenses" ON expenses
    FOR INSERT WITH CHECK (auth.uid() = created_by);

DROP POLICY IF EXISTS "Users can update their own expenses" ON expenses;
CREATE POLICY "Users can update their own expenses" ON expenses
    FOR UPDATE USING (auth.uid() = created_by);

DROP POLICY IF EXISTS "Users can delete their own expenses" ON expenses;
CREATE POLICY "Users can delete their own expenses" ON expenses
    FOR DELETE USING (auth.uid() = created_by);

-- 费用-狗狗关联表策略 (更新字段名引用)
DROP POLICY IF EXISTS "Users can view all expense links" ON expense_dog_link;
CREATE POLICY "Users can view all expense links" ON expense_dog_link
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can manage expense links" ON expense_dog_link;
CREATE POLICY "Users can manage expense links" ON expense_dog_link
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM expenses e 
            WHERE e.exp_id = expense_dog_link.exp_id 
            AND e.created_by = auth.uid()
        )
    );

-- 狗狗图片表策略
DROP POLICY IF EXISTS "Users can view all dog images" ON dog_images;
CREATE POLICY "Users can view all dog images" ON dog_images
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can manage dog images" ON dog_images;
CREATE POLICY "Users can manage dog images" ON dog_images
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM dogs d 
            WHERE d.dog_id = dog_images.dog_id 
            AND d.created_by = auth.uid()
        )
    );

-- 13. 创建存储桶 (Storage Bucket)
INSERT INTO storage.buckets (id, name, public) 
VALUES ('dog-images', 'dog-images', true)
ON CONFLICT (id) DO NOTHING;

-- 14. 创建存储策略
DROP POLICY IF EXISTS "Anyone can view dog images" ON storage.objects;
CREATE POLICY "Anyone can view dog images" ON storage.objects
    FOR SELECT USING (bucket_id = 'dog-images');

DROP POLICY IF EXISTS "Authenticated users can upload dog images" ON storage.objects;
CREATE POLICY "Authenticated users can upload dog images" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'dog-images' AND 
        auth.role() = 'authenticated'
    );

DROP POLICY IF EXISTS "Users can update their own dog images" ON storage.objects;
CREATE POLICY "Users can update their own dog images" ON storage.objects
    FOR UPDATE USING (
        bucket_id = 'dog-images' AND 
        auth.uid()::text = (storage.foldername(name))[1]
    );

DROP POLICY IF EXISTS "Users can delete their own dog images" ON storage.objects;
CREATE POLICY "Users can delete their own dog images" ON storage.objects
    FOR DELETE USING (
        bucket_id = 'dog-images' AND 
        auth.uid()::text = (storage.foldername(name))[1]
    );

-- 15. 插入默认费用类别 (使用正确的字段名cat_id)
INSERT INTO expense_categories (cat_id, name, description, is_shared, created_by) 
VALUES 
    ('default-cat-001', '食物费用', '狗粮、零食等食物相关费用', true, '00000000-0000-0000-0000-000000000000'),
    ('default-cat-002', '医疗费用', '疫苗、看病、体检等医疗费用', true, '00000000-0000-0000-0000-000000000000'),
    ('default-cat-003', '美容费用', '洗澡、美容、修毛等费用', true, '00000000-0000-0000-0000-000000000000'),
    ('default-cat-004', '用品费用', '玩具、用具、服装等用品费用', true, '00000000-0000-0000-0000-000000000000'),
    ('default-cat-005', '训练费用', '训练课程、行为矫正等费用', true, '00000000-0000-0000-0000-000000000000'),
    ('default-cat-006', '其他费用', '其他未分类的费用', true, '00000000-0000-0000-0000-000000000000')
ON CONFLICT (cat_id) DO NOTHING;

-- 16. 创建用户注册触发器函数
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.users (id, email, display_name, role)
    VALUES (NEW.id, NEW.email, NEW.raw_user_meta_data->>'display_name', 'owner');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 17. 创建用户注册触发器
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 完成！
-- 现在你可以在Flutter应用中使用Supabase了
-- 记得更新 lib/config/supabase_config.dart 中的URL和密钥 