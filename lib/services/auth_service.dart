import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String _pinKey = 'config_pin';
  static const String _defaultPin = '1234'; // PIN por defecto

  // Lee el PIN guardado (o regresa el default)
  Future<String> _getStoredPin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_pinKey) ?? _defaultPin;
  }

  /// Compatibilidad con código previo: obtener el PIN actual
  Future<String> getConfigPin() async {
    return _getStoredPin();
  }

  /// Validar PIN cuando el usuario quiere entrar a Configuración
  Future<bool> validatePin(String pin) async {
    final stored = await _getStoredPin();
    return pin == stored;
  }

  /// Actualizar el PIN (se usa desde la pantalla de configuración)
  Future<void> updatePin(String newPin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pinKey, newPin);
  }
}
