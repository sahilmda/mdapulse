import 'dart:convert';
import 'dart:io';

void main() async {
  final url = Uri.parse('https://webservices.mdapulse.com/Default.aspx/Login');
  
  final client = HttpClient();
  final req = await client.postUrl(url);
  req.headers.contentType = ContentType('application', 'json', charset: 'utf-8');
  final payload = jsonEncode({
    'ClientId': 'demo',
    'UserName': 'admin',
    'Password': '123'
  });
  print('Testing Login: $payload');
  req.write(payload);
  final res = await req.close();
  final body = await res.transform(utf8.decoder).join();
  print('Status: ${res.statusCode}');
  print('Body: $body');
  client.close();
}
