// 后端配置（对应小程序 utils/api.js 与 utils/ai.js 中的 URL）
// 请将以下地址替换为你真实的 Supabase Edge Function 地址
class ApiConfig {
  // 生产环境替换为真实的 Edge Function 地址
  static const String baseUrl = 'https://your-project.functions.supabase.co';
  static const String aiRecognizeUrl = '$baseUrl/ai-recognize';

  // 药品条码联网查询（扫码自动追溯的数据源）。
  // 默认使用极数本源（ApiZero）「商品条码查询-免费版」接口：
  //   https://apizero.cn/marketplace/barcode-lookup
  // 免费额度：匿名每日 20 次；注册并创建 API Key 后每日 200 次（Authorization: Bearer <key>）。
  // 用户可在 App 内"药品查询 API 设置"中覆盖 URL 与 Key（持久化到 shared_preferences）。
  //
  // 请求：GET {barcodeLookupUrl}?barcode=<code>
  // 响应 JSON：
  // {
  //   "code": 0,
  //   "msg": "成功",
  //   "data": {
  //     "barcode": "6921168509256",
  //     "found": true,
  //     "name": "商品名称",
  //     "brand": "品牌",
  //     "manufacturer": "生产厂商",
  //     "spec": "规格",
  //     "image": "图片URL"
  //   },
  //   "request_id": "..."
  // }
  // 未查到时 data.found=false（其余字段为 null）。
  static const String barcodeLookupUrl = 'https://v1.apizero.cn/api/barcode-lookup';
  // 可选：极数本源 API Key（放在请求头 Authorization: Bearer <key>），用于提升每日免费额度至 200 次。
  static const String barcodeLookupKey = '';
}
