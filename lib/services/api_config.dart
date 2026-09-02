// 后端配置（对应小程序 utils/api.js 与 utils/ai.js 中的 URL）
// 请将以下地址替换为你真实的 Supabase Edge Function 地址
class ApiConfig {
  // 生产环境替换为真实的 Edge Function 地址
  static const String baseUrl = 'https://your-project.functions.supabase.co';
  static const String aiRecognizeUrl = '$baseUrl/ai-recognize';

  // 药品条码联网查询（扫码自动追溯的数据源）。
  // 占位：请替换为真实接口地址，或让用户在 App 内"药品查询 API 设置"中填写并覆盖。
  //
  // 期望的请求：GET {barcodeLookupUrl}?barcode=<code>
  // 期望的响应 JSON：
  // {
  //   "code": 0,
  //   "data": {
  //     "found": true,
  //     "name": "商品名称",
  //     "brand": "品牌",
  //     "manufacturer": "生产厂商",
  //     "spec": "规格",
  //     "image": "图片URL"
  //   }
  // }
  // 未查到时 data.found=false。
  static const String barcodeLookupUrl = 'https://your-medicine-lookup.example.com/api/barcode-lookup';
  // 可选：接口所需的鉴权 Key（放在请求头 Authorization 或查询参数 key 中，视接口而定）。
  static const String barcodeLookupKey = '';
}
