
class ErrorMessages {
  static const String noInternet = 'تعذر الاتصال بالسيرفر، تأكد من اتصالك بالإنترنت وحاول تاني';
  static const String timeout = 'استغرق الاتصال وقتاً طويلاً، حاول تاني';
  static const String badResponse = 'حدث خطأ غير متوقع أثناء معالجة البيانات، حاول تاني';
  static const String unauthorized = 'انتهت صلاحية جلستك، سجّل الدخول مرة أخرى';
  static const String generic = 'حدث خطأ ما، حاول تاني';

  static String translate(Object error) {
    final text = error.toString().toLowerCase();

    if (text.contains('socketexception') || text.contains('failed host lookup') || text.contains('network is unreachable')) {
      return noInternet;
    }
    if (text.contains('timeoutexception') || text.contains('timeout')) {
      return timeout;
    }
    if (text.contains('formatexception') || text.contains('unexpected character')) {
      return badResponse;
    }
    if (text.contains('401') || text.contains('unauthorized')) {
      return unauthorized;
    }
    if (text.contains('handshake') || text.contains('certificate')) {
      return 'حدث خطأ في الاتصال الآمن بالسيرفر، حاول تاني';
    }
    return generic;
  }
}

