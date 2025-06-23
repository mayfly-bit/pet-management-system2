# 🚀 Supabase 配置指南

完整配置真实Supabase数据库的详细步骤

## 📋 配置步骤

### 1. 获取Supabase凭据

1. **登录Supabase Dashboard**：[https://supabase.com/dashboard](https://supabase.com/dashboard)

2. **创建新项目**（如果还没有）：
   - 点击 "New Project"
   - 选择组织
   - 输入项目名称：`宠物管理系统`
   - 输入数据库密码（请记住）
   - 选择地区（建议选择离你最近的）
   - 点击 "Create new project"
   - 等待2-3分钟项目创建完成

3. **获取项目凭据**：
   - 在项目Dashboard中，点击左侧 **Settings** → **API**
   - 复制以下信息：
     - **Project URL**（类似：`https://xxx.supabase.co`）
     - **anon public key**（很长的字符串）

### 2. 更新Flutter配置

打开 `lib/config/supabase_config.dart` 文件，替换以下内容：

```dart
static const String url = 'YOUR_SUPABASE_URL_HERE';
static const String anonKey = 'YOUR_SUPABASE_ANON_KEY_HERE';
```

**替换为你的实际凭据：**
```dart
static const String url = 'https://xxx.supabase.co';  // 你的Project URL
static const String anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...';  // 你的anon key
```

### 3. 初始化数据库

1. **打开SQL Editor**：
   - 在Supabase Dashboard中，点击左侧 **SQL Editor**

2. **运行初始化脚本**：
   - 复制 `supabase_setup.sql` 文件的全部内容
   - 粘贴到SQL Editor中
   - 点击 **Run** 按钮执行

3. **验证创建成功**：
   - 点击左侧 **Table Editor**
   - 你应该看到以下表格：
     - ✅ users
     - ✅ dogs  
     - ✅ expense_categories
     - ✅ expenses
     - ✅ expense_dog_link
     - ✅ dog_images

### 4. 配置存储（Storage）

1. **验证存储桶**：
   - 点击左侧 **Storage**
   - 应该看到 `dog-images` 存储桶

2. **如果没有存储桶，手动创建**：
   - 点击 "New Bucket"
   - Bucket name: `dog-images`
   - 勾选 "Public bucket"
   - 点击 "Save"

### 5. 测试连接

1. **重启Flutter应用**：
   ```bash
   flutter run -d chrome
   ```

2. **测试注册/登录**：
   - 在应用中尝试注册新账户
   - 检查是否能成功创建用户

3. **验证数据库**：
   - 在Supabase Dashboard → **Table Editor** → **users** 中
   - 应该看到刚注册的用户信息

## 🔧 配置验证清单

- [ ] ✅ 项目URL已正确配置
- [ ] ✅ anon key已正确配置  
- [ ] ✅ SQL脚本已成功执行
- [ ] ✅ 所有表格已创建
- [ ] ✅ dog-images存储桶已创建
- [ ] ✅ 应用能正常注册/登录
- [ ] ✅ 能够添加狗狗信息
- [ ] ✅ 能够记录费用

## 🛠️ 功能特性

配置完成后，你的应用将具备以下功能：

### 🔐 用户认证
- ✅ 用户注册/登录
- ✅ 密码重置
- ✅ 个人资料管理
- ✅ 安全的用户权限管理

### 🐕 狗狗管理
- ✅ 添加/编辑/删除狗狗
- ✅ 上传狗狗照片
- ✅ 记录基本信息（品种、年龄、体重等）
- ✅ 设置购买/销售价格
- ✅ 状态管理（在售/已售）

### 💰 费用管理
- ✅ 记录各种费用（食物、医疗、美容等）
- ✅ 费用分摊给不同狗狗
- ✅ 自定义费用类别
- ✅ 按时间/类别筛选费用

### 📊 数据分析
- ✅ 利润计算
- ✅ 月度报表
- ✅ 费用分类统计
- ✅ 可视化图表

### 🔒 数据安全
- ✅ 行级安全策略 (RLS)
- ✅ 用户数据隔离
- ✅ 安全的文件上传
- ✅ API访问控制

## 🐛 常见问题

### Q: 应用显示"初始化失败"
**A:** 检查URL和anon key是否正确复制，确保没有多余的空格

### Q: 无法注册用户
**A:** 确保SQL脚本已完全执行，特别是用户触发器部分

### Q: 无法上传图片
**A:** 检查Storage中是否有dog-images存储桶，且设置为public

### Q: 看不到其他用户的数据
**A:** 这是正常的，RLS策略确保用户只能看到自己的数据

## 📞 获取帮助

如果遇到问题：
1. 检查Supabase Dashboard的日志
2. 查看Flutter应用的控制台输出
3. 确认所有配置步骤都已完成

---

🎉 **配置完成后，你就拥有一个功能完整的宠物管理系统了！** 