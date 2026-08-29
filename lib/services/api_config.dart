// 后端配置（对应小程序 utils/api.js 与 utils/ai.js 中的 URL）
// 请将以下地址替换为你真实的 Supabase Edge Function 地址
class ApiConfig {
  // 生产环境替换为真实的 Edge Function 地址
  static const String baseUrl = 'https://your-project.functions.supabase.co';
  static const String aiRecognizeUrl = '$baseUrl/ai-recognize';
}
