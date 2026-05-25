import 'dart:convert';
import 'dart:io';

void main() async {
  final url = Uri.parse('https://webservices.mdapulse.com/Calling.aspx/fillList');
  
  Future<void> testCall(dynamic sno, dynamic showAllC) async {
    final client = HttpClient();
    final req = await client.postUrl(url);
    req.headers.contentType = ContentType('application', 'json', charset: 'utf-8');
    final payload = jsonEncode({
      'ClientId': 'demo',
      'type': 'OD',
      'sno': sno,
      'DB': 'mdapulse',
      'showAllC': showAllC
    });
    print('Testing: $payload');
    req.write(payload);
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    print('Status: ${res.statusCode}');
    print('Body: $body');
    print('---');
    client.close();
  }

  await testCall(1, 1);
  await testCall('1', 1);
  await testCall(1, '1');
  await testCall('1', '1');
}