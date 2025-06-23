class SupabaseConfig {
  // Supabase 配置
  static const String supabaseUrl = 'https://mjiycquxzqijrxkpvjfh.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1qaXljcXV4enFpanJ4a3B2amZoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAzOTg5NDgsImV4cCI6MjA2NTk3NDk0OH0.MEnf5G8q2-LzDQEBQxtF5u3KICPSCiA7gEx50fFzxMs';
  
  // 别名属性用于向后兼容
  static const String url = supabaseUrl;
  static const String anonKey = supabaseAnonKey;
  
  // 配置已完成！现在需要在Supabase中运行SQL脚本来创建数据库表
  
  // Storage bucket names
  static const String dogImagesBucket = 'dog-images';
  
  // Table names
  static const String usersTable = 'users';
  static const String dogsTable = 'dogs';
  static const String dogImagesTable = 'dog_images';
  static const String expenseCategoriesTable = 'expense_categories';
  static const String expensesTable = 'expenses';
  static const String expenseDogLinkTable = 'expense_dog_link';
  
  // Views
  static const String dogProfitView = 'v_dog_profit';
  static const String monthlySummaryView = 'v_monthly_summary';
  
  // Edge Functions
  static const String addExpenseFunction = 'add-expense-with-split';
  static const String getProfitReportFunction = 'get-profit-report';
  static const String getMonthlyReportFunction = 'get-monthly-report';
}