import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 👈 Asegúrate de tener esto arriba
import 'dart:convert'; // para base64Decode
import 'models/app_config.dart';
import 'services/config_service.dart';
import 'models/product.dart';
import 'services/product_service.dart';
import 'services/local_config_service.dart';
import 'dart:io'; // para SocketException
import 'services/auth_service.dart';
import 'dart:async';

//import 'models/branch_company_config.dart';

void main() {
  runApp(const PriceCheckerApp());
}

class PriceCheckerApp extends StatelessWidget {
  const PriceCheckerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Checador de precios',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const WelcomeScreen(),
        '/config': (context) => const ConfigScreen(),
        '/price-checker': (context) => const PriceCheckerScreen(),
      },
    );
  }
}

/// PANTALLA DE BIENVENIDA
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final ConfigService _configService = ConfigService();
  final LocalConfigService _localConfigService = LocalConfigService();
  final AuthService _authService = AuthService();

  AppConfig? _config;
  //bool _isLoading = true;
  String? _error;

  Timer? _autoNavigateTimer; // 👈 ya lo tenías
  bool _hasAutoNavigated = false;
  int _initialNavigateDelaySeconds = 5;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    setState(() {
      _error = null;
    });

    try {
      final localConfig = await _localConfigService.loadConfig();

      final config = await _configService.fetchConfig(
        branchId: localConfig.branchId,
        companyId: localConfig.companyId,
        baseUrl: localConfig.baseUrl,
      );

      setState(() {
        _config = config;
        _initialNavigateDelaySeconds = localConfig.initialNavigateDelaySeconds;
      });

      // 👇 Intentamos programar el auto-navegado solo la primera vez
      _scheduleInitialAutoNavigateOncePerSession();
    } on SocketException {
      setState(() {
        _error =
            'Sin conexión a la red.\n\nVerifica la conexión del dispositivo e inténtalo de nuevo.';
      });
    } catch (e) {
      setState(() {
        _error =
            'Ocurrió un problema al cargar la configuración.\n\nIntenta de nuevo o revisa la configuración del servidor.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,

      floatingActionButton: FloatingActionButton(
        onPressed: _showConfigPinDialog,
        child: const Icon(Icons.settings),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

      // aquí casi no hay teclado, puedes dejarlo así
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildLogo(),
                      const SizedBox(height: 12),
                      Text(
                        _config?.branchName ?? '',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      //const SizedBox(height: 12),
                      const Text(
                        'Bienvenido al checador de precios',
                        style: TextStyle(fontSize: 20),
                        textAlign: TextAlign.center,
                      ),
                      //const SizedBox(height: 12),

                      // Botón "Iniciar aplicación"
                      SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: ElevatedButton(
                          onPressed: () {
                            _autoNavigateTimer?.cancel();
                            _hasAutoNavigated = true;
                            Navigator.pushNamed(context, '/price-checker');
                          },
                          child: const Text(
                            'INICIAR APLICACIÓN',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      if (_error != null)
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _showConfigPinDialog() async {
    final TextEditingController pinController = TextEditingController();
    String? errorText;

    final storedPin = await _authService.getConfigPin();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: const Text('Acceso a configuración'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Ingresa el PIN de configuración para continuar.',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: pinController,
                    decoration: InputDecoration(
                      labelText: 'PIN',
                      border: const OutlineInputBorder(),
                      errorText: errorText,
                    ),
                    obscureText: true,
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                  },
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final enteredPin = pinController.text.trim();
                    if (enteredPin.isEmpty) {
                      setState(() {
                        errorText = 'Ingresa el PIN';
                      });
                      return;
                    }

                    if (enteredPin == storedPin) {
                      Navigator.of(ctx).pop(); // cierra el diálogo

                      // 👇 Abrimos Config y, cuando regrese, recargamos el logo
                      Navigator.pushNamed(context, '/config').then((updated) {
                        if (updated == true) {
                          _loadConfig(); // vuelve a llamar al endpoint y refresca logo
                        }
                      });
                    } else {
                      setState(() {
                        errorText = 'PIN incorrecto';
                      });
                    }
                  },
                  child: const Text('Aceptar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildLogo() {
    final String base64Logo = _config?.companyLogoBase64 ?? '';

    // Usamos LayoutBuilder para que el logo se adapte al ancho disponible
    return LayoutBuilder(
      builder: (context, constraints) {
        // Tamaño del cuadro del logo:
        // - 60% del ancho disponible
        // - mínimo 180
        // - máximo 260
        final double size = (constraints.maxWidth * 0.9).clamp(400.0, 400.0);

        if (base64Logo.isEmpty) {
          // Si no hay logo, dejamos el cuadro blanco más grande
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade400, width: 1),
            ),
          );
        }

        try {
          final bytes = base64Decode(base64Logo);
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade400, width: 1),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.memory(bytes, fit: BoxFit.contain),
            ),
          );
        } catch (e) {
          // Si falla el decode, mostramos placeholder (también más grande)
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.redAccent, width: 1),
            ),
            child: const Center(child: Icon(Icons.broken_image, size: 48)),
          );
        }
      },
    );
  }

  void _scheduleInitialAutoNavigateOncePerSession() {
    if (_config == null || _hasAutoNavigated) return;

    _autoNavigateTimer?.cancel();

    final seconds =
        _initialNavigateDelaySeconds > 0
            ? _initialNavigateDelaySeconds
            : 5; // fallback por si alguien pone 0 o negativo

    _autoNavigateTimer = Timer(Duration(seconds: seconds), () {
      if (!mounted) return;

      _hasAutoNavigated = true;
      Navigator.pushNamed(context, '/price-checker');
    });
  }

  @override
  void dispose() {
    _autoNavigateTimer?.cancel(); // 👈
    super.dispose();
  }
}

/// PANTALLA DE CONFIGURACIÓN
class ConfigScreen extends StatefulWidget {
  const ConfigScreen({super.key});

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  final TextEditingController _branchIdController = TextEditingController();
  final TextEditingController _companyIdController = TextEditingController();
  final TextEditingController _baseUrlController = TextEditingController();
  final TextEditingController _displayDurationController =
      TextEditingController();
  final TextEditingController _autoNavigateDelayController =
      TextEditingController();

  final TextEditingController _currentPinController = TextEditingController();
  final TextEditingController _newPinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();

  final LocalConfigService _localConfigService = LocalConfigService();
  final AuthService _authService = AuthService();

  bool _isLoading = true;
  bool _showBarcodeField = false;

  @override
  void initState() {
    super.initState();
    _loadExistingConfig();
  }

  Future<void> _loadExistingConfig() async {
    final config = await _localConfigService.loadConfig();
    setState(() {
      _branchIdController.text = config.branchId.toString();
      _companyIdController.text = config.companyId.toString();
      _baseUrlController.text = config.baseUrl;
      _displayDurationController.text =
          config.displayDurationSeconds.toString();
      _showBarcodeField = config.showBarcodeField;
      _autoNavigateDelayController.text =
          config.initialNavigateDelaySeconds.toString();
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _branchIdController.dispose();
    _companyIdController.dispose();

    _currentPinController.dispose(); // 👈
    _newPinController.dispose(); // 👈
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _saveConfig() async {
    final branchText = _branchIdController.text.trim();
    final companyText = _companyIdController.text.trim();
    final baseUrlText = _baseUrlController.text.trim();
    final durationText = _displayDurationController.text.trim();
    final autoDelayText = _autoNavigateDelayController.text.trim();

    final branchId = int.tryParse(branchText);
    final companyId = int.tryParse(companyText);
    final displayDuration = int.tryParse(durationText);
    final initialNavigateDelay = int.tryParse(autoDelayText);

    if (branchId == null || companyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('branch_id y company_id deben ser números enteros'),
        ),
      );
      return;
    }

    // 👇 Lógica de cambio de PIN
    final currentPin = _currentPinController.text.trim();
    final newPin = _newPinController.text.trim();
    final confirmPin = _confirmPinController.text.trim();

    final bool wantsToChangePin =
        currentPin.isNotEmpty || newPin.isNotEmpty || confirmPin.isNotEmpty;

    if (wantsToChangePin) {
      // Validaciones básicas
      if (currentPin.isEmpty || newPin.isEmpty || confirmPin.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Para cambiar el PIN debes llenar todos los campos.'),
          ),
        );
        return;
      }

      if (newPin.length < 4) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('El nuevo PIN debe tener al menos 4 dígitos.'),
          ),
        );
        return;
      }

      if (newPin != confirmPin) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('La confirmación del PIN no coincide.')),
        );
        return;
      }

      final isCurrentValid = await _authService.validatePin(currentPin);
      if (!isCurrentValid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El PIN actual es incorrecto.')),
        );
        return;
      }

      // Si todo ok, actualizamos el PIN
      await _authService.updatePin(newPin);
    }

    // 👇 Guardamos el resto de la configuración
    await _localConfigService.saveConfig(
      branchId: branchId,
      companyId: companyId,
      baseUrl: baseUrlText.isEmpty ? null : baseUrlText,
      displayDurationSeconds: displayDuration,
      showBarcodeField: _showBarcodeField,
      initialNavigateDelaySeconds: initialNavigateDelay,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          wantsToChangePin
              ? 'Configuración y PIN guardados'
              : 'Configuración guardada',
        ),
      ),
    );

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('Configuración')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: ListView(
          children: [
            const Text(
              'Conexión al servidor',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _baseUrlController,
              decoration: const InputDecoration(
                labelText: 'URL base del servidor',
                hintText: 'Ejemplo: http://odoo-pruebas.gcp.local:11569',
                border: OutlineInputBorder(),
                //helperText: 'No incluyas la ruta del endpoint, solo la URL base',
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _companyIdController,
              decoration: const InputDecoration(
                labelText: 'Empresa',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _branchIdController,
              decoration: const InputDecoration(
                labelText: 'Tienda',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const Text(
              'Configurar tiempo de espera:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // 🕒 Tiempo de vista de producto
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Vista de producto (segundos)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _displayDurationController,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Ej. 5',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 16),

                // 🚀 Tiempo de auto-navegación
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Auto-navegación inicio (segundos)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _autoNavigateDelayController,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Ej. 5',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            SwitchListTile(
              title: const Text(
                'Mostrar campo de captura de código de barras',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Si está apagado, el campo se oculta pero el lector sigue funcionando.',
              ),
              value: _showBarcodeField,
              onChanged: (value) {
                setState(() {
                  _showBarcodeField = value;
                });
              },
            ),

            const SizedBox(height: 24),

            ExpansionTile(
              leading: const Icon(Icons.lock),
              title: const Text(
                'Seguridad',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                'Cambiar PIN de configuración',
                style: TextStyle(fontSize: 14),
              ),

              childrenPadding: const EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 8.0,
              ),
              children: [
                TextField(
                  controller: _currentPinController,
                  decoration: const InputDecoration(
                    labelText: 'PIN actual',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _newPinController,
                  decoration: const InputDecoration(
                    labelText: 'Nuevo PIN',
                    border: OutlineInputBorder(),
                    helperText: 'Mínimo 4 dígitos',
                  ),
                  obscureText: true,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _confirmPinController,
                  decoration: const InputDecoration(
                    labelText: 'Confirmar nuevo PIN',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
              ],
            ),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: _saveConfig,
                child: const Text(
                  'Guardar configuración',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

//PANTALLA DE PRODUCTO
class PriceCheckerScreen extends StatefulWidget {
  const PriceCheckerScreen({super.key});

  @override
  State<PriceCheckerScreen> createState() => _PriceCheckerScreenState();
}

class _PriceCheckerScreenState extends State<PriceCheckerScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _codeFocusNode = FocusNode();

  final ProductService _productService = ProductService();
  final LocalConfigService _localConfigService = LocalConfigService();
  final ConfigService _configService = ConfigService();

  late AnimationController _arrowController;
  late Animation<double> _arrowAnimation;

  Product? _product;
  bool _isLoading = false;
  String? _error;

  String? _companyLogoBase64; // 👈 para el logo de fondo
  Timer? _clearTimer;
  int _displayDurationSeconds = 5;
  bool _showBarcodeField = false;

  @override
  void initState() {
    super.initState();

    // Pedimos el foco al TextField al entrar a la pantalla
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestFocus();
    });
    // Cargar logo para la pantalla de espera
    _loadCompanyLogo();
    _loadDisplayDuration();
    // 👇 Animación de la flecha
    _arrowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900), // velocidad
    );

    _arrowAnimation = Tween<double>(begin: -10, end: 10).animate(
      CurvedAnimation(parent: _arrowController, curve: Curves.easeInOut),
    );

    _arrowController.repeat(reverse: true);
  }

  Future<void> _loadCompanyLogo() async {
    try {
      final localConfig = await _localConfigService.loadConfig();

      final appConfig = await _configService.fetchConfig(
        branchId: localConfig.branchId,
        companyId: localConfig.companyId,
        baseUrl: localConfig.baseUrl,
      );

      setState(() {
        _companyLogoBase64 = appConfig.companyLogoBase64;
      });
    } catch (e) {
      // Si falla, no pasa nada: solo no habrá logo de fondo
      debugPrint('Error cargando logo en PriceChecker: $e');
    }
  }

  Future<void> _loadDisplayDuration() async {
    try {
      final config =
          await _localConfigService.loadConfig(); // 👈 ya usas este service
      setState(() {
        _displayDurationSeconds = config.displayDurationSeconds;
        _showBarcodeField = config.showBarcodeField;
      });
    } catch (e) {
      debugPrint('Error cargando displayDuration: $e');
      // Si falla, se queda en 5 segundos por default
    }
  }

  void _requestFocus() {
    if (mounted) {
      _codeFocusNode.requestFocus();
    }
  }

  @override
  void dispose() {
    _clearTimer?.cancel();
    _arrowController.dispose();
    _codeController.dispose();
    _codeFocusNode.dispose();
    super.dispose();
  }

  void _startAutoClear() {
    _clearTimer?.cancel();

    _clearTimer = Timer(Duration(seconds: _displayDurationSeconds), () {
      if (!mounted) return;
      setState(() {
        _product = null;
        _error = null;
      });
      _requestFocus();
    });
  }

  Future<void> _searchProduct() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un código de barras')),
      );
      _requestFocus();
      return;
    }
    final sw = Stopwatch()..start();

    setState(() {
      _isLoading = true;
      _error = null;
      _product = null;
    });

    try {
      final config = await _localConfigService.loadConfig();
      sw.stop();
      debugPrint('fetchProduct tomó: ${sw.elapsedMilliseconds} ms');
      print(
        'Consultando producto con código: $code, empresa: ${config.companyId}, tienda: ${config.branchId}',
      );
      final product = await _productService.fetchProductByCode(
        code,
        companyId: config.companyId,
        baseUrl: config.baseUrl,
        branchId: config.branchId.toString(),
      );
      print('Producto encontrado: ${product != null}');
      setState(() {
        if (product == null) {
          _error =
              'Producto no encontrado.\n\n'
              'Verifica que el código de barras sea correcto o consulta con el área de precios.';
        } else {
          _product = product;
        }
        _isLoading = false;
      });

    _startAutoClear(); // 👈 después de mostrar info (producto o no encontrado)
    } on SocketException {
      setState(() {
        _error =
            'Sin conexión con el servidor.\n'
            'Verifica la red del dispositivo e inténtalo de nuevo.';
        _isLoading = false;
      });
      _startAutoClear(); // 👈 también limpiamos el mensaje de error tras 5s
    } catch (e) {
      debugPrint('Error al consultar precio: $e');
      setState(() {
        _error =
            'Producto no encontrado.\n\n'
            'Código escaneado: $code\n\n'
            'Verifica que el código de barras sea correcto o consulta con el área de precios.';
        _isLoading = false;
      });
      _startAutoClear(); // 👈 igual aquí
    } finally {
      _codeController.clear();
      _requestFocus();
    }
  }

  Widget _buildProductCard() {
    if (_product == null) return const SizedBox.shrink();

    final product = _product!;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double imageWidth = constraints.maxWidth * 0.35; // 35% del ancho

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(top: 24),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🖼 LADO IZQUIERDO: IMAGEN (35%)
                SizedBox(
                  width: imageWidth,
                  child: AspectRatio(
                    aspectRatio: 1, // 👈 formato 9:16 (vertical)
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _buildProductImage(product.imageBase64),
                    ),
                  ),
                ),
                const SizedBox(width: 20),

                // 📄 LADO DERECHO: TEXTOS (65%)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nombre del producto grande
                      Text(
                        product.productName,
                        style: const TextStyle(
                          fontSize: 34, // 👈 más grande
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Código y unidad
                      /*Row(
                      children: [
                        Text(
                          'Código: ${product.productCode} ',
                          style: const TextStyle(
                            fontSize: 22,            // 👈 subimos
                          ),
                        ),
                        Text(
                          ' Unidad: ${product.uom}',
                          style: const TextStyle(
                            fontSize: 22,            // 👈 subimos
                          ),
                        ),
                      ],
                    ),*/
                      const SizedBox(height: 20),

                      // Lista de precios
                      const Text(
                        'Precio de lista:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 26, // 👈 título más grande
                        ),
                      ),
                      const SizedBox(height: 10),

                      ...product.priceList.map((p) {
                        /// 📦 EMBALAJE
                        if (p.hasPackaging) {
                          return Container(
                            width: double.infinity,

                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),

                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${p.packagingName}:',
                                  style: const TextStyle(fontSize: 26),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '\$${p.totalPrice.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 26, // 👈 línea de precio grande
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        /// 🧾 PRECIO NORMAL
                        return Container(
                          width: double.infinity,

                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),

                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Desde ${p.minQuantity.toInt()} ${product.uom}:',
                                style: const TextStyle(fontSize: 24),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '\$${p.price.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 26, // 👈 línea de precio grande
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),

                      // Promociones (si hay)
                      if (product.promotions.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        const Text(
                          'Promociones:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 22, // 👈 título grande
                          ),
                        ),
                        const SizedBox(height: 10),
                        ...product.promotions.map(
                          (promo) => Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              promo.promoName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 18, // 👈 promo bien visible
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProductImage(String base64Image) {
    if (base64Image.isEmpty) {
      return Container(
        color: Colors.grey.shade200,
        child: const Center(
          child: Icon(
            Icons.image_not_supported,
            size: 48, // 👈 también más grande
          ),
        ),
      );
    }

    try {
      // 1️⃣ Primer decode: de image_url (nivel 1) a texto base64 interno
      final level1Bytes = base64Decode(base64Image);
      final innerBase64String = utf8.decode(level1Bytes).trim();

      // 2️⃣ Segundo decode: del texto interno a bytes reales de imagen
      final imageBytes = base64Decode(innerBase64String);

      return Image.memory(
        imageBytes,
        fit: BoxFit.cover, // 👈 llena el espacio 9:16
      );
    } catch (e) {
      debugPrint('Error decodificando imagen de producto: $e');
      return Container(
        color: Colors.grey.shade200,
        child: const Center(child: Icon(Icons.broken_image, size: 48)),
      );
    }
  }

  Widget _buildContentArea() {
    // 1) Si hay error (y no estamos cargando), mostramos SOLO el mensaje de error
    if (_error != null && !_isLoading) {
      // Logo de fondo (igual que en idle)
      Widget? logoWidget;
      if (_companyLogoBase64 != null && _companyLogoBase64!.isNotEmpty) {
        try {
          final bytes = base64Decode(_companyLogoBase64!);
          logoWidget = Image.memory(bytes, fit: BoxFit.contain);
        } catch (e) {
          debugPrint('Error decodificando logo en error: $e');
        }
      }

      return Stack(
        children: [
          if (logoWidget != null)
            Center(child: Opacity(opacity: 0.08, child: logoWidget)),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.red.shade200, width: 2),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 40,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w900,
                        fontSize: 24,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    // 2) Si hay producto, mostramos la ficha de producto
    if (_product != null) {
      return SingleChildScrollView(child: _buildProductCard());
    }

    // 3) Si no hay producto ni error, mostramos la pantalla de espera
    return _buildIdleView();
  }

  Widget _buildIdleView() {
    Widget? logoWidget;
    if (_companyLogoBase64 != null && _companyLogoBase64!.isNotEmpty) {
      try {
        final bytes = base64Decode(_companyLogoBase64!);
        logoWidget = Image.memory(bytes, fit: BoxFit.contain);
      } catch (e) {
        debugPrint('Error decodificando logo en idle: $e');
      }
    }

    return Stack(
      children: [
        // Fondo con logo en baja opacidad
        if (logoWidget != null)
          Center(child: Opacity(opacity: 0.08, child: logoWidget)),

        // Contenido central: flecha animada + textos
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Listo para escanear',
                style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Acerque el código de barras al lector',
                style: TextStyle(fontSize: 30),
                textAlign: TextAlign.center,
              ),
              Icon(
                Icons.view_week, // <- antes
                size: 120,
                color: Colors.black,
              ),

              //const SizedBox(height: 12),
              AnimatedBuilder(
                animation: _arrowAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _arrowAnimation.value),
                    child: child,
                  );
                },
                child: const Icon(
                  Icons.arrow_downward,
                  size: 200,
                  color: Colors.amber,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Si quieres que el contenido se ajuste cuando salga el teclado:
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              // Esto permite que todo baje cuando hay poco espacio (pantalla chica o teclado)
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 👇 Tu campo de captura (con Opacity, etc.)
                      Opacity(
                        opacity: _showBarcodeField ? 1.0 : 0.0,
                        child: TextField(
                          controller: _codeController,
                          focusNode: _codeFocusNode,
                          autofocus: true,
                          showCursor: _showBarcodeField,
                          enableInteractiveSelection: false,
                          decoration: InputDecoration(
                            labelText:
                                _showBarcodeField ? 'Código de barras' : null,
                            border:
                                _showBarcodeField
                                    ? const OutlineInputBorder()
                                    : InputBorder.none,
                            isCollapsed: !_showBarcodeField,
                            contentPadding:
                                _showBarcodeField
                                    ? const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    )
                                    : EdgeInsets.zero,
                            suffixIcon:
                                _showBarcodeField
                                    ? IconButton(
                                      icon: const Icon(Icons.search),
                                      onPressed: _searchProduct,
                                    )
                                    : null,
                          ),
                          keyboardType:
                              _showBarcodeField
                                  ? TextInputType.number
                                  : TextInputType.none,
                          textInputAction: TextInputAction.search,
                          autocorrect: false,
                          enableSuggestions: false,
                          onSubmitted: (_) {
                            print('SUBMITTED');
                            _searchProduct();
                          },
                          onTap: () {
                            if (_showBarcodeField) {
                              if (!_codeFocusNode.hasFocus) {
                                FocusScope.of(
                                  context,
                                ).requestFocus(_codeFocusNode);
                              }
                              Future.delayed(
                                const Duration(milliseconds: 2000),
                                () {
                                  SystemChannels.textInput.invokeMethod(
                                    'TextInput.show',
                                  );
                                },
                              );
                            }
                          },
                        ),
                      ),

                      if (_isLoading)
                        const Padding(
                          padding: EdgeInsets.only(top: 24.0),
                          child: Center(child: CircularProgressIndicator()),
                        ),

                      const SizedBox(height: 16),

                      // 👇 Antes era Expanded, ahora Flexible para que no reviente el layout
                      Flexible(child: _buildContentArea()),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
